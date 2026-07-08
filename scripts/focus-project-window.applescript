-- focus-project-window.applescript
--
-- Standalone reference for what claude-traffic-light does when you click a light:
-- bring the owner app forward and raise the specific project window.
--
-- Replace the two placeholders below, then run:
--     osascript scripts/focus-project-window.applescript
--
-- __BUNDLE_ID__  — bundle id of the app running Claude Code (e.g. com.jetbrains.WebStorm).
--                  The app reads this from the hook's $__CFBundleIdentifier.
-- __PROJECT__    — text that appears in the window title (usually the project folder name).
--
-- Requirements (granted once, prompted on first run):
--   • Automation — to control the target app and System Events.
--   • Accessibility — for the AXRaise window action (System Events UI scripting).

set bundleID to "__BUNDLE_ID__"
set projectName to "__PROJECT__"

-- reopen mimics a Dock-icon click (restores a minimized window); activate brings the app forward.
tell application id bundleID
	reopen
	activate
end tell

delay 0.1

-- Raise the exact window whose title contains the project name (multi-window IDEs).
tell application "System Events"
	set procs to (every process whose bundle identifier is bundleID)
	if procs is {} then return "app not running: " & bundleID
	tell (item 1 of procs)
		set frontmost to true
		set matched to (every window whose name contains projectName)
		if matched is {} then return "no window matching: " & projectName
		perform action "AXRaise" of (item 1 of matched)
		return "raised: " & (name of (item 1 of matched))
	end tell
end tell
