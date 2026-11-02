#!/usr/bin/env bash
set -euo pipefail; source "$(dirname "$0")/_lib.sh"
[[ $# -ge 3 ]] || die "用法: handoff.sh <task-id> <from> <to> [note]"
d=$(tdir "$1"); from=$2; to=$3; note=${4:-}
[[ $to =~ ^(executor|reviewer|explorer|researcher|architect|done)$ ]] || die "未知角色: $to"
case $to in executor) ph=executing;; architect) ph=designing;; reviewer) ph=reviewing;; explorer|researcher) ph=investigating;; done) ph=done;; esac
printf -- '- %s  **%s → %s**  %s\n' "$(now)" "$from" "$to" "$note" >>"$d/HANDOFF.md"
jset "$d" --arg r "$to" --arg p "$ph" '.next_role=$r | .phase=$p'
echo "交接: $from → $to (phase=$ph)"
