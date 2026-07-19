# Ampered — Noctalia Plugin

Shows [`ampered`](https://github.com/vlukyanets/ampered) power status and lets you switch power
profiles from the Noctalia menu bar.

## Features

- Bar capsule showing a battery-level icon (or a status/`unavailable` icon when there's no
  battery), with a small badge when idle is inhibited (something is keeping the machine awake)
- Panel with the current battery percentage, charge status, time-to-empty / time-to-full, and
  power source (AC / battery)
- Idle-timer countdowns — dim / screen off / sleep / lock — with an "inhibited" indicator
- Inhibitor list — what is currently holding idle off (media players, manual, etc.)
- Switch between the daemon's configured power profiles, with the active one highlighted
- Toggle a manual "keep awake" inhibitor, lock the session, and reload the daemon config from the panel
- Live, event-driven updates over an `ampered-ctl watch` stream — no polling; the UI reflects
  changes as they happen
- Daemon availability indicator, with automatic reconnect if the stream drops or `ampered-ctl`
  stops responding
- Configurable stream reconnect interval and `ampered-ctl` binary path

## Requirements

- Noctalia ≥ 4.7.0
- The [`ampered`](https://github.com/vlukyanets/ampered) daemon running (`org.ampered.Power1` on
  the system bus)
- `ampered-ctl` on `$PATH` (or set a custom path in settings)

> **Note.** This plugin talks to `ampered` through the CLI's **JSON** interface. It reads state
> from a long-lived `ampered-ctl watch --json` stream (one JSON snapshot per line, pushed on every
> change, plus heartbeats) and mutates via the subcommands `set-profile <name>`, `lock`,
> `reload-config`, `inhibit`, and `uninhibit`. Until `ampered-ctl` implements these (its `main()`
> is currently a stub), the plugin shows the "daemon unavailable" state. See
> [docs/architecture.md](docs/architecture.md) for the exact contract.

## Settings

| Setting | Default | Description |
|---|---|---|
| `refreshInterval` | `5000` | Stream reconnect interval — how quickly to retry the `ampered-ctl watch` stream if it drops (ms) |
| `ctlPath` | `ampered-ctl` | Path to the `ampered-ctl` binary |

## IPC

```sh
# Toggle the panel open/closed
qs -c noctalia-shell ipc call plugin:<id>:ampered toggle

# Force an immediate reconnect of the watch stream
qs -c noctalia-shell ipc call plugin:<id>:ampered refresh
```

Replace `<id>` with the registry source hash shown in Noctalia's plugin list. The full plugin id is
`<hash>:ampered` because this plugin is installed from a personal registry, not the built-in one.

## Architecture

See [docs/architecture.md](docs/architecture.md) for data-flow details.
