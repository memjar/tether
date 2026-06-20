# Tether TestFlight Build Guide
## For jl1 (M1 Max, Xcode)

---

## Prerequisites

- jl1 has Xcode installed with iOS SDK
- Apple Developer account signed in (Xcode > Settings > Accounts)
- Bundle ID registered: `diy.tether.carmack` (or whatever you choose)

---

## Step 1: Clone the Repo

```bash
git clone git@github.com:memjar/tether.git
cd tether
```

---

## Step 2: Generate Xcode Project for Carmack (iOS)

```bash
cd Carmack
swift package generate-xcodeproj
# OR open directly:
open Package.swift
```

Xcode will open and resolve the package. Select the `CarmackApp` scheme.

---

## Step 3: Configure Signing

1. Select the **CarmackApp** target in Xcode
2. Go to **Signing & Capabilities**
3. Set **Team** to your Apple Developer team
4. Set **Bundle Identifier** to `diy.tether.carmack`
5. Check **Automatically manage signing**

### Add Entitlements

The entitlements file is at `Carmack/CarmackApp.entitlements`. In Xcode:

1. Go to target > **Signing & Capabilities** > **+ Capability**
2. Add: **Hotspot Configuration**
3. Add: **Multicast Networking**
4. Add: **Access WiFi Information**
5. Verify these match what's in `CarmackApp.entitlements`

### Add Info.plist Keys

Already configured in `Carmack/Sources/CarmackApp/Info.plist`:
- `NSBluetoothAlwaysUsageDescription` — BLE radar
- `NSBluetoothPeripheralUsageDescription` — BLE advertising
- `NSLocalNetworkUsageDescription` — Bonjour discovery
- `NSBonjourServices` — `_tether._tcp`

If Xcode doesn't pick up the Info.plist automatically, set it in Build Settings:
**INFOPLIST_FILE** = `Sources/CarmackApp/Info.plist`

---

## Step 4: Set Build Configuration

In Xcode, select the CarmackApp target:

| Setting | Value |
|---------|-------|
| Deployment Target | iOS 16.0 |
| Device | iPhone (arm64) |
| Build Configuration | Release |
| MARKETING_VERSION | 1.0.0 |
| CURRENT_PROJECT_VERSION | 1 |
| PRODUCT_BUNDLE_IDENTIFIER | diy.tether.carmack |
| PRODUCT_NAME | Tether |

---

## Step 5: Archive

1. Select destination: **Any iOS Device (arm64)**
2. Menu: **Product > Archive**
3. Wait for build to complete
4. Xcode Organizer opens with the archive

---

## Step 6: Upload to TestFlight

1. In the Organizer, select the archive
2. Click **Distribute App**
3. Select **App Store Connect**
4. Select **Upload**
5. Follow prompts (keep defaults for bitcode, symbols)
6. Click **Upload**

---

## Step 7: App Store Connect

1. Go to [appstoreconnect.apple.com](https://appstoreconnect.apple.com)
2. Navigate to **My Apps** > **Tether** (create if needed)
3. Go to **TestFlight** tab
4. The build will appear after processing (5-15 min)
5. Add yourself as an internal tester
6. You'll get a TestFlight invite email/notification

### If Creating the App for First Time

1. Click **+** > **New App**
2. Platform: **iOS**
3. Name: **Tether**
4. Bundle ID: select `diy.tether.carmack`
5. SKU: `tether-ios`
6. Primary Language: English

---

## Step 8: Update tether.diy

Once you have the TestFlight link (format: `https://testflight.apple.com/join/XXXXXX`), update the download page:

```bash
# On studio or wherever you edit the site
# Edit docs/download.html — replace the TestFlight button href
```

---

## Architecture Reference

### What the iOS App Does

| Feature | How It Works |
|---------|-------------|
| Discover Mac beacon | NWBrowser scans for `_tether._tcp` Bonjour |
| Live status | BLETether subscribes to GATT status characteristic |
| Radio info | BLETether subscribes to GATT radio characteristic |
| Remote control | BLETether writes JSON to GATT command characteristic |
| Device radar | BLERadar scans all BLE peripherals, estimates distance |
| Ghost hotspot | MobileWiFi private API (sideload only, `#if GHOST_MODE`) |

### Files in Carmack

```
CarmackApp.swift          — App entry, wires beacon + radar + tether
Services/
  BeaconDiscovery.swift   — Bonjour NWBrowser, TCP JSON control
  BLERadar.swift          — BLE proximity scanner
  BLETether.swift         — GATT client for macOS Tether service
  GhostHotspot.swift      — MobileWiFi hotspot toggle (ghost mode)
Models/
  TetherDevice.swift      — Device model + BeaconStatus/BeaconInfo
Views/
  StatusView.swift        — Connection status + sharing info
  DeviceListView.swift    — Connected device management
  RadarView.swift         — BLE proximity radar
  SettingsView.swift      — App settings
```

### Required Capabilities (Already Configured)

| Capability | Entitlement Key | Why |
|------------|----------------|-----|
| Hotspot Configuration | `com.apple.developer.networking.HotspotConfiguration` | NEHotspotHelper for joining Tether network |
| Multicast | `com.apple.developer.networking.multicast` | Bonjour discovery on local network |
| WiFi Info | `com.apple.developer.networking.wifi-info` | Read current SSID/BSSID |

---

## Troubleshooting

**"No such module" errors**
- Make sure you opened `Carmack/Package.swift`, not the root `Package.swift`
- The root package is the macOS app; Carmack is the iOS app

**Signing errors**
- Ensure your Apple Developer account has an active membership
- The Hotspot Configuration capability may require an explicit App ID (not wildcard)

**BLE not working on simulator**
- CoreBluetooth requires a real device. Test on a physical iPhone.

**"_tether._tcp" not found**
- The macOS Tether app must be running on the same network
- Check that the Mac's firewall allows incoming connections

**Build number conflicts on TestFlight**
- Increment `CURRENT_PROJECT_VERSION` for each upload
- App Store Connect rejects duplicate build numbers
