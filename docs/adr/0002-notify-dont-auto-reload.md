# Notify, don't auto-reload, on external file change

When the on-disk file changes, Jerboa shows a "New content" button in the window toolbar (a Pending Reload). The Reader applies it manually; rendering does not happen automatically. Reverses the previous "Live reload" behaviour shipped through 1.4.0-beta.2.

The trade-off was reading continuity vs. immediacy. Auto-reload pulled the Reader's scroll context out from under them whenever an external tool touched the file (formatter, linter, sync client, autosave from an editor in another window). Manual reload preserves position and gives the Reader explicit control; the cost is one click per genuine update, which is acceptable for a read-focused app.

Implementation: `FileWatcher.onChange` flips `hasPendingUpdate`; the toolbar button calls `reloadFromDisk()`, which preserves scroll via `viewer.js` saving and restoring `window.scrollY` across `renderMarkdown` calls. ⌘R is bound to the same action.
