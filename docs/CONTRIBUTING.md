# Development guidance

Keep this release focused on Claude Code and Codex quota visibility, local usage cost estimates, and forecasts.

- Use the installed Omarchy shell's public plugin contracts and native components.
- Read existing implementation before editing. Do not modify packaged Omarchy files.
- Reuse native usage collectors; keep credentials out of the widget and repository.
- Keep enabled providers together, respecting their chosen order and visibility. Do not add token-history charts or unrelated features.
- Use synthetic fixtures and screenshots. Do not commit personal data, local configuration, usage exports, private planning notes, or secrets.
- Preserve applicable copyright and license notices when adapting code.
- Test forecast arithmetic and failure states; verify actual QML rendering as well as lint.
- Keep README status and instructions accurate. Do not claim unimplemented functionality works.

Additional providers are welcome through proposals and pull requests. Describe the available quota or balance data, authentication requirements and any local cost support first. Add provider-specific synthetic fixtures for normal, unavailable and malformed responses. Preserve existing Claude/Codex behavior and avoid assuming every provider has weekly limits.
