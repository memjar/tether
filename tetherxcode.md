# Tether iOS — Nova Build Guide

## Pre-flight

```
Repo:     git@github.com:memjar/tether.git
Project:  TetherApp/TetherApp.xcodeproj
Bundle:   ca.axetechnologies.tether
Team:     237Q6KHJY6 (Apple Distribution: Robert Lewis)
Target:   iOS 15.0+, arm64
Version:  0.1.0 (build 1)
```

**CRITICAL:** Do NOT build over SSH. Secure Enclave signing keys are inaccessible from SSH sessions. Use Xcode GUI or a local GUI Terminal.

---

## Step 1 — Clone & open

```bash
cd ~/Developer
git clone git@github.com:memjar/tether.git
cd tether/TetherApp
open TetherApp.xcodeproj
```

If already cloned, just pull and open:
```bash
cd ~/Developer/tether && git pull
open TetherApp/TetherApp.xcodeproj
```

---

## Step 2 — Fix signing (DEVELOPMENT_TEAM is empty in pbxproj)

In Xcode:
1. Select **TetherApp** target (left sidebar > blue project icon > target)
2. **Signing & Capabilities** tab
3. Check **Automatically manage signing**
4. Set **Team** to `Robert Lewis (237Q6KHJY6)`
5. Bundle ID should read `ca.axetechnologies.tether`

If Xcode complains about the App ID, register it:
- developer.apple.com > Certificates, Identifiers & Profiles > Identifiers > `+`
- App ID type, bundle `ca.axetechnologies.tether`
- Enable: Hotspot Configuration, Access WiFi Information, Multicast Networking

---

## Step 3 — Verify build settings

In **Build Settings** (target selected, "All" filter):

| Setting | Expected |
|---------|----------|
| INFOPLIST_FILE | `Sources/TetherApp/Info.plist` |
| PRODUCT_BUNDLE_IDENTIFIER | `ca.axetechnologies.tether` |
| MARKETING_VERSION | `0.1.0` |
| CURRENT_PROJECT_VERSION | `1` |
| IPHONEOS_DEPLOYMENT_TARGET | `15.0` |
| SWIFT_VERSION | `5.0` |
| CODE_SIGN_STYLE | `Automatic` |
| DEVELOPMENT_TEAM | `237Q6KHJY6` |

---

## Step 4 — Entitlements check

File: `TetherApp.entitlements` (should already be set in target > Build Settings > CODE_SIGN_ENTITLEMENTS)

Required keys:
- `com.apple.developer.networking.HotspotConfiguration` = YES
- `com.apple.developer.networking.multicast` = YES
- `com.apple.developer.networking.wifi-info` = YES

---

## Step 5 — Build test

1. Set destination to **Any iOS Device (arm64)** (top bar, next to scheme)
2. `Cmd+B` to build
3. Fix any issues before archiving

Common fixes:
- "No such module" — make sure you opened `TetherApp/TetherApp.xcodeproj`, NOT the root `Package.swift`
- Signing errors — Step 2 wasn't completed, or App ID needs explicit registration
- BLE errors on simulator — ignore, CoreBluetooth requires physical device

---

## Step 6 — Archive

1. Destination: **Any iOS Device (arm64)**
2. Menu: **Product > Archive**
3. Wait for build (1-2 min)
4. Xcode **Organizer** window opens automatically with the archive

---

## Step 7 — Upload to TestFlight

**Use the Organizer GUI.** Do NOT use `xcodebuild -exportArchive` — macOS 26 has a known rsync bug that breaks it.

1. In Organizer, select the archive
2. Click **Distribute App**
3. Select **App Store Connect** > **Upload**
4. Keep defaults (bitcode, symbols)
5. Click **Upload**

---

## Step 8 — App Store Connect (first time only)

If the app doesn't exist yet in ASC:

1. [appstoreconnect.apple.com](https://appstoreconnect.apple.com) > My Apps > `+` > New App
2. Platform: **iOS**
3. Name: **Tether**
4. Bundle ID: `ca.axetechnologies.tether`
5. SKU: `tether-ios`
6. Primary Language: English

After upload, the build appears under **TestFlight** tab in 5-15 min.
Add yourself as internal tester to get the join link.

---

## Step 9 — Report back

Once upload succeeds, run this from GUI Terminal so studio can verify:

```bash
echo "TETHER_BUILD_REPORT" > /tmp/tether_build.log
echo "date: $(date -u +%Y-%m-%dT%H:%M:%SZ)" >> /tmp/tether_build.log
echo "archive: success" >> /tmp/tether_build.log
echo "upload: success" >> /tmp/tether_build.log
# paste the TestFlight join link:
echo "testflight_url: https://testflight.apple.com/join/XXXXXX" >> /tmp/tether_build.log
cat /tmp/tether_build.log
```

---

## Alt path — build.sh (if -exportArchive works)

From GUI Terminal only:
```bash
cd ~/Developer/tether/TetherApp
DEVELOPMENT_TEAM=237Q6KHJY6 ./build.sh release
```

This runs clean > archive > export > upload. Requires `API_KEY` and `API_ISSUER` env vars for automated upload, otherwise upload manually via Transporter.app.

Ghost mode (sideload via TrollStore):
```bash
./build.sh ghost
# Output: build/Tether-ghost.tipa
```

---

## File map

```
TetherApp/
  TetherApp.xcodeproj/       Xcode project
  TetherApp.entitlements      Signing entitlements
  Package.swift               SPM package def (iOS 15)
  build.sh                    CLI build script (release/ghost)
  Sources/TetherApp/
    TetherApp.swift            App entry point
    Info.plist                 BLE + Bonjour + network permissions
    Models/
      TetherDevice.swift       Device model
    Services/
      BeaconDiscovery.swift    Bonjour NWBrowser
      BLERadar.swift           BLE proximity scanner
      BLETether.swift          GATT client for macOS beacon
      GhostHotspot.swift       MobileWiFi private API (#if GHOST_MODE)
    Views/
      StatusView.swift         Connection status
      DeviceListView.swift     Device management
      RadarView.swift          BLE proximity radar
      SettingsView.swift       Settings
```
