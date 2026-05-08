# Use ToolbarItem for actions and NSTitlebarAccessoryViewController for labels

The two indicators that live in the top-right of a window — "New content" (Pending Reload) and "File missing" (Missing) — use different placement primitives by design.

- **Pending Reload** is a `ToolbarItem(placement: .primaryAction)` containing a SwiftUI `Button`. SwiftUI's toolbar lowers to `NSToolbarItem`, which on macOS 26 wraps content in a button-shaped chrome (rounded background + drop shadow). For an actual button, that chrome is correct — it signals that the indicator is interactive. `.keyboardShortcut("r", modifiers: .command)` on the `Button` participates in SwiftUI's focus tree for free.
- **Missing** is an `NSTitlebarAccessoryViewController` whose view is an `NSHostingView` of a SwiftUI `Text` styled red. Titlebar accessories are the documented AppKit primitive for non-toolbar content in the titlebar — the chrome doesn't apply because the controller's view isn't an `NSToolbarItem`. The label is non-interactive, so chrome would mislead Readers into thinking they could act on it.

The asymmetry is intentional: ToolbarItem for actions, TitlebarAccessoryViewController for labels. Trying to unify them — putting the button in an accessory or the label in a toolbar — was rejected because each path means using the wrong primitive for one of the two cases (losing `.keyboardShortcut` and chrome on the button, or fighting auto-applied chrome on the label).
