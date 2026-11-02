#!/usr/bin/env bash
# 用法: auto-commit-push.sh <task-id> [message]
set -euo pipefail; source "$(dirname "$0")/_lib.sh"
id=${1:?用法: auto-commit-push.sh <task-id> [message]}; d=$(tdir "$id")
msg=${2:-"ds-gpt-gate: accept $id"}; wd=$(jget "$d" '.workdir // empty')
[[ -n $wd && -d $wd ]] || die "state.workdir 无效: '$wd'"
rec="$d/gates/$(date +%Y%m%d-%H%M%S)-autopush.md"; mkdir -p "$d/gates"
log(){ echo "$*"; echo "- $*" >>"$rec"; }
echo "# Auto commit/push — $(now)" >"$rec"
git -C "$wd" rev-parse --is-inside-work-tree >/dev/null 2>&1 || { log "失败: $wd 不是 git 仓（先运行 scripts/git-init-project.sh $wd <url>）"; exit 2; }
git -C "$wd" remote get-url origin >/dev/null 2>&1 || { log "失败: $wd 没有 origin remote（git -C $wd remote add origin <url>）"; exit 3; }
if [[ -z $(git -C "$wd" status --porcelain) ]]; then log "无变更，跳过提交（成功）"; exit 0; fi
git -C "$wd" add -A
bad=$(git -C "$wd" diff --cached --name-only | grep -Ei '(^|/)\.env($|\.)|\.pem$|\.key$|\.p12$|credential|secret|token|api[_-]?key|(^|/)\.dsh/|(^|/)\.codex/|id_rsa|id_ed25519|\.bak$' || true)
if [[ -n $bad ]]; then git -C "$wd" reset -q; log "中止: 暂存区含疑似隐私文件，已取消暂存:"; echo "$bad" | sed 's/^/    /' | tee -a "$rec" >&2; exit 4; fi
# 内容扫描：常见密钥形态
if git -C "$wd" diff --cached -U0 | grep -E '^\+' | grep -Eq 'sk-[A-Za-z0-9]{20,}|ghp_[A-Za-z0-9]{30,}|github_pat_|AKIA[0-9A-Z]{16}|-----BEGIN [A-Z ]*PRIVATE KEY'; then
  git -C "$wd" reset -q; log "中止: 暂存 diff 中检测到疑似 API key/私钥"; exit 5; fi
git -C "$wd" config user.email >/dev/null || { git -C "$wd" config user.email ds-gpt-gate@local; git -C "$wd" config user.name ds-gpt-gate; }
git -C "$wd" commit -q -m "$msg"; sha=$(git -C "$wd" rev-parse --short HEAD); br=$(git -C "$wd" rev-parse --abbrev-ref HEAD)
log "已提交 $sha ($br): $msg"
if git -C "$wd" push -u origin HEAD 2>>"$rec"; then log "已推送 origin/$br"; else log "失败: push 失败（见上方输出）"; exit 6; fi
if [[ -f $d/HANDOFF.md ]]; then printf '\n## Auto push %s\n- %s %s -> origin/%s\n' "$(now)" "$sha" "$msg" "$br" >>"$d/HANDOFF.md"; fi
exit 0
