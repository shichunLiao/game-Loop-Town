# Loop Town / 回环镇 — Claude Code 工作约定

## 分工（硬性）
- **Claude Code**：逻辑、脚本、场景结构、关卡数据、文档；把完整可执行的美术需求交给 Codex。
- **Codex（插件 codex@openai-codex / companion task）**：游戏内一切美术——场景背景、角色立绘、Boss、UI、icon、动画帧、贴图。模型由 Claude 自行选择，不必问用户。
- **禁止**：Claude 自己画图；禁止用 PIL / generate_placeholder_art / generate_ai_mockups（Gemini）或任何脚本生成占位/替代美术。

## 当前目标
Demo 8 → Demo 9，依据 `docs/story-1.1.txt`（来自 `/Users/tsun/Downloads/剧情1.1.docx`）。
分支：`demo-9`（由既有 story-1.1 逻辑工作延续）。

## 委派 Codex 画图时
通过 Agent `codex:codex-rescue` 或 `node …/codex-companion.mjs task --write "…"`。
提示词须写明：输出路径、尺寸、透明要求、风格（与现有 gothic hand-inked 2D metroidvania 一致）、无 HUD/无文字。
