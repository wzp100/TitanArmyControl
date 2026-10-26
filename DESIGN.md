---
name: Mac Native Productivity
platform: macOS
style: native-precision
principles:
  - Native before custom
  - Clarity over decoration
  - Keyboard and pointer first
  - Density without clutter
colors:
  accent: systemAccentColor
  contentBackground: semantic.windowBackground
  sidebarBackground: semantic.sidebarMaterial
  primaryText: semantic.primary
  secondaryText: semantic.secondary
  separator: semantic.separator
spacing:
  xxs: 4
  xs: 8
  sm: 12
  md: 16
  lg: 24
  xl: 32
typography:
  system: SF Pro (system font)
  title: semantic.title3
  section: semantic.headline
  body: semantic.body
  detail: semantic.caption
components:
  navigation: NavigationSplitView
  toolbar: native Toolbar
  iconography: SF Symbols
  forms: native SwiftUI controls
---

# Design direction

Build a polished macOS desktop utility: Apple's native interaction model, Raycast-like efficient information density, and Linear-like visual discipline. Avoid copying third-party brand assets.

## Information architecture

- Prefer a clear sidebar + content layout; add an inspector only when contextual detail merits a third pane.
- Put global navigation in a native sidebar and primary actions in the window toolbar.
- Use tables/lists/forms for structured data rather than stacking rounded cards.
- Favor a search field or command workflow for high-frequency actions.
- Preserve window resizing, sidebar collapse, scrolling, text truncation, and small-window usability.

## Visual system

- Use system semantic colors and materials; support light/dark mode, increased contrast, accessibility text sizes, and reduced transparency.
- Use San Francisco semantic typography; create hierarchy with weight, scale, placement and whitespace rather than color alone.
- Space consistently using the token scale; align controls and baselines precisely.
- SF Symbols only for standard icons; keep symbol rendering and size consistent.
- Use standard control styles, selection and focus indicators. Avoid decorative gradients, glowing borders, excessive blur, and universal card layouts.
- Treat Liquid Glass as an OS-provided system treatment where available and appropriate, not a material to reproduce with custom blur layers.

## Interaction

- Implement expected hover, pressed, selected, focused, disabled, loading, empty and error states.
- Support keyboard shortcuts, right-click context menus, menus, navigation via keyboard, and accessible labels.
- Use sheets for focused tasks, popovers for lightweight contextual choices, and inspectors for persistent details.
- Destructive actions should be clear and appropriately confirmed.
- Do not hijack titlebar traffic lights, window drag areas, or native scrolling behavior.

## SwiftUI / AppKit implementation

- Default to SwiftUI: NavigationSplitView, List, Table, Form, Toolbar, Settings, Commands, searchable and SF Symbols.
- Use AppKit bridges only when a native capability is missing or SwiftUI's behavior is materially insufficient.
- Check the project's minimum supported macOS version before choosing APIs.
- Keep visual tokens reusable and semantic; do not hard-code light-mode RGB colors into views.
- For Electron/Tauri, treat these as interaction and appearance targets, not claims of genuine native components; implement titlebar/window/menu integration separately.

## Quality gate for coding agents

Before writing code: inspect existing architecture, describe screen hierarchy, decide primary and secondary actions, list OS version assumptions.
After implementation: compile, run, screenshot if possible, check both appearances and multiple window widths, review spacing, alignment, clipped labels, keyboard focus, empty/loading/error states, and accessibility. Iterate based on actual screenshots when available. Never claim to have visually verified an unrendered UI.

## Anti-patterns

- Web SaaS dashboard transplanted into a desktop window.
- Every content group is a card with large radius and shadow.
- Giant touch-first controls, floating mobile tab bars, fake browser nav bars.
- Emojis as functional icons, hard-coded colors, inconsistent paddings, nonstandard window chrome.
- Cosmetic rewrite that regresses working features or breaks existing keyboard shortcuts.
