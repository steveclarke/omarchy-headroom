# Headroom

Claude Code and Codex weekly percentages, local cost estimates, reset times, and usage forecasts for the Omarchy bar.

**Early proof of concept.** Choose either or both providers, their order, and where each appears. Headroom uses Omarchy's installed quota collectors with a compact, rounded panel that follows the active theme.

## What it shows

- Weekly percentages **remaining** for your chosen providers in the bar.
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

- Omarchy with the Quattro shell and native plugin services. Tested with package `omarchy 4.0.2-1`; this is a tested baseline, not a guaranteed minimum version.
- Python 3, the core usage collector, and a signed-in CLI for each enabled provider: `omarchy-agent-usage-claude` / Claude Code or `omarchy-agent-usage-codex` / Codex.
- For optional costs: Bun installs the pinned ccusage reader; system Node.js (`/usr/bin/node`) runs it.
- `qt6-5compat` for monochrome icon tinting.

## Install

```sh
omarchy plugin add https://github.com/steveclarke/omarchy-headroom.git --enable
python3 ~/.config/omarchy/plugins/io.github.steveclarke.headroom/bin/setup-costs
omarchy-shell headroom refresh
```

Click the bar summary to open the panel. Right-click or middle-click refreshes; R or Enter refreshes inside the panel, and Escape closes it. Left/right arrows or 1/2/3 select the cost period. Usage refreshes every five minutes. Repeated refresh requests within twenty seconds are coalesced.

Headroom works with the built-in Agents display disabled. Its collectors are core Omarchy commands; the Agents widget does not need to run. To avoid two independent refresh loops:

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

Removing the plugin stops its workers and removes the plugin checkout. The separate `$XDG_DATA_HOME/headroom/ccusage-20.0.20` dependency directory remains, as do the provider CLIs, their credentials/history, and Omarchy's native usage caches. Headroom does not delete those shared files or restore the Agents widget automatically. Setup refuses redirected directories and never overwrites an existing version. If it reports a damaged installation, move that exact version directory aside and rerun setup; preserve it until the replacement works.

## Settings

The panel uses Omarchy's shared popup border, corner radius, font and control styles, so it follows your desktop theme.

Click **Settings** in the panel, or press **S** while it is open. Each provider occupies one draggable row with two columns:

- **Enabled** enables usage collection and the details shown when you click Headroom. Turning it off hides that provider and stops its quota and cost workers.
- **Top bar** adds its weekly percentage to the top bar. Turning this off keeps the provider in the details. The switch is disabled while the provider is off and remembers its choice when re-enabled.

Both providers and their top-bar summaries default to on, with cost estimates enabled. Existing visibility choices are preserved when updating.

Drag a provider header on the main screen, or its grip in Settings, to move the whole provider section. Dropping saves the same order for the bar, quota groups and cost legend. A focused grip also supports Up/Down; Escape cancels a drag. The **Cost** switch controls the whole cost section and its local-history workers. Quotas work without installing the optional cost reader. When there are no bar summaries, a compact **Headroom** entry keeps the panel and settings reachable.

Changes apply and save automatically across all monitors through Omarchy's existing widget configuration. The bar updates while settings stays open. **Done** or Escape returns to the updated details panel and keeps your changes; closing the panel also keeps them. In settings, Tab moves between controls and Space activates them. A rejected change leaves the saved selection in place and shows an error. Outside settings, the native panel navigation and refresh keys remain available.

To check the runtime and selected collector commands without reading accounts or contacting providers:

```sh
python3 ~/.config/omarchy/plugins/io.github.steveclarke.headroom/bin/headroom-collect --check-dependencies --providers claude codex
```

List only the providers you use. Missing required files produce a nonzero exit status; Node and the cost reader are reported as optional. This checks availability, not login validity or future collector schema compatibility. Login failures and unsupported collector formats appear on the affected provider's card.

## Cost estimates

[ccusage](https://github.com/ccusage/ccusage) 20.0.20 reads local Claude Code and Codex history. Headroom calculates daily reports from bundled offline prices (`--mode calculate`), so all usage is estimated on the same pricing basis. Recorded cost fields are not used. It retains only daily USD totals, not project names or model/token details. Cost reading runs separately from quota collection. Each worker has an isolated temporary home and an explicit path to just one provider’s history. No usage history is uploaded. `bin/setup-costs` installs the locked reader under `$XDG_DATA_HOME/headroom/ccusage-20.0.20` (default `~/.local/share/headroom/ccusage-20.0.20`), outside the validated plugin folder.

These are estimated API-equivalent usage values, **not subscription charges**. Coverage is this machine's available local history; it does not include sessions on other computers. Today and Yesterday use the local calendar; 30 Days includes today and the previous 29 days. A used model without positive cost evidence marks its provider incomplete. Available daily amounts and their combined total stay visible with `Partial estimate · some usage may be missing`; unpriced usage is excluded from those amounts. This warning can also appear for a genuinely free model with recorded activity. Failed, missing, or outdated reports show `—`. Model mappings, deduplication and pricing accuracy depend on the pinned reader; prices can change. Its Claude parser expects the compact JSONL emitted by the CLI and can ignore reformatted history; completeness checks cannot detect records that the reader itself skips.

## Data access and network

Headroom delegates quota authentication to the installed Omarchy collectors. Claude's collector reads its CLI credentials and contacts `https://api.anthropic.com/api/oauth/usage`. Codex's collector runs the signed-in local Codex app-server and requests subscription limits; the installed Codex CLI owns its OpenAI connections and authentication. Headroom does not receive, store, or print credential values. Native collector credential handling, HTTP behavior, and cache writes remain upstream responsibilities.

The optional setup command downloads hash-locked packages from the npm registry through Bun, with lifecycle scripts disabled. Routine cost checks use offline pricing and local history. The cost worker creates an empty private temporary directory and removes it after collection or normal cancellation. Only normalized quota fields and daily money totals reach the shell; raw history and diagnostics are discarded. Helper output, runtime, strings, nesting, and model counts have explicit limits.

## Current limitations

- Headroom shows only windows exported by Omarchy's collectors. A provider can legitimately have a weekly allowance without a shared session allowance; Only reported windows appear in the panel. The current Codex collector does not export its separate model-specific pools.
- Forecasts require a known window duration and a verified recent observation. Unknown windows still show their usage and reset time. A new or unused window has no meaningful burn rate yet.
- Claude can silently fall back to cached values. Headroom checks the native usage-cache timestamp to detect this. A simultaneous check by another widget can temporarily leave Claude marked unverified; retry after twenty seconds. The native CLI owns login renewal.
- There is one active account per provider. Headroom does not persist its own snapshots or support account switching/multi-account aggregation.
- Native collectors may scan local history when their caches expire, although Headroom discards those statistics and displays only quota windows.
- This proof of concept targets horizontal bars. Vertical layout is provisional.

## Development

The bundled `providers.json` registry defines provider identity, collector names and display capabilities. `Providers.js` validates preferences and orders enabled IDs. The shell creates one `Service.qml` for all monitors. It runs `bin/headroom-collect`; `Model.js` and `Pace.js` normalize display state and calculate forecasts. `Costs.js` selects local calendar periods from the separate cost worker. `BarWidget.qml` hosts the native `Panel.qml` lifecycle.

Interface conventions are recorded in [DESIGN.md](DESIGN.md); contributor guidance is in [docs/CONTRIBUTING.md](docs/CONTRIBUTING.md).

Run the checks with Node.js, Python 3, Qt 6 qmllint and Omarchy installed:

```sh
python3 bin/check
python3 tests/check-qml
python3 tests/check-drag
python3 tests/check-reader ~/.local/share/headroom/ccusage-20.0.20/node_modules/.bin/ccusage
```

The reader integration check uses only generated histories, offline mode, and temporary homes; adjust the reader path when using a custom `XDG_DATA_HOME`.

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

`python3 tests/check-drag --desktop` also tests main-screen dragging in an isolated native panel with synthetic data; it briefly opens a window.

Use synthetic fixtures and screenshots. Never commit credentials, account identifiers, local usage records, or machine configuration. Only fixed error categories are surfaced; raw collector output is not logged. The read-only status command reports provider preferences, state and window counts, not usage amounts.

## License

MIT. See [LICENSE](LICENSE) and [NOTICE](NOTICE) for upstream attribution.

Cost has a draggable row in Settings and a grip beside its panel heading. Move it above, between, or below providers. Its position is retained when hidden; moving Cost does not change provider order in the bar.
