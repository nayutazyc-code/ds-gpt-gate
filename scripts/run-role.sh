#!/usr/bin/env bash
# 默认只打印命令；加 --run 才真正调起（会消耗模型额度）
set -euo pipefail; source "$(dirname "$0")/_lib.sh"
RUN=0; args=(); for a in "$@"; do [[ $a == --run ]] && RUN=1 || args+=("$a"); done
set -- "${args[@]}"; [[ $# -ge 2 ]] || die "用法: run-role.sh <task-id> <executor|reviewer|explorer|researcher|architect> [--run]"
d=$(tdir "$1"); role=$2; wd=$(jget "$d" .workdir)
CODEX=$(command -v codex || echo /home/box/.local/bin/codex); DSH=$(command -v dsh || echo /home/box/.local/bin/dsh)
if [[ $role == executor ]]; then
  patch="$ROOT/agents/dafeiyu-headless.patch.yml"; ts=$(date +%H%M%S)
  out="$d/out-executor-$ts.md"; ev="$d/out-executor-$ts.jsonl"; pf="$d/prompt-executor.txt"
  cat >"$pf" <<EOT
你是大肥鱼（ds-gpt-gate 执行者），以无人值守方式运行。
请阅读并执行 $d/HANDOFF.md 中的任务；工作区即当前目录 $wd。
遇三节点门禁（规划前/报错重现/最终验收）时停下并说明原因。
完成后用几句话简述改了什么、如何验证（该回复会被保存为 $out）。
EOT
  echo "执行者=大肥鱼(dsh headless 全自动)。命令："
  echo "  cd $wd && DSH_TOOLS_MODE=native $DSH --profile headless --patch $patch - < $pf > $out"
  echo "  (降级：若只想用 UI，可手动 cd $wd && $DSH web 后选「大肥鱼」)"
  [[ $RUN = 1 ]] || { echo "(加 --run 自动执行)"; exit 0; }
  cd "$wd"; export DSH_TOOLS_MODE=native
  # 优先靠 patch 启用的 credentials 服务；DSH_INJECT_KEY=1 时额外临时注入环境变量（不落盘）
  [[ ${DSH_INJECT_KEY:-0} = 1 ]] && { ensure_deepseek_key || die "无法载入 DEEPSEEK_API_KEY"; }
  set +e; "$DSH" --profile headless --patch "$patch" ${DSH_JSON:+--json} - <"$pf" >"$out" 2>"$d/err-executor-$ts.log"; rc=$?; set -e
  if [[ $rc != 0 ]] && grep -q MISSING_CREDENTIAL "$d/err-executor-$ts.log" "$out" 2>/dev/null && [[ ${DSH_INJECT_KEY:-0} != 1 ]]; then
    echo "credentials 服务未提供密钥，改用临时环境变量注入重试…" >&2
    ensure_deepseek_key || die "无法载入 DEEPSEEK_API_KEY"
    set +e; "$DSH" --profile headless --patch "$patch" - <"$pf" >"$out" 2>"$d/err-executor-$ts.log"; rc=$?; set -e
  fi
  echo "输出: $out (stderr: $d/err-executor-$ts.log, exit=$rc)"; exit $rc
fi
case $role in reviewer) ag=xiao-co; sb=workspace-write;; explorer|researcher|architect) ag=$role; sb=read-only;; *) die "未知角色: $role";; esac
toml=~/.codex/agents/$ag.toml; [[ -f $toml ]] || die "缺少 $toml"
pf="$d/prompt-$role.txt"
{ python3 -c "import tomllib,sys;print(tomllib.load(open(sys.argv[1],'rb'))['developer_instructions'])" "$toml"
  echo "---"; case $role in
   reviewer|architect) echo "请只基于以下瘦身包审查（不要读取全仓）："; cat "$d/GATE_PACKET.md" 2>/dev/null || echo "(先运行 gate.sh 生成 GATE_PACKET)";;
   *) echo "任务背景见 HANDOFF："; cat "$d/HANDOFF.md";; esac; } >"$pf"
out="$d/out-$role-$(date +%H%M%S).md"
cmd=("$CODEX" exec -s "$sb" --skip-git-repo-check -C "$wd" -o "$out" -)
echo "命令: ${cmd[*]} < $pf"
if [[ $RUN = 1 ]]; then "${cmd[@]}" <"$pf"; echo "输出: $out"; else echo "(加 --run 自动执行；或交互: cd $wd && $CODEX 后 @$ag 子代理)"; fi
