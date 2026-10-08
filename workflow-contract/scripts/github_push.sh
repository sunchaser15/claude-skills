#!/bin/bash
# Создаёт ПРИВАТНЫЙ репо sunchaser15/<имя папки> (если его нет) и пушит main.
# Перед пушем ищет секреты в новых коммитах и отслеживаемых файлах.
# Использование: github_push.sh <путь-к-проекту>
# DRY_RUN=1 — только проверки, без обращения к GitHub.
set -uo pipefail

[[ $# -eq 1 ]] || { echo "Использование: $0 <путь>" >&2; exit 2; }
cd "$1" || exit 2
git rev-parse --verify -q HEAD >/dev/null || { echo "Нет ни одного коммита — сначала git commit" >&2; exit 2; }
name=$(basename "$(pwd)")

# --- 1. Поиск секретов -------------------------------------------------------
if git rev-parse --verify -q origin/main >/dev/null; then range="origin/main..HEAD"; else range="HEAD"; fi

bad_files=$(git ls-files | grep -E '(^|/)(\.env(\..*)?|.*\.(db|sqlite3?|pem|key))$' | grep -v '\.env\.example$' || true)
patterns='[0-9]{8,10}:AA[A-Za-z0-9_-]{30,}|sk-[A-Za-z0-9_-]{20,}|gsk_[A-Za-z0-9]{20,}|gh[pousr]_[A-Za-z0-9]{30,}|AKIA[0-9A-Z]{16}|-----BEGIN [A-Z ]*PRIVATE KEY-----|xox[abp]-[A-Za-z0-9-]{10,}'
hits=$(git log -p --format= $range | grep -E '^\+' | grep -E "$patterns" || true)

if [[ -n $bad_files || -n $hits ]]; then
  echo "ОСТАНОВКА: похоже на секреты, не пушу."
  [[ -n $bad_files ]] && { echo "Файлы, которых не должно быть в git:"; echo "$bad_files" | sed 's/^/  /'; }
  [[ -n $hits ]] && { echo "Строки (значения обрезаны):"; echo "$hits" | cut -c1-24 | sed 's/$/…/; s/^/  /'; }
  exit 3
fi
echo "Секретов не найдено ($range)."

if [[ ${DRY_RUN:-0} == 1 ]]; then echo "DRY_RUN: GitHub не трогаю. Пушил бы в sunchaser15/$name (private)."; exit 0; fi

# --- 2. Репозиторий ----------------------------------------------------------
GH=$(command -v gh || echo "$HOME/.local/bin/gh")
"$GH" auth status >/dev/null 2>&1 || { echo "gh не залогинен: gh auth login --web" >&2; exit 4; }
owner=$("$GH" api user --jq .login)

if ! "$GH" repo view "$owner/$name" >/dev/null 2>&1; then
  "$GH" repo create "$owner/$name" --private --description "$name" >/dev/null || { echo "Не удалось создать репо (лимит GitHub? подожди 10–15 мин)" >&2; exit 4; }
  echo "Создан приватный репо $owner/$name"
fi
vis=$("$GH" repo view "$owner/$name" --json visibility --jq .visibility)
[[ $vis == PRIVATE ]] || { echo "ОСТАНОВКА: $owner/$name не приватный ($vis), не пушу" >&2; exit 5; }

"$GH" auth setup-git >/dev/null 2>&1
url="https://github.com/$owner/$name.git"
git remote get-url origin >/dev/null 2>&1 && git remote set-url origin "$url" || git remote add origin "$url"
git push -u origin main || exit 6
echo "Выгружено: https://github.com/$owner/$name (private), $(git rev-parse --short HEAD)"
