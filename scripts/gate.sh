#!/usr/bin/env bash
set -euo pipefail; source "$(dirname "$0")/_lib.sh"
id=${1:?用法: gate.sh <task-id> planning|error|acceptance}; type=${2:?缺少门禁类型}
[[ $type =~ ^(planning|error|acceptance)$ ]] || die "门禁类型必须是 planning|error|acceptance"
d=$(tdir "$id"); used=$(jget "$d" .reviews_used); max=$(jget "$d" .max_reviews)
(( used < max )) || die "审查次数已用尽 ($used/$max)。不再触发 GPT 审查；由执行者自行收尾，或人工决定是否放行。"
ts=$(date +%Y%m%d-%H%M%S); n=$((used+1))
case $type in planning) who="architect + reviewer(小co)";; error) who="reviewer(小co)";; acceptance) who="reviewer(小co) + architect";; esac
pk=$("$ROOT/scripts/slim-context.sh" "$id")
jset "$d" --arg t "$type" --arg ts "$(now)" --arg f "gates/$ts-$type.md" \
  '.reviews_used+=1 | .phase=("gate:"+$t) | .next_role="reviewer" | .gates+=[{type:$t,ts:$ts,record:$f}]'
cat >"$d/gates/$ts-$type.md" <<R
# Gate $type — 第 $n/$max 次审查
- 时间: $(now)
- 审查者: $who
- 输入: $pk （仅瘦身包）

## 审查结论（填写）
结论：通过 / 需改 / 阻断
要点：
风险：
R
echo "门禁 $type 已登记: $n/$max  记录: $d/gates/$ts-$type.md"
echo "瘦身包: $pk"
echo "下一步: scripts/run-role.sh $id reviewer   # 小co"
[[ $type != error ]] && echo "        scripts/run-role.sh $id architect  # Architect ≤200字巡检"
echo "审查后: scripts/handoff.sh $id reviewer executor \"<结论>\""
# 验收自动提交推送
if [[ $type == acceptance ]]; then
  ap=${DS_GPT_GATE_AUTO_PUSH:-}
  [[ -z $ap ]] && grep -Eq '^auto_push_on_acceptance:[[:space:]]*true' "$ROOT/config.yaml" && ap=1
  if [[ $ap == 1 ]]; then echo "auto_push: 执行 auto-commit-push.sh"; "$ROOT/scripts/auto-commit-push.sh" "$id" || die "自动提交/推送失败（DS_GPT_GATE_AUTO_PUSH=0 可关闭）"; fi
fi
