---
name: Headroom
description: A native Omarchy panel for remaining allowance and estimated usage costs.
colors:
  cost-claude: "#d77b5f"
  cost-codex: "#279b80"
typography:
  body:
    fontFamily: "monospace"
---

# Design System: Headroom

## Direction

Headroom follows the installed Omarchy shell. The panel is flat, with the native popup border and corner radius, shared fonts, buttons, switches and separators. It keeps the usage information together in one column. The bar remains compact, with monochrome provider marks and weekly percentages.

`Panel.qml`, `SettingsView.qml` and `BarWidget.qml` are the visual source of truth. Native expressions are recorded in [.impeccable/design.json](.impeccable/design.json). The font family in frontmatter is the shell's default alias; live controls bind to `Style.font.family` so changes follow the desktop.

## Theme and geometry

- `KeyboardPanel` owns the popup background, border, corner radius, padding, focus, placement and dismissal. Do not override its internal card or suppress its border.
- Panel colors use `Color.popups.background` and `Color.popups.text`. No light-theme whitening or inset-card backgrounds. The outline follows `Color.popups.border` and the native border specification, rather than a fixed blue.
- Text uses `Style.font.family` and the shared body, bodySmall, title, heading and display sizes. Layout uses `Style.spacing` and `Style.space()`.
- Content width is fitted from `Style.space(400)`, and height from the content with a `Style.space(1000)` cap. A vertical Flickable handles shorter screens.
- Provider sections and the footer use `PanelSeparator`. Quotas sit directly on the panel, without separate cards. Major gaps use `Style.spacing.panelGap`.
- Buttons, period choices and switches use `qs.Ui.Button` and `Toggle`. The shell owns their corners, hover, focus, selected and pressed styles. Settings and Refresh retain their native gear and refresh glyphs.

## Colors and readability

Healthy quotas use `Color.accent`, warnings use yellow, and urgent limits start from `Color.urgent`. Tracks use `Style.selectedFillFor(foreground, Color.accent)`. Cost-ring colors identify providers and never color quota groups.

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

## Costs

The optional Cost section retains Today, Yesterday and 30 Days as native button-group choices, followed by the ring and provider legend. The information icon explains that these are estimated API-equivalent USD values from this machine, not subscription charges. 30 Days includes today and the previous 29 calendar days.

The ring uses a 134-unit canvas with a 24-unit stroke. Its total is rounded to whole dollars; named legend amounts show two decimals. Missing amounts make the combined total unavailable and leave the ring neutral. Fresh zeros remain zero. A text status distinguishes loading, unavailable and outdated costs. There are no usage trends, token charts or Extra Usage rows.

## Settings

Settings replaces the detail content inside the same panel. Each provider has a native switch beside its name and a subordinate **Show weekly usage in top bar** switch. The first enables collection and the click-open details; the second controls the weekly bar summary. Disabling a provider stops its workers, disables the subordinate switch, and retains its top-bar choice for re-enabling. Existing display settings migrate without changing visibility.

All switches share one right edge. A grip on the left moves the whole provider group; provider headers on the main screen also support dragging. The dragged section follows the pointer, other sections dim, and an accent line marks the drop location. Release saves one order for the bar, quota sections and cost legend; Escape or dropping outside the list cancels. A focused grip supports Up/Down. A native **Show cost estimates** switch controls costs and their workers. All changes save immediately across monitors; the actual bar updates while settings stays open. A rejected save retains the saved selection and shows an error.

Tab walks settings controls, Space activates them, and Done or Escape returns to details while keeping changes. Reordering restores settings focus; other changes preserve the focused control. S opens settings. Outside settings, the shell owns Tab panel switching and Escape dismissal; R or activation refreshes, arrows scroll/select periods, and 1–3 select cost periods.

The footer has two explicit lines: Headroom, then Refreshes every 5 min (or Updating usage / Sample data). Both use the shared small body font and the second line never wraps. Settings and Refresh sit beside them.

## Verification

Use synthetic usage for captures. Check both light and dark palettes, missing and stale readings, warning states, costs and settings, native keyboard behavior, and saved choices. Never publish private account data or surrounding desktop content. Preserve shared shell styling rather than changing global settings to accommodate Headroom.
