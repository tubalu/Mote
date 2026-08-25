# Daily loop: `make` / `make run`. First time: `make install`.
.DEFAULT_GOAL := build

PROJECT  := Mote.xcodeproj
SCHEME   := Mote
CONFIG   ?= Debug
DERIVED  := build/DerivedData
XCODE    := /Applications/Xcode.app
IDENTITY := Mote Self-Signed

ifeq ($(CONFIG),Release)
APP_NAME := Mote.app
else
APP_NAME := Mote Dev.app
endif

APP := $(DERIVED)/Build/Products/$(CONFIG)/$(APP_NAME)

ifneq ($(wildcard $(XCODE)/Contents/Developer),)
export DEVELOPER_DIR := $(XCODE)/Contents/Developer
endif

XCODEBUILD := xcodebuild -project $(PROJECT) -scheme $(SCHEME) \
	-configuration $(CONFIG) -derivedDataPath $(DERIVED)
SIGNING := $(shell security find-identity -p codesigning 2>/dev/null | grep -F '$(IDENTITY)' >/dev/null && echo yes || echo no)
ifeq ($(SIGNING),no)
XCODEBUILD += CODE_SIGNING_ALLOWED=NO
endif

.PHONY: help build run test lint generate open install identity

help:
	@echo "make            Debug build (Mote Dev)"
	@echo "make run        Build and launch"
	@echo "make test       Harnesses"
	@echo "make lint       SwiftLint"
	@echo "make generate   Regenerate the Xcode project from project.yml"
	@echo "make open       Open the project in Xcode"
	@echo "make install    Install brew tools; print leftover manual steps"
	@echo "make identity   Create the $(IDENTITY) cert (once)"
	@echo "make CONFIG=Release  Release build"

generate:
	@command -v xcodegen >/dev/null || { echo "xcodegen missing. Run: make install" >&2; exit 1; }
	xcodegen generate

build: generate
	@test -n "$(DEVELOPER_DIR)" || { $(MAKE) install; exit 1; }
	$(XCODEBUILD) build

run: build
	open "$(APP)"

test:
	./Scripts/run-tests.sh

lint:
	./Scripts/lint.sh

open: generate
	open $(PROJECT)

# Brew-installs what it can. Prints only what you still have to do yourself.
install:
	@bash -euo pipefail -c '\
	need=0; \
	if command -v brew >/dev/null; then \
	  brew list xcodegen >/dev/null 2>&1 || brew install xcodegen; \
	  brew list swiftlint >/dev/null 2>&1 || brew install swiftlint; \
	else \
	  need=1; \
	  echo "Homebrew is not installed. Get it from https://brew.sh then:"; \
	  echo; \
	  echo "  brew install xcodegen swiftlint"; \
	  echo; \
	fi; \
	if [ ! -d "$(XCODE)/Contents/Developer" ]; then \
	  need=1; \
	  echo "Install Xcode 26 from the App Store (Command Line Tools cannot build this app), then:"; \
	  echo; \
	  echo "  sudo xcode-select -s $(XCODE)/Contents/Developer"; \
	  echo "  sudo xcodebuild -runFirstLaunch"; \
	  echo; \
	  open "https://apps.apple.com/app/xcode/id497799835" 2>/dev/null || true; \
	elif ! xcode-select -p 2>/dev/null | grep -q "/Xcode.app/"; then \
	  need=1; \
	  echo "Point the tools at Xcode (currently $$(xcode-select -p)):"; \
	  echo; \
	  echo "  sudo xcode-select -s $(XCODE)/Contents/Developer"; \
	  echo; \
	fi; \
	if ! security find-identity -p codesigning 2>/dev/null | grep -F "$(IDENTITY)" >/dev/null; then \
	  need=1; \
	  echo "Create the signing identity so Accessibility survives rebuilds:"; \
	  echo; \
	  echo "  make identity"; \
	  echo; \
	fi; \
	if [ "$$need" -eq 0 ]; then \
	  echo "Ready.  make        # build"; \
	  echo "        make run    # build and launch Mote Dev"; \
	else \
	  echo "Run those, then: make"; \
	fi'

identity:
	@if security find-identity -p codesigning 2>/dev/null | grep -F "$(IDENTITY)" >/dev/null; then \
	  echo "$(IDENTITY) already exists."; \
	  exit 0; \
	fi; \
	openssl req -x509 -newkey rsa:2048 -nodes -days 3650 \
	  -keyout /tmp/tc-key.pem -out /tmp/tc-cert.pem \
	  -subj "/CN=$(IDENTITY)" \
	  -addext "basicConstraints=critical,CA:false" \
	  -addext "keyUsage=critical,digitalSignature" \
	  -addext "extendedKeyUsage=critical,codeSigning"; \
	openssl pkcs12 -export -inkey /tmp/tc-key.pem -in /tmp/tc-cert.pem \
	  -name "$(IDENTITY)" -out /tmp/tc.p12 -passout pass:mote; \
	security import /tmp/tc.p12 -k ~/Library/Keychains/login.keychain-db \
	  -P mote -A -T /usr/bin/codesign; \
	rm -f /tmp/tc-key.pem /tmp/tc-cert.pem /tmp/tc.p12; \
	security find-identity -p codesigning | grep -F "$(IDENTITY)"; \
	echo "Grant Accessibility once on the next launch."
