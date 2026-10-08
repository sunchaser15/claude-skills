#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Применение правок к транскрипту — с защитой от съезда на соседнюю строку.

Зачем это вообще нужно. Правки удобно писать словарём «таймкод -> новый
текст», но применять их по таймкоду в лоб нельзя:

  * таймкоды повторяются (две реплики в одну секунду — обычное дело);
  * при наборе словаря легко взять таймкод соседней строки, и тогда правка
    молча затирает не ту реплику. На часовой лекции такое смещение
    обнаруживается только вычиткой результата целиком.

Поэтому каждая правка сажается не туда, куда указывает таймкод, а туда, где
в окне +-4 строки исходный текст максимально похож на новый. Правка вида
«[неразборчиво]» сажается строго по таймкоду: сравнивать там не с чем.

Скрипт сам сообщает о правках, которым не нашлось похожей строки (порог 0.30)
и о двух правках, претендующих на одну строку. И то и другое — почти всегда
ошибка в словаре, а не в тексте.

Когда лектор диктует под запись, соседние строки почти одинаковы, и поиск по
похожести честно не может их различить. На такой случай есть «!» в конце
ключа: правка садится строго по таймкоду, без поиска.

    python3 apply_fixes.py <исходный.txt> <fixes1.py> [fixes2.py ...] -o <результат.txt>

Файл правок — обычный python со словарём FIXES:

    FIXES = {
        "00:12:30": "Исправленная реплика.",
        "00:12:30.1": "Вторая реплика с тем же таймкодом.",
        "00:12:34": "[неразборчиво]",
        "00:12:38!": "Прибита к таймкоду, поиск похожей строки не ведётся.",
    }
"""
import argparse
import collections
import difflib
import re
import sys
from pathlib import Path

UNCLEAR = "[неразборчиво]"
LINE = re.compile(r"^\[(\d\d:\d\d:\d\d)\]\s*(.*)$")
WINDOW = 4
MIN_SIMILARITY = 0.30


def load_fixes(paths):
    fixes = {}
    for path in paths:
        namespace = {}
        exec(Path(path).read_text(encoding="utf-8"), namespace)
        found = namespace.get("FIXES")
        if not isinstance(found, dict):
            sys.exit(f"{path}: нет словаря FIXES")
        fixes.update(found)
    return fixes


def similarity(a: str, b: str) -> float:
    return difflib.SequenceMatcher(None, a.lower(), b.lower()).ratio()


def main() -> int:
    parser = argparse.ArgumentParser(add_help=True)
    parser.add_argument("transcript")
    parser.add_argument("fixes", nargs="+")
    parser.add_argument("-o", "--out", required=True)
    args = parser.parse_args()

    raw = Path(args.transcript).read_text(encoding="utf-8").splitlines()
    parsed = []
    for number, line in enumerate(raw, 1):
        match = LINE.match(line)
        if not match:
            sys.exit(f"строка {number} не похожа на «[чч:мм:сс] текст»: {line[:60]}")
        parsed.append(match.groups())

    # Ключ -> позиция. Повторный таймкод адресуется суффиксом .1, .2, ...
    seen = collections.Counter()
    position_of = {}
    for index, (tc, _) in enumerate(parsed):
        n = seen[tc]
        seen[tc] += 1
        position_of[tc if n == 0 else f"{tc}.{n}"] = index

    fixes = load_fixes(args.fixes)
    placed, weak, collisions, orphans = {}, [], [], []

    for key, new in fixes.items():
        pinned = key.endswith("!")
        lookup = key[:-1] if pinned else key
        if lookup not in position_of:
            orphans.append(key)
            continue
        anchor = position_of[lookup]
        if pinned or new.strip() == UNCLEAR:
            target, score = anchor, 1.0
        else:
            lo, hi = max(0, anchor - WINDOW), min(len(parsed), anchor + WINDOW + 1)
            score, target = max((similarity(parsed[i][1], new), i) for i in range(lo, hi))
            if score < MIN_SIMILARITY:
                weak.append((key, target, score, parsed[target][1], new))
        if target in placed and placed[target] != new:
            collisions.append((key, target, placed[target], new))
        placed[target] = new

    out = [f"[{tc}] {placed.get(i, text)}" for i, (tc, text) in enumerate(parsed)]
    Path(args.out).write_text("\n".join(out) + "\n", encoding="utf-8")

    unchanged = sum(1 for i in range(len(parsed)) if i not in placed)
    print(f"строк {len(parsed)}, правок применено {len(placed)}, не тронуто {unchanged}")
    if orphans:
        print(f"\nКЛЮЧИ БЕЗ СТРОКИ ({len(orphans)}): {', '.join(orphans[:10])}")
    if collisions:
        print(f"\nКОЛЛИЗИИ ({len(collisions)}) — две правки на одну строку:")
        for key, target, a, b in collisions[:10]:
            print(f"  L{target + 1} key={key}\n    A: {a[:80]}\n    B: {b[:80]}")
    if weak:
        print(f"\nСЛАБЫЕ СОВПАДЕНИЯ ({len(weak)}) — проверь, та ли это строка:")
        for key, target, score, old, new in weak[:10]:
            print(f"  {score:.2f} key={key} L{target + 1}\n    БЫЛО: {old[:80]}\n    СТАЛО: {new[:80]}")
    if not (orphans or collisions or weak):
        print("проблем не найдено")
    return 1 if (orphans or collisions or weak) else 0


if __name__ == "__main__":
    sys.exit(main())
