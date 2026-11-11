# kwall: shortcuts to set up, check, run and build the Flutter app (Android and Linux).
# Prerequisites: Flutter SDK; adb and an attached device or emulator for Android targets.

## DEVICE: device id from `flutter devices` (e.g. linux); default the only one connected
DEVICE ?=

APP_ID := com.knotes.app
APK    := build/app/outputs/flutter-apk/app-release.apk
ADB    := adb $(if $(DEVICE),-s $(DEVICE))
RUN_ON := $(if $(DEVICE),-d $(DEVICE))

.DEFAULT_GOAL := help
.PHONY: help deps check run logs apk linux install clean

help: ## List the targets and their arguments
	@grep -E '^[a-z-]+:.*## ' $(MAKEFILE_LIST) | awk -F':.*## ' '{printf "  %-16s %s\n", $$1, $$2}'
	@echo; echo 'Arguments (make <target> NAME=value):'
	@grep -E '^## [A-Z_]+: ' $(MAKEFILE_LIST) | sed -E 's/^## ([A-Z_]+): /\1|/' | awk -F'|' '{printf "  %-26s %s\n", $$1, $$2}'

deps: ## Install dependencies
	flutter pub get

check: ## Format check, analyze and tests
	dart format --output=none --set-exit-if-changed lib test
	flutter analyze
	flutter test

run: ## Run in debug with hot reload
	flutter run $(RUN_ON)

logs: ## Stream device logs
	flutter logs $(RUN_ON)

apk: ## Build the Android release APK
	flutter build apk --release
	@echo "$(APK)"

linux: ## Build the Linux release bundle
	flutter build linux --release

install: apk ## Build, install and launch the release APK on the device
	$(ADB) install -r $(APK)
	$(ADB) shell monkey -p $(APP_ID) -c android.intent.category.LAUNCHER 1

clean: ## Delete build outputs
	flutter clean
