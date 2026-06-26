PROJECT     = rawm.xcodeproj
SCHEME      = rawm
APP_NAME    = rawm.app
INSTALL_DIR = /Applications

# Use the first available Apple Development certificate for signing.
# A stable cert identity preserves TCC (accessibility) permission across reinstalls.
# Ad-hoc signing ("-") changes identity every build, causing macOS to revoke the
# accessibility grant on each install and making shortcuts appear gone.
SIGNING_IDENTITY := $(shell security find-identity -v -p codesigning 2>/dev/null \
    | grep -E "Apple Development|Developer ID Application" \
    | head -1 | sed 's/.*"\(.*\)"/\1/')

SIGN_FLAGS  = CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=YES

# Resolve the DerivedData build dir at make-time so it survives DerivedData resets.
# Use $1 == "BUILT_PRODUCTS_DIR" (field match) so we don't accidentally match
# PRECOMPS_INCLUDE_HEADERS_FROM_BUILT_PRODUCTS_DIR = YES and corrupt the path.
BUILD_DIR = $(shell xcodebuild -project $(PROJECT) -scheme $(SCHEME) \
              -configuration Release -showBuildSettings 2>/dev/null \
              | awk '$$1 == "BUILT_PRODUCTS_DIR" {print $$3; exit}')

.PHONY: all build install uninstall reinstall test clean run open help

all: build

## Build release binary
build:
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) -configuration Release \
	  $(SIGN_FLAGS) build \
	  | xcpretty 2>/dev/null || xcodebuild -project $(PROJECT) -scheme $(SCHEME) \
	    -configuration Release $(SIGN_FLAGS) build

## Run tests
test:
	xcodebuild test -project $(PROJECT) -scheme $(SCHEME) \
	  -destination 'platform=macOS' $(SIGN_FLAGS) 2>&1 \
	  | xcpretty 2>/dev/null || xcodebuild test -project $(PROJECT) -scheme $(SCHEME) \
	    -destination 'platform=macOS' $(SIGN_FLAGS)

## Install release build to /Applications (quits running instance first)
install: build
	@echo "Stopping any running rawm instance..."
	-killall rawm 2>/dev/null; sleep 0.5
	@echo "Installing $(APP_NAME) → $(INSTALL_DIR)/$(APP_NAME)"
	rm -rf "$(INSTALL_DIR)/$(APP_NAME)"
	cp -R "$(BUILD_DIR)/$(APP_NAME)" "$(INSTALL_DIR)/$(APP_NAME)"
	@echo "Signing bundle (stable identity preserves TCC accessibility grant across reinstalls)..."
	@if [ -n "$(SIGNING_IDENTITY)" ]; then \
	    echo "  Using: $(SIGNING_IDENTITY)"; \
	    codesign --sign "$(SIGNING_IDENTITY)" --force --deep "$(INSTALL_DIR)/$(APP_NAME)"; \
	else \
	    echo "  WARNING: No Apple Development cert found — falling back to ad-hoc."; \
	    echo "  Accessibility permission may need to be re-granted after each install."; \
	    codesign --sign - --force --deep "$(INSTALL_DIR)/$(APP_NAME)"; \
	fi
	@echo "Launching rawm..."
	open "$(INSTALL_DIR)/$(APP_NAME)"

## Remove rawm from /Applications
uninstall:
	@echo "Stopping rawm..."
	-killall rawm 2>/dev/null; sleep 0.5
	rm -rf "$(INSTALL_DIR)/$(APP_NAME)"
	@echo "Uninstalled."

## Build, uninstall old, install new
reinstall: uninstall install

## Clean DerivedData for this project
clean:
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) clean
	@echo "Cleaned."

## Build debug and run directly from DerivedData (no install)
run:
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) -configuration Debug \
	  $(SIGN_FLAGS) build \
	  | xcpretty 2>/dev/null || xcodebuild -project $(PROJECT) -scheme $(SCHEME) \
	    -configuration Debug $(SIGN_FLAGS) build
	@DEBUG_DIR=$$(xcodebuild -project $(PROJECT) -scheme $(SCHEME) \
	  -configuration Debug -showBuildSettings 2>/dev/null \
	  | awk '/BUILT_PRODUCTS_DIR =/ {print $$3}'); \
	  open "$$DEBUG_DIR/$(APP_NAME)"

## Open project in Xcode
open:
	open $(PROJECT)

help:
	@echo "rawm Makefile targets:"
	@echo "  make build      — Release build (default)"
	@echo "  make install    — Release build + install to $(INSTALL_DIR)"
	@echo "  make uninstall  — Remove from $(INSTALL_DIR)"
	@echo "  make reinstall  — Uninstall then install"
	@echo "  make test       — Run test suite"
	@echo "  make clean      — Clean DerivedData"
	@echo "  make run        — Debug build and launch from DerivedData"
	@echo "  make open       — Open in Xcode"
