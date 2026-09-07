# Headroom

Claude Code and Codex quota percentages, reset times, and usage forecasts for the Omarchy bar.

Headroom is an early proof of concept. This repository currently contains project setup; the widget is not implemented or ready to install.

The initial scope is a compact bar summary for both providers and one panel showing their session, weekly, and available model-specific limits. Forecasts will show the capacity expected to remain at reset, or an estimated time until the allowance is exhausted.

The interface will follow Omarchy's native style and reuse its installed usage collectors. Forecasts describe consumption of an allowance, not billing or additional charges.

## Development

Target: Omarchy with the Quattro shell and authenticated Claude Code and Codex CLIs. Installation and validation instructions will be added when the first working version is available.

Use synthetic data for fixtures and screenshots. Never commit credentials, account identifiers, local usage records, or machine configuration.

## License

MIT. See [LICENSE](LICENSE).
