# Headroom

## Platform

Linux: Omarchy's native Quickshell/QML plugin system.

## Users and purpose

People using Claude Code and Codex together need to see their weekly allowance without opening a panel, then inspect quota resets, projected capacity, and local usage value in one place.

## Capabilities and constraints

- Selected providers appear together, in the user’s order. A provider switch enables its details and collection; a separate switch shows its weekly value in the top bar. Disabled providers remember the top-bar choice. The bar shows weekly percentages remaining.
- The panel shows Session, Weekly, and reported model-specific limits together.
- Optional costs have Today, Yesterday, and 30 Days views. They represent estimated API-equivalent USD value from this machine's local history, not subscription charges.
- Keep healthy buffer forecasts on hover. Show spare-capacity or flame warnings beside quota titles only when capacity needs attention. Label stale readings and distinguish missing data from zero.
- No token charts, usage trends, Extra Usage section, provider tabs, or marketplace release in this proof of concept.
- Native collectors own provider authentication and quota requests. Cost reading is local and independent.

## Product principles

Immediate visibility, clear units, honest data coverage, and a small native desktop footprint. Use Omarchy's standard flat surfaces, theme border, corner radius, fonts and controls; settings save immediately.

## Accessibility

Readable light and dark themes, keyboard-operable controls, text alongside warning colors, and readable unavailable states.
