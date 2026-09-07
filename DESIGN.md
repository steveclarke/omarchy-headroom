---
name: Headroom
description: A compact native desktop instrument for usage costs and remaining allowance.
colors:
  cost-claude: "#d77b5f"
  cost-codex: "#279b80"
typography:
  body:
    fontFamily: "sans-serif"
---

# Design System: Headroom

## Overview

**Creative North Star: "A compact desktop usage instrument"**

Headroom is a Linux Omarchy plugin built with Quickshell and QML. Its visual language combines monochrome provider marks, soft grouped surfaces, clear sans-serif labels, and thin accent meters. The bar is compact; the popup gives the figures enough space to read together.

The native shell supplies theme colors, scaling, and panel behavior. `Panel.qml`, `BarWidget.qml`, and `TintedIcon.qml` are the visual source of truth. The frontmatter records fixed primitives only; native expressions and component metadata live in [.impeccable/design.json](.impeccable/design.json).

**Key Characteristics:**

- Rounded outer surface with quiet inset groups.
- Strong headings and amounts, subdued supporting text.
- Provider color confined to the cost split; shared theme accent for allowance.
- Explicit text for unavailable readings, resets, and forecast warnings.

## Colors

The palette follows the active Omarchy theme, with two fixed colors for the cost legend and ring.

### Primary

Quota fills use `Color.accent`. The accent is shared by both providers and does not change with forecast severity.

### Secondary

The warm coral `cost-claude` and green teal `cost-codex` identify providers in the cost ring and matching legend dots. Provider names and exact amounts accompany the colors.

### Neutral

Popup text uses `Color.popups.text`. The popup surface uses `Color.popups.background`, mixed 68% toward white when its HSL lightness exceeds 0.5. Inset groups mix that surface 3.5% toward the foreground; meter tracks mix the group 14% toward the foreground. The period-selector bed uses a quieter 5.5% group-to-foreground mix.

Secondary text begins with a foreground-to-surface mix. `legible()` adjusts it toward the foreground against the selector bed; caution and urgency use the same adjustment against the group. The function seeks a calculated contrast ratio of at least 4.65, with the popup foreground as its fallback. Theme-derived colors remain expressions, not captured light/dark hex palettes.

Caution starts from a theme-dependent amber; urgency starts from `Color.urgent`. The bar uses `WidgetButton.foreground`, including the shell's wallpaper-aware contrast, and the bar's urgent color for flame warnings.

**The Separate Roles Rule.** Cost colors identify providers, the accent measures remaining allowance, and warning colors accompany forecast text.

## Typography

Panel labels and bar percentages use Qt's `sans-serif` family. Normal and `Font.DemiBold` weights create hierarchy without a second text family. All sizes below are arguments to `Style.space()`, not fixed CSS pixels.

| Role | QML size | Weight and use |
|---|---|---|
| Cost total | `Style.space(20)` | DemiBold; center of the ring |
| Section heading | `Style.space(18)` | DemiBold; Cost and provider names |
| Quota title | `Style.space(16)` | DemiBold; window names |
| Body | `Style.space(14)` | Normal; remaining allowance and legend labels |
| Compact label | `Style.space(13)` | Periods, plans, resets, and exact costs; selected period is DemiBold |
| Supporting text | `Style.space(11)`–`Style.space(12)` | Units, status, forecasts, and Refresh; warnings use DemiBold |

Bar percentages are DemiBold at `Style.space(14)`, right-aligned in a width measured from `100%`. The ring total and legend amounts can shrink to fit. Plan names and quota titles elide; status, reset, and forecast text can wrap.

## Layout

The popup is one column. `KeyboardPanel` requests content width `Style.space(400)`, fits it to the available area, and fits content height with a `Style.space(1000)` maximum. Its padding is `Style.space(18)`. A clipped vertical `Flickable` supplies scrolling when the content is taller than the available space; there is no separate breakpoint layout.

Major sections are separated by `Style.space(22)`. Cost content has `Style.space(14)` insets; provider groups have `Style.space(16)` insets and `Style.space(22)` between quota rows. These are component measurements, not a new global spacing scale.

The cost group places the three-period selector above a ring and an aligned provider legend. Each provider heading sits outside its inset quota group. Inside a quota row, the order is title, meter, remaining percentage on the left with reset on the right, then forecast text. The footer pairs update status with Refresh.

The bar shows two provider summaries horizontally, separated by a fine rule. On a vertical bar they stack and the separator disappears. Both providers remain visible in either orientation.

## Elevation & Depth

The plugin adds no custom shadow. Depth comes from the outer surface, subtly contrasting inset groups, and the selected period's surface-colored pill. Groups have no outline; `KeyboardPanel` uses `Border.none()`.

Positioning, focus, dismissal, and panel transitions belong to the native shell. Guarded `Binding` objects style only the current native panel instance's background and corner radius. Preserve that ownership when changing the appearance.

## Shapes

The outer popup has a `Style.space(18)` corner radius. Cost and provider groups use `Style.space(14)`. Period controls, Refresh, and meter ends are fully rounded using half their height. Meters are thin (`Style.space(6)`) and show a continuous fill without a pace marker.

The cost ring is drawn in a `Style.space(134)` square with a `Style.space(24)` stroke. Small gaps separate nonzero provider segments. Local SVG assets supply the monochrome provider marks and information icon through `TintedIcon`.

## Components

### Weekly bar summary

Each provider has a monochrome mark and its weekly percentage remaining. Session values belong in the popup. A stale reading adds `!`; an urgent or exhausted weekly forecast adds a flame. Left-click toggles the native panel; right-click refreshes. The native open-panel indicator follows the visible content width.

### Cost summary

Today, Yesterday, and 30 Days select local estimated API-equivalent value in USD. The information icon's tooltip and accessible name explain the meaning. 30 Days includes today and the previous 29 calendar days.

The selected pill moves over 150 ms with `Easing.OutCubic`. Selected text is DemiBold; selected and hovered labels use the foreground while other labels use secondary text. Left/right arrows and keys 1–3 also select periods.

The ring total is rounded to whole dollars; the adjacent provider amounts show two decimal places. A missing provider amount makes the combined total unavailable and leaves the ring neutral. Fresh zero values remain zero. A text status beneath the group distinguishes estimated local usage, loading, missing data, and outdated costs. `Costs.js` owns these distinctions.

### Provider quota group

A monochrome provider mark, heading, and subdued plan label introduce each group. Session, Weekly, and reported model-specific windows appear together. The accent meter represents allowance remaining, followed by a textual percentage and reset countdown.

Calm forecasts use secondary text. Low-buffer forecasts use amber and DemiBold; urgent or exhausted forecasts use urgency color, DemiBold, and a flame alongside text. Forecast tooltips explain the average-use basis. Missing or expired percentages use an em dash and an empty meter. Stale unexpired readings retain their numbers with reduced fill opacity (0.4), an explicit status, and no forecast.

### Native panel controls

Refresh is a compact pill using the group color at rest and track color on hover; its text dims while disabled. The footer reports updating status or the normal refresh cadence and identifies sample data when enabled. `R` and native keyboard activation refresh; up/down moves through scrollable content. Escape dismisses and Tab uses the shell's panel-switching behavior through `PanelKeyCatcher`.

## Do's and Don'ts

### Do:

- **Do** keep theme colors and `Style.space()` expressions live.
- **Do** retain text, units, and accessible names alongside charts, colors, and icons.
- **Do** distinguish missing, stale, expired, and zero readings.
- **Do** preserve the native panel lifecycle and keyboard controls.
- **Do** use synthetic data and identify it in previews.

### Don't:

- **Don't** hardcode the captured blue accent or a captured light/dark palette.
- **Don't** use cost colors to tint provider quota groups or replace forecast text with color alone.
- **Don't** add provider tabs, Extra Usage, or Usage Trend sections to this widget.
- **Don't** put every quota row in a separate card or add decorative animation.
