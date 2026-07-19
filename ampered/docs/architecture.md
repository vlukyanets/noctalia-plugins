# Architecture

## Entry points (Noctalia v4)

| File | Entry type | Role |
|---|---|---|
| `Main.qml` | `main` | Singleton; runs the `ampered-ctl watch` stream, owns all state, runs commands |
| `BarWidget.qml` | `barWidget` | Bar capsule per screen; renders a battery-level / status icon |
| `Panel.qml` | `panel` | Drop-down; battery percent + profile switcher, calls `main` methods |
| `Settings.qml` | `settings` | Plugin settings UI |

## Data flow

Reads are **event-driven**: a single long-lived `ampered-ctl watch --json` process streams one JSON
snapshot per line, and `applySnapshot()` folds each into the reactive properties. There is no
polling. Mutations are still one-shot commands; their effect comes back over the same stream.

```
ampered-ctl watch --json   ── long-lived; one JSON snapshot per line, pushed on every change ──┐
                                                                                               │
   set-profile <name> / inhibit / uninhibit                        ── one-shot mutations ──┐  │
                                                                                            ▼  ▼
   Main.qml  (applySnapshot() → QML properties: available, profile, profiles, powerSource,
              dimmed, screenOff, locked, inhibited, inhibitors, manualInhibitActive,
              idleSec, dimInSec, screenOffInSec, sleepInSec, lockInSec, lockOnScreenOff,
              batteryPresent, batteryStatus, batteryPercent,
              batteryTimeToEmpty, batteryTimeToFull)
        │
        ├──pluginApi.mainInstance──▶  BarWidget.qml  (reads properties, re-renders on change)
        ├──pluginApi.mainInstance──▶  Panel.qml      (reads properties, calls setProfile /
        │                                             toggleManualInhibit / reconnect)
        └──pluginApi.mainInstance──▶  Settings.qml   (reads/writes plugin settings)
```

All state is owned by `Main.qml` as reactive QML properties. `BarWidget` and `Panel` access them
through `pluginApi.mainInstance`.

## Connection lifecycle

The `watch` process is the single source of truth for `available`:

- **Connect** — `Component.onCompleted` starts the process; the first snapshot sets `available`.
- **Liveness** — a watchdog `Timer` is restarted by *every* incoming line (snapshots and heartbeat
  lines alike). If nothing arrives within its window (`max(2×heartbeatInterval, 15s)`), the pipe is
  assumed hung and the process is torn down to trigger a reconnect.
- **Reconnect** — on `onExited` (crash, daemon stop, missing binary, or the liveness teardown) all
  state is cleared (`available = false`) and the process is relaunched after a backoff that ramps
  `1s → 2s → 4s …` capped at `heartbeatInterval`. A good snapshot resets the backoff.
- **`refresh` IPC** — forces an immediate reconnect (`reconnect()`), not a poll.

`heartbeatInterval` sizes the liveness/backoff windows around the daemon's own heartbeat cadence —
it isn't a poll rate; updates are pushed the moment they happen.

## CLI contract

`ampered-ctl watch --json` is now implemented upstream (`crates/ampered-ctl/src/main.rs`); this
section documents the shape the plugin relies on.

### `ampered-ctl watch --json` → long-lived stream, one JSON object per line

The primary read path. On connect it prints a **full snapshot**, then a fresh snapshot on every
`PropertiesChanged` and every change to the inhibitor set (the daemon's whole design is "properties
notify, clients never poll" — this subcommand simply relays that). Requirements:

- **One compact JSON object per line** — no embedded newlines; the plugin splits on `\n`.
- **Heartbeat** — when idle, emit a small `{ "heartbeat": true }` line every 20s (the CLI's fixed
  `HEARTBEAT_INTERVAL`) so the plugin can tell "connected but quiet" from "hung". Any line (snapshot
  or heartbeat) resets the liveness watchdog; lines carrying `heartbeat` are otherwise ignored.
- The process should stay up until the daemon exits or the pipe closes; the plugin owns reconnect.

Snapshot object — field names/types mirror the `org.ampered.Power1` properties (see the daemon's
`docs/dbus-api.md`), plus an inline `inhibitors` array (the `ListInhibitors` `a(sss)` result).
`-1` sentinels stand in for "unknown":

```json
{
  "active_profile": "balanced",
  "profiles": ["balanced", "performance", "powersave"],
  "power_source": "battery",
  "battery": {
    "present": true,
    "status": "discharging",
    "percent": 72,
    "time_to_empty_min": 143,
    "time_to_full_min": -1
  },
  "dimmed": false,
  "screen_off": false,
  "locked": false,
  "inhibited": false,
  "lock_on_screen_off": true,
  "idle_sec": 10,
  "dim_in_sec": 170,
  "screen_off_in_sec": 290,
  "sleep_in_sec": 590,
  "lock_in_sec": 290,
  "inhibitors": [
    { "source": "mpris",  "scope": "3", "reason": "Playing video" },
    { "source": "manual", "scope": "",  "reason": "noctalia" }
  ]
}
```

`battery.status ∈ full | charging | discharging | not_charging | absent | unknown`.
`idle_sec = -1` when no session agent is connected; otherwise seconds since last activity.
`*_in_sec = -1` when that stage is disabled, no session agent is connected, or idle is inhibited
(the stage is paused and won't fire, so a ticking countdown would be misleading).
`inhibitors[].source ∈ mpris | screensaver | powermanagement | manual | user` — a `manual` entry
means the user holds a persistent inhibitor (the panel's Inhibit toggle). A snapshot **must** carry
`active_profile`; lines without it (or with `heartbeat`) are ignored so a partial line can't wipe
state. Additional Power1 properties (`capabilities`, `active_session_id`, `agents_connected`) may
be present and are ignored for now.

### Mutating subcommands (exit 0 on success)

| Command | D-Bus method | polkit action |
|---|---|---|
| `ampered-ctl set-profile <name>` | `SetProfile` | `org.ampered.set-profile` |
| `ampered-ctl inhibit` | `AddManualInhibit` | `org.ampered.inhibit` |
| `ampered-ctl uninhibit` | `RemoveManualInhibit` | `org.ampered.inhibit` |

`uninhibit` passes no reason: the daemon drops the sole manual inhibitor when exactly one is held,
which is what the panel's single toggle button relies on.

## State shape

```qml
// Main.qml properties (consumed by BarWidget and Panel via pluginApi.mainInstance)
property bool   available          // true once a snapshot arrives; false while the stream is down
property string profile            // active profile name, "" when unavailable
property var    profiles           // string[] of configured profile names
property string powerSource        // "ac" | "battery"
property bool   dimmed             // active session dimmed   (parsed; not shown — see note below)
property bool   screenOff          // active session's display off (parsed; not shown)
property bool   locked             // active session locked   (parsed; not shown)
property bool   inhibited          // true if any idle inhibitor is held (countdowns paused)
property var    inhibitors         // [{ source, scope, reason }, ...] carried in each snapshot
property bool   manualInhibitActive// true if an inhibitor with source == "manual" is held

property int    idleSec            // seconds since last activity, -1 when no agent
property int    dimInSec           // seconds until dim, -1 when disabled / no agent
property int    screenOffInSec     // seconds until screen off, -1 when disabled / no agent
property int    sleepInSec         // seconds until sleep, -1 when disabled / no agent
property int    lockInSec          // seconds until idle-lock, -1 when disabled / no agent
property bool   lockOnScreenOff    // daemon also locks when the screen turns off

property bool   batteryPresent     // false when no battery / not reported
property string batteryStatus      // "charging" | "discharging" | "full" | "not_charging" | "absent" | "unknown"
property int    batteryPercent     // 0–100, -1 when unknown
property int    batteryTimeToEmpty // minutes until empty, -1 when N/A
property int    batteryTimeToFull  // minutes until full, -1 when N/A
```

## Settings

Declared as `metadata.defaultSettings` in `manifest.json`; read in any QML file via:

```qml
pluginApi?.pluginSettings?.key ?? pluginApi?.manifest?.metadata?.defaultSettings?.key ?? fallback
```

Persisted by calling `pluginApi.saveSettings()` after mutating `pluginApi.pluginSettings`.

| Key | Type | Default | Meaning |
|---|---|---|---|
| `heartbeatInterval` | int | `20000` ms | Expected cadence of `ampered-ctl watch`'s heartbeat lines; sizes the liveness watchdog and the reconnect backoff cap |
| `ctlPath` | string | `"ampered-ctl"` | Path to the `ampered-ctl` binary |

> Default matches `ampered-ctl`'s own fixed `HEARTBEAT_INTERVAL` (20s, in `crates/ampered-ctl/src/main.rs`)
> so the liveness window lines up with reality out of the box; raise it if a slower stream is expected.

## Translations

Strings live in `i18n/<lang>.json`. Resolved with `pluginApi.tr("key")`.

## IPC

`Main.qml` registers an `IpcHandler` on target `"plugin:" + pluginApi.manifest.id` (resolved at
runtime, so it works regardless of the registry source hash prefix) exposing:

| Function | Effect |
|---|---|
| `toggle()` | Opens the panel on the current screen |
| `refresh()` | Forces an immediate reconnect of the `ampered-ctl watch` stream |
