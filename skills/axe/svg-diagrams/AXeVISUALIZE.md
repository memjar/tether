# axe-visualize — Integration Guide

AXE Technologies | SVG Diagram System

---

## What this is

Three pieces that work together:

```
SKILL.md          → agent-side: tells your model HOW to produce diagrams
server.py         → gateway-side: MCP tool that takes a JSON spec, returns SVG
SVGWidget.tsx     → UI-side: React component that renders SVG + wires interactions
```

The model never writes SVG directly. It calls `axe_visualize` with a structured
spec. The MCP server does the geometry. The widget renders it and routes node
clicks back to gateway.axe.onl as new agent calls.

---

## Deployment

### 1. MCP server on JL1

```bash
# Install
pip install fastmcp pydantic

# With Databricks artifact storage
pip install fastmcp pydantic databricks-sdk

# Run (pick a port not used by your existing specialists)
python src/server.py --port 8204

# Or via uvicorn for production
uvicorn src.server:mcp.http_app --host 0.0.0.0 --port 8204
```

### 2. Register with gateway.axe.onl

Add to your gateway MCP config:

```json
{
  "mcpServers": {
    "axe-visualize": {
      "url": "http://jl1:8204/mcp",
      "name": "axe-visualize"
    }
  }
}
```

### 3. Add SKILL.md to your agent skill loader

```python
# In your agent bootstrap / system prompt builder
skill_path = "/skills/axe-svg-diagrams/SKILL.md"
with open(skill_path) as f:
    skill_content = f.read()

system_prompt = base_prompt + "\n\n" + skill_content
```

### 4. Drop SVGWidget.tsx into Pulse Chat v2

```tsx
// In your message thread component
import { SVGWidget, renderMessageContent } from './SVGWidget';

// Wire sendPrompt to your gateway call
const handleSendPrompt = (text: string) => {
  sendToGateway(text, currentSessionId);
};

// In your message renderer
{message.content.includes('<svg') 
  ? <SVGWidget svg={extractSVG(message.content)} onSendPrompt={handleSendPrompt} />
  : <MarkdownBlock content={message.content} />
}
```

---

## Usage patterns

### Pattern 1: Agent calls axe_visualize directly

Your Qwen specialist or Claude agent calls the tool:

```python
result = axe_visualize(DiagramSpec(
    type="pipeline",
    title="GGUF deploy pipeline",
    description="Steps from trained model to edge-deployable GGUF artifact",
    nodes=[
        Node(id="train", label="Databricks fine-tune", sublabel="Qwen 14B QLoRA", color="c-teal",
             prompt="Walk me through the Databricks QLoRA config"),
        Node(id="merge", label="Adapter merge",        sublabel="axe-mlx fuse",   color="c-purple",
             prompt="How does LoRA adapter fusion work?"),
        Node(id="quant", label="Quantize to GGUF",     sublabel="Q4_K_M or Q8",   color="c-slate",
             prompt="What quantization level should we use for JL1?"),
        Node(id="deploy", label="Deploy to JL1",       sublabel=":8201/:8202/:8203", color="c-coral",
             prompt="How does the GGUF binary load on JL1?"),
    ],
    edges=[
        Edge(from_id="train", to_id="merge"),
        Edge(from_id="merge", to_id="quant"),
        Edge(from_id="quant", to_id="deploy"),
    ],
    store_artifact=True,
    session_id="pulse_chat_session_abc123",
))

svg_string = result["svg"]  # ready for SVGWidget
```

### Pattern 2: Quick call from agent (no full spec)

```python
result = axe_visualize_quick(
    nodes=[
        "Behavioral data|IMI raw events",
        "Databricks pipeline|ETL + feature eng",
        "Qwen 14B|LoRA fine-tune",
        "Eval cycle|30-min rubric score",
        "GGUF deploy|JL1 :8201",
    ],
    colors=["c-blue", "c-teal", "c-purple", "c-green", "c-coral"],
    prompts=[
        "What behavioral data does IMI collect?",
        "Walk me through the Databricks ETL pipeline",
        "What LoRA config is used for Qwen 14B?",
        "How does the 30-minute eval cycle work?",
        "How does GGUF load on JL1?",
    ],
    diagram_type="pipeline",
    title="IMI closed-loop flywheel",
)
```

### Pattern 3: Model produces spec via tool call (preferred for Pulse Chat v2)

The model receives the SKILL.md as part of its system prompt. When a diagram
is needed, it calls `axe_visualize` via the MCP tool interface. The gateway
routes the call to JL1:8204, gets back an SVG string, and includes it in the
response. SVGWidget.tsx renders it inline.

---

## Databricks artifact storage (wire-up)

Replace the stub in `server.py` with your actual SDK call:

```python
from databricks.sdk import WorkspaceClient
from databricks.sdk.service.files import FileSystemClient

def store_artifact(svg: str, spec: DiagramSpec) -> str:
    w = WorkspaceClient()
    diagram_hash = hashlib.sha256(svg.encode()).hexdigest()[:12]
    path = f"/Volumes/axe_catalog/diagrams/{spec.session_id}/{diagram_hash}.svg"
    w.files.upload(path, svg.encode())
    return path
```

---

## Adding new diagram types

1. Add the type to `DiagramType` in `server.py`
2. Write a `layout_{type}` function following the existing pattern
3. Register it in the `layout_fn` dict in `assemble_svg`
4. Add a usage example to `SKILL.md` under "Diagram types to use"
5. Add component examples to `SKILL.md` under "AXE/IMI diagram vocabulary"

---

## Files

```
axe-svg-diagrams/
  SKILL.md              ← agent-side skill (load in system prompt)

axe-visualize-mcp/
  pyproject.toml        ← package config
  src/
    server.py           ← MCP server (deploy to JL1:8204)
    SVGWidget.tsx       ← React component (add to Pulse Chat v2)
  INTEGRATION.md        ← this file
```
