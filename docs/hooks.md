# Wiring claude-traffic-light into Claude Code hooks

The app is driven entirely by [Claude Code hooks](https://code.claude.com/docs/en/hooks).
Claude Code fires lifecycle events; a tiny shell gateway forwards each one to the
app's local HTTP server (`127.0.0.1:47615`), which updates the matching light.

Nothing here is a third-party dependency — both scripts live in this repo:

| Script | Role |
|--------|------|
| `hooks/traffic-hook.sh` | gateway: forwards a hook event (with its stdin JSON) to the app via `curl` |
| `hooks/last-question.py` | on `Stop`, inspects the transcript and reports whether the agent ended its turn with a text question |

## What each event does

The gateway is invoked as `traffic-hook.sh <EventName>`; it POSTs to
`http://127.0.0.1:47615/event?type=<EventName>` with the hook's stdin JSON body
(`session_id`, `cwd`, `transcript_path`, …).

| Hook event         | Meaning                          | Light                          |
|--------------------|----------------------------------|--------------------------------|
| `UserPromptSubmit` | prompt sent, agent starts        | 🟡 yellow                       |
| `PreToolUse`       | a tool starts                    | 🔴 red                          |
| `PostToolUse`      | tool finished (thinking again)   | 🟡 yellow, clears ❓            |
| `Notification`     | permission prompt / waiting      | ❓ only while the agent is active (idle 60 s pings are ignored) |
| `Stop`             | agent finished the turn          | 🟢 green — **or** 🔴 + ❓ if the last message was a text question |
| `SessionStart`     | session appears                  | adds a light (🟢)               |
| `SessionEnd`       | session closes                   | removes the light               |

### The `Stop` → question special case

Claude Code emits the same `Stop` event whether the agent answered you or asked
you something. To light ❓ on a **free-form text question**, `traffic-hook.sh`
runs `last-question.py` on `Stop`: it opens `transcript_path`, takes the last
assistant message, and if it ends with `?` the gateway sends a synthetic
`StopAsk` event instead of `Stop` — which the app renders as 🔴 + ❓ (waiting for
your answer). Interface questions (`AskUserQuestion`, permission prompts) already
light ❓ via `PreToolUse` + `Notification` while the agent is active.

## Install

1. **Find your clone's absolute path** (used in every command below):

   ```bash
   cd /path/where/you/cloned/claude-traffic-light && pwd
   ```

2. **Copy the hooks block** from [`hooks/settings.example.json`](../hooks/settings.example.json)
   into `~/.claude/settings.json`, under the top-level `"hooks"` key. If you already
   have a `"hooks"` object, merge the per-event arrays rather than replacing it.

   To print the block with the correct absolute path already filled in:

   ```bash
   sed "s#/ABSOLUTE/PATH/TO/claude-traffic-light#$(pwd)#g" hooks/settings.example.json
   ```

3. **Make the scripts executable** (once):

   ```bash
   chmod +x hooks/traffic-hook.sh hooks/last-question.py
   ```

4. **Restart Claude Code** (or open a new session) so it reloads `settings.json`.

That's it — hooks fire per session, and each `session_id` gets its own light.
`traffic-hook.sh` fails silently (`curl -m 1 … || true`) when the app isn't
running, so hooks never block or error out Claude Code.

## Verify

With the app running, you can simulate an event by hand:

```bash
curl -s -X POST "http://127.0.0.1:47615/event?type=StopAsk" \
  -H "Content-Type: application/json" \
  --data-binary '{"session_id":"test","cwd":"'"$(pwd)"'"}'
# → a light appears (🔴 + ❓). Clear it:
curl -s -X POST "http://127.0.0.1:47615/event?type=SessionEnd" \
  -H "Content-Type: application/json" --data-binary '{"session_id":"test"}'
```

## Requirements

- `bash`, `curl` — preinstalled on macOS.
- `python3` — used only by `last-question.py` (the `Stop` transcript check).
  If it's missing, `Stop` still works; you just won't get ❓ on text questions.
