#!/usr/bin/env python3
# Читает тело хука Stop (JSON со stdin), открывает transcript_path и печатает "1",
# если последнее сообщение ассистента — текст, оканчивающийся вопросительным знаком.
# Используется traffic-hook.sh, чтобы светофор показывал «?» и на свободные
# текстовые вопросы (не только на интерфейсные вроде AskUserQuestion).
import sys, json


def last_assistant_text(path):
    last = None
    with open(path, "r", encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            try:
                obj = json.loads(line)
            except ValueError:
                continue
            if obj.get("type") != "assistant":
                continue
            content = obj.get("message", {}).get("content")
            if isinstance(content, str):
                last = content
            elif isinstance(content, list):
                texts = [b.get("text", "") for b in content
                         if isinstance(b, dict) and b.get("type") == "text"]
                # Пустой список текстов (например, чистый tool_use) не сбрасывает
                # предыдущий текст: последнее содержательное сообщение — это ответ.
                if texts:
                    last = "".join(texts)
    return last


def main():
    try:
        data = json.load(sys.stdin)
    except ValueError:
        return
    path = data.get("transcript_path")
    if not path:
        return
    try:
        text = last_assistant_text(path)
    except OSError:
        return
    if text and text.rstrip().endswith("?"):
        print("1")


if __name__ == "__main__":
    main()
