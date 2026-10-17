# Single entry point for local development and CI. `make check-ci` is exactly what CI runs.

SWIFTLINT_VERSION := 0.63.2
# swift-format ships with the Swift toolchain, so its version follows the toolchain.
SWIFT_FORMAT ?= swift format
SWIFTLINT ?= $(if $(wildcard .tools/swiftlint),.tools/swiftlint,swiftlint)
SWIFT_PATHS := Package.swift Sources Tests App
# The Mac app's Xcode build output; under .build so it is ignored like SwiftPM's.
APP_DERIVED_DATA := .build/xcode

.PHONY: format format-check swiftlint swiftlint-version lint lint-files build test app check-ci hooks tools

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
	swift test
	scripts/test-check-conventional-commit.sh

# Builds the Mac app, ad-hoc signed, into $(APP_DERIVED_DATA)/Build/Products/Release/Luthor.app.
app:
	xcodebuild -project App/Luthor.xcodeproj -scheme Luthor -configuration Release \
	  -destination 'generic/platform=macOS' -derivedDataPath $(APP_DERIVED_DATA) -quiet build

check-ci: lint build test app

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
