Status: TEMPLATE
<!-- Template v2.5. Drafted from 01-prd.md and approved by the user. The wireframe in docs/03-wireframe/ must follow this file. -->

# <Product name> - UI Design

## 1. Style
<!-- Tone in a few words, and 1 to 3 reference products. -->

## 2. Colour tokens
Define every colour as a token, in light and dark.
Never hard-code a colour in a component.

| Token | Light | Dark | Use |
|---|---|---|---|
| `--bg` | | | Page background |
| `--surface` | | | Cards, panels |
| `--text` | | | Body text |
| `--text-muted` | | | Secondary text |
| `--primary` | | | Main action, links, focus |
| `--danger` | | | Errors, destructive actions |
| `--warning` | | | |
| `--success` | | | |

All text meets WCAG AA contrast (4.5:1 body, 3:1 large text and UI) in both themes.

## 3. Typography
| Use | Font | Size / weight |
|---|---|---|
| H1 | | |
| H2 | | |
| Body | | |
| Small / labels | | |

Fonts are self-hosted or bundled unless an external font is approved in 02-architecture.md.

## 4. Layout and spacing
- Spacing grid: e.g. 4 or 8 px.
- Breakpoints: 375, 768, 1280 px (mobile first).
- Maximum content width:

## 5. Components
<!-- Buttons, inputs, cards, tables, dialogs, navigation. Use the component library first (see RULES.md). -->
| Component | Variants | Notes |
|---|---|---|

## 6. States (every screen)
Every screen and data-driven component defines all four:
- **Empty** - nothing yet, with the next action.
- **Loading** - skeleton or spinner, no layout jump.
- **Error** - what went wrong and how to recover.
- **Success / populated.**

## 7. Accessibility
- Keyboard reachable, visible focus, logical tab order.
- Colour is never the only signal; pair it with text or an icon.
- Images have alt text; icon-only buttons have `aria-label`.
- Respect `prefers-reduced-motion`.

## 8. Writing style in the UI
- Plain language, sentence case, one clear primary action per screen.

## 9. Screens
| Screen | Purpose | REQ-IDs | Wireframe file |
|---|---|---|---|
