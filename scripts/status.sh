#!/usr/bin/env bash
set -euo pipefail; source "$(dirname "$0")/_lib.sh"
if [[ $# -eq 0 ]]; then for s in "$TASKS"/*/state.json; do [[ -f $s ]] && jq -r '"\(.id)\t\(.phase)\treviews \(.reviews_used)/\(.max_reviews)\tnext=\(.next_role)"' "$s"; done; exit 0; fi
d=$(tdir "$1")
jq -r '"任务: \(.name) [\(.id)]\n工作区: \(.workdir)\n阶段: \(.phase)\n下一角色: \(.next_role)\n审查: reviews_used=\(.reviews_used) / max=\(.max_reviews)（剩余 \(.max_reviews-.reviews_used)）\n门禁记录:" , (.gates[] | "  - \(.ts) \(.type) → \(.record)")' "$d/state.json"
echo "最近交接:"; grep -E '^- .*→' "$d/HANDOFF.md" | tail -3 || echo "  (无)"
