#!/bin/bash
# Изолированные рабочие копии для воркеров (режим оркестратора, этап 4).
#   worktree.sh add   <проект> <задача>           — ветка task/<задача> от main в <проект>.wt/<задача>, печатает путь
#   worktree.sh check <проект> <задача> <тесты>…  — всё закоммичено и тесты (пути) не тронуты относительно main
#   worktree.sh merge <проект> <задача>           — слить в main (--no-ff), удалить worktree и ветку
# Коды: 0 ок, 1 уже существует/нет такой задачи, 2 неверные аргументы,
#       3 тронуты тесты, 4 незакоммиченные изменения, 5 конфликт при слиянии.
set -uo pipefail

usage() { sed -n 2,7p "$0" | sed 's/^# \{0,1\}//' >&2; exit 2; }
[[ $# -ge 3 ]] || usage
cmd=$1; proj=$(cd "$2" 2>/dev/null && pwd) || { echo "Нет папки $2" >&2; exit 2; }; task=$3; shift 3
[[ $task =~ ^[a-z0-9][a-z0-9-]*$ ]] || { echo "Имя задачи '$task': латиница в kebab-case" >&2; exit 2; }
branch=task/$task
wt=$proj.wt/$task
g() { git -C "$proj" "$@"; }

case $cmd in
  add)
    if g rev-parse -q --verify "$branch" >/dev/null || [[ -e $wt ]]; then
      echo "Задача $task уже есть: $wt" >&2; exit 1
    fi
    mkdir -p "$proj.wt"
    g worktree add -q -b "$branch" "$wt" main || exit 1
    echo "$wt"
    ;;

  check)
    [[ $# -ge 1 ]] || usage
    [[ -d $wt ]] || { echo "Нет worktree $wt" >&2; exit 1; }
    dirty=$(git -C "$wt" status --porcelain)
    [[ -z $dirty ]] || { echo "Незакоммиченные изменения в $wt:"; echo "$dirty" | sed 's/^/  /'; exit 4; }
    touched=$(g diff --name-only "main...$branch" -- "$@")
    [[ -z $touched ]] || { echo "Воркер изменил тесты:"; echo "$touched" | sed 's/^/  /'; exit 3; }
    echo "ок: $branch закоммичен, тесты не тронуты ($(g rev-list --count "main..$branch") коммит(ов))"
    ;;

  merge)
    [[ -d $wt ]] || { echo "Нет worktree $wt" >&2; exit 1; }
    [[ $(g rev-parse --abbrev-ref HEAD) == main ]] || { echo "В $proj сейчас не main" >&2; exit 2; }
    if ! g merge --no-ff -q -m "merge: $task" "$branch" >/dev/null 2>&1; then
      echo "Конфликт при слиянии $branch, main оставлен в состоянии слияния. Файлы:"
      g diff --name-only --diff-filter=U | sed 's/^/  /'
      echo "Разреши, git commit, затем: git worktree remove $wt && git branch -d $branch"
      exit 5
    fi
    g worktree remove --force "$wt" && g branch -q -d "$branch"
    rmdir "$proj.wt" 2>/dev/null
    echo "влито: $branch → main ($(g rev-parse --short HEAD))"
    ;;

  *) usage ;;
esac
