"""
axe_visualize MCP Server
AXE Technologies — AI-agnostic SVG diagram generation

Model-agnostic: works with Qwen, Claude, GPT, Gemini, Llama, or any
model that can call MCP tools. No provider-specific dependencies.

Deploy: gateway.axe.onl or standalone on JL1:8204
"""

from fastmcp import FastMCP
from pydantic import BaseModel, Field
from typing import Literal, Optional
import hashlib
import time

mcp = FastMCP(
    name="axe-visualize",
    instructions="""
AXE Technologies SVG diagram generation tool.
Use axe_visualize to produce branded, interactive SVG diagrams for the AXE/IMI
stack. Pass a DiagramSpec with nodes, edges, and type. Receive a raw SVG string
ready for SVGWidget. Use axe_visualize_quick for fast calls with parallel lists.
This tool is model-agnostic — call it from Qwen, Claude, or any other model.
""",
)

# ── Types ─────────────────────────────────────────────────────────────────────

AXEColor = Literal[
    "c-slate",    # infra, structural
    "c-teal",     # data pipeline, training
    "c-purple",   # model layer (any model)
    "c-coral",    # orchestration, routing
    "c-amber",    # scheduled agents, Tier 5
    "c-blue",     # product surface
    "c-green",    # eval pass, STABLE/IMPROVED
    "c-red",      # drift, failure, alerts
]

DiagramType = Literal[
    "pipeline",   # linear flow
    "topology",   # orchestrator + specialist fan
    "spectrum",   # agency tier stack
    "eval_loop",  # rubric scoring cycle
    "custom",     # free-form
]

class Node(BaseModel):
    id: str
    label: str = Field(..., description="Primary label, max 25 chars")
    sublabel: Optional[str] = Field(None, description="Secondary label, max 30 chars")
    color: AXEColor = "c-slate"
    action: str = Field(
        ...,
        description="Text passed to axe.action() when this node is clicked"
    )

class Edge(BaseModel):
    from_id: str
    to_id: str
    dashed: bool = False

class DiagramSpec(BaseModel):
    type: DiagramType
    title: str
    description: str = Field(..., description="One sentence for SVG <desc>")
    nodes: list[Node]
    edges: list[Edge] = []
    store_artifact: bool = False
    session_id: Optional[str] = None

# ── Design constants ──────────────────────────────────────────────────────────

ARROW_DEFS = """<defs>
  <marker id="arrow" viewBox="0 0 10 10" refX="8" refY="5"
          markerWidth="6" markerHeight="6" orient="auto-start-reverse">
    <path d="M2 1L8 5L2 9" fill="none" stroke="context-stroke"
          stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"/>
  </marker>
</defs>"""

NODE_W   = 200
NODE_H1  = 44
NODE_H2  = 56
GAP_Y    = 24
CANVAS_W = 680
SAFE_X   = 40

# ── Render helpers ────────────────────────────────────────────────────────────

def node_h(node: Node) -> int:
    return NODE_H2 if node.sublabel else NODE_H1

def render_node(node: Node, x: int, y: int, w: int = NODE_W) -> str:
    h   = node_h(node)
    cx  = x + w // 2
    ty  = y + NODE_H1 // 2 if not node.sublabel else y + 20
    out = [
        f'<g class="node {node.color}" onclick="axe.action(\'{node.action}\')">',
        f'  <rect x="{x}" y="{y}" width="{w}" height="{h}" rx="8" stroke-width="0.5"/>',
        f'  <text class="th" x="{cx}" y="{ty}" text-anchor="middle" dominant-baseline="central">{node.label}</text>',
    ]
    if node.sublabel:
        out.append(
            f'  <text class="ts" x="{cx}" y="{y+38}" text-anchor="middle" dominant-baseline="central">{node.sublabel}</text>'
        )
    out.append('</g>')
    return "\n".join(out)

def connector(x1, y1, x2, y2, dashed=False) -> str:
    dash = ' stroke-dasharray="5 4"' if dashed else ""
    return (
        f'<line x1="{x1}" y1="{y1}" x2="{x2}" y2="{y2}" '
        f'stroke="var(--b)" stroke-width="1"{dash} marker-end="url(#arrow)"/>'
    )

# ── Layout strategies ─────────────────────────────────────────────────────────

def layout_pipeline(nodes, edges):
    els, pos = [], {}
    y = 60
    cx_offset = (CANVAS_W - NODE_W) // 2
    for node in nodes:
        els.append(render_node(node, cx_offset, y))
        pos[node.id] = (cx_offset, y, node_h(node))
        y += node_h(node) + GAP_Y
    for e in edges:
        if e.from_id in pos and e.to_id in pos:
            fx, fy, fh = pos[e.from_id]
            tx, ty, _  = pos[e.to_id]
            els.append(connector(fx + NODE_W//2, fy + fh, tx + NODE_W//2, ty, e.dashed))
    return "\n".join(els), y + 40

def layout_topology(nodes, edges):
    if not nodes:
        return "", 200
    els, pos = [], {}
    gw = nodes[0]
    gx = (CANVAS_W - NODE_W) // 2
    gy = 60
    els.append(render_node(gw, gx, gy))
    pos[gw.id] = (gx, gy, node_h(gw))

    specs   = nodes[1:]
    sw      = 160
    sg      = 20
    row_sz  = 3
    base_y  = gy + node_h(gw) + 60

    for i, node in enumerate(specs):
        col   = i % row_sz
        row   = i // row_sz
        n_row = min(row_sz, len(specs) - row * row_sz)
        total = n_row * sw + (n_row - 1) * sg
        sx    = (CANVAS_W - total) // 2 + col * (sw + sg)
        sy    = base_y + row * (NODE_H2 + GAP_Y)
        h     = node_h(node)
        cx    = sx + sw // 2
        ty    = sy + NODE_H1//2 if not node.sublabel else sy + 20
        el    = [
            f'<g class="node {node.color}" onclick="axe.action(\'{node.action}\')">',
            f'  <rect x="{sx}" y="{sy}" width="{sw}" height="{h}" rx="8" stroke-width="0.5"/>',
            f'  <text class="th" x="{cx}" y="{ty}" text-anchor="middle" dominant-baseline="central">{node.label}</text>',
        ]
        if node.sublabel:
            el.append(f'  <text class="ts" x="{cx}" y="{sy+38}" text-anchor="middle" dominant-baseline="central">{node.sublabel}</text>')
        el.append('</g>')
        els.append("\n".join(el))
        els.append(connector(gx + NODE_W//2, gy + node_h(gw), cx, sy))

    max_row = (len(specs) - 1) // row_sz if specs else 0
    final_y = base_y + (max_row + 1) * (NODE_H2 + GAP_Y) + 40
    return "\n".join(els), final_y

def layout_spectrum(nodes, edges):
    els = []
    y   = 60
    w   = 580
    x   = SAFE_X
    for node in nodes:
        h  = node_h(node)
        cx = x + w // 2
        ty = y + NODE_H1//2 if not node.sublabel else y + 20
        el = [
            f'<g class="node {node.color}" onclick="axe.action(\'{node.action}\')">',
            f'  <rect x="{x}" y="{y}" width="{w}" height="{h}" rx="8" stroke-width="0.5"/>',
            f'  <text class="th" x="{cx}" y="{ty}" text-anchor="middle" dominant-baseline="central">{node.label}</text>',
        ]
        if node.sublabel:
            el.append(f'  <text class="ts" x="{cx}" y="{y+38}" text-anchor="middle" dominant-baseline="central">{node.sublabel}</text>')
        el.append('</g>')
        els.append("\n".join(el))
        els.append(connector(cx, y + h, cx, y + h + GAP_Y - 4))
        y += h + GAP_Y
    return "\n".join(els), y + 20

def layout_custom(nodes, edges):
    return layout_pipeline(nodes, edges)

# ── SVG assembly ──────────────────────────────────────────────────────────────

LAYOUTS = {
    "pipeline":  layout_pipeline,
    "topology":  layout_topology,
    "spectrum":  layout_spectrum,
    "eval_loop": layout_pipeline,
    "custom":    layout_custom,
}

def assemble_svg(spec: DiagramSpec) -> str:
    body, h = LAYOUTS[spec.type](spec.nodes, spec.edges)
    return (
        f'<svg width="100%" viewBox="0 0 {CANVAS_W} {h}" role="img">\n'
        f'  <title>{spec.title}</title>\n'
        f'  <desc>{spec.description}</desc>\n'
        f'  {ARROW_DEFS}\n'
        f'  {body}\n'
        f'</svg>'
    )

# ── Artifact store stub ───────────────────────────────────────────────────────

def store_artifact(svg: str, spec: DiagramSpec) -> str:
    """
    Wire to your Databricks SDK:

    from databricks.sdk import WorkspaceClient
    w    = WorkspaceClient()
    path = f"/Volumes/axe_catalog/diagrams/{spec.session_id}/{hash}.svg"
    w.files.upload(path, svg.encode())
    return path
    """
    h = hashlib.sha256(svg.encode()).hexdigest()[:12]
    return f"axe_diagrams/{spec.session_id or 'nosession'}/{h}"

# ── MCP tools ─────────────────────────────────────────────────────────────────

@mcp.tool()
def axe_visualize(spec: DiagramSpec) -> dict:
    """
    Generate a branded AXE/IMI SVG diagram from a structured spec.
    Returns the raw SVG string for injection into SVGWidget.
    Model-agnostic — call from Qwen, Claude, GPT, or any other model.
    """
    svg         = assemble_svg(spec)
    artifact_id = store_artifact(svg, spec) if spec.store_artifact else None
    return {
        "svg":          svg,
        "artifact_id":  artifact_id,
        "node_count":   len(spec.nodes),
        "diagram_type": spec.type,
        "generated_at": int(time.time()),
    }

@mcp.tool()
def axe_visualize_quick(
    nodes:        list[str],
    colors:       list[str],
    actions:      list[str],
    diagram_type: DiagramType = "pipeline",
    title:        str = "AXE diagram",
) -> dict:
    """
    Fast diagram from parallel lists — no full DiagramSpec needed.
    Use label|sublabel syntax to include a sublabel (e.g. "Qwen 14B|LoRA specialist").

    Args:
        nodes:        Label strings, optionally "label|sublabel"
        colors:       AXE color class strings (e.g. "c-teal")
        actions:      axe.action() text strings, one per node
        diagram_type: Layout type
        title:        SVG title string
    """
    if not (len(nodes) == len(colors) == len(actions)):
        return {"error": "nodes, colors, and actions must be the same length"}

    built = []
    for i, (label_str, color, action) in enumerate(zip(nodes, colors, actions)):
        parts = label_str.split("|", 1)
        built.append(Node(
            id       = f"n{i}",
            label    = parts[0].strip(),
            sublabel = parts[1].strip() if len(parts) > 1 else None,
            color    = color,
            action   = action,
        ))

    spec = DiagramSpec(
        type        = diagram_type,
        title       = title,
        description = f"Auto-generated {diagram_type} with {len(built)} nodes",
        nodes       = built,
    )
    return axe_visualize(spec)


if __name__ == "__main__":
    mcp.run()
