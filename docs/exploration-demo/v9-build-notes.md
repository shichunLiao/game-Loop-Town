# Demo 9 构建记录

日期：2026-11-08。引擎：Godot 4.6.2（本机 macOS），OpenGL Compatibility。分支：`demo-9`。
剧情依据：`docs/story-1.1.txt`（《剧情 1.1》）。world 版本 9。

## 分工

- 美术：全部由 Codex（`codex@openai-codex` companion `task --write`，模型 `gpt-6.1-sol`，effort medium）用内置 image_gen 绘制，分五批并行：梅·莫里、沃伊德、守钟人与弗瑞、玲、美术馆区域背景。每批的逐张提示词保存在同目录 `v9-art-prompts-*.json`。
- 逻辑与接线：Claude Code。本轮没有用脚本、PIL 或 Gemini 生成任何图像。

## 新增与替换的美术

角色立绘（透明 PNG，默认朝左、脚底贴齐画布底边，`assets/environments/exploration/actors/`）：

| 角色 | 文件 | 用途 |
| --- | --- | --- |
| 梅·莫里 | `may_idle` `may_windup` `may_slash` `may_summon` `may_brush` `may_brush_strike` | 美术馆 Boss 三阶段：美工刀 → 雕像替身 → 入画（画笔） |
| 雕像替身 | `may_statue` | 第二、三阶段召唤的纯白替身 |
| 沃伊德 | `void_idle` `void_command` `void_lash` `void_frenzy` | 剧院 Boss：丝线操控、丝线鞭打/绞杀、暴走丝线 |
| 座位人偶 | `void_puppet` | 沃伊德的人偶，也是剧院里的「断线木偶」敌人 |
| 守钟人 | `keeper_back` `keeper_hidden` `keeper_unmasked` | 追逐中背身拧发条；钟楼顶转身、摘帽露出杰利的脸 |
| 弗瑞 | `fury_idle` `fury_lunge` `fury_punch` | 枯井边的突进，以及视角切换后玩家操控的身体 |
| 玲 | `ling_giant` `ling_hand` `ling_crouch` | 井底泥浆藤蔓巨体、泥里伸出的手、角落里真正的玲 |

背景（1672×941，覆盖原文件，`assets/environments/exploration/backgrounds/`）：

- `museum.png`：美术馆 · 无尽走廊（原为蜡像熔炉大厅）。
- `basement.png`：七镜画室（地下室与被遗忘的档案室共用；原为蜡像地下工坊）。
- `wax.png`：美术馆前街及其街边室内（原为蜡像馆街景）。

## 脚本接线

- `exploration_boss.gd`：梅·莫里按阶段与招式选择姿势（`_pose_name`），每个姿势有各自的显示高度。不再使用 `morris*` 图集。
- `exploration_morris_double.gd`：替身改用 `may_statue`，去掉蜡壳着色器。
- `exploration_void_boss.gd`：沃伊德按招式换姿势；剪断红线时右侧布片仍叠加绘制。`actors.json` 的 `puppet` 改用 `void_puppet`（`build_exploration_v9.py` 新增 `art_v9` 同步此项）。
- `exploration_keeper_figure.gd`：去掉压暗的主角贴图与代码画的发条；钟楼顶依杰利距离切换 背身 → 转身 → 摘帽。
- `exploration_fury_body.gd` / `exploration_fury_scene.gd` / `exploration_player.gd`：弗瑞用新立绘，去掉色调压暗；`ExplorationPlayer.wear` 增加出拳姿势与「朝左绘制」标记，玩家操控弗瑞时出拳显示 `fury_punch`。
- `exploration_ling_boss.gd` / `exploration_ling_figure.gd` / `exploration_ling_hand.gd`：巨体、真身与泥手改为贴图；藤蔓缠绕、藤结光点、声音干扰的圆环仍按原逻辑叠加绘制。
- `exploration_art.gd`：新增 `foot_center` / `foot_shift`，按贴图底部不透明像素求出脚的位置，使宽姿势（甩线、挥画笔、突进）脚下仍对准碰撞体。
- `exploration_hud.gd`：人物图鉴底排改为六人（杰利、梅·莫里、沃伊德、守钟人、弗瑞、玲）；敌人格子读取 `cell` 时允许缺省。

## 验证

- `tools/dev/validate_v9_art.gd`（新增）：21 张新立绘均可载入；在各自房间生成梅·莫里、替身、沃伊德与人偶、守钟人、弗瑞、玲、泥手与真正的玲，强制每个姿势并核对显示的 PNG；玩家穿上弗瑞时的站姿与出拳；人物图鉴。带窗口运行结果 `V9_ART_QA 48 passed, 0 failed`，截图为同目录 `v9-*.png`。
- `tools/dev/validate_exploration.gd`：23 通过、5 失败。这 5 项（房间实例化、后台奖励、第三印记、终局井、车站路线）在本轮改动之前的 HEAD 上同样失败，原因是该脚本仍按 Demo 8 的路线断言；本轮未修改。
- Godot 无界面导入无错误，新 PNG 已生成 `.import`。

## 尚未处理

- 美术馆两套中景已在 follow-up item 1 替换，见下。其他建筑与 props 尚保留。
- 丰收祭之夜仍用燃烧街道背景；井口、警戒线、藤蔓、红线仍由代码绘制；音效未换。
- 梅·莫里的撕碎与雕塑化结局、入画后的画作化、可推倒掩体，钟楼瓦解演出、刑警登场等剧情机制仍未实现（见 README-V9「尚未改动」）。
- 未重新导出 Windows 包；未手动完整通关。

## Follow-up item 1：美术馆中景

2026-11-08：由 Codex 内置 image_gen 新绘 museum_mid / museum_depth，各为 1536×1024 RGBA 2×2 图集；透明清理亦经 image_gen，未用脚本或 PIL 绘图。提示词含清理指令见 v9-art-prompts-museum-mid.json。内容为画墙、遮布画架、空基座、七镜、修复桌、廊柱、画框库与破损栏杆维修架。新增八个 AtlasTexture 与运行时 art-regions；仅 wax_lane / wax_museum / wax_basement 的 buildings 和 rear_scenery 引用迁移（地下室七镜选 cell 2），build_exploration_v9.py 同步。

验证：本环境可用 Godot 4.5.1 headless 导入，两张 PNG 与八个切片载入，三个房间实例化通过。视窗运行在此受限环境启动崩溃，因此没有新游戏截图；导入另有宿主 CA / 编辑器设置写入警告。只验证本项，不代表完整通关。其他主题和旧 wax 图集保持原样。三房间中无 wax_mid / wax_depth_v7 引用；wax_shop / wax_workshop 建筑、其他道具与地形是范围外残留。未 push、未导出 Windows、未开始后续待办。

提交限制：本轮 git add / commit 被工作区只读 .git 权限阻止（无法建立 .git/index.lock）；改动留在工作树，尚未提交。
