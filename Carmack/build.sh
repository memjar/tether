#!/bin/bash
set -euo pipefail

PROJECT="Carmack.xcodeproj"
SCHEME="Carmack"
BUNDLE_ID="ca.axetechnologies.tether"
BUILD_DIR="build"
ARCHIVE="$BUILD_DIR/Carmack.xcarchive"
IPA_DIR="$BUILD_DIR/ipa"
GHOST_IPA_DIR="$BUILD_DIR/ghost"

cd "$(dirname "$0")"

echo "=== Carmack iOS Build ==="
echo ""

case "${1:-release}" in
  release)
    echo "[1/4] Cleaning..."
    xcodebuild clean -project "$PROJECT" -scheme "$SCHEME" -configuration Release -quiet

    echo "[2/4] Archiving (Release)..."
    xcodebuild archive \
      -project "$PROJECT" \
      -scheme "$SCHEME" \
      -configuration Release \
      -archivePath "$ARCHIVE" \
      -destination "generic/platform=iOS" \
      CODE_SIGN_STYLE=Automatic \
      -quiet

    echo "[3/4] Exporting IPA..."
    mkdir -p "$IPA_DIR"
    cat > "$BUILD_DIR/export.plist" << 'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>app-store</string>
    <key>destination</key>
    <string>upload</string>
    <key>signingStyle</key>
    <string>automatic</string>
</dict>
</plist>
PLIST

    xcodebuild -exportArchive \
      -archivePath "$ARCHIVE" \
      -exportOptionsPlist "$BUILD_DIR/export.plist" \
      -exportPath "$IPA_DIR" \
      -quiet

    echo "[4/4] Uploading to TestFlight..."
    xcrun altool --upload-app \
      -f "$IPA_DIR/Carmack.ipa" \
      -t ios \
      --apiKey "${API_KEY:-}" \
      --apiIssuer "${API_ISSUER:-}" \
      2>/dev/null || echo "NOTE: Set API_KEY and API_ISSUER env vars, or upload manually via Transporter.app"

    echo ""
    echo "=== Release build complete ==="
    echo "IPA: $IPA_DIR/Carmack.ipa"
    ;;

  ghost)
    echo "[1/3] Cleaning..."
    xcodebuild clean -project "$PROJECT" -scheme "$SCHEME" -configuration Ghost -quiet

    echo "[2/3] Building (Ghost Mode — GHOST_MODE flag active)..."
    xcodebuild build \
      -project "$PROJECT" \
      -scheme "$SCHEME" \
      -configuration Ghost \
      -destination "generic/platform=iOS" \
      CODE_SIGN_IDENTITY="" \
      CODE_SIGNING_REQUIRED=NO \
      CODE_SIGNING_ALLOWED=NO \
      -quiet

    echo "[3/3] Packaging TrollStore IPA..."
    mkdir -p "$GHOST_IPA_DIR/Payload"
    APP_PATH=$(find "$BUILD_DIR" -name "Carmack.app" -type d | head -1)
    if [ -z "$APP_PATH" ]; then
      APP_PATH=$(find ~/Library/Developer/Xcode/DerivedData -name "Carmack.app" -path "*/Ghost-iphoneos/*" -type d | head -1)
    fi
    cp -r "$APP_PATH" "$GHOST_IPA_DIR/Payload/"
    cd "$GHOST_IPA_DIR"
    zip -qr "../Carmack-ghost.tipa" Payload
    cd ..
    rm -rf ghost

    echo ""
    echo "=== Ghost build complete ==="
    echo "TrollStore IPA: $BUILD_DIR/Carmack-ghost.tipa"
    echo "Install via TrollStore or AltStore"
    ;;

  *)
    echo "Usage: ./build.sh [release|ghost]"
    echo "  release  — Archive + upload to TestFlight"
    echo "  ghost    — Build with GHOST_MODE, package unsigned .tipa for TrollStore"
    exit 1
    ;;
esac
