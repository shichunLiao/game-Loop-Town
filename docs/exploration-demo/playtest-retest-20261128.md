# Demo 9 可玩性复测（2026-11-28）

依据：`/tmp/loop-town-playtest/loop-town-playtest-diagnosis.md` 第 7 节「只改 5 件事」与第 8 节复测脚本。
引擎：Godot 4.6.3 stable（macOS / Apple M3 Max / 1280×720 窗口，非 headless）。
复测方式：`tools/dev/gui_retest.gd` 在真实窗口里通过 Godot 输入管线发送键盘/鼠标事件（A/D、Space、J、E、H、M、鼠标点击按钮），同时保存游戏帧、桌面截图和桌面录屏。**这是脚本化输入，不是真人试玩**；凡用调试手段跳段的地方都以 `ASSIST` 记录在 `metrics.json` 中。

## 前后对比

| 指标 | 修复前（诊断报告 / main `0b4ef28`） | 修复后（本 PR） |
|---|---|---|
| 开局常驻操作提示 | 11 类，含未解锁能力 | 4 类（A/D、E、Space、J）；H 首次受伤时出现，K 拿到美工刀后出现，W/S、Shift、Q 获得能力后出现，S+Space 只在钟楼/井中出现 |
| 基础操作上手（GUI） | 无安全练习 | 移动 1.8 s、读传唤单 4.3 s、跳跃 5.3 s、首次攻击 11.6 s（均在 60 s 内）；练习蜡偶伤害为 0 |
| 镇口 → 美术馆黑屏换场 | 6 次（3 个过道） | 2 次（0.39 s 普通换场 + 3.46 s 现实→记忆转场）；passage_00/05/08 仍可加载，存档 ID 不变 |
| 主街楼梯卡死（本次新发现） | 按住 D 会走上楼梯，在陡屋檐下卡住，到不了东出口 | 走街道时直接从楼梯下方通过；跳一下仍能上楼梯（4 处楼梯均已检查） |
| 不安全出口落点 | 29 个；`validate_exploration` 22/8 | 0 个：92/92 出口加载 0.5 s 后都站在地面且在边界内；连续往返 10 轮无跌落；`validate_exploration` 40/0 |
| 物理回调 ERROR | GUI 死亡时出现 `Disabling a CollisionObject…` | 0：30 次 Area2D 击杀、10 次钟楼 GUI 死亡、梅战胜利转场全程日志 0 条 ERROR |
| 二次死亡卡死（本次新发现） | 重生淡入期间再次死亡会被丢弃，玩家 0 HP 且无法操作 | 第二次死亡正常进入重生流程（已加回归测试） |
| 梅战失败重试 | 实际路线退回镇口路灯：2 次换场 + 约 45 s 步行 | 战前检查点：0.37 s 恢复操作，仍在美术馆；开场对话不重复 |
| 钟楼失败成本 | 死亡回塔底，两只回声全部重打；敲钟回退两层且 Boss 回血 30% | 第 2/4/6 层永久检查点；GUI 实测重生 0.35–0.38 s（10 次）；回声伤害保留（10 次死亡后仍为 420/560）；敲钟最多回退一层、不低于检查点、不回血；单段重做估计 13.1 s（目标 <90 s） |
| 现实↔记忆转场辨识 | 只靠文字和约 0.26 s 黑屏 | 统一约 3 s：钟声、HUD 淡出（中段透明度 0.0）、记忆青色/现实琥珀色调、居中字幕；返回时镜像（3.10 s）；HUD 常驻标记「◇ 记忆世界 / ● 现实」。静音也能看出 |
| 致死状态反馈 | 只有失败卡解释 | 状态栏显示层数、阈值和解除方法（例：`纸裂 1 · 被刀击倒＝撕裂 · H修补`），接近阈值时变红闪烁；首次叠层给出一句可操作提示；沃布化阈值改为真实值 8（原 HUD 写 6） |
| 恢复操作后的安全窗 | 无 | 换场、重生、剧情卡、钟楼瓦解、坠井之后均 ≥0.5 s |
| 七镜按键 | 最少 12 次 E | 7 次 E |
| 玩家可见版本 | 标题与 README 写 Demo 8 | 标题显示「动作探索 Demo 9」；README 改为 Demo 9 |

## 自动化矩阵（`tools/dev/run_all_tests.sh`）

退出码非 0、出现任何非白名单 `ERROR:` / `SCRIPT ERROR:`，或出现 `ObjectDB instances leaked`，都算失败。白名单为空。

| 套件 | 结果 |
|---|---|
| validate_project | 138 个脚本，0 失败 |
| validate_assets | 31 项，0 失败 |
| validate_runtime | 0 失败 |
| validate_gameplay | 17 项通过 |
| validate_transition | 0 失败 |
| validate_exploration | 40/0：69 个房间、92 个出口、30 次击杀、10 轮往返；用真实输入爬完钟楼全部 7 层；电梯在物理帧中移动；藤蔓攀爬、长距离坠落致死、全部结局 |
| validate_experience_improvements | 46/0：楼梯、练习敌人、两次换场、3 s 镜像转场、梅战检查点、钟楼分段/敲钟/Boss 血量、二次死亡、状态提示 |
| validate_v9_art / museum_mid / item3 / item4 / item5 / item6 / animation | 全部通过（48 / 8+3 / 0 / 0 / 0 / 32 / 828） |

## 证据

- 关键帧（本目录）：`01-title` 标题 Demo 9；`02-opening-hud` 开局 4 键；`04-practice-enemy` 练习敌人；`06-realm-shift-enter-mid` / `12-realm-return-mid` 转场中段（进入 / 返回）；`09-mei-first-status` 首次叠层的状态栏与提示；`10-mei-defeat-card` 失败卡；`17-tower-checkpoint-floor2` 钟楼第 2 层检查点；`19-bell-rewind` 敲钟回退；`20-map` 地图首章路线。
- 全部帧、桌面截图、录屏（`realm-enter-museum.mov`、`realm-return-after-mei.mov`、`tower-death-respawn.mov`）和 Godot 日志位于 `/tmp/loop-town-playtest/retest-after/`（本机路径，未入库）。
- `metrics.json`：本次 GUI 复测的全部 METRIC 和 ASSIST 记录。

## 跳段说明与遗留风险

- 梅战：先用真实 J/H 打了 29 s，以「结局 · 雕塑」失败；重试后为了观察胜利转场，开无敌并把梅压到低血量，再用真实 J 击败（ASSIST）。
- 七镜地下室、剧院、钟楼是直接加载房间进入的（ASSIST）；钟楼两层用真实输入攀爬，耗时 12.7 s。
- 后台能力交付：GUI 驱动按 E 时点到了旁边的缝纫桌，没有点到印记，所以这一项只由 headless validator 验证。剧院仍然一次给出二段跳、藤蔓和冲刺，诊断 B3 的「分批给能力」不在五项范围内。
- 进入美术馆就会开始梅战，美工刀要在战后才能拿到（沿用原设计）；本次 GUI 中第一次拿到美工刀用了 96.9 s，其中包含一次失败和强制胜利。
- 重生时，画面在操作恢复后还会淡入约 0.35 s，这段时间由 0.5 s 安全窗覆盖。
- 首章跳过的过道仍保留为可选房间；从美术馆前街东出口往回走会直接回到镇口，西环需从广场进入。
