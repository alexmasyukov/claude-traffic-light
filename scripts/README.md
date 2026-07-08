# scripts/

Standalone reference scripts — the same actions claude-traffic-light performs on
click, runnable by hand for testing or reuse. Nothing here is required at runtime;
the app builds the equivalent AppleScript internally.

## `focus-project-window.applescript`

Brings an app forward and raises a specific project window (by title). Mirrors a
click on a traffic light.

```bash
# Edit the two placeholders (__BUNDLE_ID__, __PROJECT__) in the file, then:
osascript scripts/focus-project-window.applescript

# …or substitute on the fly without editing the file:
sed -e 's/__BUNDLE_ID__/com.jetbrains.WebStorm/' \
    -e 's/__PROJECT__/arenadata-network/' \
    scripts/focus-project-window.applescript | osascript
```

To just bring a regular (single-window) app forward, the window part is optional:

```bash
osascript -e 'tell application id "com.jetbrains.WebStorm" to activate'
```

### Permissions (macOS, granted once, prompted on first run)

- **Automation** — control the target app and System Events.
- **Accessibility** — required for the `AXRaise` window action (System Events UI
  scripting). Add the caller (Terminal, or `claude-traffic-light.app`) under
  System Settings → Privacy & Security → Accessibility.

Note: ad-hoc–signed builds change signature on each rebuild, so macOS may re-prompt
for these permissions after `./build-app.sh`. A stable signed release asks once.
