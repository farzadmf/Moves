scheme := "Moves"
project := "Moves.xcodeproj"
version := "1.0.5"

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
    xcodebuild -quiet -scheme {{scheme}} -configuration Debug -destination 'platform=macOS,arch=arm64' build CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO

# Build release
@release:
    xcodebuild -quiet -scheme {{scheme}} -configuration Release -destination 'platform=macOS,arch=arm64' build CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO

# Clean build artifacts
@clean:
    xcodebuild -scheme {{scheme}} clean

# Clean and rebuild
rebuild: clean build

# Run the built app
@run: build quit
    tccutil reset Accessibility dk.computersarehard.Moves 2>/dev/null || true
    open ~/Library/Developer/Xcode/DerivedData/Moves-*/Build/Products/Debug/Moves.app

# Quit the running app
@quit:
    pkill -x Moves || true

# Run tests
@test:
    xcodebuild -scheme {{scheme}} test

# List schemes
@schemes:
    xcodebuild -list -project {{project}}

# Show build settings
@settings:
    xcodebuild -scheme {{scheme}} -showBuildSettings

# Tag and push a release
@tag:
    git tag v{{version}}
    git push origin v{{version}}
