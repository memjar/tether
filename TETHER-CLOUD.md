# Tether Cloud — Architecture & Integration Guide

Cloud relay layer that extends Tether's local beacon mesh to the internet. Any browser can join a beacon without installing an app.

## Architecture

```
┌──────────────┐                         ┌──────────────┐                         ┌──────────────┐
│  iOS/macOS   │───► POST /beacon/ ─────►│  Beam Relay  │◄── WebSocket ──────────│  Web Client  │
│  Tether App  │     register            │  beam.tether │     role=client         │  tether.diy  │
│              │                         │  .diy        │                         │  /app        │
│              │───► WebSocket ─────────►│  (8902)      │                         │              │
│  (host)      │     role=host           │              │                         │  (browser)   │
└──────────────┘                         └──────────────┘                         └──────────────┘
```

## Components

| Component | Location | Status |
|---|---|---|
| Beam Relay Server | beam.tether.diy (159.203.18.103:8902) | Live, systemd |
| Web Client | tether.diy/app/ (GitHub Pages) | Live |
| iOS Cloud Module | Sources/TetherBeam/BeamCloudRelay.swift | Built, needs wiring |
| Server Source | memjar/axe-speak beam_server.py | Synced |

## Two Modes of Operation

### Mode 1 — Cloud-to-Local Bridge
User grants cloud access to their device. Web clients can monitor, chat, and control the local Tether instance through the relay. The device runs as WebSocket host.

### Mode 2 — Browser Joins Beacon Mesh
A web user joins an active beacon from any browser. No phone needed. They appear as a client in the mesh and can use chat, file sharing, and any connector the host has enabled.

## iOS Integration (BeamCloudRelay.swift)

```swift
// On beacon start
BeamCloudRelay.shared.configure(onMessage: { type, payload in
    // Handle incoming messages from web clients
})
BeamCloudRelay.shared.registerBeacon(
    beaconId: beaconId,
    deviceName: UIDevice.current.name,
    capabilities: ["wifi", "hotspot", "chat"]
)

// On beacon stop
BeamCloudRelay.shared.unregisterBeacon()
```

Features:
- Auto-register/unregister beacon with cloud relay
- WebSocket host connection with exponential backoff reconnect (max 10 attempts)
- 30s ping keepalive, 300s idle timeout
- Message routing by type (chat, signal, peer events)

## Relay API

| Endpoint | Method | Purpose |
|---|---|---|
| `/beacon/register` | POST | Register beacon `{beacon_id, device_name, capabilities, sharing_type, max_clients}` |
| `/beacon/{id}` | GET | Lookup beacon |
| `/beacon/{id}` | DELETE | Unregister beacon |
| `/beacons` | GET | List active beacons |
| `/relay/{beacon_id}` | WS | Join relay room (`?role=host\|client&name=<display>`) |
| `/health` | GET | Status + relay stats |

### OTA Distribution (preserved from Beam v1)

| Endpoint | Method | Purpose |
|---|---|---|
| `/upload` | POST | Upload and sign IPA |
| `/manifest/{name}` | GET | OTA install manifest |
| `/ipa/{name}` | GET | Download signed IPA |
| `/latest` | GET | Latest build info |
| `/latest/install` | GET | itms-services install URL |
| `/web/upload` | POST | Deploy web app tarball |
| `/web/{app}/info` | GET | Web app build info |
| `/connector/{app}` | GET | Embed info for connectors |

## WebSocket Protocol

All messages are JSON. Relayed messages include `from`, `from_role`, `from_name`.

### Server to Client (system events)
```json
{"type": "connected", "client_id": "c000001", "role": "host", "beacon": {...}}
{"type": "peer_joined", "client_id": "c000002", "role": "client", "name": "Web-A3F2", "client_count": 1}
{"type": "peer_left", "client_id": "c000002", "client_count": 0}
{"type": "host_disconnected"}
{"type": "pong", "ts": 1782369200.0}
```

### Client to Server
```json
{"type": "ping"}
{"type": "chat", "text": "hello from web"}
{"type": "signal", "target": "c000001", "payload": {...}}
```

Signal messages route point-to-point (for WebRTC negotiation). All other message types broadcast to the room.

## Deployment

```bash
# Systemd service on NewtonCloud (159.203.18.103)
systemctl status beam
systemctl restart beam

# Caddy reverse proxy
beam.tether.diy → localhost:8902

# Environment
BEAM_URL=https://beam.tether.diy
BEAM_KEY=<optional API key>
BEAM_DIST=/var/lib/tether-beam
BEAM_WEB_DIST=/var/lib/beam-web
```

## Remaining Work

- [ ] Wire BeamCloudRelay into beacon start/stop in TetherEngine
- [ ] Add "Cloud Relay" toggle in app settings
- [ ] File sharing over relay (chunked binary via WebSocket)
- [ ] WebRTC upgrade path (signal routing already in place)
- [ ] Cloud access permissions (grant/revoke per web client)
