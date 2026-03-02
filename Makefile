SCHEME = Jerboa
DESTINATION = platform=macOS
APP_NAME = Jerboa.app
CONFIGURATION = Release
DERIVED_DATA = $(HOME)/Library/Developer/Xcode/DerivedData

.PHONY: all generate build run test uitest test-package clean lint install zip

all: generate build

# Generate .xcodeproj from project.yml
generate:
	@mkdir -p BuildConfig
	@echo "GIT_SHA = $$(git rev-parse --short HEAD 2>/dev/null || echo unknown)" > BuildConfig/GitInfo.xcconfig
	xcodegen generate

# Build the app
build: generate
	xcodebuild build \
		-scheme $(SCHEME) \
		-destination '$(DESTINATION)' \
		-configuration $(CONFIGURATION) \
		CODE_SIGNING_ALLOWED=NO

# Build for debugging
debug: generate
	xcodebuild build \
		-scheme $(SCHEME) \
		-destination '$(DESTINATION)' \
		-configuration Debug \
		CODE_SIGNING_ALLOWED=NO

# Run the app (debug build)
run: debug
	@app=$$(find $(DERIVED_DATA)/Jerboa-*/Build/Products/Debug -name "$(APP_NAME)" -maxdepth 1 2>/dev/null | head -1); \
	if [ -n "$$app" ]; then open "$$app"; else echo "App not found. Build first."; exit 1; fi

# Run Xcode project tests
test: generate
	xcodebuild test \
		-scheme $(SCHEME) \
		-destination '$(DESTINATION)' \
		CODE_SIGNING_ALLOWED=NO

# Run UI tests (requires signing — uses separate scheme like timer-app)
uitest: generate
	xcodebuild -quiet test \
		-scheme JerboaUITests \
		-destination '$(DESTINATION)' \
		-allowProvisioningUpdates

# Run Swift package tests
test-package:
	cd Shared && swift test

# Run SwiftLint
lint:
	swiftlint lint --config .swiftlint.yml App/ QuickLook/ Tests/

# Ad-hoc sign the release build
sign: build
	@app=$$(find $(DERIVED_DATA)/Jerboa-*/Build/Products/$(CONFIGURATION) -name "$(APP_NAME)" -maxdepth 1 2>/dev/null | head -1); \
	codesign --sign - --force --deep "$$app"

# Create zip for distribution
zip: sign
	@app=$$(find $(DERIVED_DATA)/Jerboa-*/Build/Products/$(CONFIGURATION) -name "$(APP_NAME)" -maxdepth 1 2>/dev/null | head -1); \
	ditto -c -k --sequesterRsrc --keepParent "$$app" Jerboa.zip


# Install app and CLI
install: sign
	@app=$$(find $(DERIVED_DATA)/Jerboa-*/Build/Products/$(CONFIGURATION) -name "$(APP_NAME)" -maxdepth 1 2>/dev/null | head -1); \
	if [ -z "$$app" ]; then echo "App not found. Build first."; exit 1; fi; \
	rm -rf /Applications/$(APP_NAME) && \
	cp -R "$$app" /Applications/$(APP_NAME) && \
	echo "Installed $(APP_NAME) to /Applications/" && \
	ln -sf /Applications/$(APP_NAME)/Contents/MacOS/Jerboa /usr/local/bin/jerboa && \
	echo "Symlinked jerboa to /usr/local/bin/jerboa"

# Clean build artifacts
clean:
	rm -rf Jerboa.xcodeproj
	cd Shared && swift package clean
