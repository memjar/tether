# Tether - App Store Connect listing (draft)

Honest to what ships on iOS. The iPhone does **not** create a Wi‑Fi hotspot (Apple
grants no third‑party entitlement for that). Tether for iPhone is a companion that
controls your Mac's Tether beacon and connects your own devices in a local mesh. Do
not use hotspot‑creation language anywhere in the listing - it is false for this build
and an App Review rejection risk.

Bundle ID: `ca.axetechnologies.tether` · Team: 237Q6KHJY6 · Category: Utilities · Min iOS 15.0

---

## Name (30 char max)
`Tether: Beacon & Mesh`

## Subtitle (30 char max)
`Control sharing. Link nearby.`

## Promotional text (170 char max)
`See and steer your Mac's Tether hotspot from your pocket, spot nearby devices on the radar, and beam files phone‑to‑phone with no router and no cloud.`

## Description (4000 char max)
Tether turns your iPhone into the remote for your Mac's shared connection, and a
private bridge between your own devices.

CONTROL YOUR BEACON
When your Mac is sharing its connection with Tether, this app is the dashboard. See
whether the beacon is live, the network name, how many devices are connected, and the
Bluetooth link signal at a glance. Start and stop sharing, and pause or disconnect a
device, without getting up.

RADAR FOR NEARBY DEVICES
A live proximity radar shows Tether devices around you, ordered by how close they are,
using Bluetooth signal strength. Find the right device in a room full of them.

LOCAL MESH, NO INTERNET REQUIRED
Connect your iPhones and iPads to each other directly over a local mesh. Send messages
and files between your devices with no router, no account, and no cloud in the middle.
It works on a plane, in a basement, or anywhere the internet does not reach.

PRIVATE BY DESIGN
Discovery and control happen over Bluetooth and your local network. Mesh transfers go
straight between your devices. There is no Tether account and nothing to sign up for.

Tether pairs with the Tether app for Mac, which does the actual connection sharing.
Learn more at tether.diy.

## Keywords (100 char max, comma‑separated, no spaces)
`tether,hotspot,share,mesh,bluetooth,radar,nearby,file transfer,wifi,local,airdrop,proximity,devices`

## What's New (first release)
`First release. Control your Mac's Tether beacon, see nearby devices on the radar, and share files device‑to‑device over a local mesh.`

## Support URL
`https://tether.diy`

## Marketing URL
`https://tether.diy`

## Privacy - data types
Declare **no data collected** (accurate for this build): discovery is local, mesh is
peer‑to‑peer, there is no account and no analytics SDK in the shippable target. If an
analytics SDK is added later, update this before submitting.

## Info.plist usage strings (already in the build - keep consistent with the listing)
- NSBluetoothAlwaysUsageDescription - discovering and controlling nearby Tether devices.
- NSLocalNetworkUsageDescription - finding your Mac's beacon and nearby devices for the mesh.
- NSBonjourServices - `_tether._tcp`, `_tether-mesh._tcp`, `_tether-mesh._udp`.

## App Review notes (paste into the Review Notes field)
This iPhone app is a COMPANION and a local mesh tool. It does NOT create a Personal
Hotspot or a Wi‑Fi access point on the device; iOS provides no public API for that and
this build does not attempt it. It uses Bluetooth and MultipeerConnectivity to discover
and control a separate Mac app that shares its own connection, and to move files between
the reviewer's own devices. No private frameworks are linked in this build (the GHOST_MODE
code path is compiled out for App Store distribution). To exercise the mesh without a Mac,
run the app on two iOS devices on the same local network and use the Mesh tab.

## Age rating
4+ (no objectionable content).

## Screenshots (to capture in Xcode Simulator, 6.7" + 6.5" + 5.5")
1. Status - beacon live, device count, BLE link card.
2. Devices - connected clients list.
3. Radar - nearby devices by proximity.
4. Mesh - a live peer session sending a file.
5. Settings.
