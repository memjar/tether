# AXE Repository Consolidation Plan
### 2026-06-21 | Prepared by: James Lewis (AI Lead) | 200 repos audited

---

## Status

- **Total repos (memjar org):** 200
- **Already archived:** 5 (axe-cursor, axe-remote, axe-ml-dashboard, axe-agent, axe-gateway)
- **Archived in this round:** 3 (see below)
- **Recommended for team review:** ~40 candidates grouped below

---

## Completed Archives (verified safe, self-described as superseded)

| Repo | Reason | Superseded by | Last commit |
|------|--------|---------------|-------------|
| `surfboard` | Description says "superseded by axe-aibrowser as canonical" | `axe-aibrowser` | 2026-06-19 |
| `the-answer-staging` | Description says "Consolidated orphan TheAnswer/IMI parser staging work" | `theANSWERapp` | 2026-06-18 |
| `axe-mempalace` | Description says "Earlier memory surface, see axe-palace + axe-mem" + repo is empty | `axe-palace` | empty |

---

## Unarchived

| Repo | Reason |
|------|--------|
| `axe-gateway` | Needed as the canonical gateway.axe.onl repo (was archived with 30KB of content from April) |

---

## Consolidation Recommendations (requires team review)

### Memory (10 repos -> 2 canonical)

**Canonical:** `axe-memory-gateway` (production memory API) + `mum-memory` (special purpose)

| Repo | Description | Recommendation | Notes |
|------|-------------|----------------|-------|
| `axe-memory` | Private unified memory for Forge/Cortana/Klaus | Review: merge into memory-gateway or archive | Last push: 2026-06-09 |
| `axe-memory-kit` | Portable team continued-context for AI sessions | Review: merge into memory-gateway | Last push: 2026-06-10 |
| `axe-mem` | Vector + graph + KV on Qdrant | Review: merge into memory-gateway or archive | Last push: 2026-04-13 |
| `axe-memunlocked` | MemPalace integration for GODMODE CLI | Review: archive (GODMODE CLI deprecated?) | Last push: 2026-04-14 |
| `axe-palace` | 4-layer memory (Identity/Session/History/Archival) | Review: merge into memory-gateway | Last push: 2026-04-15 |
| `axe-recall` | C-R-A retrieval layer | Review: merge into memory-gateway | Last push: 2026-05-05 |
| `axe-obsidian` | Vigil's Obsidian + Qdrant bridge | Review: keep if Vigil-specific, else merge | Last push: 2026-06-21 |

### MCP / Tools (5 repos -> 1 canonical)

**Canonical:** `AXeGoMCP` (135 tools, 3 modes: CLI + MCP + HTTP)

| Repo | Description | Recommendation | Notes |
|------|-------------|----------------|-------|
| `axe-mcp` | 77+ tools across AXE platform | Merge unique tools into AXeGoMCP, archive | Last push: 2026-05-26 |
| `axe-edgemcp` | AXEClaw edge MCP + SKILL.md knowledge base | Merge skills into axe-skills, tools into GoMCP | Last push: 2026-05-14 |
| `axe-skills-hub` | MCP server for 72+ skill ecosystem | Merge into axe-skills as MCP transport layer | Last push: 2026-04-25 |
| `imi-sdk` | IMI intelligence pipeline as MCP server | Merge into AXeGoMCP as IMI tool namespace | Last push: 2026-06-18 |

### Skills (4 locations -> 1 canonical)

**Canonical:** `axe-skills` (72+ production skills)

| Location | Recommendation |
|----------|----------------|
| `axe-skills` | Keep as canonical skill library |
| `axe-skills-hub` | Merge MCP transport into axe-skills |
| `axe-config` (skills dir) | Reference axe-skills, don't duplicate |
| `tether/skills/` | App-specific skills OK, shared ones should live in axe-skills |

### Chat / Comms (6 repos -> 1 canonical)

**Canonical:** `chorus` (AI-native communications)

| Repo | Description | Recommendation | Notes |
|------|-------------|----------------|-------|
| `axeCHAT` | Sovereign unified chat/audio/video/AI | Review: features merged into chorus? | Last push: 2026-06-17 |
| `observer` | axe.observer AI team chat | Review: merge into chorus or archive | Last push: 2026-06-20 |
| `axe-chat` | Sovereign team comms (BitChat-class) | Review: archive if chorus supersedes | Last push: 2026-05-09 |
| `axe-bbm` | BBM bridge over RIM relay | Review: archive (experimental?) | Last push: 2026-05-03 |
| `pulseai-chat` | IMI Pulse chat surface | Review: merge into theANSWERapp or chorus | Last push: 2026-05-22 |

### Browser (6 repos -> 2 canonical)

**Canonical:** `axe-aibrowser` (desktop) + `axe-lens-ios` (mobile)

| Repo | Description | Recommendation | Notes |
|------|-------------|----------------|-------|
| `axe-lens` | Lens desktop browser intelligence | Review: merge into axe-aibrowser | Last push: 2026-04-28 |
| `axe-iris` | Fleet browser AI, LoRA client | Review: merge into axe-aibrowser | Last push: 2026-05-30 |
| `axe-browser-4s` | iPhone 4S browser (iOS 8+) | Review: archive (retro hardware) | Last push: 2026-04-30 |

### VPN / Mesh (5 repos -> 1 canonical)

**Canonical:** `axe-conduit` (federated mesh substrate)

| Repo | Description | Recommendation | Notes |
|------|-------------|----------------|-------|
| `axe-vpn` | VPN client with kill switch | Review: merge into conduit | Last push: 2026-05-09 |
| `axe-axeguard` | Zero-trust AI mesh VPN daemon | Review: merge into conduit | Last push: 2026-05-10 |
| `axe-wire` | Python userspace tunnel (Noise_IKpsk2) | Review: merge into conduit | Last push: 2026-05-10 |
| `axe-axescale` | Tailscale-class WireGuard control | Review: merge into conduit | Last push: 2026-04-27 |

### Research (5 repos -> 1 canonical)

**Canonical:** `meridian` (research swarm)

| Repo | Description | Recommendation | Notes |
|------|-------------|----------------|-------|
| `meridian-icu` | 5-phase multi-agent research | Review: merge into meridian | Last push: 2026-06-19 |
| `axe-research-engine` | (no description) | Review: merge or archive | Last push: 2026-06-18 |
| `homer` | Internal research/intel/ops brain | Review: merge into meridian or keep if ops-specific | Last push: 2026-06-18 |
| `partner` | Autonomous AI runner and research tools | Review: merge into meridian | Last push: 2026-06-19 |

### Auth (3 repos -> 1 canonical)

**Canonical:** `authgate` (self-hosted push-auth)

| Repo | Description | Recommendation | Notes |
|------|-------------|----------------|-------|
| `axe-shield` | Zero-trust AI auth (CASTLE-tier) | Review: merge into authgate | Last push: 2026-04-15 |
| `authgate-native` | (no description) | Review: merge as subdir in authgate | Last push: 2026-06-19 |

### Intel (2 repos -> 1 canonical)

**Canonical:** `axe-intel` (more detailed description)

| Repo | Description | Recommendation | Notes |
|------|-------------|----------------|-------|
| `intel` | Same domain (intel.axetechnologies.ca) | Review: verify identical, archive older | Both ~3.5MB |

### IMI / theANSWER (12 repos -> 3 canonical)

**Canonical:** `axe-imibuild` (pipeline) + `theANSWERapp` (app) + `imi-backend` (API)

| Repo | Description | Recommendation | Notes |
|------|-------------|----------------|-------|
| `imi-research-drop` | (no description) | Review: archive if one-time drop | Last push: 2026-06-19 |
| `imi-live` | (no description) | Review: merge into imi-backend | Last push: 2026-05-29 |
| `imi-klausfiles` | Klaus.systems source files | Review: archive (Klaus superseded?) | Last push: 2026-05-25 |
| `theanswerai` | Blueprint: train/gate/serve specialists | Review: merge into theANSWERapp | Last push: 2026-06-05 |
| `axe-imi` | Sovereign AI for IMI Pulse | Review: merge into axe-imibuild | Last push: 2026-06-02 |
| `imi-app` | (no description) | Review: merge into theANSWERapp | Last push: 2026-05-29 |
| `answerai-designs` | (no description) | Review: archive (design assets) | Last push: 2026-06-12 |

### Training / ML (12 repos -> 3 canonical)

**Canonical:** `axe-edge` (foundation model) + `AXeGoFlywheel` (training pipeline) + `axe-ml` (ML platform)

| Repo | Description | Recommendation | Notes |
|------|-------------|----------------|-------|
| `axe-dl` | Pretraining/GRPO/LoRA/distillation pipeline | Review: merge into AXeGoFlywheel | Last push: 2026-05-14 |
| `axe-distillery` | Proprietary distillation pipeline | Review: merge into AXeGoFlywheel | Last push: 2026-05-14 |
| `axe-flywheel` | Collect/Score/Train/Deploy engine | Review: merge into AXeGoFlywheel (duplicate name?) | Last push: 2026-04-14 |
| `axe-collector` | Telemetry pipeline for training pairs | Review: merge into AXeGoFlywheel | Last push: 2026-04-14 |
| `axe-supercharge` | Cognitive AI OS (axe-meta/loom/oracle/verify) | Review: keep if active research, else archive | Last push: 2026-06-19 |
| `WINcorpus` | Verified wins corpus for Code-7B | Review: merge into axe-ml | Last push: 2026-06-21 |
| `AXeEpistemics` | Founding doctrine + verified knowledge | Review: keep (foundational doc) | Last push: 2026-05-31 |
| `code7b` | (no description) | Review: archive if superseded by Edge | Last push: 2026-06-01 |
| `cursoragent-trace` | Private Cursor agent traces for SFT | Review: merge into axe-ml | Last push: 2026-04-25 |

---

## Repos confirmed canonical (no action needed)

| Repo | Function |
|------|----------|
| `tether` | Smart tethering app |
| `tether.diy` | Marketing site |
| `axe-config` | System configuration |
| `axe-edge` | Foundation model |
| `axe-ml` | ML platform |
| `AXeGoFlywheel` | Training pipeline |
| `AXeGoMCP` | Tool registry (135 tools) |
| `axe-skills` | Skill library (72+) |
| `axe-anvil` | AI document engine |
| `chorus` | AI-native comms |
| `authgate` | Auth service |
| `axe-intel` | Intelligence command |
| `axe-aibrowser` | Desktop browser |
| `axe-lens-ios` | Mobile browser |
| `meridian` | Research swarm |
| `axe-conduit` | Mesh substrate |
| `axe-memory-gateway` | Memory API |
| `mum-memory` | Special purpose |
| `axe-vigil` | Agent swarm hub |
| `axe-ghost` | Fleet operative |
| `axe-knox` | Tool-call security |
| `AXeGoTrust` | Model provenance |
| `axe-classifier` | Intent classifier |
| `axe-runway` | Model configurations |
| `axe-tower` | Fleet dashboard |
| `axe-design-system` | Design system |
| `axe-gateway` | Gateway orchestrator (unarchived) |
| `axeagentsapp` | Native AI command center |
| `theANSWERapp` | IMI app |
| `axe-imibuild` | IMI pipeline |
| `imi-backend` | IMI API |
| `marketsim` | Market simulator |
| `axe-bunker` | Database platform |
| `axe-halo` | Knowledge vault |
| `axe-crown` | Knowledge surface |
| `axe-algorithm` | Recommendation AI |
| `axe-aiworker` | AI worker (Manus-pattern) |
| `axe-warden` | Off-grid AI radio |
| `axe-nano` | iPhone agent |
| `axe-oracle` | Knowledge artifact |
| `axe-loom` | LoRA mixer |
| `dotfiles` | Dev environment |
| `axe-family` | Private |
| `axetechnologies.ca` | Company website |

---

## Process

1. **This round (today):** Archive 3 verified-safe repos. Unarchive axe-gateway.
2. **Team review (this week):** Each functional group lead reviews their section above and confirms merge/archive decisions.
3. **Merge round (next week):** For each confirmed merge, extract unique code/docs into canonical repo before archiving the source.
4. **No deletions.** Archived repos remain accessible. Git history preserved.

---

## Target state

| Metric | Before | After (estimated) |
|--------|--------|-------------------|
| Total repos | 200 | ~60 active + ~140 archived |
| MCP repos | 5 | 1 (`AXeGoMCP`) |
| Skills locations | 4 | 1 (`axe-skills`) |
| Memory repos | 10 | 2 |
| Chat repos | 6 | 1 (`chorus`) |
| Research repos | 5 | 1 (`meridian`) |

---

*This document is a recommendation. No repo is archived without team confirmation unless it self-describes as superseded and has a verified canonical replacement.*
