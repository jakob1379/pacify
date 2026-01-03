# Makefile for common Flutter tasks

FLUTTER := flutter
SUDO :=

.PHONY: help setup get gen watch gen-clean analyze format sort-imports test splash clean clean-all clean-gradle stop-gradle run run-ios run-android build-android build-ios

help:
	@echo "Available targets:"
	@echo "  setup          - Install Dart/Flutter deps"
	@echo "  get            - flutter pub get"
	@echo "  gen            - Run build_runner build"
	@echo "  watch          - Run build_runner watch"
	@echo "  gen-clean      - build_runner with --delete-conflicting-outputs"
	@echo "  analyze        - Run flutter analyze"
	@echo "  format         - Format Dart files"
	@echo "  sort-imports   - Sort Dart imports"
	@echo "  test           - Run tests"
	@echo "  splash         - Generate native splash assets"
	@echo "  clean          - flutter clean + delete build artifacts"
	@echo "  clean-all      - Clean all build artifacts"
	@echo "  clean-gradle   - Clean the gradle cache"
	@echo "  stop-gradle    - Stop all gradle daemons"
	@echo "  run            - Run app (auto device)"
	@echo "  run-ios        - Run app on iOS"
	@echo "  run-android    - Run app on Android"
	@echo "  build-android  - Build Android APK (release)"
	@echo "  build-ios      - Build iOS (release)"

setup: get

get:
	$(FLUTTER) pub get

gen: get
	$(FLUTTER) packages pub run build_runner build

watch: get
	$(FLUTTER) packages pub run build_runner watch

gen-clean: get
	$(FLUTTER) packages pub run build_runner build --delete-conflicting-outputs

analyze:
	$(FLUTTER) analyze

format:
	dart format .

sort-imports:
	dart run import_sorter:main --no-comments --no-emojis

test:
	$(FLUTTER) test

splash: get
	$(FLUTTER) pub run flutter_native_splash:create

clean:
	$(FLUTTER) clean
	rm -rf build .dart_tool

clean-all: clean clean-gradle stop-gradle

clean-gradle:
	cd android && ./gradlew --no-daemon cleanBuildCache

stop-gradle:
	cd android && ./gradlew --stop

run: setup
	$(FLUTTER) run

run-ios: setup
	$(FLUTTER) run -d ios

run-android: setup
	$(FLUTTER) run -d android

build-android: setup
	$(FLUTTER) build apk --release

build-ios: setup
	$(FLUTTER) build ios --release
