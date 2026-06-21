# AXE SVG Diagram Skill

Load this skill before generating any visual/diagram output. All SVG must conform to these tokens and patterns.

## Design Tokens

### Colors
```
PRIMARY_GOLD     = #D4AF37
GOLD_DARK        = #B8962E
GOLD_LIGHT       = #E8C547
GOLD_GLOW        = rgba(212,175,55,0.3)

BG_BLACK         = #0A0A0C
SURFACE          = #1A1A1F
SURFACE_RAISED   = #222228
BORDER           = #2A2A30
BORDER_ACTIVE    = #3A3A42

TEXT_PRIMARY     = #E0E0E0
TEXT_SECONDARY   = #888888
TEXT_MUTED       = #555555

STATUS_OK        = #4CAF50
STATUS_ERR       = #F44336
STATUS_WARN      = #FF9800
STATUS_INFO      = #2196F3

TIER1            = #D4AF37
TIER2            = #A0A0A0
TIER3            = #8B6914
TIER_INACTIVE    = #333338
```

### Typography
```
FONT_DISPLAY     = 'Space Grotesk', sans-serif
FONT_MONO        = 'IBM Plex Mono', monospace
SIZE_TITLE       = 18
SIZE_LABEL       = 13
SIZE_VALUE        = 11
SIZE_CAPTION     = 9
WEIGHT_BOLD      = 700
WEIGHT_NORMAL    = 400
LETTER_SPACING   = 0.5px
```

### Geometry
```
BORDER_RADIUS    = 0        (ALWAYS zero — sharp edges only)
STROKE_WIDTH     = 1.5
STROKE_THIN      = 0.75
PADDING          = 16
GAP              = 12
BOX_MIN_W        = 140
BOX_MIN_H        = 48
```

## SVG Output Rules

1. Always set `xmlns="http://www.w3.org/2000/svg"`
2. viewBox calculated from content: `0 0 {width} {height}` with 32px padding
3. Background: full-bleed rect with `fill="#0A0A0C"`
4. All text uses `font-family="'Space Grotesk', sans-serif"` unless showing code/values (use IBM Plex Mono)
5. No rounded corners anywhere — `rx="0" ry="0"` or omit
6. Strokes: `stroke="#2A2A30"` default, `stroke="#D4AF37"` for active/selected
7. Text fill: `#E0E0E0` primary, `#888888` secondary, `#D4AF37` accent
8. No emojis. Ever. Use geometric SVG shapes for icons.

## Arrow Marker Definition

Include this `<defs>` block in every diagram with edges:

```svg
<defs>
  <marker id="arrow" viewBox="0 0 10 7" refX="10" refY="3.5"
    markerWidth="8" markerHeight="6" orient="auto-start-reverse">
    <path d="M 0 0 L 10 3.5 L 0 7 z" fill="#D4AF37"/>
  </marker>
  <marker id="arrow-muted" viewBox="0 0 10 7" refX="10" refY="3.5"
    markerWidth="8" markerHeight="6" orient="auto-start-reverse">
    <path d="M 0 0 L 10 3.5 L 0 7 z" fill="#555555"/>
  </marker>
</defs>
```

## Component Patterns

### Tier Box
```svg
<g transform="translate({x},{y})">
  <rect width="{w}" height="{h}" fill="#1A1A1F" stroke="{tierColor}" stroke-width="1.5"/>
  <rect width="{w}" height="3" fill="{tierColor}"/>
  <text x="{w/2}" y="24" text-anchor="middle" fill="#E0E0E0"
    font-family="'Space Grotesk', sans-serif" font-size="13" font-weight="700"
    letter-spacing="0.5">{LABEL}</text>
  <text x="{w/2}" y="40" text-anchor="middle" fill="#888888"
    font-family="'IBM Plex Mono', monospace" font-size="9">{subtitle}</text>
</g>
```

### Flow Arrow (horizontal)
```svg
<line x1="{x1}" y1="{y}" x2="{x2}" y2="{y}"
  stroke="#D4AF37" stroke-width="1.5" marker-end="url(#arrow)"/>
<text x="{midX}" y="{y - 8}" text-anchor="middle" fill="#888888"
  font-family="'IBM Plex Mono', monospace" font-size="9">{label}</text>
```

### Infrastructure Bar
```svg
<g transform="translate({x},{y})">
  <rect width="{totalW}" height="28" fill="#1A1A1F" stroke="#2A2A30" stroke-width="1"/>
  <rect width="{fillW}" height="28" fill="{statusColor}" opacity="0.25"/>
  <rect width="{fillW}" height="3" fill="{statusColor}"/>
  <text x="8" y="18" fill="#E0E0E0" font-family="'Space Grotesk', sans-serif"
    font-size="11">{label}</text>
  <text x="{totalW - 8}" y="18" text-anchor="end" fill="{statusColor}"
    font-family="'IBM Plex Mono', monospace" font-size="11">{value}</text>
</g>
```

### Metric Cell (for eval dashboards)
```svg
<g transform="translate({x},{y})">
  <rect width="100" height="56" fill="#1A1A1F" stroke="#2A2A30" stroke-width="1"/>
  <text x="50" y="22" text-anchor="middle" fill="#888888"
    font-family="'Space Grotesk', sans-serif" font-size="9"
    letter-spacing="1" text-transform="uppercase">{METRIC}</text>
  <text x="50" y="44" text-anchor="middle" fill="#D4AF37"
    font-family="'IBM Plex Mono', monospace" font-size="18" font-weight="700">{value}</text>
</g>
```

### Pipeline Stage
```svg
<g transform="translate({x},{y})">
  <rect width="120" height="52" fill="#1A1A1F" stroke="#2A2A30" stroke-width="1.5"/>
  <rect width="120" height="3" fill="{stageColor}"/>
  <text x="60" y="20" text-anchor="middle" fill="#888888"
    font-family="'Space Grotesk', sans-serif" font-size="9"
    letter-spacing="0.8">STAGE {n}</text>
  <text x="60" y="38" text-anchor="middle" fill="#E0E0E0"
    font-family="'Space Grotesk', sans-serif" font-size="13" font-weight="700">{name}</text>
</g>
```

## Agent Instructions

1. **Load tokens** — apply the color palette, fonts, and geometry rules above
2. **Pick components** — select the patterns that match the diagram type
3. **Auto-layout** — if no positions given, arrange left-to-right (pipeline) or top-to-bottom (tiers), with GAP=12 between items
4. **Compose SVG** — assemble components, add defs block with markers, wrap in viewBox
5. **Validate** — confirm: no border-radius, no emojis, correct fonts, gold accents on active elements, dark background
6. **Output** — return raw SVG string wrapped in ```svg code fence

Never use: rounded corners, emoji characters, bright white backgrounds, Comic Sans, drop shadows, gradients (except subtle gold glow on active items).

Always use: sharp edges, AXE gold for primary accents, dark surfaces, monospace for data values, Space Grotesk for labels.
