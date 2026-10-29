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
# Where `make install` puts the app.
APP_INSTALL_DIR ?= /Applications
# Release zips; named after the tag on a tagged commit.
DIST := .build/dist
VERSION ?= $(shell git describe --tags --always --dirty)
# What About Luthor shows: the version's x.y.z (empty if untagged) and the commit count as the build.
APP_VERSION := $(shell scripts/app-version.sh '$(VERSION)')
APP_BUILD_NUMBER := $(shell git rev-list --count HEAD 2>/dev/null)
TERRAFORM ?= terraform

.PHONY: format format-check swiftlint swiftlint-version lint architecture lint-files build test coverage test-unit test-acceptance bench test-linux app install dist check-ci hooks tools infra infra-token

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

lint: format-check swiftlint architecture

# Architecture rules (domain purity, layer boundaries) and the AGENTS.md code map, checked by script.
architecture:
	scripts/check-architecture.sh

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
	scripts/test-next-version.sh
	scripts/test-app-version.sh
	scripts/test-check-version-tag.sh
	scripts/test-check-architecture.sh

# Runs the tests with coverage on and fails below COVERAGE_MIN percent line coverage of Sources/.
coverage:
	$(MAKE) test SWIFT_TEST_FLAGS=--enable-code-coverage
	scripts/coverage-report.sh >$(COVERAGE_REPORT)
	@cat $(COVERAGE_REPORT)
	scripts/check-coverage.sh $(COVERAGE_MIN) $(COVERAGE_REPORT)

# Fast unit tests only: every test target except the acceptance tests.
test-unit:
	swift test --skip LuthorAcceptanceTests --skip LuthorPerformanceTests

# End-to-end behaviour tests only.
test-acceptance:
	swift test --filter LuthorAcceptanceTests

# Launch and action timings on synthetic logs of 1, 3 and 5 years; prints the numbers (BENCH lines).
bench:
	swift test --filter LuthorPerformanceTests

# What the Linux CI job runs, and what an agent session without Xcode can run: build and test the
# package alone (no app, no lint, no coverage gate).
test-linux:
	swift build
	swift test
	scripts/check-architecture.sh

# Builds the Mac app, ad-hoc signed, into $(APP_BUILD), with the version of the tag it is built from.
app:
	xcodebuild -project App/Luthor.xcodeproj -scheme Luthor -configuration Release \
	  -destination 'generic/platform=macOS' -derivedDataPath $(APP_DERIVED_DATA) -quiet \
	  $(if $(APP_VERSION),MARKETING_VERSION=$(APP_VERSION)) \
	  $(if $(APP_BUILD_NUMBER),CURRENT_PROJECT_VERSION=$(APP_BUILD_NUMBER)) build

# Builds the app and installs it into $(APP_INSTALL_DIR).
install: app
	mkdir -p $(APP_INSTALL_DIR)
	rm -rf $(APP_INSTALL_DIR)/Luthor.app
	ditto $(APP_BUILD) $(APP_INSTALL_DIR)/Luthor.app

# Zips the app into $(DIST), as attached to a GitHub Release.
dist: app
	rm -rf $(DIST)
	mkdir -p $(DIST)
	ditto -c -k --keepParent $(APP_BUILD) '$(DIST)/Luthor-$(VERSION).zip'

check-ci: lint build coverage app

hooks:
	git config core.hooksPath .githooks

# Installs the pinned SwiftLint into .tools/: the macOS portable build, or the static Linux one.
# The Linux build has no SourceKit, so it skips the few rules that need it.
tools:
	mkdir -p .tools
	if [ "$$(uname -s)" = Linux ]; then \
	  curl -fsSL -o .tools/swiftlint.zip \
	    https://github.com/realm/SwiftLint/releases/download/$(SWIFTLINT_VERSION)/swiftlint_linux_amd64.zip; \
	  unzip -o -q .tools/swiftlint.zip swiftlint-static -d .tools; \
	  mv .tools/swiftlint-static .tools/swiftlint; \
	else \
	  curl -fsSL -o .tools/swiftlint.zip \
	    https://github.com/realm/SwiftLint/releases/download/$(SWIFTLINT_VERSION)/portable_swiftlint.zip; \
	  unzip -o -q .tools/swiftlint.zip swiftlint -d .tools; \
	fi
	rm .tools/swiftlint.zip
	.tools/swiftlint version

# Applies infra/ to the GitHub repo settings: shows the plan and asks for "yes" before changing anything,
# so answering anything else is a dry run. Needs GITHUB_TOKEN; see README.
infra: infra-token
	$(TERRAFORM) -chdir=infra init -input=false
	$(TERRAFORM) -chdir=infra apply

infra-token:
	@if [ -z "$$GITHUB_TOKEN" ]; then echo "GITHUB_TOKEN not set: see 'Repository settings' in README.md"; exit 1; fi
