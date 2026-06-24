#!/bin/bash
set -euo pipefail

IDENTITY="${SIDELOADER_IDENTITY:-Apple Distribution: Robert Lewis (237Q6KHJY6)}"
BUNDLE_ID="ca.axetechnologies.tether"
TEAM_ID="237Q6KHJY6"

usage() {
    echo "usage: sign.sh <input.ipa> [--ghost] [--profile <path>] [--output <path>]"
    exit 1
}

INPUT=""
GHOST=false
PROFILE=""
OUTPUT=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --ghost)   GHOST=true; shift ;;
        --profile) PROFILE="$2"; shift 2 ;;
        --output)  OUTPUT="$2"; shift 2 ;;
        -h|--help) usage ;;
        *)         INPUT="$1"; shift ;;
    esac
done

[[ -z "$INPUT" ]] && usage
[[ ! -f "$INPUT" ]] && echo "error: $INPUT not found" && exit 1

WORK=$(mktemp -d)
trap "rm -rf '$WORK'" EXIT

echo "[sign] extracting $INPUT"
unzip -q "$INPUT" -d "$WORK"

APP=$(find "$WORK/Payload" -name "*.app" -maxdepth 1 | head -1)
[[ -z "$APP" ]] && echo "error: no .app in IPA" && exit 1
echo "[sign] found bundle: $(basename "$APP")"

if [[ -n "$PROFILE" && -f "$PROFILE" ]]; then
    cp "$PROFILE" "$APP/embedded.mobileprovision"
    echo "[sign] embedded profile: $PROFILE"
fi

ENT="$WORK/entitlements.plist"
if $GHOST; then
    echo "[sign] writing GHOST entitlements"
    cat > "$ENT" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>application-identifier</key><string>${TEAM_ID}.${BUNDLE_ID}</string>
    <key>com.apple.developer.team-identifier</key><string>${TEAM_ID}</string>
    <key>com.apple.developer.networking.HotspotConfiguration</key><true/>
    <key>com.apple.developer.networking.multicast</key><true/>
    <key>com.apple.developer.networking.wifi-info</key><true/>
    <key>com.apple.private.security.no-sandbox</key><true/>
    <key>platform-application</key><true/>
    <key>com.apple.private.mobileinstall.allowedSPI</key>
    <array><string>Lookup</string><string>Install</string><string>Browse</string></array>
</dict>
</plist>
PLIST
else
    echo "[sign] writing standard entitlements"
    cat > "$ENT" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>application-identifier</key><string>${TEAM_ID}.${BUNDLE_ID}</string>
    <key>com.apple.developer.team-identifier</key><string>${TEAM_ID}</string>
    <key>com.apple.developer.networking.HotspotConfiguration</key><true/>
    <key>com.apple.developer.networking.multicast</key><true/>
    <key>com.apple.developer.networking.wifi-info</key><true/>
</dict>
</plist>
PLIST
fi

echo "[sign] signing with: $IDENTITY"
codesign --force --sign "$IDENTITY" \
    --entitlements "$ENT" \
    --timestamp \
    --generate-entitlement-der \
    "$APP"

codesign -dvvv "$APP" 2>&1 | grep -E "Authority|TeamIdentifier|Identifier"

VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$APP/Info.plist" 2>/dev/null || echo "0.0.0")
BUILD=$(/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" "$APP/Info.plist" 2>/dev/null || echo "1")
TAG=$($GHOST && echo "ghost" || echo "release")

if [[ -z "$OUTPUT" ]]; then
    OUTPUT="tether-${VERSION}-${BUILD}-${TAG}.ipa"
fi

echo "[sign] packaging $OUTPUT"
cd "$WORK"
zip -qr "$OLDPWD/$OUTPUT" Payload
cd "$OLDPWD"

SHA=$(shasum -a 256 "$OUTPUT" | cut -d' ' -f1)
SIZE=$(stat -f%z "$OUTPUT" 2>/dev/null || stat -c%s "$OUTPUT")

echo "[sign] done"
echo "  ipa:     $OUTPUT"
echo "  version: $VERSION ($BUILD)"
echo "  mode:    $TAG"
echo "  sha256:  $SHA"
echo "  size:    $SIZE bytes"
