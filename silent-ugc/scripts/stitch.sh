#!/bin/bash
# Хук + демо в один ролик 1080x1920, 30 fps, без звука. Разные размеры/fps входов приводятся к одному.
# Использование: stitch.sh <хук> <демо> <выход>
export PATH="$HOME/.local/bin:$PATH"
[[ $# -eq 3 ]] || { echo "Использование: $0 <хук> <демо> <выход>" >&2; exit 2; }
for f in "$1" "$2"; do [[ -f $f ]] || { echo "Нет файла: $f" >&2; exit 2; }; done
n='scale=1080:1920:force_original_aspect_ratio=decrease,pad=1080:1920:(ow-iw)/2:(oh-ih)/2:black,setsar=1,fps=30,format=yuv420p'
ffmpeg -v error -y -i "$1" -i "$2" \
  -filter_complex "[0:v]$n[a];[1:v]$n[b];[a][b]concat=n=2:v=1:a=0[v]" -map "[v]" -an \
  -c:v libx264 -crf 18 -preset fast -movflags +faststart "$3" || exit 1
echo "$3"
