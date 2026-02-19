SCHEME = Jerboa
DESTINATION = platform=macOS
APP_NAME = Jerboa.app
CONFIGURATION = Release
DERIVED_DATA = $(HOME)/Library/Developer/Xcode/DerivedData

.PHONY: all generate build run test uitest test-package clean lint deploy

all: generate build

# Generate .xcodeproj from project.yml
generate:
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

# Create DMG for distribution
dmg: sign
	@app=$$(find $(DERIVED_DATA)/Jerboa-*/Build/Products/$(CONFIGURATION) -name "$(APP_NAME)" -maxdepth 1 2>/dev/null | head -1); \
	create-dmg \
		--volname "Jerboa" \
		--window-pos 200 120 \
		--window-size 600 400 \
		--icon-size 100 \
		--icon "$(APP_NAME)" 150 190 \
		--app-drop-link 450 190 \
		Jerboa.dmg \
		"$$app"

# Deploy to personal machine via Tailscale
DEPLOY_HOST = personal
DEPLOY_PATH = ~/Desktop
SSH_OPTS = -o IdentitiesOnly=yes -o PreferredAuthentications=publickey,keyboard-interactive,password

deploy: sign
	@app=$$(find $(DERIVED_DATA)/Jerboa-*/Build/Products/$(CONFIGURATION) -name "$(APP_NAME)" -maxdepth 1 2>/dev/null | head -1); \
	rsync -az -e "ssh $(SSH_OPTS)" "$$app" $(DEPLOY_HOST):$(DEPLOY_PATH)/ && \
	ssh $(SSH_OPTS) $(DEPLOY_HOST) '/usr/bin/xattr -cr $(DEPLOY_PATH)/$(APP_NAME)'

# Clean build artifacts
clean:
	rm -rf Jerboa.xcodeproj
	cd Shared && swift package clean
