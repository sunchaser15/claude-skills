#!/bin/bash
# Склейки в видео: печатает «секунда  оценка» для смен сцены с оценкой > порога (по умолчанию 0.3).
# Использование: scenes.sh <видео> [порог]
export PATH="$HOME/.local/bin:$PATH"
[[ -f ${1:-} ]] || { echo "Нет файла: ${1:-}" >&2; exit 2; }
ffmpeg -hide_banner -i "$1" -vf "select='gt(scene,${2:-0.3})',metadata=print" -an -f null - 2>&1 \
  | awk '/pts_time:/{match($0,/pts_time:[0-9.]+/); t=substr($0,RSTART+9,RLENGTH-9)} /lavfi.scene_score=/{split($0,a,"="); printf "%.3f  %.3f\n", t, a[2]}'
