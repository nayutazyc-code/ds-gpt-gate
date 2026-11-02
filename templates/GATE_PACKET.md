# GATE_PACKET 说明（瘦身上下文包）
审查者只看本包，禁止全量仓库上下文。由 scripts/slim-context.sh 生成，仅含：
1. 计划草案：workdir 的 plan.md/PLAN.md 或 HANDOFF.md 的「计划」段（截断 120 行）
2. Git Diff：`git diff HEAD --stat` + `git diff HEAD`（截断 400 行；非 git 仓则为空）
3. 报错日志：error.log / logs/error* 末尾 120 行
