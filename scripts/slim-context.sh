#!/usr/bin/env bash
set -euo pipefail; source "$(dirname "$0")/_lib.sh"
d=$(tdir "${1:?用法: slim-context.sh <task-id>}"); wd=$(jget "$d" .workdir); out="$d/GATE_PACKET.md"
{
echo "# GATE_PACKET — $(jget "$d" .id)  ($(now))"
echo "phase=$(jget "$d" .phase) reviews_used=$(jget "$d" .reviews_used)/$(jget "$d" .max_reviews)"
echo; echo "## 1. 计划草案"
pf=""; for f in plan.md PLAN.md docs/plan.md; do [[ -f "$wd/$f" ]] && { pf="$wd/$f"; break; }; done
if [[ -n $pf ]]; then echo "_来源: ${pf}_"; head -n 120 "$pf"
else echo "_来源: HANDOFF.md 计划段_"; awk '/^## 计划/{f=1;next} /^## /{f=0} f' "$d/HANDOFF.md" | head -n 120; fi
echo; echo "## 2. Git Diff"
if git -C "$wd" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  base=HEAD; git -C "$wd" rev-parse -q --verify HEAD >/dev/null || base=$(git hash-object -t tree /dev/null)
  echo '```'; git -C "$wd" diff "$base" --stat; echo '```'; echo '```diff'
  git -C "$wd" diff "$base" | head -n 400; echo '```'
  echo "_未跟踪文件:_ $(git -C "$wd" ls-files --others --exclude-standard | head -20 | tr '\n' ' ')"
else echo "(非 git 仓，无 diff)"; fi
echo; echo "## 3. 报错日志"
found=0; shopt -s nullglob
for f in "$wd"/error.log "$wd"/logs/error* "$d"/error.log; do [[ -f $f ]] || continue; found=1; echo "### $f"; echo '```'; tail -n 120 "$f"; echo '```'; done
[[ $found = 1 ]] || echo "(无)"
} >"$out"
echo "$out"
