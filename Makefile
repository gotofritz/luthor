# Single entry point for local development and CI. `make check-ci` is exactly what CI runs.

SWIFTLINT_VERSION := 0.63.2
# swift-format ships with the Swift toolchain, so its version follows the toolchain.
SWIFT_FORMAT ?= swift format
SWIFTLINT ?= $(if $(wildcard .tools/swiftlint),.tools/swiftlint,swiftlint)
SWIFT_PATHS := Package.swift Sources Tests App
# The Mac app's Xcode build output; under .build so it is ignored like SwiftPM's.
APP_DERIVED_DATA := .build/xcode
# Lowest line coverage of Sources/ that `make coverage` (and so CI) accepts, in percent.
COVERAGE_MIN := 90
COVERAGE_REPORT := .build/coverage.txt
APP_BUILD := $(APP_DERIVED_DATA)/Build/Products/Release/Luthor.app
# Universal (arm64 and x86_64) release build of the CLI. Where SwiftPM puts multi-arch output depends on
# the toolchain, so ask it; `=` defers the call until a recipe needs the path.
CLI_ARCHS := --arch arm64 --arch x86_64
CLI_BUILD = $(shell swift build -c release $(CLI_ARCHS) --show-bin-path)/luthor
# Where `make install` puts the CLI and the app.
PREFIX ?= $(HOME)/.local
APP_INSTALL_DIR ?= /Applications
# Release zips; named after the tag on a tagged commit.
DIST := .build/dist
VERSION ?= $(shell git describe --tags --always --dirty)
TERRAFORM ?= terraform

.PHONY: format format-check swiftlint swiftlint-version lint lint-files build test coverage test-unit test-acceptance app cli install dist check-ci hooks tools infra infra-token

format:
	$(SWIFT_FORMAT) --in-place --recursive $(SWIFT_PATHS)

format-check:
	$(SWIFT_FORMAT) lint --strict --recursive $(SWIFT_PATHS)

swiftlint: swiftlint-version
	$(SWIFTLINT) lint --strict --quiet

swiftlint-version:
	@found="$$($(SWIFTLINT) version 2>/dev/null)"; \
	if [ -z "$$found" ]; then \
	  echo "SwiftLint not installed: run 'make tools'"; exit 1; \
	elif [ "$$found" != "$(SWIFTLINT_VERSION)" ]; then \
	  echo "SwiftLint $$found found, $(SWIFTLINT_VERSION) pinned: run 'make tools'"; exit 1; \
	fi

lint: format-check swiftlint

# Format check and lint on the given files only; used by the pre-commit hook.
lint-files: swiftlint-version
	$(SWIFT_FORMAT) lint --strict $(FILES)
	$(SWIFTLINT) lint --strict --quiet $(FILES)

build:
	swift build

test:
	swift test $(SWIFT_TEST_FLAGS)
	scripts/test-check-conventional-commit.sh
	scripts/test-check-coverage.sh

# Runs the tests with coverage on and fails below COVERAGE_MIN percent line coverage of Sources/.
coverage:
	$(MAKE) test SWIFT_TEST_FLAGS=--enable-code-coverage
	scripts/coverage-report.sh >$(COVERAGE_REPORT)
	@cat $(COVERAGE_REPORT)
	scripts/check-coverage.sh $(COVERAGE_MIN) $(COVERAGE_REPORT)

# Fast unit tests only: every test target except the acceptance tests.
test-unit:
	swift test --skip LuthorAcceptanceTests

# End-to-end behaviour tests only.
test-acceptance:
	swift test --filter LuthorAcceptanceTests

# Builds the Mac app, ad-hoc signed, into $(APP_BUILD).
app:
	xcodebuild -project App/Luthor.xcodeproj -scheme Luthor -configuration Release \
	  -destination 'generic/platform=macOS' -derivedDataPath $(APP_DERIVED_DATA) -quiet build

# Builds the luthor CLI for release, universal and ad-hoc signed, into $(CLI_BUILD).
cli:
	swift build -c release $(CLI_ARCHS) --product luthor
	codesign --force --sign - $(CLI_BUILD)

# Builds both and installs them: the CLI into $(PREFIX)/bin, the app into $(APP_INSTALL_DIR).
install: app cli
	mkdir -p $(PREFIX)/bin $(APP_INSTALL_DIR)
	install -m 0755 $(CLI_BUILD) $(PREFIX)/bin/luthor
	rm -rf $(APP_INSTALL_DIR)/Luthor.app
	ditto $(APP_BUILD) $(APP_INSTALL_DIR)/Luthor.app

# Zips the app and the CLI into $(DIST), as attached to a GitHub Release.
dist: app cli
	rm -rf $(DIST)
	mkdir -p $(DIST)
	ditto -c -k --keepParent $(APP_BUILD) $(DIST)/Luthor-$(VERSION).zip
	ditto -c -k --keepParent $(CLI_BUILD) $(DIST)/luthor-cli-$(VERSION).zip

check-ci: lint build coverage app

hooks:
	git config core.hooksPath .githooks

# Installs the pinned SwiftLint (macOS portable build) into .tools/.
tools:
	mkdir -p .tools
	curl -fsSL -o .tools/swiftlint.zip \
	  https://github.com/realm/SwiftLint/releases/download/$(SWIFTLINT_VERSION)/portable_swiftlint.zip
	unzip -o -q .tools/swiftlint.zip swiftlint -d .tools
	rm .tools/swiftlint.zip
	.tools/swiftlint version

# Applies infra/ to the GitHub repo settings: shows the plan and asks for "yes" before changing anything,
# so answering anything else is a dry run. Needs GITHUB_TOKEN; see README.
infra: infra-token
	$(TERRAFORM) -chdir=infra init -input=false
	$(TERRAFORM) -chdir=infra apply

infra-token:
	@if [ -z "$$GITHUB_TOKEN" ]; then echo "GITHUB_TOKEN not set: see 'Repository settings' in README.md"; exit 1; fi
