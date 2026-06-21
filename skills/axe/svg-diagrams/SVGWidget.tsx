/**
 * SVGWidget.tsx
 * AXE Technologies — Pulse Chat v2
 * AI-agnostic: renders SVG from any model via axe_visualize MCP tool.
 *
 * The only coupling to any specific model is in the caller —
 * this component just renders SVG and routes axe.action() callbacks.
 */

import { useEffect, useRef } from "react";

// ── AXE design tokens ─────────────────────────────────────────────────────────

const AXE_CSS = `
:root {
  --axe-text-primary:   #1a1a18;
  --axe-text-secondary: #5f5e5a;
  --axe-text-muted:     #88877f;
  --axe-border:         rgba(0,0,0,0.15);
  --axe-border-strong:  rgba(0,0,0,0.25);
  --axe-bg-surface:     #f5f4f0;
  --axe-bg-elevated:    #ffffff;
  --p:   var(--axe-text-primary);
  --s:   var(--axe-text-secondary);
  --t:   var(--axe-text-muted);
  --b:   var(--axe-border);
  --bg2: var(--axe-bg-surface);
}
@media (prefers-color-scheme: dark) {
  :root {
    --axe-text-primary:   #e8e6df;
    --axe-text-secondary: #9c9a92;
    --axe-text-muted:     #6b6a64;
    --axe-border:         rgba(255,255,255,0.12);
    --axe-border-strong:  rgba(255,255,255,0.22);
    --axe-bg-surface:     #1e1e1c;
    --axe-bg-elevated:    #252523;
  }
}
* { box-sizing: border-box; margin: 0; padding: 0; }
body { background: transparent; }
text { font-family: -apple-system, BlinkMacSystemFont, sans-serif; }
.t  { font-size: 14px; fill: var(--axe-text-primary); }
.ts { font-size: 12px; fill: var(--axe-text-secondary); }
.th { font-size: 14px; font-weight: 500; fill: var(--axe-text-primary); }
.box    { fill: var(--axe-bg-surface); stroke: var(--axe-border); }
.arr    { stroke: var(--axe-border-strong); stroke-width: 1.5; fill: none; }
.leader { stroke: var(--axe-text-muted); stroke-width: 0.5; stroke-dasharray: 4 3; fill: none; }
.node   { cursor: pointer; }
.node:hover > rect,
.node:hover > circle { opacity: 0.85; }

/* Color ramps — light */
.c-slate  rect { fill: #F1EFE8; stroke: #888780; }
.c-slate  .t, .c-slate  .th { fill: #444441; } .c-slate  .ts { fill: #5F5E5A; }
.c-teal   rect { fill: #E1F5EE; stroke: #1D9E75; }
.c-teal   .t, .c-teal   .th { fill: #085041; } .c-teal   .ts { fill: #0F6E56; }
.c-purple rect { fill: #EEEDFE; stroke: #7F77DD; }
.c-purple .t, .c-purple .th { fill: #3C3489; } .c-purple .ts { fill: #534AB7; }
.c-coral  rect { fill: #FAECE7; stroke: #D85A30; }
.c-coral  .t, .c-coral  .th { fill: #712B13; } .c-coral  .ts { fill: #993C1D; }
.c-amber  rect { fill: #FAEEDA; stroke: #BA7517; }
.c-amber  .t, .c-amber  .th { fill: #633806; } .c-amber  .ts { fill: #854F0B; }
.c-blue   rect { fill: #E6F1FB; stroke: #378ADD; }
.c-blue   .t, .c-blue   .th { fill: #0C447C; } .c-blue   .ts { fill: #185FA5; }
.c-green  rect { fill: #EAF3DE; stroke: #639922; }
.c-green  .t, .c-green  .th { fill: #27500A; } .c-green  .ts { fill: #3B6D11; }
.c-red    rect { fill: #FCEBEB; stroke: #E24B4A; }
.c-red    .t, .c-red    .th { fill: #791F1F; } .c-red    .ts { fill: #A32D2D; }

/* Color ramps — dark */
@media (prefers-color-scheme: dark) {
  .c-slate  rect { fill: #444441; stroke: #B4B2A9; }
  .c-slate  .t, .c-slate  .th { fill: #D3D1C7; } .c-slate  .ts { fill: #B4B2A9; }
  .c-teal   rect { fill: #085041; stroke: #5DCAA5; }
  .c-teal   .t, .c-teal   .th { fill: #9FE1CB; } .c-teal   .ts { fill: #5DCAA5; }
  .c-purple rect { fill: #3C3489; stroke: #AFA9EC; }
  .c-purple .t, .c-purple .th { fill: #CECBF6; } .c-purple .ts { fill: #AFA9EC; }
  .c-coral  rect { fill: #712B13; stroke: #F0997B; }
  .c-coral  .t, .c-coral  .th { fill: #F5C4B3; } .c-coral  .ts { fill: #F0997B; }
  .c-amber  rect { fill: #633806; stroke: #EF9F27; }
  .c-amber  .t, .c-amber  .th { fill: #FAC775; } .c-amber  .ts { fill: #EF9F27; }
  .c-blue   rect { fill: #0C447C; stroke: #85B7EB; }
  .c-blue   .t, .c-blue   .th { fill: #B5D4F4; } .c-blue   .ts { fill: #85B7EB; }
  .c-green  rect { fill: #27500A; stroke: #97C459; }
  .c-green  .t, .c-green  .th { fill: #C0DD97; } .c-green  .ts { fill: #97C459; }
  .c-red    rect { fill: #791F1F; stroke: #F09595; }
  .c-red    .t, .c-red    .th { fill: #F7C1C1; } .c-red    .ts { fill: #F09595; }
}
`;

// ── axe.action bridge ─────────────────────────────────────────────────────────
// Model-agnostic: fires postMessage with a generic 'axe_action' type.
// The parent window wires this to whatever backend is active.

const BRIDGE_SCRIPT = `
<script>
  window.axe = {
    action: function(text) {
      window.parent.postMessage({ type: 'axe_action', text: text }, '*');
    }
  };
</script>
`;

// ── Component ─────────────────────────────────────────────────────────────────

interface SVGWidgetProps {
  /** Raw SVG string from axe_visualize MCP tool */
  svg: string;
  /**
   * Called when a node is clicked.
   * Wire this to whatever model/backend is active:
   *   - Qwen via gateway.axe.onl
   *   - Claude API directly
   *   - GPT or Gemini endpoint
   *   - No-op for static renders
   */
  onAction?: (text: string) => void;
}

export function SVGWidget({ svg, onAction }: SVGWidgetProps) {
  const iframeRef = useRef<HTMLIFrameElement>(null);

  useEffect(() => {
    const handler = (e: MessageEvent) => {
      if (e.data?.type === "axe_action" && onAction) {
        onAction(e.data.text as string);
      }
    };
    window.addEventListener("message", handler);
    return () => window.removeEventListener("message", handler);
  }, [onAction]);

  const handleLoad = () => {
    const f = iframeRef.current;
    if (!f?.contentDocument) return;
    const svgEl = f.contentDocument.querySelector("svg");
    if (svgEl) f.style.height = `${svgEl.getBoundingClientRect().height + 8}px`;
  };

  const srcDoc = `<!DOCTYPE html><html><head><meta charset="utf-8">
<style>${AXE_CSS}</style></head><body>
${BRIDGE_SCRIPT}
${svg}
</body></html>`;

  return (
    <iframe
      ref={iframeRef}
      srcDoc={srcDoc}
      sandbox="allow-scripts"
      style={{ width: "100%", border: "none", display: "block", minHeight: "120px" }}
      onLoad={handleLoad}
      title="AXE diagram"
    />
  );
}

// ── Message renderer helper ───────────────────────────────────────────────────

export function renderMessageContent(
  content: string,
  onAction: (text: string) => void
) {
  const match = content.match(/<svg[\s\S]*?<\/svg>/);
  if (match) return <SVGWidget svg={match[0]} onAction={onAction} />;
  return <span>{content}</span>;
}

// ── Backend adapter examples ──────────────────────────────────────────────────
// Wire onAction to whichever model is active. These are drop-in examples.

/**
 * Route to gateway.axe.onl (Qwen specialists or any model behind gateway)
 */
export function makeGatewayAction(sessionId: string) {
  return async (text: string) => {
    await fetch("https://gateway.axe.onl/v1/chat", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ session_id: sessionId, message: text }),
    });
  };
}

/**
 * Route to Anthropic API directly (when using Claude as the active model)
 */
export function makeClaudeAction(onMessage: (text: string) => void) {
  return (text: string) => onMessage(text);
}

/**
 * Route to OpenAI API directly (when using GPT as the active model)
 */
export function makeOpenAIAction(onMessage: (text: string) => void) {
  return (text: string) => onMessage(text);
}

/**
 * No-op for static renders (reports, exports, previews)
 */
export const noopAction = (_text: string) => {};
