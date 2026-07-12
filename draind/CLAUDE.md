# CLAUDE.md — Draind plugin

## Layout

```
manifest.json            Plugin manifest (id, version, entry points, default settings)
Main.qml                 Headless service: polls draind-ctl, owns all state, handles commands
BarWidget.qml            Bar capsule widget (NIconButton)
Panel.qml                Drop-down panel (status, idle timers, inhibitors, profiles, lock)
Settings.qml             Plugin settings UI (poll interval, ctl path, reload-config)
i18n/en.json             English strings
docs/architecture.md     Data-flow and state-shape reference
```

## Key conventions

- **State ownership**: all mutable state lives in `Main.qml` as QML properties. `BarWidget.qml` and `Panel.qml` read them via `pluginApi.mainInstance.<property>`. See [docs/architecture.md](docs/architecture.md) for the full property list — don't duplicate it here, it drifts.
- **Commands**: `Panel.qml` calls `pluginApi.mainInstance.setProfile(name)`, `lock()`, `toggleManualInhibit()`, and `refreshStatus()` directly; `Settings.qml` calls `reloadConfig()`.
- **Parsing `draind-ctl` text output**: labels can contain spaces (e.g. `active session id:`, `dim in:`), so parse by splitting each line on its *first* colon, not with a `\S+:` regex — the latter silently fails to match multi-word labels.
- **Settings**: read via `pluginApi.pluginSettings.<key>` with fallback to `pluginApi.manifest.metadata.defaultSettings.<key>`. Saved via `pluginApi.saveSettings()`.
- **Translations**: `pluginApi.tr("key")`. Add new keys to every `i18n/*.json` file.
- **API version**: targets Noctalia v4.7.0+. Uses `qs.Commons`, `qs.Services.UI`, `qs.Widgets`, `Quickshell.Io`.

## No build / test tooling

No package manager, bundler, or test runner. Validate by loading the plugin in Noctalia directly.
