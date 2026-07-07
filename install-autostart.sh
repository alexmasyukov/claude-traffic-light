#!/usr/bin/env bash
# Ставит автозапуск TrafficLight.app при входе в систему (LaunchAgent).
set -euo pipefail

DIR="$(cd "$(dirname "$0")" && pwd)"
LABEL="com.alex.claude-traffic-light"
APP_BIN="${HOME}/Applications/claude-traffic-light.app/Contents/MacOS/claude-traffic-light"
AGENTS="${HOME}/Library/LaunchAgents"
PLIST="${AGENTS}/${LABEL}.plist"

if [[ ! -x "$APP_BIN" ]]; then
    echo "Сначала собери .app:  ./build-app.sh" >&2
    exit 1
fi

mkdir -p "$AGENTS"
sed "s#__APP_BIN__#${APP_BIN}#" "${DIR}/${LABEL}.plist" > "$PLIST"

# Перезагружаем агент.
launchctl bootout "gui/$(id -u)/${LABEL}" 2>/dev/null || true
launchctl bootstrap "gui/$(id -u)" "$PLIST"
launchctl enable "gui/$(id -u)/${LABEL}"

echo "✓ Автозапуск установлен: ${PLIST}"
echo "  Остановить:  launchctl bootout gui/$(id -u)/${LABEL}"
