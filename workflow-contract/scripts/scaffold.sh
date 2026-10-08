#!/bin/bash
# Каркас нового проекта: папка, git, .gitignore под стек, README, CLAUDE.md, SPEC.md.
# Использование: scaffold.sh <путь-к-проекту> <python|node|web|swift|other>
# Повторный запуск безопасен: существующие файлы не перезаписываются.
set -euo pipefail

[[ $# -eq 2 ]] || { echo "Использование: $0 <путь> <python|node|web|swift|other>" >&2; exit 2; }
dir=$1; stack=$2
case $stack in python|node|web|swift|other) ;; *) echo "Неизвестный стек: $stack" >&2; exit 2;; esac

here=$(cd "$(dirname "$0")/.." && pwd)
name=$(basename "$dir")
[[ $name =~ ^[a-z0-9][a-z0-9-]*$ ]] || { echo "Имя '$name' должно быть латиницей в kebab-case" >&2; exit 2; }

mkdir -p "$dir"
cd "$dir"
[[ -d .git ]] || git init -q -b main

# write_if_absent <файл>  (содержимое из stdin)
write_if_absent() {
  if [[ -e $1 ]]; then cat >/dev/null; echo "  есть: $1"; else cat >"$1"; echo "  создан: $1"; fi
}

{
  cat <<'EOF'
# Секреты и локальные данные
.env
.env.*
!.env.example
*.db
*.sqlite
*.sqlite3
*.pem
*.key
secrets/

# Система и редакторы
.DS_Store
.idea/
.vscode/
*.log
EOF
  case $stack in
    python) printf '\n# Python\n__pycache__/\n*.py[cod]\n.venv/\n.pytest_cache/\n.ruff_cache/\n.mypy_cache/\n*.egg-info/\ndist/\nbuild/\n' ;;
    node|web) printf '\n# Node\nnode_modules/\ndist/\nbuild/\ncoverage/\n.vite/\n' ;;
    swift) printf '\n# Swift\n.build/\n.swiftpm/\nDerivedData/\n*.xcuserstate\nxcuserdata/\n*.app/\n' ;;
    other) ;;
  esac
} | write_if_absent .gitignore

printf '# %s\n\nСм. [SPEC.md](SPEC.md) — контракт проекта: цель, требования, как проверить.\n' "$name" \
  | write_if_absent README.md

cat <<'EOF' | write_if_absent CLAUDE.md
@SPEC.md

Проект ведётся по регламенту из ~/.claude/CLAUDE.md и скиллу /workflow-contract.
SPEC.md — утверждённый контракт: не менять без согласия владельца.

## Тесты
<!-- команда прогона, заполняется на этапе 3 -->
EOF

sed "s/__NAME__/$name/" "$here/templates/SPEC.md" | write_if_absent SPEC.md

echo "Каркас готов: $(pwd) (стек: $stack)"
