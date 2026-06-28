# Architecture

## Entry points (Noctalia v4)

| File | Entry type | Role |
|---|---|---|
| `Main.qml` | `main` | Singleton; polls `draind-ctl`, owns all state, handles commands |
| `BarWidget.qml` | `barWidget` | Bar capsule per screen; reads state from main instance, renders icon + label |
| `Panel.qml` | `panel` | Drop-down; shows profile list, calls methods on main instance |
| `Settings.qml` | `settings` | Plugin settings UI |

## Data flow

```
draind-ctl status / list-profiles / set-profile
        │
        ▼
   Main.qml  (QML properties: available, profile, dimmed, activeSession, profiles)
        │
        ├──pluginApi.mainInstance──▶  BarWidget.qml  (reads properties, re-renders on change)
        └──pluginApi.mainInstance──▶  Panel.qml      (reads properties, calls setProfile / refreshStatus)
```

All state is owned by `Main.qml` as reactive QML properties. `BarWidget` and `Panel` access them through `pluginApi.mainInstance`.

## State shape

```qml
// Main.qml properties (consumed by BarWidget and Panel via pluginApi.mainInstance)
property bool   available      // false when draind-ctl exits non-zero
property string profile        // active profile name, "" when unavailable
property bool   dimmed         // true when draind reports dimmed state
property string activeSession  // active session name reported by draind
property var    profiles       // string[] from draind-ctl list-profiles
```

## Settings

Declared as `metadata.defaultSettings` in `manifest.json`; read in any QML file via:

```qml
pluginApi?.pluginSettings?.key ?? pluginApi?.manifest?.metadata?.defaultSettings?.key ?? fallback
```

Persisted by calling `pluginApi.saveSettings()` after mutating `pluginApi.pluginSettings`.

| Key | Type | Default |
|---|---|---|
| `refreshInterval` | int | `5000` ms |
| `compactMode` | bool | `false` |
| `ctlPath` | string | `"draind-ctl"` |

## Translations

Strings live in `i18n/<lang>.json`. Resolved with `pluginApi.tr("key")`.

## IPC

`Main.qml` registers an `IpcHandler` on target `"plugin:" + pluginApi.manifest.id` (resolved at runtime, so it works regardless of the registry source hash prefix) exposing:

| Function | Effect |
|---|---|
| `toggle()` | Opens the panel on the current screen |
| `refresh()` | Triggers an immediate `draind-ctl status` poll |
