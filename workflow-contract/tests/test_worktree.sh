#!/bin/bash
# Тесты scripts/worktree.sh. Запуск: bash tests/test_worktree.sh
set -u
WT="$(cd "$(dirname "$0")/.." && pwd)/scripts/worktree.sh"
pass=0; fail=0
ok()   { pass=$((pass+1)); echo "  ok   $1"; }
bad()  { fail=$((fail+1)); echo "  FAIL $1"; }
check() { if eval "$2"; then ok "$1"; else bad "$1"; fi; }

T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
P=$T/demo
mkdir -p $P/tests && cd $P && git init -q -b main
git config user.name t; git config user.email t@t
echo 'x' > a.txt; echo 'test' > tests/test_a.txt
git add -A && git commit -qm init

echo "add"
out=$(bash "$WT" add "$P" parser 2>&1); rc=$?
check "W1 add: код 0" "[[ $rc == 0 ]]"
check "W2 add: worktree в <проект>.wt/<задача>" "[[ -d $T/demo.wt/parser ]]"
check "W3 add: ветка task/parser" "git -C $P rev-parse -q --verify task/parser >/dev/null"
check "W4 add: печатает путь worktree" "[[ \"\$out\" == *'$T/demo.wt/parser'* ]]"
bash "$WT" add "$P" parser >/dev/null 2>&1; rc=$?
check "W5 add: повтор той же задачи — ошибка (код 1)" "[[ $rc == 1 ]]"
bash "$WT" add "$P" 'Bad Name' >/dev/null 2>&1; rc=$?
check "W6 add: плохое имя задачи — код 2" "[[ $rc == 2 ]]"

echo "check"
W=$T/demo.wt/parser
echo 'impl' > $W/parser.txt; git -C $W add -A; git -C $W commit -qm impl
bash "$WT" check "$P" parser tests >/dev/null 2>&1; rc=$?
check "W7 check: тесты не тронуты — код 0" "[[ $rc == 0 ]]"
echo 'hacked' > $W/tests/test_a.txt; git -C $W commit -qam hack
out=$(bash "$WT" check "$P" parser tests 2>&1); rc=$?
check "W8 check: тронут тест — код 3" "[[ $rc == 3 ]]"
check "W9 check: называет изменённый файл" "[[ \"\$out\" == *tests/test_a.txt* ]]"
git -C $W reset -q --hard HEAD~1
echo 'dirty' > $W/uncommitted.txt
bash "$WT" check "$P" parser tests >/dev/null 2>&1; rc=$?
check "W10 check: незакоммиченные изменения — код 4" "[[ $rc == 4 ]]"
rm $W/uncommitted.txt

echo "merge"
had=$([[ -d $T/demo.wt/parser ]] && git -C $P rev-parse -q --verify task/parser >/dev/null && echo yes)
out=$(bash "$WT" merge "$P" parser 2>&1); rc=$?
check "W11 merge: код 0" "[[ $rc == 0 ]]"
check "W12 merge: файл воркера в main" "[[ -f $P/parser.txt ]]"
check "W13 merge: merge-коммит (--no-ff)" "[[ \$(git -C $P log -1 --format=%p | wc -w) -eq 2 ]]"
check "W14 merge: worktree удалён" "[[ \$had == yes && $rc == 0 && ! -d $T/demo.wt/parser ]]"
check "W15 merge: ветка удалена" "[[ \$had == yes && $rc == 0 ]] && ! git -C $P rev-parse -q --verify task/parser >/dev/null"

echo "merge с конфликтом"
bash "$WT" add "$P" conflict >/dev/null 2>&1
W=$T/demo.wt/conflict
echo 'from worker' > $W/a.txt; git -C $W commit -qam w
echo 'from main' > $P/a.txt; git -C $P commit -qam m
out=$(bash "$WT" merge "$P" conflict 2>&1); rc=$?
check "W16 merge: конфликт — код 5" "[[ $rc == 5 ]]"
check "W17 merge: конфликт — main остаётся в состоянии слияния для разбора" "[[ -f $P/.git/MERGE_HEAD ]]"
check "W18 merge: конфликт — worktree не удалён" "[[ -d $T/demo.wt/conflict ]]"
check "W19 merge: называет конфликтный файл" "[[ \"\$out\" == *a.txt* ]]"

echo
echo "итог: $pass ok, $fail fail"
[[ $fail == 0 ]]
