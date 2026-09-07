# Headroom

Claude Code and Codex weekly percentages, local cost estimates, reset times, and usage forecasts for the Omarchy bar.

**Early proof of concept.** Both providers stay visible in the bar and in one compact panel. Headroom uses Omarchy's installed quota collectors with a compact, rounded panel that follows the active theme.

## What it shows

- Weekly percentages **remaining** for both providers in the bar.
- Session, weekly, and reported model-specific quota windows in the panel.
- Estimated local usage value in USD for Today, Yesterday, and 30 Days, with a provider cost split.
- Reset countdowns beneath thin quota meters.
- Quiet quota rows when capacity is healthy. A yellow meter and spare-capacity note appear when the projected buffer is below 10%; a red meter and flame warn of a limit, with an exhaustion estimate when available.
- Hover a quota meter for the projected capacity at reset. Warning notes sit beside the quota title.
- Last-known percentages with a warning when a refresh cannot be verified. Unreliable data never generates a forecast.

Forecasts use average consumption since the quota window began. They are estimates of allowance consumption, not additional charges or a measurement of the last few minutes' activity.

## Preview

Synthetic values; the interface follows the active Omarchy theme.

![Both providers visible together in the bar](screenshots/headroom-bar.png)

| Light | Dark |
| --- | --- |
| ![Light panel with synthetic quota readings](screenshots/headroom-light.png) | ![Dark panel with synthetic quota readings](screenshots/headroom-dark.png) |

## Requirements

- Omarchy with the Quattro shell, native plugin services, and `omarchy-agent-usage-claude` / `omarchy-agent-usage-codex` collectors.
- Python 3 and signed-in Claude Code / Codex CLIs.
- Bun and Node.js for installing/running the pinned ccusage cost reader.
- `qt6-5compat` for monochrome icon tinting.

## Install

```sh
omarchy plugin add https://github.com/steveclarke/omarchy-headroom.git --enable
python3 ~/.config/omarchy/plugins/io.github.steveclarke.headroom/bin/setup-costs
omarchy-shell headroom refresh
```

Click the bar summary to open the panel. Right-click or middle-click refreshes; R or Enter refreshes inside the panel, and Escape closes it. Left/right arrows or 1/2/3 select the cost period. Usage refreshes every five minutes. Repeated refresh requests within twenty seconds are coalesced.

Once satisfied with Headroom, disable the built-in Agents display to avoid two independent refresh loops:

```sh
omarchy plugin disable omarchy.agents
```

To restore the built-in display:

```sh
omarchy plugin remove io.github.steveclarke.headroom
omarchy plugin enable omarchy.agents
```

Update with `omarchy plugin update io.github.steveclarke.headroom`, then rerun `bin/setup-costs` from the installed plugin directory to apply any pinned cost-reader update.
If an update still shows the old behavior, run `omarchy restart shell` to clear the shell's compiled QML cache.

## Cost estimates

[ccusage](https://github.com/ccusage/ccusage) 20.0.20 reads local Claude Code and Codex history. Headroom requests daily reports with bundled offline pricing, preserving recorded costs when available. It retains only daily USD totals, not project names or model/token details. Cost reading runs separately from quota collection. No usage history is uploaded. `bin/setup-costs` installs the locked reader under `$XDG_DATA_HOME/headroom/ccusage-20.0.20` (default `~/.local/share/headroom/ccusage-20.0.20`), outside the validated plugin folder.

These are estimated API-equivalent usage values, **not subscription charges**. Coverage is this machine's available local history; it does not include sessions on other computers. Today and Yesterday use the local calendar; 30 Days includes today and the previous 29 days. Missing or incomplete pricing shows `—`, never an invented zero or a misleading combined total. Model mappings, deduplication and pricing accuracy depend on the pinned reader; prices can change.

## Current limitations

- Headroom shows only windows exported by Omarchy's collectors. A provider can legitimately have a weekly allowance without a shared session allowance; Only reported windows appear in the panel. The current Codex collector does not export its separate model-specific pools.
- Forecasts require a known window duration and a verified recent observation. Unknown windows still show their usage and reset time. A new or unused window has no meaningful burn rate yet.
- Claude can silently fall back to cached values. Headroom checks the native usage-cache timestamp to detect this. A simultaneous check by another widget can temporarily leave Claude marked unverified; retry after twenty seconds. The native CLI owns login renewal.
- There is one active account per provider. Headroom does not persist its own snapshots or support account switching/multi-account aggregation.
- Native collectors may scan local history when their caches expire, although Headroom discards those statistics and displays only quota windows.
- This proof of concept targets horizontal bars. Vertical layout is provisional.

## Development

The shell creates one `Service.qml` for all monitors. It runs `bin/headroom-collect`; `Model.js` and `Pace.js` normalize display state and calculate forecasts. `Costs.js` selects local calendar periods from the separate cost worker. `BarWidget.qml` hosts the native `Panel.qml` lifecycle.

Interface conventions are recorded in [DESIGN.md](DESIGN.md).

Run the checks with Node.js, Python 3, Qt 6 qmllint and Omarchy installed:

```sh
python3 bin/check
```

For runtime checks on an installed plugin:

```sh
omarchy-shell headroom status
omarchy-shell shell summon io.github.steveclarke.headroom '{}'
omarchy-shell shell hide io.github.steveclarke.headroom
```

Synthetic previews exercise forecasts, errors and empty states without provider calls. The footer always identifies sample data. Return to live mode when finished:

```sh
omarchy-shell headroom preview normal
omarchy-shell headroom preview stale
omarchy-shell headroom preview empty
omarchy-shell headroom preview ''
```

Use synthetic fixtures and screenshots. Never commit credentials, account identifiers, local usage records, or machine configuration. Only fixed error categories are surfaced; raw collector output is not logged. The read-only status command reports state and window counts, not usage amounts.

## License

MIT. See [LICENSE](LICENSE) and [NOTICE](NOTICE) for upstream attribution.
