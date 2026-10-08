#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Распознавание аудио: m4a/mp3/wav/... -> текст с таймкодами.

ffmpeg не нужен: конвертация делается afconvert, он есть в macOS из коробки.
Декодирование WAV идёт через стандартный wave, поэтому mlx-whisper не зовёт
ffmpeg сам (иначе упал бы).

    python3 transcribe.py <аудио> <куда-без-расширения> [язык]

Создаёт три файла:
    <out>.txt         строки вида [чч:мм:сс] текст
    <out>.plain.txt   сплошной текст
    <out>.json        полный ответ модели (нужен, если захочется пересобрать)
"""
import json
import subprocess
import sys
import tempfile
import wave
from pathlib import Path

MODEL = "mlx-community/whisper-large-v3-turbo"


def to_wav(src: Path, dst: Path) -> None:
    """16 кГц моно 16 бит — то, что ждёт whisper."""
    subprocess.run(
        ["afconvert", "-f", "WAVE", "-d", "LEI16@16000", "-c", "1", str(src), str(dst)],
        check=True,
    )


def read_wav(path: Path):
    import numpy as np
    with wave.open(str(path), "rb") as w:
        assert w.getsampwidth() == 2 and w.getnchannels() == 1 and w.getframerate() == 16000
        raw = w.readframes(w.getnframes())
    return np.frombuffer(raw, dtype=np.int16).astype(np.float32) / 32768.0


def stamp(seconds: float) -> str:
    s = int(seconds)
    return f"{s // 3600:02d}:{(s % 3600) // 60:02d}:{s % 60:02d}"


def main() -> int:
    if len(sys.argv) < 3:
        print(__doc__, file=sys.stderr)
        return 2
    src, out = Path(sys.argv[1]), Path(sys.argv[2])
    language = sys.argv[3] if len(sys.argv) > 3 else "ru"

    import mlx_whisper

    with tempfile.TemporaryDirectory() as tmp:
        wav = Path(tmp) / "audio.wav"
        to_wav(src, wav)
        audio = read_wav(wav)
        print(f"длительность: {len(audio) / 16000 / 60:.1f} мин", flush=True)
        result = mlx_whisper.transcribe(
            audio,
            path_or_hf_repo=MODEL,
            language=language,
            task="transcribe",
            verbose=False,
            # Без этого модель на тихих участках зацикливается и дописывает
            # несуществующие фразы, подхватывая собственный предыдущий вывод.
            condition_on_previous_text=False,
            word_timestamps=False,
        )

    with open(f"{out}.txt", "w", encoding="utf-8") as f:
        for seg in result["segments"]:
            f.write(f"[{stamp(seg['start'])}] {seg['text'].strip()}\n")
    with open(f"{out}.plain.txt", "w", encoding="utf-8") as f:
        f.write(result["text"].strip() + "\n")
    with open(f"{out}.json", "w", encoding="utf-8") as f:
        json.dump(result, f, ensure_ascii=False)

    print(f"сегментов: {len(result['segments'])}", flush=True)
    return 0


if __name__ == "__main__":
    sys.exit(main())
