# Headroom interface

Headroom follows Omarchy's native shell. Its job is to make remaining allowance and the risk of running out easy to read while working.

## Bar

Keep Claude Code and Codex visible together. Each provider has its own icon, Session and Weekly labels, and fixed-width percentages. Numbers carry more weight than labels. Reserve warning space so a flame appearing does not move neighboring widgets. A thin separator distinguishes the providers.

Use the bar's own text color, including its wallpaper-aware contrast. Provider identity stays separate from urgency. The native open-panel underline follows the visible content width.

## Panel

Stack the two providers on one native popup surface. Place each provider name beside its icon, with the subscription name aligned at the right. Separate providers with space and a fine rule; do not wrap quota rows in individual cards.

Within a quota row, read in this order: window name and remaining percentage, capacity meter, reset time and forecast. Percentages are neutral, larger and heavier than their labels. Safe forecasts recede; amber spare-capacity warnings and flame estimates receive emphasis. The even-pace marker remains visible over both filled and empty portions of the meter.

Use popup text and background tokens for the popup, and shared Omarchy font, spacing and control tokens throughout. Secondary text and semantic colors are adjusted toward the popup foreground when needed for contrast. Do not choose a separate font or replace the user's theme.

Forecast details wrap onto another line when the width cannot accommodate them. Missing values stay missing; expired readings do not leave a filled meter. Stale readings retain legible numbers and an explicit warning, while forecasts disappear.

The existing native panel transition and a brief meter-width transition provide feedback. No decorative motion, gradients, extra dashboards or provider tabs.

Synthetic previews must remain visibly identified. Preserve mouse refresh, keyboard refresh, Escape, native panel switching and the shared collection service.
