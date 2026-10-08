#!/bin/bash
# Проверяет всё, что нужно пайплайну: ffmpeg (с drawtext), ffprobe, yt-dlp, node/npx и ключ KIE.
# SKIP_KIE=1 — не обращаться к kie.ai (для тестов). Код 0 — всё на месте, 1 — чего-то нет.
export PATH="$HOME/.local/bin:$PATH"
missing=()
for c in ffmpeg ffprobe yt-dlp npx; do command -v $c >/dev/null 2>&1 || missing+=($c); done
if command -v ffmpeg >/dev/null 2>&1 && ! ffmpeg -hide_banner -filters 2>/dev/null | grep -q ' drawtext '; then
  missing+=("ffmpeg-с-drawtext")
fi
if [[ ${#missing[@]} -gt 0 ]]; then
  echo "Не хватает: ${missing[*]}"
  echo "Установка без brew: uv tool install yt-dlp; uv tool install static-ffmpeg && static_ffmpeg_paths,"
  echo "затем ln -sf <путь>/ffmpeg <путь>/ffprobe ~/.local/bin/ (пути печатает static_ffmpeg_paths)."
  exit 1
fi
echo "ffmpeg, ffprobe, yt-dlp, npx — ок ($(ffmpeg -hide_banner -version | head -1 | cut -d' ' -f1-3))"
[[ ${SKIP_KIE:-0} == 1 ]] && exit 0
out=$(npx -y velsvisual credits --json 2>&1)
credits=$(echo "$out" | sed -n 's/.*"credits": *\([0-9.]*\).*/\1/p' | head -1)
if [[ -z $credits ]]; then
  echo "KIE недоступен: $(echo "$out" | tail -2)"
  echo "Настройка ключа: npx -y velsvisual setup (или velsvisual config --set-key, ключ просит владелец)."
  exit 1
fi
echo "KIE — ок, баланс $credits кредитов"
