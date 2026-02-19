# Render Benchmarks

Machine: MacBook Pro (Apple Silicon), macOS 26.3
Test: `RenderBenchmarkTests.testBenchmarkAll` — 10 iterations per doc size, `performance.now()` around `renderMarkdown()`.

## 2026-02-19 — v0.1.0 (baseline)

Commit: `4c6eb26` — HTML sidebar, grid CSS, `processHeadingsAndToc`, stacking scroll listeners, js-yaml (39KB), no FileWatcher debounce.

| Doc | Size | Median | Avg | Min | Max |
|---------|--------|--------|--------|------|------|
| small | 203 B | 3 ms | 3.5 ms | 1 ms | 9 ms |
| medium | 8.3 KB | 13 ms | 12.8 ms | 8 ms | 21 ms |
| large | 92 KB | 50 ms | 51.2 ms | 40 ms | 64 ms |

## 2026-02-19 — current

Changes:
- Removed HTML sidebar, grid layout, `processHeadingsAndToc` (replaced with `assignHeadingIds`)
- Removed js-yaml (39KB) — replaced with inline 20-line key:value parser
- Removed morphdom (12KB) — innerHTML + scroll save/restore is faster
- Removed CSS `transition`, stale print rules, `body[data-theme]` selector prefix
- String-based `escapeHtml` (regex replace instead of DOM element)
- String-based footnote backref removal (regex instead of DOM clone)
- UTF-8 byte iteration for `escapeForTemplateLiteral` in Swift
- Scroll listener cleanup (no stacking on re-render)
- RAF-throttled scroll spy
- FileWatcher 100ms debounce
- Scroll position preserved on file-change re-renders
- TOC posting and scroll tracking deferred via `requestIdleCallback`
- markdown-it pre-warmed on page load (`md.render('')`)

| Doc | Size | Median | Avg | Min | Max |
|---------|--------|--------|--------|------|------|
| small | 203 B | 1 ms | 1.3 ms | 0 ms | 4 ms |
| medium | 8.3 KB | 6 ms | 5.8 ms | 3 ms | 8 ms |
| large | 92 KB | 19 ms | 17.7 ms | 13 ms | 22 ms |

## Summary

| Doc | Baseline | Current | Change |
|---------|----------|---------|--------|
| small | 3 ms | 1 ms | -67% |
| medium | 13 ms | 6 ms | -54% |
| large | 50 ms | 19 ms | -62% |

JS payload reduced from 175KB to 129KB (-26%).
