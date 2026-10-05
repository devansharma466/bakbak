# Bakbak — personal on-device dictation for macOS (Apple Silicon)
CONFIGURATION ?= release
APP_DIR ?= dist/Bakbak.app

.PHONY: build app run clean fetch

fetch:
	swift package resolve

build:
	swift build -c $(CONFIGURATION) --arch arm64

app: build
	CONFIGURATION=$(CONFIGURATION) APP_DIR="$(CURDIR)/$(APP_DIR)" ./Scripts/build_app.sh

run: app
	open "$(APP_DIR)"

clean:
	rm -rf .build dist
	swift package reset || true
