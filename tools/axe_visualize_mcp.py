#!/usr/bin/env python3
"""AXE SVG Diagram MCP Tool — generates on-brand diagrams from structured JSON specs."""

import json, math, sys

try:
    from mcp.server.fastmcp import FastMCP
    HAS_MCP = True
except ImportError:
    HAS_MCP = False

AXE_TOKENS = {
    "gold": "#D4AF37", "gold_dark": "#B8962E", "gold_light": "#E8C547",
    "bg": "#0A0A0C", "surface": "#1A1A1F", "surface_raised": "#222228",
    "border": "#2A2A30", "border_active": "#3A3A42",
    "text": "#E0E0E0", "text_sec": "#888888", "text_muted": "#555555",
    "ok": "#4CAF50", "err": "#F44336", "warn": "#FF9800", "info": "#2196F3",
    "tier1": "#D4AF37", "tier2": "#A0A0A0", "tier3": "#8B6914", "inactive": "#333338",
    "font": "'Space Grotesk', sans-serif",
    "mono": "'IBM Plex Mono', monospace",
}

TIER_COLORS = ["#D4AF37", "#A0A0A0", "#8B6914", "#555555"]

def _defs():
    return '''<defs>
  <marker id="arrow" viewBox="0 0 10 7" refX="10" refY="3.5" markerWidth="8" markerHeight="6" orient="auto-start-reverse">
    <path d="M 0 0 L 10 3.5 L 0 7 z" fill="#D4AF37"/>
  </marker>
  <marker id="arrow-muted" viewBox="0 0 10 7" refX="10" refY="3.5" markerWidth="8" markerHeight="6" orient="auto-start-reverse">
    <path d="M 0 0 L 10 3.5 L 0 7 z" fill="#555555"/>
  </marker>
</defs>'''

def _box(x, y, w, h, label, subtitle="", color="#D4AF37"):
    parts = [f'<g transform="translate({x},{y})">',
        f'<rect width="{w}" height="{h}" fill="{AXE_TOKENS["surface"]}" stroke="{color}" stroke-width="1.5"/>',
        f'<rect width="{w}" height="3" fill="{color}"/>',
        f'<text x="{w//2}" y="{h//2 + (0 if subtitle else 5)}" text-anchor="middle" fill="{AXE_TOKENS["text"]}" font-family="{AXE_TOKENS["font"]}" font-size="13" font-weight="700" letter-spacing="0.5">{label}</text>']
    if subtitle:
        parts.append(f'<text x="{w//2}" y="{h//2 + 16}" text-anchor="middle" fill="{AXE_TOKENS["text_sec"]}" font-family="{AXE_TOKENS["mono"]}" font-size="9">{subtitle}</text>')
    parts.append('</g>')
    return '\n'.join(parts)

def _arrow(x1, y1, x2, y2, label="", muted=False):
    mid = "arrow-muted" if muted else "arrow"
    parts = [f'<line x1="{x1}" y1="{y1}" x2="{x2}" y2="{y2}" stroke="{AXE_TOKENS["text_muted"] if muted else AXE_TOKENS["gold"]}" stroke-width="1.5" marker-end="url(#{mid})"/>']
    if label:
        mx, my = (x1+x2)//2, (y1+y2)//2 - 8
        parts.append(f'<text x="{mx}" y="{my}" text-anchor="middle" fill="{AXE_TOKENS["text_sec"]}" font-family="{AXE_TOKENS["mono"]}" font-size="9">{label}</text>')
    return '\n'.join(parts)

def _metric(x, y, name, value):
    return f'''<g transform="translate({x},{y})">
  <rect width="100" height="56" fill="{AXE_TOKENS["surface"]}" stroke="{AXE_TOKENS["border"]}" stroke-width="1"/>
  <text x="50" y="22" text-anchor="middle" fill="{AXE_TOKENS["text_sec"]}" font-family="{AXE_TOKENS["font"]}" font-size="9" letter-spacing="1">{name.upper()}</text>
  <text x="50" y="44" text-anchor="middle" fill="{AXE_TOKENS["gold"]}" font-family="{AXE_TOKENS["mono"]}" font-size="18" font-weight="700">{value}</text>
</g>'''

def _bar(x, y, w, label, value, pct, color="#4CAF50"):
    fw = int(w * min(pct, 1.0))
    return f'''<g transform="translate({x},{y})">
  <rect width="{w}" height="28" fill="{AXE_TOKENS["surface"]}" stroke="{AXE_TOKENS["border"]}" stroke-width="1"/>
  <rect width="{fw}" height="28" fill="{color}" opacity="0.25"/>
  <rect width="{fw}" height="3" fill="{color}"/>
  <text x="8" y="18" fill="{AXE_TOKENS["text"]}" font-family="{AXE_TOKENS["font"]}" font-size="11">{label}</text>
  <text x="{w-8}" y="18" text-anchor="end" fill="{color}" font-family="{AXE_TOKENS["mono"]}" font-size="11">{value}</text>
</g>'''

def auto_layout(nodes, layout="horizontal"):
    bw, bh, gap = 160, 60, 40
    for i, n in enumerate(nodes):
        if "x" not in n or "y" not in n:
            if layout == "vertical":
                n.setdefault("x", 32)
                n.setdefault("y", 32 + i * (bh + gap))
            elif layout == "grid":
                cols = max(1, int(math.sqrt(len(nodes))))
                n.setdefault("x", 32 + (i % cols) * (bw + gap))
                n.setdefault("y", 32 + (i // cols) * (bh + gap))
            else:
                n.setdefault("x", 32 + i * (bw + gap))
                n.setdefault("y", 32)
        n.setdefault("width", bw)
        n.setdefault("height", bh)
    return nodes

def render_svg(spec, design_tokens=None):
    t = design_tokens or AXE_TOKENS
    nodes = spec.get("nodes", [])
    edges = spec.get("edges", [])
    tiers = spec.get("tiers", [])
    metrics = spec.get("metrics", [])
    title = spec.get("title", "")
    layout = spec.get("layout", "horizontal")
    dtype = spec.get("type", "custom")

    nodes = auto_layout(nodes, layout)
    node_map = {n.get("id", str(i)): n for i, n in enumerate(nodes)}

    parts = []
    pad = 32
    max_x = max((n["x"] + n["width"] for n in nodes), default=200) + pad
    max_y = max((n["y"] + n["height"] for n in nodes), default=100) + pad

    if metrics:
        max_x = max(max_x, 32 + len(metrics) * 112 + pad)
        max_y += 80

    if title:
        max_y += 32

    vw, vh = int(max_x + pad), int(max_y + pad)

    parts.append(f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {vw} {vh}" width="{vw}" height="{vh}">')
    parts.append(f'<rect width="{vw}" height="{vh}" fill="{t["bg"]}"/>')
    parts.append(_defs())

    y_off = 0
    if title:
        y_off = 32
        parts.append(f'<text x="{vw//2}" y="28" text-anchor="middle" fill="{t["gold"]}" font-family="{t["font"]}" font-size="18" font-weight="700" letter-spacing="0.5">{title}</text>')

    if tiers:
        for ti, tier in enumerate(tiers):
            tc = tier.get("color", TIER_COLORS[ti % len(TIER_COLORS)])
            tn = tier.get("nodes", [])
            for nid in tn:
                if nid in node_map:
                    node_map[nid]["color"] = tc

    for n in nodes:
        c = n.get("color", t["gold"])
        parts.append(_box(n["x"], n["y"] + y_off, n["width"], n["height"],
                         n.get("label", n.get("id", "")), n.get("subtitle", ""), c))

    for e in edges:
        src = node_map.get(e["from"])
        dst = node_map.get(e["to"])
        if src and dst:
            x1 = src["x"] + src["width"]
            y1 = src["y"] + src["height"] // 2 + y_off
            x2 = dst["x"]
            y2 = dst["y"] + dst["height"] // 2 + y_off
            muted = e.get("style") == "dashed"
            parts.append(_arrow(x1, y1, x2, y2, e.get("label", ""), muted))

    if metrics:
        my = max(n["y"] + n["height"] for n in nodes) + y_off + 24
        for mi, m in enumerate(metrics):
            parts.append(_metric(32 + mi * 112, my, m["name"], m.get("value", "—")))

    parts.append('</svg>')
    return '\n'.join(parts)


if HAS_MCP:
    mcp = FastMCP("axe-visualize")

    @mcp.tool()
    def axe_visualize(spec: dict) -> str:
        """Generate an AXE-branded SVG diagram from a structured spec.

        spec fields: type, title, nodes[], edges[], tiers[], metrics[], layout, theme
        nodes: {id, label, subtitle?, color?, x?, y?, width?, height?}
        edges: {from, to, label?, style?: "solid"|"dashed"}
        tiers: {name, color, nodes[]}
        metrics: {name, value}
        layout: "horizontal"|"vertical"|"grid"
        """
        return render_svg(spec, AXE_TOKENS)


if __name__ == "__main__":
    if HAS_MCP and len(sys.argv) > 1 and sys.argv[1] == "serve":
        mcp.run()
    else:
        sample = {
            "type": "tier",
            "title": "AXE INFRASTRUCTURE",
            "nodes": [
                {"id": "gw", "label": "Gateway", "subtitle": "gateway.axe.onl"},
                {"id": "ollama", "label": "Ollama", "subtitle": "10.118.0.11:11434"},
                {"id": "db", "label": "Databricks", "subtitle": "vector store"},
            ],
            "edges": [
                {"from": "gw", "to": "ollama", "label": "VPC"},
                {"from": "ollama", "to": "db", "label": "embed"},
            ],
            "tiers": [
                {"name": "Edge", "color": "#D4AF37", "nodes": ["gw"]},
                {"name": "Compute", "color": "#A0A0A0", "nodes": ["ollama"]},
                {"name": "Storage", "color": "#8B6914", "nodes": ["db"]},
            ],
            "metrics": [
                {"name": "Uptime", "value": "99.7%"},
                {"name": "Latency", "value": "42ms"},
                {"name": "Models", "value": "3"},
            ],
            "layout": "horizontal",
        }
        svg = render_svg(sample, AXE_TOKENS)
        print(svg)
        with open("/tmp/axe_test_diagram.svg", "w") as f:
            f.write(svg)
        print(f"\nSaved to /tmp/axe_test_diagram.svg", file=sys.stderr)
