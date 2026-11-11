---
name: Headroom
description: A native Omarchy panel for remaining allowance and usage forecasts.
typography:
  body:
    fontFamily: "monospace"
---

# Design System: Headroom

## Direction

Headroom follows the installed Omarchy shell. The panel is flat, with the native popup border and corner radius, shared fonts, buttons, switches and separators. It keeps the usage information together in one column. The bar remains compact, with monochrome provider marks and weekly percentages.

`Panel.qml`, `SettingsView.qml` and `BarWidget.qml` are the visual source of truth. The font family in frontmatter is the shell's default alias; live controls bind to `Style.font.family` so changes follow the desktop.

## Theme and geometry

- `KeyboardPanel` owns the popup background, border, corner radius, padding, focus, placement and dismissal. Do not override its internal card or suppress its border.
- Panel colors use `Color.popups.background` and `Color.popups.text`. No light-theme whitening or inset-card backgrounds. The outline follows `Color.popups.border` and the native border specification, rather than a fixed blue.
- Text uses `Style.font.family` and the shared body, bodySmall, title, heading and display sizes. Layout uses `Style.spacing` and `Style.space()`.
- Content width is fitted from `Style.space(400)`, and height from the content with a `Style.space(1000)` cap. A vertical Flickable handles shorter screens.
- Provider sections and the footer use `PanelSeparator`. Quotas sit directly on the panel, without separate cards. Major gaps use `Style.spacing.panelGap`.
- Buttons and switches use `qs.Ui.Button` and `ToggleSwitch`. The shell owns their corners, hover, focus, selected and pressed styles. Settings and Refresh retain their native gear and refresh glyphs.

## Colors and readability

Healthy quotas use `Color.accent`, warnings use yellow, and urgent limits start from `Color.urgent`. Tracks use `Style.selectedFillFor(foreground, Color.accent)`.

Supporting text and urgency colors are adjusted toward the foreground to seek a calculated contrast ratio of at least 4.65 against the panel surface. Caution meters use `#c49a16` on light surfaces and `#edc35b` on dark surfaces. The hourglass uses `#916900` on light surfaces and the caution color on dark surfaces. Text and icons accompany all warning colors.

## Bar

Each selected provider has a monochrome mark and weekly percentage remaining, using the native WidgetButton font and bar icon tokens. Summaries are horizontal with a plain gap; they stack on a vertical bar. There is no separator, hover tooltip or hover-opened panel. The hand cursor indicates clickability. Left-click opens details; right-click refreshes. A Headroom label keeps settings reachable when no provider is shown in the bar.

Stale readings add `!`; an urgent or exhausted weekly forecast adds a flame. Missing percentages show an em dash. The native open indicator follows the visible content width.

## Quota details

All enabled providers appear together, in the chosen order. A monochrome mark, provider name and subdued plan introduce each section. Session, Weekly and reported model-specific limits remain visible together. Each row has its title and conditional warning, a thin meter, remaining percentage, and reset countdown.

Meters are `Style.space(6)` high. Their ends follow the native corner radius, capped at half the track height. Plan names and quota titles can elide; status and reset text wrap. The warning takes priority over the quota title when width is tight.

- Healthy forecasts with at least 10% projected spare show no permanent note or marker; hover reveals the projection.
- A smaller buffer rounding to at least 1% shows a yellow meter, hourglass and `~N% spare` beside the title.
- A buffer rounding to zero, or exhaustion projected before reset, shows a red meter and flame. A meaningful exhaustion estimate accompanies the flame; zero remaining reads `Limit reached`.
- Caution and urgent forecasts show the even-pace tick. Healthy, exhausted, stale and unavailable readings do not.
- Early readings below 5% usage suppress extrapolated alarms. Without a usable projection, fresh readings use absolute usage bands: yellow at 80% used, red at 90%, without a forecast note.
- Missing or expired values show an em dash and empty track. Stale unexpired values retain numbers with 0.4 fill opacity, a status, and no forecast.

Warning icons use `Style.font.heading` (16 at the default size) for recognition, with a 4-unit text gap. Forecast text is secondary and normal weight. Hover explains the average-use basis.

## Settings

Settings uses one flat draggable row per provider, with aligned **Enabled** and **Top bar** columns. Compact native ToggleSwitch controls have 44-unit click targets, explicit accessible names and keyboard focus. No nested toggle cards, per-provider status labels or preview content.

Enabled controls collection and panel visibility. Disabling a provider stops its workers, disables its top-bar switch, and retains the top-bar choice. One shared explanation describes this. Changes save immediately across monitors; a rejected save retains the existing state and shows an error. Grips preserve pointer and Up/Down reordering, with the insertion marker and cancellation behavior shared with the main panel.

Tab walks settings controls, Space activates them, and Done or Escape returns to details while keeping changes. Reordering restores settings focus; other changes preserve the focused control. S opens settings. Outside settings, the shell owns Tab panel switching and Escape dismissal; R or activation refreshes, and arrows scroll.

The footer has two explicit lines: Headroom, then Next update in X min (or Updating… / Sample data). The countdown follows the usage worker's next deadline, updates each second, and shows <1 min in the final minute. Both use the shared small body font and the second line never wraps. Settings and Refresh sit beside them.

## Verification

Use synthetic usage for captures. Check both light and dark palettes, missing and stale readings, warning states, settings, native keyboard behavior, and saved choices. Never publish private account data or surrounding desktop content. Preserve shared shell styling rather than changing global settings to accommodate Headroom.

Settings uses the compact two-column matrix described above.

The panel captures its bar anchor on opening and keeps that position until it closes. Live bar width changes must not move Settings under the pointer. Reopening captures the current button position; native screen-edge fitting remains active.
