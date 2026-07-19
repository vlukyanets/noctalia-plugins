# CLAUDE.md — Ampered plugin

## Layout

```
manifest.json            Plugin manifest (id, version, entry points, default settings)
Main.qml                 Headless service: runs the `ampered-ctl watch` stream, owns all state
BarWidget.qml            Bar capsule widget (battery-level / status icon, idle-inhibited badge)
Panel.qml                Drop-down panel (battery, power source, idle timers, profiles, lock/reload)
Settings.qml             Plugin settings UI (reconnect interval, ctl path)
Card.qml                 Reusable header-icon + title + content container
i18n/en.json             English strings
docs/architecture.md     Data-flow and state-shape reference
```

## Key conventions

- **JSON, not text.** Unlike the old draind plugin (which parsed `label: value` lines), this
  plugin `JSON.parse`s objects whose fields mirror the `org.ampered.Power1` D-Bus properties 1:1
  (snake_case; `-1` sentinels for unknown).
- **Event-driven, not polled.** Reads come from a single long-lived `ampered-ctl watch --json`
  stream (`applySnapshot()` folds each line into state); there is no poll timer. Mutations are
  one-shot commands whose effect returns over the same stream. See the Connection lifecycle section
  in [docs/architecture.md](docs/architecture.md).
- **`ampered-ctl` is a stub upstream** (`crates/ampered-ctl/src/main.rs` exits 1). This plugin
  therefore *defines* the CLI contract the daemon author must match. Assumed contract:
  - `ampered-ctl watch --json` → long-lived stream, one compact JSON object per line: a full
    snapshot on connect and on every change, plus `{ "heartbeat": <epoch> }` liveness lines (≈≤10s
    when idle). Snapshot fields: `active_profile`, `profiles[]`, `power_source`,
    `battery{present,status,percent,time_to_empty_min,time_to_full_min}`, `dimmed`, `screen_off`,
    `locked`, `inhibited`, `lock_on_screen_off`, `dim_in_sec`/`screen_off_in_sec`/`sleep_in_sec`/
    `lock_in_sec` (`-1` = disabled/no agent), and an inline `inhibitors[]` array of
    `{source, scope, reason}` (`source == "manual"` marks a user-held inhibitor). A real snapshot
    **must** carry `active_profile`; lines without it (or with `heartbeat`) are ignored.
  - `ampered-ctl set-profile <name>` → D-Bus `SetProfile` (polkit `.set-profile`).
  - `ampered-ctl lock` → D-Bus `Lock` (ungated).
  - `ampered-ctl reload-config` → D-Bus `ReloadConfig` (polkit `.reload`).
  - `ampered-ctl inhibit` / `uninhibit` → D-Bus `AddManualInhibit` / `RemoveManualInhibit`
    (polkit `.inhibit`); `uninhibit` with no reason drops the sole manual inhibitor.
- **State ownership**: all mutable state lives in `Main.qml` as QML properties. `BarWidget.qml`
  and `Panel.qml` read them via `pluginApi.mainInstance.<property>`. See
  [docs/architecture.md](docs/architecture.md) for the property list — don't duplicate it here.
- **Availability, liveness & reconnect**: `available` tracks the live stream — false whenever the
  `watch` process is down. A liveness `Timer` (restarted by every line, incl. heartbeats) tears the
  process down if it goes silent; `onExited` clears state and reconnects with a backoff that ramps
  to `reconnectInterval` (the `refreshInterval` setting, no longer a poll rate). `refresh()` IPC
  forces an immediate reconnect.
- **Settings**: read via `pluginApi.pluginSettings.<key>` with fallback to
  `pluginApi.manifest.metadata.defaultSettings.<key>`; saved via `pluginApi.saveSettings()`.
- **Translations**: `pluginApi.tr("key")`. Add new keys to every `i18n/*.json` file.
- **API version**: targets Noctalia v4.7.0+. Uses `qs.Commons`, `qs.Services.UI`, `qs.Widgets`,
  `Quickshell.Io`.

## Scope

Current: bar icon with an idle-inhibited badge; panel with battery + power source, idle-timer
countdowns, inhibitor list, profile switcher, and Inhibit-toggle / Lock-now / Reload-config
buttons; event-driven updates via the `watch` stream; settings (reconnect interval, ctl path).
Deferred until the CLI grows the matching subcommand: charge-limit slider (`SetBatteryThreshold`).

Note: instantaneous session state (`dimmed`/`screen_off`/`locked`) is intentionally **not** shown
in the panel — those states aren't observable on demand (opening the panel resets idle/undims, and
a locked/blanked screen hides the bar entirely). The idle-timer countdowns cover the useful
forward-looking view instead. The properties are still parsed as a faithful mirror of `status
--json` in case a passive surface needs them later.

## No build / test tooling

No package manager, bundler, or test runner. Validate by loading the plugin in Noctalia directly.
