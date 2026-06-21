---
name: axe-svg-diagrams
version: 1.1.0
owner: AXE Technologies
model_compatibility: any — Qwen, Claude, GPT, Gemini, Llama, or custom
description: >
  Use this skill whenever generating a visual diagram, architecture map, agent
  topology, model pipeline, data flow, or any structured visual for the AXE/IMI
  stack. Triggers: "diagram", "visualize", "show me", "map out", "draw the flow",
  "architecture of", or any request where a structured visual communicates more
  than prose. Outputs a raw <svg> string. The front end renders it via
  SVGWidget — no model-specific renderer required. Do NOT use for numeric
  charts or graphs — use a charting library for that.
---

# AXE SVG Diagrams Skill

You are generating a branded SVG diagram for the AXE/IMI platform. The output
is a raw `<svg>` element injected directly into the front end. This skill is
model-agnostic — it works identically whether you are Qwen, Claude, GPT,
Gemini, or a custom AXE fine-tune.

**Output contract:** respond with only the raw `<svg>` element. No wrapper
markup, no markdown fences, no prose before or after the tag. If the caller
also needs an explanation, that is a separate response turn.

---

## Core output rules

- Output ONLY the raw `<svg>` element.
- `viewBox="0 0 680 {H}"` — width always 680. Height calculated from content.
  All elements must fit within x=40..640, y=40..(H-40).
- Dark mode mandatory. Use only the AXE CSS variables and color classes
  defined below. Never hardcode hex colors on themed elements.
- Every `<text>` must carry class `t`, `ts`, or `th`. Unclassed text breaks
  in dark mode.
- Every interactive node must have `onclick="axe.action('...')"` — the
  interaction callback. See "Interaction model" below.
- Labels max 30 chars. SVG text never wraps — shorten or move detail to prose.
- No gradients, drop shadows, blur, or glow. Flat fills only.
- Sentence case on all labels. Never ALL CAPS or Title Case on node labels.
  Exception: verdict labels (STABLE, DRIFT, IMPROVED) are always uppercase.
- Include the arrow `<defs>` marker block at the top of every SVG.
- `fill="none"` on every `<path>` or `<polyline>` used as a connector line.

---

## Interaction model

Node clicks fire through a single generic callback:

```js
axe.action(text)
```

The front end (SVGWidget) wires `axe.action` to whatever is appropriate for
the runtime:

- In Pulse Chat v2 → posts `text` as the next user message to gateway.axe.onl
- In a static report → logs or no-ops
- In a test harness → captures for assertion

**You, the model, only write the text string.** You do not know or care how
the front end wires it. Write questions that are specific and actionable:

```svg
onclick="axe.action('Walk me through the Qwen 14B LoRA training config')"
onclick="axe.action('How does drift detection work in the eval cycle?')"
onclick="axe.action('What does Redis handle in the AXE agent message bus?')"
```

Never use `sendPrompt`, `window.postMessage`, or any model-specific function
name. Always use `axe.action`.

---

## AXE design tokens

Injected by SVGWidget at render time. Use CSS variable names exactly.

```
Text
  var(--axe-text-primary)    main labels
  var(--axe-text-secondary)  sublabels, descriptions
  var(--axe-text-muted)      leader lines, hints

Borders
  var(--axe-border)          default stroke
  var(--axe-border-strong)   arrows, emphasis

Backgrounds
  var(--axe-bg-surface)      neutral node fill
  var(--axe-bg-elevated)     elevated card fill

Shortcuts
  var(--p)  → axe-text-primary
  var(--s)  → axe-text-secondary
  var(--b)  → axe-border
  var(--bg2)→ axe-bg-surface
```

Pre-built SVG classes (auto-loaded by widget runtime):

```
t        14px regular,  var(--axe-text-primary)
ts       12px regular,  var(--axe-text-secondary)
th       14px 500,      var(--axe-text-primary)
box      fill: var(--axe-bg-surface), stroke: var(--axe-border)
arr      1.5px stroke,  var(--axe-border-strong), chevron head
leader   0.5px dashed,  var(--axe-text-muted)
node     cursor pointer, hover dims opacity to 0.85
```

---

## AXE color ramps

Apply `c-{ramp}` to the innermost `<g>` containing shape + text.
Never apply to `<path>` elements. Each class handles light + dark mode.

| Class    | Semantic meaning in AXE/IMI              |
|----------|------------------------------------------|
| c-slate  | Infra, structural (Databricks, Redis)    |
| c-teal   | Data pipeline, training jobs             |
| c-purple | Model layer (any model, LoRA, weights)   |
| c-coral  | Orchestration, routing, gateway          |
| c-amber  | Scheduled agents, background, Tier 5     |
| c-blue   | Product surface (Pulse Chat, Lens, Vanna)|
| c-green  | Eval pass, STABLE, IMPROVED verdicts     |
| c-red    | Drift, failure, DRIFT verdict, alerts    |

Color values (light fill / dark fill — for reference only, do not hardcode):

```
c-slate   #F1EFE8 / #444441
c-teal    #E1F5EE / #085041
c-purple  #EEEDFE / #3C3489
c-coral   #FAECE7 / #712B13
c-amber   #FAEEDA / #633806
c-blue    #E6F1FB / #0C447C
c-green   #EAF3DE / #27500A
c-red     #FCEBEB / #791F1F
```

---

## Required arrow marker

Include inside `<defs>` at the top of every SVG:

```svg
<defs>
  <marker id="arrow" viewBox="0 0 10 10" refX="8" refY="5"
          markerWidth="6" markerHeight="6" orient="auto-start-reverse">
    <path d="M2 1L8 5L2 9" fill="none" stroke="context-stroke"
          stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"/>
  </marker>
</defs>
```

---

## Component patterns

### Two-line node (56px)

```svg
<g class="node c-teal" onclick="axe.action('Explain the Databricks training job')">
  <rect x="60" y="40" width="200" height="56" rx="8" stroke-width="0.5"/>
  <text class="th" x="160" y="60" text-anchor="middle" dominant-baseline="central">Databricks job</text>
  <text class="ts" x="160" y="78" text-anchor="middle" dominant-baseline="central">QLoRA fine-tune pass</text>
</g>
```

### Single-line node (44px)

```svg
<g class="node c-purple" onclick="axe.action('What does this model specialist do?')">
  <rect x="60" y="40" width="180" height="44" rx="8" stroke-width="0.5"/>
  <text class="th" x="150" y="62" text-anchor="middle" dominant-baseline="central">Model specialist</text>
</g>
```

### Connector arrow

```svg
<line x1="160" y1="98" x2="160" y2="130"
      stroke="var(--b)" stroke-width="1" marker-end="url(#arrow)"/>
```

### Dashed container (logical group)

```svg
<rect x="40" y="200" width="600" height="120" rx="12"
      fill="none" stroke="var(--b)" stroke-width="0.5" stroke-dasharray="6 4"/>
<text class="ts" x="56" y="220">Specialist cluster</text>
```

### Infra bar (4 boxes, bottom of diagram)

x positions: 60, 206, 352, 498 — width 128 each, gap 18. Use `c-slate`.

---

## AXE/IMI diagram vocabulary

Use these exact names for consistency. Lens and eval tooling may parse labels.

**Models** (model-agnostic — list the actual model, not the provider)
- `Qwen 14B` — sub-agent specialist, LoRA fine-tuned, JL1
- `Qwen 72B` — heavy training, rented GPU / Databricks
- `[model name]` — use whatever model is actually running; do not assume Claude
- `axe-mlx` — local MLX inference, Mac Studio M1 64GB
- `GGUF` — quantized deploy artifact, edge-deployable

**Infrastructure**
- `Databricks` — training + behavioral data warehouse
- `Redis` — session state, cache, agent message bus
- `TOWER` — fleet observability (Nova + Forge nodes)
- `gateway.axe.onl` — orchestrator entry point
- `JL1` — agent host, :8201 / :8202 / :8203

**Products**
- `Pulse Chat v2` — IMI conversational interface
- `Lens` — institutional intelligence, research methodology
- `Vanna` — fallthrough tier (Daniel / CTO)
- `Authgate` — auth layer
- `Axiom` — (reserved)

**Evaluation**
- `rubric scorer` — 1–5 constitution, 30-min cycle
- `Ed25519 sign` — cryptographic output verification
- `STABLE / DRIFT / IMPROVED` — always uppercase
- `Shawn HITL` — human-in-the-loop reviewer

**Agency tiers**
- `Tier 1` reactive chat
- `Tier 2` tool-augmented chat
- `Tier 3` supervised agent
- `Tier 4` autonomous multi-agent
- `Tier 5` scheduled / background

---

## Diagram types

### Pipeline
Linear sequence. Training, eval, deploy flows.
Top-to-bottom or left-to-right. Max 6 nodes. Split if more complex.

### Topology
Orchestrator at top center, specialists fanned below in rows of 3.
Dashed container around specialist cluster. Infra bar at bottom.

### Spectrum
Vertical tier stack. Lowest tier at top, highest at bottom.
Colors escalate: c-slate (Tier 1) → c-amber (Tier 5).

### Eval loop
Linear sequence with a return arrow at the bottom.
Verdict branch: c-green left (STABLE/IMPROVED), c-red right (DRIFT).

---

## Box sizing

```
min_width = max(title_chars × 8 + 24, sublabel_chars × 7 + 24)

Heights
  single-line   44px
  two-line      56px
  three-line    72px

Row packing (safe width 640px, start x=60)
  4 boxes  width=128  gap=18   x: 60, 206, 352, 498
  3 boxes  width=170  gap=25   x: 60, 255, 450
  2 boxes  width=260  gap=40   x: 60, 360
```

---

## viewBox height

```
H = max(y + height across all elements) + 40
```

Compute from actual coordinates. Never guess.

---

## Full example — eval loop

```svg
<svg width="100%" viewBox="0 0 680 480" role="img">
  <title>AXE model evaluation loop</title>
  <desc>30-minute rubric scoring cycle with drift detection and Ed25519 signing</desc>
  <defs>
    <marker id="arrow" viewBox="0 0 10 10" refX="8" refY="5"
            markerWidth="6" markerHeight="6" orient="auto-start-reverse">
      <path d="M2 1L8 5L2 9" fill="none" stroke="context-stroke"
            stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"/>
    </marker>
  </defs>

  <g class="node c-teal" onclick="axe.action('How are test prompts generated for the eval cycle?')">
    <rect x="240" y="40" width="200" height="56" rx="8" stroke-width="0.5"/>
    <text class="th" x="340" y="60" text-anchor="middle" dominant-baseline="central">Test prompt batch</text>
    <text class="ts" x="340" y="78" text-anchor="middle" dominant-baseline="central">Auto-generated, 30-min cadence</text>
  </g>

  <line x1="340" y1="98" x2="340" y2="128" stroke="var(--b)" stroke-width="1" marker-end="url(#arrow)"/>

  <g class="node c-purple" onclick="axe.action('How does the 1-5 rubric constitution work?')">
    <rect x="240" y="130" width="200" height="56" rx="8" stroke-width="0.5"/>
    <text class="th" x="340" y="150" text-anchor="middle" dominant-baseline="central">Rubric scorer</text>
    <text class="ts" x="340" y="168" text-anchor="middle" dominant-baseline="central">1–5 constitution, threshold 0.3</text>
  </g>

  <line x1="340" y1="188" x2="340" y2="218" stroke="var(--b)" stroke-width="1" marker-end="url(#arrow)"/>

  <g class="node c-green" onclick="axe.action('What happens on a STABLE verdict?')">
    <rect x="100" y="220" width="160" height="44" rx="8" stroke-width="0.5"/>
    <text class="th" x="180" y="242" text-anchor="middle" dominant-baseline="central">STABLE / IMPROVED</text>
  </g>
  <g class="node c-red" onclick="axe.action('What happens when DRIFT is detected?')">
    <rect x="420" y="220" width="160" height="44" rx="8" stroke-width="0.5"/>
    <text class="th" x="500" y="242" text-anchor="middle" dominant-baseline="central">DRIFT flagged</text>
  </g>

  <line x1="290" y1="218" x2="220" y2="218" stroke="var(--b)" stroke-width="1" marker-end="url(#arrow)"/>
  <line x1="390" y1="218" x2="450" y2="218" stroke="var(--b)" stroke-width="1" marker-end="url(#arrow)"/>

  <g class="node c-slate" onclick="axe.action('How does Ed25519 signing work in the eval pipeline?')">
    <rect x="240" y="310" width="200" height="44" rx="8" stroke-width="0.5"/>
    <text class="th" x="340" y="332" text-anchor="middle" dominant-baseline="central">Ed25519 sign output</text>
  </g>
  <line x1="180" y1="264" x2="300" y2="310" stroke="var(--b)" stroke-width="1" marker-end="url(#arrow)"/>

  <g class="node c-blue" onclick="axe.action('When does Shawn review in the eval loop?')">
    <rect x="420" y="310" width="160" height="54" rx="8" stroke-width="0.5"/>
    <text class="th" x="500" y="330" text-anchor="middle" dominant-baseline="central">Shawn HITL review</text>
    <text class="ts" x="500" y="348" text-anchor="middle" dominant-baseline="central">Post-product surface</text>
  </g>
  <line x1="500" y1="264" x2="500" y2="308" stroke="var(--b)" stroke-width="1" marker-end="url(#arrow)"/>

  <g class="node c-amber" onclick="axe.action('How does Shawn feedback re-enter training data?')">
    <rect x="240" y="400" width="200" height="44" rx="8" stroke-width="0.5"/>
    <text class="th" x="340" y="422" text-anchor="middle" dominant-baseline="central">Feedback → training data</text>
  </g>
  <line x1="340" y1="356" x2="340" y2="398" stroke="var(--b)" stroke-width="1" marker-end="url(#arrow)"/>
  <line x1="500" y1="364" x2="400" y2="400" stroke="var(--b)" stroke-width="1" marker-end="url(#arrow)"/>

</svg>
```
