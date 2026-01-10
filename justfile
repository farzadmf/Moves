scheme := "Moves"
project := "Moves.xcodeproj"

# List available commands
default:
    @just --list

# First-time setup (run after cloning)
@init:
    xcodebuild -runFirstLaunch
    xcode-build-server config -scheme {{scheme}} -project {{project}}

# Regenerate buildServer.json for LSP
@config:
    xcode-build-server config -scheme {{scheme}} -project {{project}}

# Build debug
@build:
    xcodebuild -quiet -scheme {{scheme}} -configuration Debug build CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO

# Build release
@release:
    xcodebuild -quiet -scheme {{scheme}} -configuration Release build CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO

# Clean build artifacts
@clean:
    xcodebuild -scheme {{scheme}} clean

# Clean and rebuild
rebuild: clean build

# Run the built app
@run:
    open ~/Library/Developer/Xcode/DerivedData/Moves-*/Build/Products/Debug/Moves.app

# Build and run
br: build run

# Run tests
@test:
    xcodebuild -scheme {{scheme}} test

# List schemes
@schemes:
    xcodebuild -list -project {{project}}

# Show build settings
@settings:
    xcodebuild -scheme {{scheme}} -showBuildSettings
