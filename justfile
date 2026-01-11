scheme := "Moves"
project := "Moves.xcodeproj"
version := "1.0.9"

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
@build-release:
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

# Create a release: bump version, tag, and push
# Usage: just release [patch|minor|major]
release part="patch": (update-version part)
    #!/usr/bin/env bash
    set -euo pipefail
    version=$(sed -n 's/^version := "\(.*\)"/\1/p' justfile)
    git tag "v${version}"
    git push origin main "v${version}"
    echo "Released v${version}"

# Update version (default 'patch', can be 'major', 'minor')
[no-exit-message]
update-version part="patch":
    #!/usr/bin/env bash
    set -euo pipefail
    current="{{version}}"
    IFS='.' read -r major minor patch <<< "$current"
    case "{{part}}" in
        major) major=$((major + 1)); minor=0; patch=0 ;;
        minor) minor=$((minor + 1)); patch=0 ;;
        patch) patch=$((patch + 1)) ;;
        *) echo "Invalid part: {{part}}. Use major, minor, or patch"; exit 1 ;;
    esac
    new="${major}.${minor}.${patch}"
    if sed --version &>/dev/null; then
        sed -i "s/^version := \"$current\"/version := \"$new\"/" justfile
    else
        sed -i '' "s/^version := \"$current\"/version := \"$new\"/" justfile
    fi
    git add justfile && git commit -q -m "Bump version to $new"
    echo "Updated version: $current -> $new"
