# CLAUDE.md — Registry root

## Layout

```
registry.json    Registry index — one object per plugin (Noctalia v4 format)
draind/          Draind plugin (see draind/CLAUDE.md for plugin-specific notes)
LICENSE
```

## Adding a new plugin

1. Create `<name>/` with `manifest.json` and the required QML entry files.
2. Add an entry object to `registry.json` — keep `id`, `version`, and metadata in sync with `manifest.json`.
