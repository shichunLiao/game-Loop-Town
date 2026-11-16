# Demo 9 任务 brief（Claude Code 执行）

## 目标
在分支 `demo-9` 上把回环镇从 Demo 8 收束为 Demo 9（剧情 1.1）。
工作目录：`/Users/tsun/Projects/game-Loop-Town`
剧本全文：`docs/story-1.1.txt`（必读）
现状：逻辑/文案/Boss 脚本大多已在本分支（见 `docs/exploration-demo/README-V9.md`）。**尚无新美术文件**（相对 main 无 png 变更）；Void/守钟人等仍复用旧素材。

## 硬性分工
1. **Claude**：逻辑、脚本接线、数据、文档、把美术需求写清楚并委派。
2. **Codex**：绘制全部新美术。用插件 `codex@openai-codex`（`codex:codex-rescue` / companion `task --write`）。**模型由你自选**，不必问用户。
3. **禁止**自己画或跑 `generate_*` / PIL / Gemini mockup 产图。

## 必做
A. 读完 `docs/story-1.1.txt` 与 `docs/exploration-demo/README-V9.md`，核对缺口。
B. **美术（一律 Codex）** — 至少产出并接入这些（路径可微调，但须写入仓库并改脚本引用）：
   - `assets/enemies/void_*`：沃伊德（右脸布料缝合、舞台丝线操控者）idle/attack 等必要帧
   - `assets/enemies/keeper_*`：守钟人剪影（宽檐帽、拧发条、五官不清）
   - `assets/enemies/fury_*`：弗瑞（霸凌少年）
   - `assets/enemies/ling_*`：玲（井底藤蔓/泥浆形态 + 角落真正的玲若需）
   - `assets/enemies/may_statue_*` 或更新梅·莫里：右脸黑印、美工刀、纯白雕像替身（若现有 morris_* 语义不符则新画并改引用）
   - 若剧本要求美术馆不再是蜡像馆氛围：委派 Codex 更新相关背景（museum / basement），风格延续 `docs/exploration-demo/ART_PROMPTS.md` 的 gothic hand-inked 规格（无人物、无 HUD、底部雾区）
C. 接线：改 `scripts/exploration` / data，使新 Boss 使用 Codex 新图，不再「暂用检票人/主角压暗」。
D. 文档：补 `docs/exploration-demo/v9-build-notes.md`；必要时微调 README-V9 标题为 Demo 9；根 README 注明剧情以 1.1 为准、世界版本 9。
E. 在 `docs/demo9-report.md` 写繁中摘要：
   1) 相对剧情1.1 的改动要点
   2) Codex 画的文件完整路径列表
   3) 分支名 + `git rev-parse HEAD`
F. `git add` 相关文件并 `git commit`（讯息清楚，如 `Demo 9: story 1.1 art via Codex + wiring`）。**不要 force-push**；未明确要求则先不 push。

## 不要做
- 不要删除 Demo 8 可用内容以外的大重构
- 不要提交任何 token / .env 密钥
- 不要用 danger/yolo 跑无关系统命令

## 完成标准
- demo-9 分支有 commit
- Codex 产出的 png（及 .import 若 Godot 需要）在树内
- demo9-report.md 存在且列出 Codex 路径
