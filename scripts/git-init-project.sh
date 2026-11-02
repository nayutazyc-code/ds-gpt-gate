#!/usr/bin/env bash
# 用法: git-init-project.sh <workdir> [remote-url]
set -euo pipefail; source "$(dirname "$0")/_lib.sh"
wd=${1:?用法: git-init-project.sh <workdir> [remote-url]}; url=${2:-}
mkdir -p "$wd"; cd "$wd"
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || { git init -q; echo "已 git init: $wd"; }
tpl="$ROOT/templates/project.gitignore"; touch .gitignore; added=0
while IFS= read -r l; do [[ -z $l || $l == \#* ]] && continue
  grep -qxF -- "$l" .gitignore || { echo "$l" >>.gitignore; added=$((added+1)); }; done <"$tpl"
echo ".gitignore 合并新增 $added 条"
if ! git config user.email >/dev/null; then git config user.email ds-gpt-gate@local; git config user.name ds-gpt-gate; echo "已为本仓设置本地作者 ds-gpt-gate"; fi
if [[ -n $url ]]; then
  if git remote get-url origin >/dev/null 2>&1; then git remote set-url origin "$url"; else git remote add origin "$url"; fi
  echo "origin -> $url"
else git remote get-url origin >/dev/null 2>&1 || echo "提示: 尚无 origin；验收自动推送前请: git -C $wd remote add origin <url>"; fi
