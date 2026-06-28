# CLAUDE.md — Draind plugin

## Layout

```
manifest.json            Plugin manifest (id, version, entry points, default settings)
Main.qml                 Headless service: polls draind-ctl, owns all state, handles commands
BarWidget.qml            Bar capsule widget (NIconButton)
Panel.qml                Drop-down panel (profile switcher)
Settings.qml             Plugin settings UI
i18n/en.json             English strings
docs/architecture.md     Data-flow and state-shape reference
```

## Key conventions

- **State ownership**: all mutable state lives in `Main.qml` as QML properties (`available`, `profile`, `dimmed`, `activeSession`, `profiles`). `BarWidget.qml` and `Panel.qml` read them via `pluginApi.mainInstance.<property>`.
- **Commands**: `Panel.qml` calls `pluginApi.mainInstance.setProfile(name)` and `pluginApi.mainInstance.refreshStatus()` directly.
- **Settings**: read via `pluginApi.pluginSettings.<key>` with fallback to `pluginApi.manifest.metadata.defaultSettings.<key>`. Saved via `pluginApi.saveSettings()`.
- **Translations**: `pluginApi.tr("key")`. Add new keys to every `i18n/*.json` file.
- **API version**: targets Noctalia v4.7.0+. Uses `qs.Commons`, `qs.Services.UI`, `qs.Widgets`, `Quickshell.Io`.

## No build / test tooling

No package manager, bundler, or test runner. Validate by loading the plugin in Noctalia directly.
