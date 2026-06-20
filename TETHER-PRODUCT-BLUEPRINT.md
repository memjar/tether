# TETHER — Product Blueprint
### AXE Technology · June 2026

---

## 1. WHAT TETHER IS

A native macOS menubar app that captures any available internet source (cellular via iPhone USB, WiFi, Ethernet, Thunderbolt, Bluetooth) and surfaces it as a secure WiFi network. AI-driven prediction, failover, and device management.

Phase 2: hardware puck (travel router) with iOS/Android companion app.

---

## 2. PRODUCT TIERS

| Tier | Platform | What It Does | Status |
|------|----------|-------------|--------|
| Tether for Mac | macOS 12+ | Creates hotspot, manages devices, AI failover | v0.1.0 built |
| Tether iOS | iOS 16+ | Monitor/control dashboard for Mac app | Not started |
| Tether Puck | Custom ARM hardware | Standalone portable hotspot with multi-radio | Concept |

---

## 3. CURRENT STATE (v0.1.0)

### Built
- macOS menubar app (NSStatusItem + NSPopover)
- 4-tab SwiftUI dashboard (Status, Devices, Radio, Share)
- InternetSharing via launchd + NAT plist generation
- CoreWLAN radio info + WiFi scanner
- PF firewall device pause/kick
- DHCP lease + ARP client detection
- REST API on port 8421
- AI NetworkPredictor scaffold
- Landing page live at tether.diy

### Not Built Yet
- Everything in Section 5 below

---

## 4. COMPETITIVE REFERENCE: STARLINK APP

Starlink is the gold standard for consumer network management UX. Key patterns to replicate:

### Dashboard
- Speed test widget (tap-to-run, arc graph)
- Uptime percentage (24hr rolling)
- Network topology map (router → mesh → devices)
- Device count badge
- Alert banner (obstructions, firmware, outages)

### Device Management
- Device list: name, IP, MAC, band (2.4/5), signal per device
- Per-device bandwidth graph (real-time up/down)
- Pause/resume per device
- Kick device
- Custom naming with device-type icons
- Device grouping ("Family", "Work", "IoT")
- Priority marking

### Network Controls
- SSID + password management
- Band steering (split vs unified)
- Guest network (separate SSID, device isolation)
- WPA2/WPA3 toggle
- Hidden SSID
- Custom DNS
- Port forwarding
- IPv4/IPv6 toggle

### Observability
- Speed history (days/weeks/months)
- Latency graph (24hr, P50/P95)
- Data usage (per-device, daily/weekly/monthly)
- Network events log
- Signal quality per device

**Screenshots wanted**: Yes — desktop and mobile Starlink screenshots will directly inform layout decisions for every view below.

---

## 5. FRONTEND DESIGNS NEEDED

### 5.1 macOS Menubar App (NSPopover — 340x520)

Current: basic 4-tab layout. Needs complete redesign for each tab.

#### Tab 1: STATUS (Home Dashboard)

| Component | Description | Starlink Ref |
|-----------|-------------|-------------|
| Connection Card | Large card showing active source, SSID, uptime counter | Main dashboard card |
| Signal Meter | Animated signal quality arc (0-100%) with RSSI/SNR | Speed test arc |
| Speed Widget | Mini speed test — download/upload/latency | Speed test widget |
| Quick Stats Row | Connected devices count, data transferred, uptime | Stats strip |
| Source Indicator | Active interface icon + name with fallback chain | Network status |
| Alert Banner | Warning/error state banner (no source, weak signal) | Alert banner |

#### Tab 2: DEVICES

| Component | Description | Starlink Ref |
|-----------|-------------|-------------|
| Device List | Scrollable list with icon, name, IP, bandwidth sparkline | Device list |
| Device Row | Expandable — shows MAC, band, signal, first seen, data used | Device detail |
| Action Buttons | Pause/Resume, Kick, Priority toggle per device | Device controls |
| Device Naming | Tap name to edit, persists to UserDefaults | Custom naming |
| Group Filter | Tab bar or segmented control — All / Family / Work / IoT / Guests | Device grouping |
| Empty State | wifi.slash icon + "No devices connected" | — |
| Bulk Actions | Select multiple → pause all, kick all | — |

#### Tab 3: RADIO

| Component | Description | Starlink Ref |
|-----------|-------------|-------------|
| Radio Info Card | Channel, band, width, PHY mode, country code | Network info |
| Signal Gauges | RSSI + Noise + SNR as three mini gauges | Signal display |
| Channel Grid | All supported channels, color-coded by congestion | — |
| Best Channel | AI-recommended channel with "Apply" button | — |
| WiFi Scanner | Nearby networks list with RSSI bars, sorted by strength | — |
| Band Selector | 2.4 GHz / 5 GHz / Auto toggle | Band steering |

#### Tab 4: SHARE (Hotspot Config)

| Component | Description | Starlink Ref |
|-----------|-------------|-------------|
| Sharing Toggle | Large on/off toggle with status indicator | — |
| SSID Field | Editable network name | SSID management |
| Password Field | SecureField with show/hide toggle | Password management |
| Security Picker | WPA2 / WPA3 / None segmented control | WPA toggle |
| Source Selector | Radio-button list of detected sources with icons | — |
| Channel Override | Optional channel picker (default: auto) | — |
| Guest Network | Toggle + separate SSID/password for guests | Guest network |
| Hidden SSID | Toggle to hide broadcast | Hidden SSID |
| Active Info | When sharing: SSID, password, IP, subnet, device count | — |

#### Tab 5: SETTINGS (New)

| Component | Description | Starlink Ref |
|-----------|-------------|-------------|
| Auto-Start | Launch at login toggle | — |
| Auto-Share | Auto-start sharing when source detected | — |
| Failover Config | Priority order of interfaces for auto-failover | — |
| DNS Config | Custom DNS servers (CloudFlare, Google, custom) | DNS settings |
| Port Forwarding | Rules list with add/edit/delete | Port forwarding |
| Data Limits | Per-device or total data cap with alerts | — |
| Notifications | Toggle for connect/disconnect/failover alerts | — |
| API Toggle | Enable/disable REST API + port config | — |
| About | Version, GitHub link, tether.diy | — |

### 5.2 macOS Full Window (Phase 1.5)

Triggered by "Open Dashboard" or window icon. Full-size window with richer views.

| Screen | Description |
|--------|-------------|
| Network Topology | Visual map: source → Tether → devices (like Starlink topology) |
| Speed Test | Full-screen speed test with animated arc, history graph |
| Device Detail | Full page per device: bandwidth graph, connection history, data usage over time |
| Data Analytics | Total data usage charts — daily/weekly/monthly, per-device breakdown |
| Network Log | Scrollable event log: connects, disconnects, failovers, errors |
| Signal History | RSSI/SNR/noise over time graph (hours/days) |

### 5.3 iOS Companion App

Monitoring and control only — no hotspot creation.

| Screen | Description | Starlink Ref |
|--------|-------------|-------------|
| Home | Connection status, device count, signal quality, quick actions | Main dashboard |
| Devices | Same as macOS device list — pause/kick/priority | Device list |
| Speed Test | Run speed test on the Mac's shared connection | Speed test |
| Notifications | Push alerts for failover, device connect/disconnect, signal drops | Alerts |
| Settings | Configure Mac app remotely via API | Settings |

### 5.4 Landing Page (tether.diy) — LIVE

| Section | Status |
|---------|--------|
| Hero + CTA | Done |
| Screenshot | Done (needs update as UI evolves) |
| Feature grid | Done |
| Specs strip | Done |
| Email signup | Done (client-side only — needs backend) |
| Docs/API section | Not built |
| Download section | Not built (needs .dmg hosting) |
| Pricing section | Not built |

---

## 6. USER JOURNEYS

### Journey 1: First Launch
```
Download .dmg → Drag to Applications → Launch
  → Menubar icon appears (antenna icon)
  → Click icon → Popover opens
  → Welcome card: "Tether detected 2 internet sources"
  → Shows detected interfaces with recommendation
  → "Start Sharing" button → configures SSID/password
  → Sharing active → shows QR code for devices to scan
```

### Journey 2: Daily Use — Road Trip
```
Open laptop with iPhone USB tethered
  → Tether auto-detects iPhone USB as source
  → Auto-starts sharing (if configured)
  → Passenger connects iPad to "Tether" WiFi
  → Status tab shows: 1 device, 45 Mbps, strong signal
  → iPhone signal drops → AI predicts failover
  → Tether switches to backup WiFi source seamlessly
  → Notification: "Switched to Starbucks WiFi (auto-failover)"
```

### Journey 3: Device Management — Home Office
```
Running Tether as home backup network
  → 6 devices connected
  → Devices tab → see kid's iPad using 80% bandwidth
  → Tap iPad → "Pause" → iPad loses internet
  → Set work laptop as "Priority"
  → Zoom call quality improves immediately
  → After meeting → Resume iPad
```

### Journey 4: Radio Optimization — Dense Environment
```
Conference hotel, terrible WiFi
  → Radio tab → scan nearby networks
  → 15 networks on channel 6, 3 on channel 36
  → Tether recommends channel 36 (5GHz)
  → Tap "Apply" → channel switches
  → Signal quality jumps from 40% to 78%
```

### Journey 5: Guest Access
```
Friends visiting → Share tab → enable Guest Network
  → Separate SSID "Tether-Guest" with simple password
  → Guest devices isolated from main network
  → Set data limit: 500MB per guest device
  → Guest hits limit → notification → choose to extend or kick
```

### Journey 6: AI Failover — Van Life
```
Parked with Starlink Mini + iPhone cellular
  → Tether using Starlink as primary (Ethernet)
  → Cloud cover approaching → AI detects signal degradation trend
  → Pre-warms cellular fallback
  → Starlink drops → instant switch to cellular
  → Zero downtime for video call
  → Starlink recovers → switches back automatically
```

### Journey 7: iOS Companion — Remote Monitor
```
Tether running on Mac at home
  → Open Tether iOS app at coffee shop
  → See 3 devices connected at home
  → Unknown device "android-abc123" appeared
  → Tap → Kick → device removed
  → Rename remaining devices for easy ID
  → Push notification: "New device connected: Sarah's MacBook"
```

### Journey 8: API Integration — Smart Home
```
Home Assistant queries Tether API
  → GET /api/v1/clients → 4 devices
  → Automation: if device_count > 5, alert
  → POST /api/v1/share/stop at midnight (scheduled)
  → POST /api/v1/share/start at 6am
  → GET /api/v1/prediction → failureProbability: 0.85
  → Trigger backup internet switch via smart plug
```

### Journey 9: Speed Test & Diagnostics
```
Connection feels slow
  → Status tab → tap speed test widget
  → Animated arc: Download 12 Mbps, Upload 3 Mbps, Latency 85ms
  → Below average → tap "Diagnose"
  → AI report: "Channel congestion detected. 8 networks on channel 1. Recommend channel 44."
  → One-tap apply
  → Re-test: 45 Mbps down
```

### Journey 10: Hardware Puck (Phase 2)
```
Buy Tether Puck → plug into USB-C power bank
  → Puck creates WiFi network automatically
  → Insert SIM card for cellular
  → Connect to puck WiFi from any device
  → Open Tether iOS app → discovers puck via BLE
  → Full dashboard: signal, devices, speed, failover config
  → Attach LoRa antenna → mesh network mode for remote areas
```

---

## 7. DESIGN SYSTEM — AXE Brand + Starlink Density

Tether inherits AXE Technologies' core brand (axetechnologies.ca) and layers in Starlink-inspired dashboard density for the app UI.

### Brand Heritage
- **Parent brand**: AXE Technologies (axetechnologies.ca)
- **Typography**: Space Grotesk (AXE primary) + IBM Plex Mono (AXE mono)
- **Gold accent**: #D4AF37 (AXE signature — used for primary actions, active states, brand marks)
- **Dark mode**: AXE uses dark hero sections; Tether is dark-first throughout
- **Sharp edges on CTAs**: AXE uses border-radius: 0 on buttons — Tether adopts for primary actions
- **Starlink influence**: card-based dashboard, circular gauges, sparklines, dense data display

### Colors
| Token | Hex | Usage | Source |
|-------|-----|-------|--------|
| bg | #0a0a0f | Primary background | Starlink dark |
| bg2 | #111118 | Card background | Starlink panels |
| bg3 | #1a1a24 | Elevated surface / hover | Starlink hover |
| text | #f5f5f5 | Primary text | AXE --gray-100 |
| text2 | #737373 | Secondary / muted text | AXE --gray-500 |
| gold | #D4AF37 | Primary accent — buttons, active tabs, indicators | AXE --accent |
| gold-hover | #e8c84a | Accent hover / glow | AXE gold light |
| teal | #14b8a6 | Secondary accent — success, signal good, online | AXE palette |
| danger | #ef4444 | Error, destructive, signal critical | AXE palette |
| warning | #f59e0b | Warning, signal weak | AXE palette |
| border | #262626 | Borders, dividers | AXE --gray-800 |
| border-light | #2a2a2a | Subtle card borders | AXE dark palette |

### Typography
| Element | Font | Weight | Size | Source |
|---------|------|--------|------|--------|
| App name / brand | Space Grotesk | 600 | 18-20px | AXE nav logo |
| Headings | Space Grotesk | 600-700 | 17-24px | AXE headings |
| Body | Space Grotesk | 400 | 13-15px | AXE body |
| Labels / section headers | Space Grotesk | 500 | 11-13px | AXE labels |
| Data values / mono | IBM Plex Mono | 500 | 12-14px | AXE mono |
| Stats / large numbers | IBM Plex Mono | 600 | 24-32px | AXE spec values |

Note: macOS/iOS app uses system fonts mapped to similar weights (SF Pro ≈ Space Grotesk, SF Mono ≈ IBM Plex Mono). Web properties use the actual Google Fonts.

### Button Styles (AXE Heritage)
| Type | Style |
|------|-------|
| Primary | Gold bg (#D4AF37), black text, border-radius: 0, sharp edges |
| Primary hover | Lighter gold (#e8c84a), subtle glow shadow |
| Secondary | Transparent bg, 1.5px border (white or gold), border-radius: 0 |
| Secondary hover | Fill with gold, text goes black |
| Destructive | Red bg (#ef4444), white text |
| Ghost | No border, text only, gold on hover |

### Icons
- SF Symbols throughout (macOS/iOS native)
- Device icons: laptopcomputer, iphone, ipad, appletv, applewatch, desktopcomputer
- Network icons: wifi, antenna.radiowaves.left.and.right, network, bolt.horizontal
- Status icons: checkmark.circle.fill, xmark.circle.fill, exclamationmark.triangle.fill
- Gold tint on active/selected icons

### Component Patterns
| Pattern | Description | Influence |
|---------|-------------|-----------|
| Cards | bg2 fill, 1px border (#262626), rounded-8 (not 14 — tighter than before), hover border goes gold | Starlink + AXE |
| Gauges | Circular arc with percentage center, gold gradient for good signal, red for bad | Starlink speed test |
| Sparklines | Inline mini charts for bandwidth per device, gold stroke | Starlink device list |
| Toggle rows | Label left, toggle right, full-width tap target, gold toggle accent | Starlink settings |
| Section headers | Uppercase, 11px, Space Grotesk 500, letter-spacing 0.08em, text2 color | AXE nav style |
| Nav bar | Sticky, backdrop-filter: blur(20px), bg with 0.9 opacity, bottom border appears on scroll | AXE nav |
| Data tables | IBM Plex Mono for values, Space Grotesk for labels, gold highlights on key metrics | AXE data style |
| Status indicators | Gold dot = active, teal dot = connected, red dot = error, gray dot = inactive | — |

### Logo Treatment
- "T" icon in gold (#D4AF37) square, sharp corners (border-radius: 2px max)
- "Tether" wordmark in Space Grotesk 600
- Tagline "by AXE Technologies" in IBM Plex Mono 400, 11px, text2 color
- Footer: "tether.diy — AXE Technology" in IBM Plex Mono

---

## 8. TECH STACK

### macOS App
- Swift 5.7 / SwiftUI
- macOS 12+ (Monterey)
- NSStatusItem + NSPopover (menubar)
- CoreWLAN, NWPathMonitor, SystemConfiguration
- PF (packet filter) for NAT/firewall
- Core ML for network prediction

### iOS Companion
- Swift 5.9+ / SwiftUI
- iOS 16+
- CoreBluetooth (BLE discovery of Mac/Puck)
- Network framework for API communication
- WidgetKit for home screen speed widget

### Landing Page
- Static HTML/CSS/JS on GitHub Pages
- No framework, no dependencies
- Email signup needs backend (Cloudflare Worker or DO function)

### API
- Built-in REST server (no dependencies)
- Port 8421
- JSON responses
- Future: WebSocket for real-time events

---

## 9. FRONTEND BUILD ORDER

Priority order for implementation:

| # | Screen/Component | Platform | Effort | Dependency |
|---|-----------------|----------|--------|------------|
| 1 | Settings tab | macOS | S | None |
| 2 | Speed test widget | macOS | M | ping/curl implementation |
| 3 | Device naming + groups | macOS | S | UserDefaults persistence |
| 4 | Signal history graph | macOS | M | Data collection over time |
| 5 | Network topology view | macOS | L | Full window mode |
| 6 | Guest network config | macOS | M | InternetSharing multi-SSID |
| 7 | Data usage tracking | macOS | M | Per-device byte counting |
| 8 | Port forwarding UI | macOS | M | PF rule management |
| 9 | Full window dashboard | macOS | L | All above components |
| 10 | iOS companion app | iOS | XL | API auth, BLE discovery |
| 11 | Docs/API page | Web | S | None |
| 12 | Download page + .dmg | Web | M | Code signing, notarization |

S = small (hours), M = medium (1-2 days), L = large (3-5 days), XL = extra large (1-2 weeks)

---

## 10. APP STORE STRATEGY

**Category**: Utilities
**Positioning**: "Network management and monitoring dashboard"
**Comparable apps**: Starlink, Eero, Google Home, Ubiquiti, Fing, iNet

### macOS (Direct + Mac App Store)
- Direct download from tether.diy (notarized .dmg)
- Mac App Store listing (sandboxed version with reduced functionality)
- Full version needs admin privileges for PF/InternetSharing

### iOS (App Store)
- Companion app only — "monitor and manage your Tether network"
- All public APIs — no restricted entitlements needed
- BLE for discovery, Network framework for API calls
- Parental controls angle: "pause devices, set limits"

### Keywords
network management, hotspot manager, wifi dashboard, internet sharing, device control, network monitor, parental controls, bandwidth monitor, signal analyzer
