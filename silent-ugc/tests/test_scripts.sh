#!/bin/bash
# Тесты локальных скриптов silent-ugc (ffmpeg). Запуск: bash tests/test_scripts.sh
# Сеть и кредиты KIE не нужны: проверка KIE в check_env отключается SKIP_KIE=1.
set -u
export PATH="$HOME/.local/bin:$PATH"
SD="$(cd "$(dirname "$0")/.." && pwd)/scripts"
pass=0; fail=0
check() { if eval "$2"; then pass=$((pass+1)); echo "  ok   $1"; else fail=$((fail+1)); echo "  FAIL $1"; fi; }
dur()   { ffprobe -v error -show_entries format=duration -of csv=p=0 "$1" 2>/dev/null; }
near()  { python3 -c "import sys; sys.exit(0 if abs(float('${1:-0}' or 0)-$2)<=$3 else 1)" 2>/dev/null; }
streams() { ffprobe -v error -show_entries stream=codec_type -of csv=p=0 "$1" 2>/dev/null | sort -u | tr '\n' ' '; }
wh()    { ffprobe -v error -select_streams v:0 -show_entries stream=width,height -of csv=p=0:s=x "$1" 2>/dev/null; }
fps()   { ffprobe -v error -select_streams v:0 -show_entries stream=r_frame_rate -of csv=p=0 "$1" 2>/dev/null; }
# средняя яркость центральной полосы кадра на секунде $2
luma()  { ffmpeg -v error -ss "$2" -i "$1" -frames:v 1 -vf "crop=iw:ih/5:0:ih*2/5,scale=1:1,format=gray" -f rawvideo - 2>/dev/null | od -An -tu1 | tr -d ' '; }

# последний кадр красный? (R>150, B<100)
is_red_last() { local rgb; rgb=$(ffmpeg -v error -sseof -0.05 -i "$1" -frames:v 1 -vf scale=1:1,format=rgb24 -f rawvideo - 2>/dev/null | od -An -tu1); set -- $rgb; [[ -n ${1:-} && $1 -gt 150 && $3 -lt 100 ]]; }

T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
# фикстуры: 2 с красного + 2 с синего с тоном (хук со звуком); демо другого размера/fps со звуком
ffmpeg -v error -f lavfi -i "color=red:s=720x1280:r=30:d=2" -f lavfi -i "color=blue:s=720x1280:r=30:d=2" \
  -f lavfi -i "sine=f=440:d=4" -filter_complex "[0][1]concat=n=2:v=1:a=0[v]" -map "[v]" -map 2 -c:v libx264 -pix_fmt yuv420p -c:a aac -shortest $T/src.mp4
ffmpeg -v error -f lavfi -i "testsrc=s=886x1920:r=60:d=3" -f lavfi -i "sine=f=880:d=3" -c:v libx264 -pix_fmt yuv420p -c:a aac -shortest $T/demo.mp4
ffmpeg -v error -f lavfi -i "color=black:s=1080x1920:r=30:d=3" -c:v libx264 -pix_fmt yuv420p $T/black.mp4

echo "check_env.sh"
SKIP_KIE=1 bash $SD/check_env.sh >/dev/null 2>&1; rc=$?
check "C1 всё на месте — код 0" "[[ $rc == 0 ]]"
out=$(SKIP_KIE=1 PATH=/usr/bin:/bin bash $SD/check_env.sh 2>&1); rc=$?
check "C2 без ffmpeg/yt-dlp — код 1" "[[ $rc == 1 ]]"
check "C3 называет, чего нет" "[[ \"\$out\" == *ffmpeg* && \"\$out\" == *yt-dlp* ]]"

echo "scenes.sh"
out=$(bash $SD/scenes.sh $T/src.mp4 2>&1); rc=$?
check "S1 код 0" "[[ $rc == 0 ]]"
first=$(echo "$out" | awk 'NF>=2{print $1; exit}')
check "S2 находит склейку около 2.0 с" "near '$first' 2.0 0.1"
bash $SD/scenes.sh $T/nope.mp4 >/dev/null 2>&1; rc=$?
check "S3 нет файла — код 2" "[[ $rc == 2 ]]"

echo "cut.sh"
bash $SD/cut.sh $T/src.mp4 $T/hook.mp4 2.0 >/dev/null 2>&1; rc=$?
check "K1 код 0" "[[ $rc == 0 ]]"
check "K2 длительность 2.0 ± 0.1" "near '$(dur $T/hook.mp4)' 2.0 0.1"
check "K3 звука нет" "[[ \"$(streams $T/hook.mp4)\" == 'video ' ]]"
check "K4 по кадрам точно: последний кадр ещё красный" "is_red_last $T/hook.mp4"
bash $SD/cut.sh $T/src.mp4 $T/x.mp4 abc >/dev/null 2>&1; rc=$?
check "K5 секунды не число — код 2" "[[ $rc == 2 ]]"
bash $SD/cut.sh $T/nope.mp4 $T/x.mp4 1 >/dev/null 2>&1; rc=$?
check "K6 нет файла — код 2" "[[ $rc == 2 ]]"

echo "add_text.sh"
bash $SD/add_text.sh $T/black.mp4 $T/t1.mp4 "i'm 100%: shook, \"really\"|second line" center >/dev/null 2>&1; rc=$?
check "A1 спецсимволы ' % : \" — код 0" "[[ $rc == 0 ]]"
check "A2 длительность не изменилась" "near '$(dur $T/t1.mp4)' 3.0 0.1"
check "A3 в центре появился светлый текст" "[[ \$(luma $T/t1.mp4 1) -gt \$(( \$(luma $T/black.mp4 1) + 5 )) ]]"
bash $SD/add_text.sh $T/black.mp4 $T/t2.mp4 "мой тренер берёт 80\$|а это бесплатно" top >/dev/null 2>&1; rc=$?
check "A4 кириллица — код 0" "[[ $rc == 0 && -s $T/t2.mp4 ]]"
check "A5 top: центр кадра остался тёмным" "[[ -s $T/t2.mp4 && -n \$(luma $T/t2.mp4 1) ]] && [[ \$(luma $T/t2.mp4 1) -le \$(( \$(luma $T/black.mp4 1) + 5 )) ]]"
bash $SD/add_text.sh $T/black.mp4 $T/x.mp4 "" >/dev/null 2>&1; rc=$?
check "A6 пустой текст — код 2" "[[ $rc == 2 ]]"
bash $SD/add_text.sh $T/black.mp4 $T/x.mp4 "hi" left >/dev/null 2>&1; rc=$?
check "A7 неизвестная позиция — код 2" "[[ $rc == 2 ]]"

bash $SD/add_text.sh $T/black.mp4 $T/t3.mp4 "мой тренер берёт 80 долларов за то, что это приложение делает" center >/dev/null 2>&1; rc=$?
edge=$(ffmpeg -v error -ss 1 -i $T/t3.mp4 -frames:v 1 -vf "crop=iw*0.03:ih/20:0:ih*19/40,scale=1:1,format=gray" -f rawvideo - 2>/dev/null | od -An -tu1 | tr -d ' ')
check "A8 длинная строка не вылезает за поля (левые 3% кадра пустые)" "[[ $rc == 0 && -n '$edge' && '${edge:-999}' -le 5 ]]"

echo "stitch.sh"
bash $SD/stitch.sh $T/hook.mp4 $T/demo.mp4 $T/final.mp4 >/dev/null 2>&1; rc=$?
check "T1 код 0" "[[ $rc == 0 ]]"
check "T2 длительность = хук + демо (5.0 ± 0.2)" "near '$(dur $T/final.mp4)' 5.0 0.2"
check "T3 1080x1920" "[[ \"$(wh $T/final.mp4)\" == 1080x1920 ]]"
check "T4 30 fps" "[[ \"$(fps $T/final.mp4)\" == 30/1 ]]"
check "T5 без звука (у демо он был)" "[[ \"$(streams $T/final.mp4)\" == 'video ' ]]"
bash $SD/stitch.sh $T/hook.mp4 $T/nope.mp4 $T/x.mp4 >/dev/null 2>&1; rc=$?
check "T6 нет файла — код 2" "[[ $rc == 2 ]]"

echo
echo "итог: $pass ok, $fail fail"
[[ $fail == 0 ]]
