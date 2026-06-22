# AXE ULTRAPLAN — Enterprise Restructuring + Sprint Plan
## 2026-06-22 | Prepared by Ghost Operative

---

## Part 1: Enterprise Repository Restructuring

### Current State
- 198 repos, 196 private, 2 public
- ~13 empty, ~25 overlapping pairs, 8 functional groups with 4-7x redundancy
- No consistent naming convention, no monorepo strategy, no repo ownership model

### Target State: Enterprise LLM Company Structure

Modeled after Anthropic, OpenAI, Hugging Face, and Databricks repo architecture:

```
TIER 1 — CORE PLATFORM (6 repos)
  axe-platform        <- merge: axe-app, axe-command-centre, axe-dashboard, axe-portal, axe-desktop
  axe-gateway          <- gateway.axe.onl (already canonical, production code)
  axe-infrastructure   <- merge: axe-ocean, axe-config, axe-system, axe-server
  axe-auth             <- merge: authgate, authgate-native, axe-shield, observer-auth
  axe-sdk              <- canonical SDK for all AXE API consumers
  axe-docs             <- merge: axe-docs, awesome-axe-code, axe-enterprise-trust

TIER 2 — AI / ML (5 repos)
  axe-models           <- merge: axe-edge, axe-edgecode, axe-edge-app, axe-promodels, axe-lm
  axe-training         <- merge: axe-dl, axe-flywheel, AXeGoFlywheel, axe-distillery
  axe-eval             <- merge: axe-eval, touchstone, AXeGoTrust
  axe-tools            <- AXeGoMCP (already canonical, 172 tools)
  axe-skills           <- already canonical, 72+ skills

TIER 3 — PRODUCTS (6 repos)
  chorus               <- AI-native comms (already canonical)
  meridian             <- research engine (keep meridian + meridian-icu)
  tether               <- smart tethering (already canonical, public)
  axe-agents           <- merge: axeagentsapp, axe-agent, agent-fleet, axe-aiworker
  axe-intel            <- merge: axe-intel, axe-intel-terminal, homer
  axe-browser          <- surfboard (already consolidated with aibrowser)

TIER 4 — INFRASTRUCTURE SERVICES (5 repos)
  axe-memory           <- merge: axe-mem, axe-palace, axe-memunlocked, axe-recall, Aeterna, axe-vault
  axe-knowledge        <- merge: axe-crown, axe-halo, axe-obsidian, axe-onix, axe-oracle
  axe-mesh             <- merge: axe-axeguard, axe-axescale, axe-wire, axe-vpn, axe-conduit
  axe-database         <- merge: axe-bunker, axe-atlas
  axe-security         <- merge: axe-ghost, axe-knox, axe-bypass

TIER 5 — CLIENT APPS (4 repos)
  axe-ios              <- merge: axe-nano, axe-pulse, axe-lens-ios, axe-beamapp, iosapps
  axe-macos            <- merge: axe-app-swift, axe-pulse-mac, axe-reins
  tether-ios           <- already exists (renamed from Carmack)
  axe-web              <- axetechnologies.ca (keep)

TIER 6 — IMI / CUSTOMER (3 repos)
  imi-platform         <- merge: axe-imi, axe-imibuild, imi-backend, imi-sdk, theanswerai
  imi-app              <- merge: imi-app, theANSWERapp, pulseai-chat, imi-live
  axe-anvil            <- document engine (already canonical)

TIER 7 — RESEARCH / INTERNAL (4 repos)
  axe-research         <- merge: axe-research-engine, foundry-research, axiom-research, axe-karp
  axe-design           <- merge: axe-brand, axe-design, axe-design-system, axiom-designs
  AXeEpistemics        <- founding doctrine (keep as-is)
  axe-games            <- competition/research (keep)
```

**Result: 198 repos -> ~33 canonical repos + archives**

---

## Part 2: Suggestions

### Immediate (this sprint)
1. **Rotate axe-gateway API key** — exposed in git history, private repo but still a risk
2. **Archive 13 empty repos** — zero risk, zero value
3. **Enable GitHub secret scanning** on all repos if not already active
4. **Create `CODEOWNERS` files** in top-10 repos by activity
5. **Standardize branch protection** — require PR reviews on canonical repos

### Short-term (next 2 sprints)
6. **Monorepo migrations** — start with lowest-risk groups: Design (4->1), Auth (4->1), VPN/Mesh (5->1)
7. **CI/CD standardization** — GitHub Actions templates across canonical repos
8. **Dependency audit** — `npm audit` / `pip audit` across all repos with package files
9. **Fleet security sweep** — dispatch to JL1 agents (see Part 4)

### Medium-term (next month)
10. **Complete Tier 1-3 consolidation** — platform, AI/ML, products
11. **Training data pipeline** — completed tasks -> WINcorpus for model improvement
12. **Sprint dashboard integration** — axe.observer task cards auto-sync with GitHub Issues

### Architectural
13. **Adopt trunk-based development** on canonical repos
14. **Tag releases** — semantic versioning on all Tier 1-2 repos
15. **Internal package registry** — shared Python/JS packages via GitHub Packages

---

## Part 3: Task Assignments

### James (JL / Principal)
Tasks only you can do:

| # | Task | Repo | Priority |
|---|------|------|----------|
| J1 | Rotate axe-gateway API key, update all services using it | `axe-gateway`, fleet nodes | CRITICAL |
| J2 | Review + approve 13 empty repo archives | All empty repos | HIGH |
| J3 | TestFlight rebuild on jl1 under Tether scheme | `tether-ios` on jl1 | HIGH |
| J4 | Review consolidation plan with team leads | This document | HIGH |
| J5 | Decide canonical repos per overlap group | This document | HIGH |
| J6 | Push gateway.axe.onl production code to axe-gateway | `axe-gateway` | MEDIUM |
| J7 | Set up GitHub secret scanning org-wide | GitHub org settings | MEDIUM |
| J8 | Review fleet security sweep results | `axe-observer` dashboard | MEDIUM |
| J9 | Sign off on monorepo migration plan per group | This document | MEDIUM |
| J10 | Update axe.observer sprint board with these tasks | `observer` | MEDIUM |

### Ghost (AI Operative / Automated)
Tasks for AI agents:

| # | Task | Repo | Priority |
|---|------|------|----------|
| G1 | Run `git log -p -S` credential scan across all 196 private repos | All repos via fleet | CRITICAL |
| G2 | Generate CODEOWNERS for top-10 active repos | Top-10 by commit frequency | HIGH |
| G3 | Run `npm audit` / `pip audit` on all repos with package files | All repos with deps | HIGH |
| G4 | Create migration PRs for Design group (4->1) | `axe-design-system` | MEDIUM |
| G5 | Create migration PRs for Auth group (4->1) | `authgate` | MEDIUM |
| G6 | Index all MCP servers across repos | All repos | MEDIUM |
| G7 | Index all SKILL.md files across repos | All repos | MEDIUM |
| G8 | Build repo dependency graph (which repos import from which) | All repos | LOW |

### Team Members — Fleet Nodes
- **Nova (JL1)** — primary compute, model hosting, inference
- **Forge (JL2)** — build/deploy, IMI pipeline, customer-facing
- **Vigil (JL3)** — agent swarm, memory, perpetuity-loop, ops

| # | Task | Assignee | Repo | Priority |
|---|------|----------|------|----------|
| T1 | Review IMI group consolidation, confirm canonical repos | Forge (JL2) | `imi-*`, `theANSWER*` | HIGH |
| T2 | Review ML/Training group, confirm flywheel canonical | Nova (JL1) | `axe-dl`, `AXeGoFlywheel` | HIGH |
| T3 | Review product repos, confirm which apps ship | Forge (JL2) | `axe-agents`, `axe-browser` | MEDIUM |
| T4 | Audit axe-ghost for leaked credentials | Vigil (JL3) | `axe-ghost` | HIGH |
| T5 | Audit axe-knox key management | Vigil (JL3) | `axe-knox` | HIGH |
| T6 | Update sprint dashboard task cards | Forge (JL2) | `observer` | MEDIUM |
| T7 | Archive previous sprint tasks to training corpus | Nova (JL1) | `WINcorpus` | LOW |
| T8 | Run credential scan across all 196 private repos | Nova (JL1) | All repos | CRITICAL |
| T9 | Memory group consolidation analysis (17 repos) | Vigil (JL3) | `axe-memory`, `axe-crown` | MEDIUM |
| T10 | Dependency audit (npm/pip) across all repos with packages | Nova (JL1) | All repos | HIGH |
| T11 | Index all MCP servers + SKILL.md files across org | Vigil (JL3) | All repos | MEDIUM |
| T12 | Build repo dependency graph (import/require mapping) | Nova (JL1) | All repos | LOW |

---

## Part 4: Fleet Security Sweep Task

Queue for JL1 fleet dispatch:

```bash
# Credential scan across all private repos
# Dispatch to axe-worker-headless or JL1 agents

SCAN_TARGETS=(
  "Bearer" "sk-" "api_key" "API_KEY" "secret" "token"
  "password" "private_key" "-----BEGIN" "ghp_" "gho_"
  "AKIA" "aws_secret" "client_secret"
)

for repo in $(gh repo list memjar --limit 200 --json name --jq '.[].name'); do
  for pattern in "${SCAN_TARGETS[@]}"; do
    gh api repos/memjar/$repo/git/grep -f query="$pattern" 2>/dev/null
  done
done
```

Dispatch via: `POST gateway.axe.onl/fleet/dispatch`
Results stored in: `axe-observer` security dashboard
Alert on: any match in non-.env.example, non-.md files

---

## Part 5: Training Data Pipeline

### Completed Tasks (this session) — save for model training

```json
{
  "session": "2026-06-21",
  "tasks_completed": [
    {"task": "Integrate AXE visualizer (SKILL.md, SVGWidget.tsx, MCP server)", "repo": "tether", "commit": "f13707c"},
    {"task": "Add AI-agnostic enterprise blueprint", "repo": "tether", "commit": "27fdfa9"},
    {"task": "Audit 200 repos, archive 3, unarchive 1", "repo": "tether", "commit": "8179db4"},
    {"task": "Unarchive surfboard, add aibrowser as sibling", "repo": "surfboard", "commit": "1af2dab"},
    {"task": "Register visualize tools in AXeGoMCP (172 tools)", "repo": "AXeGoMCP", "commit": "b71e018"},
    {"task": "Deep consolidation review + security audit", "repo": "tether", "commit": "17bdee0"},
    {"task": "Add __pycache__ to gitignore", "repo": "tether", "commit": "e864a89"}
  ],
  "decisions": [
    "surfboard is canonical browser repo, not axe-aibrowser",
    "axe-gateway contains critical production infra — do not archive",
    "Only archive repos with self-described 'superseded' status AND verified canonical replacement",
    "13 empty repos identified as safe archive candidates"
  ],
  "training_value": "repo_consolidation, security_audit, enterprise_restructuring, principal_engineering"
}
```

Store at: `WINcorpus/sessions/2026-06-21-consolidation.json`
Feed to: Edge training pipeline via AXeGoFlywheel

---

## Part 6: Sprint Dashboard Updates

### axe.observer Task Cards to Create

| Card | Status | Assignee | Sprint |
|------|--------|----------|--------|
| Rotate gateway API key | TODO | James | Current |
| Archive 13 empty repos | TODO | James (approve) + Ghost (execute) | Current |
| TestFlight rebuild (Tether scheme) | TODO | James on jl1 | Current |
| Fleet credential scan (196 repos) | TODO | Ghost fleet | Current |
| Design group consolidation (4->1) | TODO | Ghost + review | Next |
| Auth group consolidation (4->1) | TODO | Ghost + review | Next |
| VPN/Mesh monorepo (5->1) | TODO | Ghost + review | Next |
| Memory group consolidation (17->4) | PLANNED | Team | Next+1 |
| App/Platform consolidation (11->4) | PLANNED | Team | Next+1 |
| Full enterprise restructure complete | PLANNED | All | Q3 target |

---

## Appendix: Repos NOT to Touch

These repos have active production traffic or unique irreplaceable content:

- `chorus` — live comms platform
- `axe-gateway` — production API relay
- `authgate` — SSO for all services
- `axe-ghost` — 46MB of security tooling
- `axe-skills` — 36MB skill library
- `AXeGoMCP` — 172-tool registry
- `axe-vigil` — agent swarm coordinator
- `axeCHAT` — 58MB comms platform
- `mum-memory` — 68MB brain backup (data, not code)
- `axe-system` — 270MB (investigate before touching)
