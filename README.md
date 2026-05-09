# DevPorts

A tiny native macOS menu bar app that lists every TCP port being listened on locally — Python dev servers (Streamlit, Shiny, FastAPI, Jupyter…), Node, Docker containers, system services — and lets you kill/stop them with one click.

![icon](https://img.shields.io/badge/macOS-13%2B-blue) ![swift](https://img.shields.io/badge/swift-6-orange) ![size](https://img.shields.io/badge/binary-~300KB-brightgreen)

## Features

- Lives in the menu bar (network glyph), zero dock icon
- Auto-refreshes every 3 seconds
- Categorized by Python / Node / Docker / Other / System
- Click a row → opens `http://localhost:PORT` in your browser
- ✕ button → SIGTERM, then SIGKILL after 1.5s (or `docker stop` for containers)
- Newly-detected services pop to the top within each category

## Install

1. Download `DevPorts.zip` from the latest [release](../../releases).
2. Unzip → drag `DevPorts.app` to `/Applications`.
3. **First launch (Gatekeeper)**: the app is ad-hoc signed (not notarized), so macOS will refuse to open it directly. Either:
   - **Right-click → Open**, then click "Open" in the dialog, *or*
   - Run once: `xattr -dr com.apple.quarantine /Applications/DevPorts.app`

## Build from source

Requires macOS 13+, Xcode Command Line Tools (`xcode-select --install`).

```bash
git clone https://github.com/<you>/devports.git
cd devports
./build.sh
open build/DevPorts.app
```

The build script produces `build/DevPorts.app` and `build/DevPorts.zip`.

## How it works

- **Process discovery**: `lsof -nP -iTCP -sTCP:LISTEN -F pcn` — parses listening sockets owned by the current user.
- **Docker discovery**: `docker ps --format '{{json .}}'` — picks up host port mappings (including ranges).
- **Kill**: `kill -TERM <pid>`, wait 1.5s, then `kill -KILL <pid>` if the process is still alive.

No entitlements required, no sandbox, no network access.

## Limitations

- Only sees processes owned by the current user (lsof without root).
- Ad-hoc signed — not notarized for distribution. For wider distribution, sign with Developer ID and run `xcrun notarytool`.

## License

MIT.
