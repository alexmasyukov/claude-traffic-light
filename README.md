# claude-traffic-light 🚦

A tiny always-on-top **traffic light** for macOS that shows what [Claude Code](https://claude.com/claude-code) is doing right now — driven by Claude Code hooks. One light per session, so you can watch several terminals at once.

![claude-traffic-light — one light per Claude Code session, showing idle / thinking / running-a-tool and a question block](docs/screenshot.png)

- 🟢 **green** — idle, agent finished and is waiting for you
- 🟡 **yellow** — thinking / preparing / generating a reply (spinner animates)
- 🔴 **red** — running a tool (spinner animates)
- ❓ **question block** — lights up when Claude is waiting for your input / permission

Each session gets its own light in a horizontal row. When a light shows the question block, its neighbours slide right so nothing overlaps.

## How it works

```
Claude Code (session N)
   └─ hook (bash + curl) ──JSON{session_id,event,cwd}──▶  claude-traffic-light.app
                                                            ├─ HTTP server on 127.0.0.1:47615
                                                            ├─ one light per session_id
                                                            └─ floating SwiftUI overlay
```

Claude Code fires lifecycle hooks; a small shell gateway forwards each event (with the session's `session_id` and `cwd`) to a local HTTP server inside the app, which updates the matching light.

| Hook event        | Meaning                        | Result        |
|-------------------|--------------------------------|---------------|
| `UserPromptSubmit`| prompt sent, agent starts      | 🟡 yellow      |
| `PreToolUse`      | tool starts                    | 🔴 red         |
| `PostToolUse`     | tool finished (thinking again) | 🟡 yellow      |
| `Notification`    | waiting for input / permission | ❓ question     |
| `Stop`            | agent finished                 | 🟢 green       |
| `SessionStart` / `SessionEnd` | session appears / closes | add / remove light |

## Interaction

- **Hover** — cursor turns into a hand, the light brightens, and a tooltip shows `folder · branch`.
- **Double-click** — cycle scale +10% up to +50%, then reset. Scale and window position are remembered.
- **Drag** — move the window anywhere; position is saved.
- **Right-click** — context menu with **Quit**.

## Build & install

Requires macOS 13+ and a Swift toolchain (Xcode / Swift 5.9+).

```bash
# 1. Build the release .app into ~/Applications
./build-app.sh

# 2. Install autostart (LaunchAgent, runs at login)
./install-autostart.sh
```

To stop / remove autostart:

```bash
launchctl bootout gui/$(id -u)/com.alex.claude-traffic-light
```

Or just **right-click → Quit** (with `KeepAlive=false` the app stays quit until next login or manual relaunch).

Development build & run:

```bash
swift run
```

## Wire up the hooks

Add the gateway script to your Claude Code hooks in `~/.claude/settings.json` (adjust the path to where you cloned this repo). Point every relevant event at:

```
/path/to/claude-traffic-light/hooks/traffic-hook.sh <EventName>
```

For example a `PreToolUse` entry:

```json
{
  "matcher": "*",
  "hooks": [
    { "type": "command", "command": "/path/to/claude-traffic-light/hooks/traffic-hook.sh PreToolUse", "timeout": 5 }
  ]
}
```

Repeat for `PostToolUse`, `UserPromptSubmit`, `Notification`, `SessionStart`, `SessionEnd`, and `Stop`. The script simply pipes the hook's stdin JSON to `http://127.0.0.1:47615`.

## Layout

- `Sources/TrafficLight/` — Swift sources (App, Model, Overlay, Server, Tooltip)
- `hooks/traffic-hook.sh` — hook → HTTP gateway
- `build-app.sh` — build the release `.app` bundle into `~/Applications`
- `install-autostart.sh` — install the LaunchAgent
- `com.alex.claude-traffic-light.plist` — LaunchAgent template

## Notes

- The overlay window never takes focus (no focus ring), floats above everything, and joins all Spaces including fullscreen apps.
- There is no distinct "typing a reply" event in Claude Code, so yellow covers both thinking and generating text; red is precise (only while a tool runs).
- The `Notification` hook can fire with a small delay — that's Claude Code's timing, not the app's.
