#!/bin/bash
# Шлюз: Claude Code hook -> TrafficLight.app
# Использование в settings.json: "command": "/Users/alex/claude-traffic-light/hooks/traffic-hook.sh <EventName>"
# stdin хука (JSON с session_id, cwd) пробрасывается в тело запроса как есть.
EVENT="$1"
BODY="$(cat)"
TYPE="$EVENT"

# На Stop проверяем: закончил ли ассистент ход свободным текстовым вопросом
# (последнее сообщение оканчивается на «?»). Если да — шлём синтетический тип
# StopAsk, чтобы светофор показал красный + «?» (ждём ответа), а не просто зелёный.
if [ "$EVENT" = "Stop" ]; then
    if [ "$(printf '%s' "$BODY" | python3 "$(dirname "$0")/last-question.py" 2>/dev/null)" = "1" ]; then
        TYPE="StopAsk"
    fi
fi

curl -s -m 1 -X POST "http://127.0.0.1:47615/event?type=${TYPE}" \
     -H "Content-Type: application/json" \
     --data-binary "${BODY}" >/dev/null 2>&1 || true
exit 0
