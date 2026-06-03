# ADR 0003 — Hotwire (Turbo Streams) Instead of React

**Status:** Accepted
**Date:** 2026-06-03

---

## Context

Real-time dashboard UI requires the browser to reflect server-side state changes (new log entries) without a full page reload. Two mainstream approaches exist:

1. **SPA with React (or Vue):** Frontend subscribes to a WebSocket or SSE endpoint, receives JSON, and reconciles component state. Requires a separate JS build pipeline, client-side routing, API serialization layer, and state management.

2. **Hotwire / Turbo Streams:** Server renders HTML partials and broadcasts them over WebSocket as `<turbo-stream>` elements. The browser applies DOM mutations (append, prepend, replace, remove) declaratively — no JavaScript written.

---

## Decision

Use **Hotwire** — specifically **Turbo Streams** over Action Cable — for all real-time UI updates.

The broadcast pattern:
```ruby
Turbo::StreamsChannel.broadcast_prepend_to(
  "log_entries",
  target: "log_entries_list",
  partial: "log_entries/log_entry",
  locals: { log_entry: log_entry }
)
```

The view subscribes with a single ERB tag:
```erb
<%= turbo_stream_from "log_entries" %>
```

No JavaScript written. No JSON serializer. No React component tree.

---

## Consequences

**Positive:**
- Zero custom JavaScript for real-time behaviour — Turbo handles WebSocket subscription and DOM patching
- HTML is rendered server-side, so the same partial is used for both initial page load and live updates
- Tailwind classes live in one place (the ERB partial), not split between a serializer and a React component
- Fits the Rails "One-Person Framework" philosophy: one engineer can own the entire stack
- Stimulus (also in Hotwire) is available for any sprinkles of interactivity needed later

**Negative / Trade-offs:**
- Less portable: UI logic is coupled to server-rendered HTML. A future mobile app or public API would need a separate JSON layer.
- Turbo's mental model (HTML-over-the-wire) is unfamiliar coming from React/Vue. The key shift: stop thinking in "state" and start thinking in "DOM mutations."
- Complex client-side interactions (drag-and-drop, rich charts) still require JavaScript.

**Laravel analogy:**
- Hotwire/Turbo Streams ↔ Laravel Livewire (server-driven reactivity)
- Both avoid writing a SPA. Key difference: Livewire uses its own wire protocol; Turbo uses standard WebSockets and ships HTML diffs.
