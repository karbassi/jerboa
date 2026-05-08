# Jerboa

A native macOS app for reading Markdown. Single-user, local, read-only by design — no editor, no sync, no accounts.

## Language

**Reader**:
The person using Jerboa. There is exactly one Reader per running app instance.
_Avoid_: user, viewer

**Document**:
A Markdown file a Reader has opened. Always Markdown — no other formats.
_Avoid_: file, note, markdown, page

**Heading**:
A Markdown heading (h1–h6) inside a Document. Acts as the marker for a Section.
_Avoid_: title, header

**Section**:
The content under a Heading, up to (but not including) the next equal-or-shallower Heading. The unit a Reader collapses, scrolls to via TOC, or is "currently in." Sections nest.
_Avoid_: chunk, block, fold

**Pending Reload**:
The state of a window when the on-disk file has been modified after Jerboa last rendered it. The Reader can apply the Pending Reload (manually) to render the new version; until they do, the displayed Document is the previous version.
_Avoid_: pending update, stale, drift, external change

**Missing**:
The state of a window whose backing file is no longer at its original path (deleted or renamed away with no replacement). Terminal: the rendered Document remains on screen (the Reader can still read what they had), but the window cannot return to Reading or Pending Reload until the Reader re-opens the file. Distinct from Pending Reload, which means "new content available"; Missing means "no content to show."
_Avoid_: deleted, gone, lost

## Relationships

- A **Reader** opens one **Document** per window. There is exactly one Reader per window; multiple windows are independent reading sessions with no shared state.
- A **Document** contains zero or more **Sections**, each introduced by a **Heading**.
- **Sections** nest by Heading level (an h3 Section lives inside the most recent h2 Section).
- A Markdown link from one Document to another `.md` file opens the linked Document in a **new window** (a new Reader session); the original window is unchanged.

## Scope rule

A feature is in scope if and only if **it helps the Reader read THIS Document right now**. The "this" is per-window; "right now" excludes anything that introduces state across sessions, manages multiple Documents, or treats Jerboa as more than a transient lens on one file.

Examples:
- In: TOC, collapsing Sections, font-size controls, footnote tooltips, link clicks, scroll-preserving reload, a future find-in-Document.
- Out: a recent-Documents menu, project/folder mode, cross-Document search, "where I left off" persistence, sync, accounts.

See [ADR-0001](docs/adr/0001-scope-rule.md) for the full rationale and consequences.

## Example dialogue

> **Dev:** "If the **Reader** collapses an h2 **Section**, what happens to the h3 **Sections** inside it?"
> **Ali:** "They're hidden along with the parent's content. **Sections** nest by **Heading** level — collapsing an outer **Section** collapses everything within."
>
> **Dev:** "And if a **Pending Reload** is applied while a **Section** is collapsed?"
> **Ali:** "The collapse is lost. Reload re-renders the **Document** from scratch; we preserve scroll position but not micro-state. Per the scope rule, persisting collapse state across reloads would be 'helps them pick up later,' not 'helps them read this right now.'"
>
> **Dev:** "If the **Reader** clicks a Markdown link to `notes.md`, do they leave their current **Document**?"
> **Ali:** "No — `notes.md` opens in a new window with its own **Reader** session. The original window is unchanged. Two open **Documents** = two independent reading sessions."

## Flagged ambiguities

- Format scope: `App/Info.plist` registers Jerboa as a Viewer for both `net.daringfireball.markdown` and `public.plain-text`. The latter contradicts the "Markdown only" rule and should be removed from `LSItemContentTypes`. Resolved: Markdown only.
