# Watcher state machine: Reading / Pending Reload / Missing

A window is in exactly one of three states with respect to its backing file. The state determines the toolbar indicator and what happens when the Reader interacts with it.

- **Reading** (default): the rendered Document matches the file on disk.
- **Pending Reload**: the file changed on disk after the last render. Toolbar shows the "New content" button; clicking (or ⌘R) reads the new content and returns to Reading.
- **Missing**: the file is no longer at its path. Toolbar shows a non-interactive "File missing" label, in red. The previously-rendered Document stays on screen so the Reader can keep reading. Missing is **terminal** — the only way out is to re-open the file.

Transitions:

| From | Trigger | To |
|---|---|---|
| Reading | `.write` event, OR `.rename`/`.delete` + reopening the path succeeds | Pending Reload |
| Reading | `.rename`/`.delete` + reopening the path fails | Missing |
| Pending Reload | another `.write` (no count, just stays Pending Reload) | Pending Reload |
| Pending Reload | Reader applies Reload, file read succeeds | Reading |
| Pending Reload | Reader applies Reload, file read fails (race) | Missing |
| Pending Reload | `.rename`/`.delete` + reopening fails | Missing |

The reopen-and-check rule disambiguates atomic save (vim, VSCode default save) from real rename/delete. An atomic save unlinks the watched inode but immediately replaces the path with a new inode containing the new content; reopening the path succeeds and we treat it as a normal change. A real rename/delete leaves the path empty; reopen fails and we go to Missing.

Missing is terminal because the alternative (polling or directory-watching to recover) costs ongoing work for a rare case the Reader can resolve in one action (re-open). Sync clients that briefly stage files elsewhere are an edge case; if it bites, the contract can be revisited.
