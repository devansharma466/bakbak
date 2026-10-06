# Bakbak — personal on-device dictation for macOS (Apple Silicon)
CONFIGURATION ?= release
APP_DIR ?= dist/Bakbak.app

.PHONY: build app run clean fetch check-cleanup icns

fetch:
	swift package resolve

build:
	swift build -c $(CONFIGURATION) --arch arm64

app: build
	CONFIGURATION=$(CONFIGURATION) APP_DIR="$(CURDIR)/$(APP_DIR)" ./Scripts/build_app.sh

run: app
	open "$(APP_DIR)"

# Heuristic cleanup regression checks (fast; no app bundle needed)
check-cleanup:
	./Scripts/check_cleanup.sh

clean:
	rm -rf .build dist
	swift package reset || true

# macOS only — builds Resources/Bakbak.icns via iconutil
icns:
	./Scripts/generate_icns.sh
