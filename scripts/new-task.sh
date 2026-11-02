#!/usr/bin/env bash
set -euo pipefail; source "$(dirname "$0")/_lib.sh"
[[ $# -ge 1 ]] || die "用法: new-task.sh <name> [workdir] [architect|executor]"
name=$1; wd=$(realpath -m "${2:-$PWD}"); next=${3:-architect}
slug=$(echo "$name" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9]+/-/g;s/^-|-$//g'); [[ -n $slug ]] || slug="task"
slug="$slug-$(date +%m%d%H%M%S)"; d="$TASKS/$slug"; mkdir -p "$d/gates"
jq -n --arg id "$slug" --arg n "$name" --arg w "$wd" --arg r "$next" --arg ts "$(now)" \
 '{id:$id,name:$n,workdir:$w,reviews_used:0,max_reviews:3,phase:"init",gates:[],next_role:$r,created:$ts}' >"$d/state.json"
sed -e "s|{{NAME}}|$name|;s|{{ID}}|$slug|;s|{{WORKDIR}}|$wd|;s|{{TS}}|$(now)|" "$ROOT/templates/HANDOFF.md" >"$d/HANDOFF.md"
echo "$slug"; echo "已创建 $d （next_role=$next）" >&2
