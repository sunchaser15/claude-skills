#!/bin/bash
# Текст в стиле TikTok: белый жирный шрифт с чёрной обводкой, строки по центру, на всё видео.
# Использование: add_text.sh <вход> <выход> "<строка1|строка2>" [center|top] [размер_px]
# Строки разделяются «|». Любые символы (' " % : кириллица) безопасны: текст идёт через файл.
export PATH="$HOME/.local/bin:$PATH"
[[ $# -ge 3 ]] || { echo "Использование: $0 <вход> <выход> \"<текст>\" [center|top] [размер]" >&2; exit 2; }
in=$1; out=$2; text=$3; pos=${4:-center}
[[ -f $in ]] || { echo "Нет файла: $in" >&2; exit 2; }
[[ -n $text ]] || { echo "Пустой текст" >&2; exit 2; }
case $pos in center) y='(h-text_h)/2' ;; top) y='h*0.16' ;; *) echo "Позиция: center или top, не $pos" >&2; exit 2 ;; esac
font=/System/Library/Fonts/Supplemental/Arial\ Bold.ttf
[[ -f $font ]] || font=/Library/Fonts/Arial\ Bold.ttf
IFS=x read -r w h < <(ffprobe -v error -select_streams v:0 -show_entries stream=width,height -of csv=p=0:s=x "$in")
tf=$(mktemp); trap 'rm -f "$tf"' EXIT
# Строки длиннее 24 символов переносятся по словам; шрифт уменьшается, если строка всё равно шире 88% кадра
# (средняя ширина знака Arial Bold ≈ 0.56 кегля).
size=$(TEXT="$text" W=$w H=$h SIZE=${5:-} TF="$tf" python3 -c '
import os, textwrap
lines = [l for part in os.environ["TEXT"].split("|") for l in (textwrap.wrap(part.strip(), 24) or [""])]
open(os.environ["TF"], "w", encoding="utf-8").write("\n".join(lines))
w, h = int(os.environ["W"]), int(os.environ["H"])
size = int(os.environ["SIZE"] or h // 24)
longest = max(len(l) for l in lines) or 1
print(max(12, min(size, int(0.88 * w / (longest * 0.56)))))
')
ffmpeg -v error -y -i "$in" -map 0 -c:a copy -c:v libx264 -crf 18 -preset fast -pix_fmt yuv420p \
  -vf "drawtext=fontfile='$font':textfile='$tf':expansion=none:text_align=C:fontcolor=white:fontsize=$size:borderw=$(( size / 10 + 1 )):bordercolor=black:line_spacing=$(( size / 5 )):x=(w-text_w)/2:y=$y" \
  "$out" || exit 1
echo "$out"
