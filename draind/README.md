# Draind — Noctalia Plugin

Shows and controls [draind](https://github.com/vlukyanets/draind) power management profiles from the Noctalia menu bar.

## Features

- Bar capsule with two icons: battery level and charging status (bolt / plug / arrow-down)
- Battery percentage, time-to-empty, and time-to-full shown in the panel
- Click to open a panel for switching between power profiles
- Daemon availability indicator
- Configurable poll interval and `draind-ctl` binary path

## Requirements

- Noctalia ≥ 4.7.0
- [`draind`](https://github.com/vlukyanets/draind) daemon running
- `draind-ctl` on `$PATH` (or set a custom path in settings)

## Settings

| Setting | Default | Description |
|---|---|---|
| `refreshInterval` | `5000` | How often to poll `draind-ctl` for status (ms) |
| `compactMode` | `false` | *(reserved)* |
| `ctlPath` | `draind-ctl` | Path to the `draind-ctl` binary |

## IPC

```sh
# Toggle the panel open/closed
qs -c noctalia-shell ipc call plugin:<id>:draind toggle

# Force a status refresh
qs -c noctalia-shell ipc call plugin:<id>:draind refresh
```

Replace `<id>` with the registry source hash shown in Noctalia's plugin list (e.g. `ef2bc0`). The full plugin id is displayed as `<hash>:draind` because this plugin is installed from a personal registry, not the built-in one.

## Architecture

See [docs/architecture.md](docs/architecture.md) for data-flow details.
