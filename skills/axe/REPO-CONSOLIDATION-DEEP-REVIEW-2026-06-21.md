# Memjar Repo Consolidation — Deep Review
## 2026-06-21 | 198 repos audited

---

## Public Repos (2)

| Repo | Size | Description |
|------|------|-------------|
| `tether` | 381KB | Tether - AI-driven smart tethering and network sharing |
| `tether.diy` | 230KB | tether.diy - Smart Network Sharing |

All other 196 repos are **private**.

---

## Consolidation Map

### 1. MEMORY / KNOWLEDGE (17 repos -> 3-4)

| Overlap Group | Repos | Likely Canonical |
|---|---|---|
| Memory store | `axe-memory` (165MB), `axe-mem` (28KB), `axe-palace` (185KB), `axe-memunlocked` (157KB), `Aeterna` (287KB), `axe-vault` (32KB) | `axe-memory` |
| Memory gateway/retrieval | `axe-memory-gateway` (34KB), `axe-recall` (9KB), `axe-memory-kit` (51KB) | `axe-memory-gateway` |
| Knowledge vault | `axe-crown` (1.2MB), `axe-halo` (2.2MB), `axe-obsidian` (4.9MB), `axe-onix` (117KB), `axe-oracle` (4KB) | `axe-crown` (halo desc says "canonical product: Crown") |
| Conversation memory | `axe-axenetwork` (341KB), `axe-collector` (12KB) | Unique enough to keep |
| Brain backup | `mum-memory` (68MB) | Keep - data archive, not code |

### 2. BROWSER (7 repos -> 2-3)

| Overlap Group | Repos | Likely Canonical |
|---|---|---|
| Desktop browser | `surfboard` (860KB), `axe-aibrowser` (519KB) | `surfboard` (consolidated this session) |
| Mobile browser | `axe-lens-ios` (51KB), `axe-browser-4s` (188KB) | Different targets, keep both |
| Browser intelligence | `axe-lens` (582KB), `axe-iris` (28KB) | `axe-lens` |
| Fork | `brave-browser` (35MB) | Archive candidate - upstream fork, stale |

### 3. APP / PLATFORM (11 repos -> 3-4)

| Overlap Group | Repos | Likely Canonical |
|---|---|---|
| macOS app | `axe-app` (65MB), `axe-app-swift` (10KB), `axe-desktop` (12KB) | `axe-app` or `axeagentsapp` (25MB, Jun 20) |
| Command center | `axe-platform` (24MB), `axe-command-centre` (564KB), `axe-dashboard` (609KB), `axe-portal` (103KB) | `axe-platform` |
| Backend | `axe-backend` (26MB) - "AXIOM Intelligence" | Unique, keep |
| Observer | `axe-observer` (36KB), `observer` (7.6MB) | `observer` (bigger, newer) |
| AI portal | `axe-ai-portal` (21MB) | Overlaps with `axe-platform` |

### 4. VPN / MESH (6 repos -> 2)

| Overlap Group | Repos | Likely Canonical |
|---|---|---|
| Mesh VPN | `axe-axeguard` (168KB), `axe-axescale` (129KB), `axe-wire` (224KB), `axe-vpn` (35KB), `axe-conduit` (69KB) | 3 layers of same stack - could be monorepo |
| Sync | `axe-sync` (470KB) | Related but distinct |

### 5. AUTH (4 repos -> 1-2)

| Overlap Group | Repos | Likely Canonical |
|---|---|---|
| Auth | `authgate` (1.2MB), `authgate-native` (601KB), `axe-shield` (244KB), `observer-auth` (113KB) | `authgate` (SSO for all AXE services) |

### 6. DESIGN (4 repos -> 1)

| Repos | Notes |
|---|---|
| `axe-brand` (3KB), `axe-design` (64KB), `axe-design-system` (130KB), `axiom-designs` (254KB) | All design assets/tokens - one repo |

### 7. TRAINING / ML (7 repos -> 2-3)

| Overlap Group | Repos | Likely Canonical |
|---|---|---|
| Training pipeline | `axe-dl` (95MB), `axe-flywheel` (89KB), `AXeGoFlywheel` (4.3MB) | `AXeGoFlywheel` or `axe-dl` |
| Edge model | `axe-edge` (5.4MB), `axe-edgecode` (6MB), `axe-edge-app` (182KB) | `axe-edge` |
| ML platform | `axe-ml` (96MB), `code7b` (63MB), `WINcorpus` (1MB) | Training data - keep separate |

### 8. IMI / theANSWER (8 repos -> 3)

| Overlap Group | Repos | Likely Canonical |
|---|---|---|
| IMI app | `imi-app` (286KB), `imi-live` (102KB), `theANSWERapp` (2.6MB), `pulseai-chat` (127KB) | `theANSWERapp` |
| IMI backend | `imi-backend` (754KB), `theanswerai` (674KB), `imi-sdk` (64KB) | `imi-backend` |
| IMI files | `imi-klausfiles` (0KB), `imi-research-drop` (944KB) | `imi-klausfiles` is empty |

---

## Empty / Zero-Size Repos (13 - safe archive candidates)

| Repo | Description | Last Updated |
|---|---|---|
| `axe-enterprise` (1KB) | No description | 2026-04-08 |
| `axe-text2speech` (0KB) | Empty | 2026-03-28 |
| `axe-notion` (0KB) | Empty | 2026-03-28 |
| `foundry-research` (0KB) | Empty | 2026-03-10 |
| `classifier` (0KB) | Empty | 2026-06-11 |
| `claude-test-repo` (0KB) | "test tes test" | 2026-03-06 |
| `movesync` (0KB) | Empty | 2026-02-19 |
| `axe-deepseek-re` (0KB) | Empty | 2026-06-10 |
| `axe-mistral-re` (0KB) | Empty | 2026-06-10 |
| `virul-agency` (0KB) | Empty | 2026-01-23 |
| `virul-creator-shop` (0KB) | Empty | 2026-03-06 |
| `virulai` (0KB) | Empty | 2024-11-05 |
| `Mjbeta` (0KB) | "Memory jar beta" from 2023 | 2023-07-09 |

---

## Standalone / Unique Repos (keep as-is)

These repos have distinct purposes with no clear overlap:

- `AXeEpistemics` - founding doctrine
- `AXeGoArc` - foundational model
- `AXeGoMCP` - 172-tool fleet registry
- `AXeGoPipeline` - pipeline hardening
- `AXeGoTrust` - model provenance
- `Heretic-Rend` - abliteration toolkit
- `JLa-treasures` - field operative arsenal
- `WINcorpus` - verified wins corpus
- `axe-algorithm` - recommendation AI
- `axe-anvil` - document engine
- `axe-atlas` - sovereign database
- `axe-bunker` - local-first Postgres
- `axe-headroom` - capacity extension
- `axe-chat` - encrypted comms
- `axe-classifier` - intent classifier
- `axe-config` - system configuration
- `axe-costpulse` - token cost calculator
- `axe-distillery` - model distillation
- `axe-echo` - inference engine
- `axe-gateway` - unified API gateway
- `axe-ghost` - pentesting/security (46MB)
- `axe-knox` - tool-call security (6.9MB)
- `axe-mcp` - fleet MCP server (7.8MB)
- `axe-nano` - iPhone agent (7.9MB)
- `axe-skills` - 72+ skill library (36MB)
- `axe-skills-hub` - skills MCP server
- `axe-supercharge` - cognitive AI OS
- `axe-superdaemons` - 5 autonomous daemons
- `axe-tower` - fleet command dashboard
- `axe-vigil` - agent swarm (9.2MB)
- `axe-warden` - off-grid radio AI
- `axeCHAT` - unified comms platform (58MB)
- `axeagentsapp` - native AI command center (25MB)
- `chorus` - AI-native communications
- `homer` - research/intel brain
- `intel` - global intelligence command
- `marketsim` - competitive market simulator
- `meridian` - research swarm
- `meridian-icu` - research engine
- `relay` - fleet relay
- `tether` - smart tethering
- `touchstone` - verifier library

---

## Security Review

### Public Repos (2)

Only `tether` and `tether.diy` are public. These were security-scrubbed prior to publication.

### Known Credential Exposure (found this session)

| Repo | File | Issue | Status |
|---|---|---|---|
| `axe-gateway` | `gateway.py:37` | Hardcoded API key: `API_KEY = "_J1ra0x7W-..."` | In git history even after removal commit `3ea6b8a` |
| `axe-gateway` | `gateway.py` | xAI and Gemini API key variables (now empty strings) | Cleared, but check git history |

### Repos Requiring Security Audit

| Repo | Concern |
|---|---|
| `axe-ghost` (46MB) | Pentesting tools, C2 framework, exploit code - verify no leaked creds |
| `axe-knox` (6.9MB) | Tool-call security, encryption keys - verify key management |
| `axe-headroom` (1.1MB) | Capacity extension - verify no auth tokens committed |
| `axe-config` (1.2MB) | System configuration - likely contains or references secrets |
| `axe-bunker` (2.4MB) | Database platform - verify no connection strings |
| `axe-system` (270MB) | Largest repo - broad surface area |
| `axe-dl` (95MB) | Training pipeline - may contain API keys for cloud training |
| `axe-ml` (96MB) | ML platform - cloud service credentials |
| `axe-memory` (165MB) | May contain cached API responses with tokens |
| `mum-memory` (68MB) | Brain backup - may contain sensitive conversation data |
| `operation-sovereign` (34MB) | Name suggests sensitive operational content |
| `axe-intel` (3.5MB) + `axe-intel-terminal` (7.6MB) | OSINT tools - verify no API keys for intel services |
| `axe-storage` (10KB) | "Telegram-backed unlimited cloud storage" - bot tokens? |
| `authgate` (1.2MB) | Auth service - JWT secrets, OAuth client secrets |

### Recommendations

1. **IMMEDIATE**: Rotate the API key found in `axe-gateway` git history
2. **HIGH**: Run `git log --all -p -S 'Bearer' --` and `-S 'API_KEY'` across all repos
3. **HIGH**: Audit `.env`, `.env.example`, `secrets/`, `config/` in every repo
4. **MEDIUM**: Consider GitHub secret scanning alerts (may already be enabled)
5. **MEDIUM**: Verify `brave-browser` fork doesn't contain modified auth code

---

## Action Required

- [ ] Team reviews this document
- [ ] Decide on consolidation per group (sections 1-8)
- [ ] Archive 13 empty repos
- [ ] Rotate axe-gateway API key
- [ ] Run credential scan across all repos
- [ ] Deep security audit of flagged repos
