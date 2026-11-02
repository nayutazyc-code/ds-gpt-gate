# ds-gpt-gate — DeepSeek 执行 + GPT 三节点把关

**绝对路径：`/home/box/workflows/ds-gpt-gate/`**

快速开始：
```bash
cd /home/box/workflows/ds-gpt-gate
id=$(scripts/new-task.sh my-feature /path/to/any/git/workdir)   # 建任务
scripts/run-role.sh $id architect --run                         # Architect 出草案（写入 workdir/plan.md 或 HANDOFF 计划段）
scripts/gate.sh $id planning && scripts/run-role.sh $id reviewer --run   # 规划门禁：小co 审查
scripts/handoff.sh $id reviewer executor "通过" && scripts/run-role.sh $id executor --run  # 大肥鱼 headless 全自动执行
scripts/gate.sh $id acceptance && scripts/status.sh $id         # 验收门禁 + 查看状态
```

## 角色表
| 角色 | 实体 | 工具 | 权限 | 何时 |
|---|---|---|---|---|
| executor | 大肥鱼（DeepSeek，dsh preset `dafeiyu`） | `dsh --profile headless`（全自动；降级可手动 `dsh web`） | 可写 | 主会话与写代码，全程 |
| reviewer | 小co（`~/.codex/agents/xiao-co.toml`） | codex | workspace-write（仅验收核对用） | 仅三节点 |
| architect | Architect（`architect.toml`） | codex | read-only | 出草案；巡检 ≤200 字 |
| explorer | Explorer（`explorer.toml`） | codex | read-only | 可选：代码定位 |
| researcher | Researcher（`researcher.toml`） | codex | read-only | 可选：文档检索 |

## 三节点规则
- GPT 侧只在 **planning（规划前）/ error（报错重现）/ acceptance（最终验收前）** 介入。
- 每次 `gate.sh` 计 1 次，**单任务审查严格 ≤3 次**（state.json `max_reviews`），用尽后 gate 直接失败。
- 审查者/架构师**只看瘦身包** `tasks/<id>/GATE_PACKET.md`：计划草案 + Git Diff + 报错日志（均截断），禁止整仓上下文。
- Architect 巡检输出 ≤200 字：判断（继续/修改/停止）+ 三大风险（见 `templates/ARCHITECT_REVIEW.md`）。
- 小co 输出：通过 / 需改 / 阻断 + 要点 + 风险。

## 完整回路示例
1. `new-task.sh` → Architect 出计划草案（`run-role.sh $id architect`）
2. `gate.sh $id planning` → 小co/Architect 审查（第 1 次）→ `handoff.sh $id reviewer executor "通过"`
3. 大肥鱼执行（`run-role.sh $id executor --run`，headless 全自动，按 HANDOFF.md 推进）；可选 `run-role.sh $id explorer|researcher`
4. 出错：把日志放到 workdir 的 `error.log` 或 `logs/error*` → `gate.sh $id error`（第 2 次）→ 回到执行
5. `gate.sh $id acceptance`（第 3 次）→ 通过后 `handoff.sh $id reviewer done`

## 脚本
- `new-task.sh <name> [workdir] [architect|executor]` 建 `tasks/<slug>/`（state.json + HANDOFF.md）
- `slim-context.sh <id>` 生成 GATE_PACKET.md
- `gate.sh <id> planning|error|acceptance` 计数 + `gates/<ts>-<type>.md` 记录 + 生成瘦身包
- `handoff.sh <id> <from> <to> [note]` 追加交接，切换 next_role/phase（to 可为 done）
- `status.sh [id]` 状态（无参列出全部任务）
- `run-role.sh <id> <role> [--run]` 默认打印命令；`--run` 自动调起：codex 角色走 `codex exec -s <sandbox> -C <workdir> -o tasks/<id>/out-<role>-*.md`，把 agent TOML 的 developer_instructions + 瘦身包/HANDOFF 作为 prompt；executor 走 headless 全自动：`cd <workdir> && DSH_TOOLS_MODE=native dsh --profile headless --patch agents/dafeiyu-headless.patch.yml - < prompt-executor.txt`，stdout 存为 `out-executor-<ts>.md`、stderr 存 `err-executor-<ts>.log`，透传退出码。密钥由 patch 重新启用的本地 credentials 服务提供；若报 MISSING_CREDENTIAL 会自动用 `ensure_deepseek_key` 临时注入环境变量重试（可用 `DSH_INJECT_KEY=1` 强制），密钥不落盘、不回显。只想用 UI 时可手动 `dsh web` 选「大肥鱼」。

`agents/` 存 TOML 副本与改造前备份（`*.orig.bak`）；实际生效位置为 `~/.codex/agents/`。

## Git / GitHub
- **gitignore 原则**：`.env*`、`*.pem`/`*.key`、`*credentials*`/`*secret*`/`*token*`、`.dsh/`、`.codex/`、`*.bak`/`agents/*.orig.bak`、`tasks/**` 运行态（保留 `tasks/.gitkeep`）、`node_modules/` 等一律不提交。`~/.dsh/.credentials.yaml` 绝不拷进仓。
- **初始化项目仓**：`scripts/git-init-project.sh <workdir> [remote-url]` —— 必要时 `git init`，合并 `templates/project.gitignore`，可选设置 `origin`。
- **设置 remote**：`git -C <workdir> remote add origin git@github.com:<user>/<repo>.git`（或用上面脚本第二参数）。可在 `config.yaml` 的 `github.repo` 记录。
- **验收自动推送**：`gate.sh <id> acceptance` 在登记成功后，若 `DS_GPT_GATE_AUTO_PUSH=1` 或 `config.yaml` 中 `auto_push_on_acceptance: true`（默认），调用 `scripts/auto-commit-push.sh <id>`：无变更跳过；`git add -A` 后扫描暂存区路径与 diff 内容，命中密钥模式即中止；提交信息默认 `ds-gpt-gate: accept <id>`，`git push -u origin HEAD`；结果写入 `tasks/<id>/gates/*-autopush.md` 与 HANDOFF。无 git 仓或无 origin 会明确失败（非0）。`DS_GPT_GATE_AUTO_PUSH=0` 关闭。
