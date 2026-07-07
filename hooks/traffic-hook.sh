#!/bin/bash
# Шлюз: Claude Code hook -> TrafficLight.app
# Использование в settings.json: "command": "/Users/alex/claude-traffic-light/hooks/traffic-hook.sh <EventName>"
# stdin хука (JSON с session_id, cwd) пробрасывается в тело запроса как есть.
EVENT="$1"
BODY="$(cat)"
curl -s -m 1 -X POST "http://127.0.0.1:47615/event?type=${EVENT}" \
     -H "Content-Type: application/json" \
     --data-binary "${BODY}" >/dev/null 2>&1 || true
exit 0
