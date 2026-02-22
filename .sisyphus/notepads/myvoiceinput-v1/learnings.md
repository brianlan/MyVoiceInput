
## Task 15 (Fix 4): Menu Style for Key Equivalents - Feb 22, 2026

### Problem
- Even with manual window management, the `Cmd+,` shortcut for Settings was not triggering when the `MenuBarExtra` menu was open.
- This is because the default `MenuBarExtra` style (often `.window` or `.automatic` behaving like a popover) does not always forward `NSMenu` key equivalents correctly in the same way a standard `NSMenu` does.

### Solution
- Applied `.menuBarExtraStyle(.menu)` to the `MenuBarExtra` scene in `MyVoiceInputApp.swift`.
- This forces the menu bar item to behave like a traditional macOS menu, ensuring that standard behavior for key equivalents (like `Cmd+,` for Settings and `Cmd+Q` for Quit) is respected by the system when the menu is open.

### Learnings
- **MenuBarExtra Style**: For agent apps that need standard menu behavior (shortcuts working while the menu is open), explicit `.menu` style is preferred over the default or `.window` style.
