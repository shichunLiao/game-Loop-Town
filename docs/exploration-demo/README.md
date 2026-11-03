# 回环镇 场景探索 Demo

这是基于《完整提示词》和《回环镇·剧情 5.0》制作的可玩环境版本。美术沿用用户确认的手绘哥特方向。环境图中不含人物，运行时只有一个单独绘制的简单侦探角色。

## 启动

直接运行 `dist/LoopTownDemo/LoopTownDemo.exe`。必须让同目录的 `LoopTownDemo.pck` 与可执行文件放在一起。无需安装 Godot，无需联网或 API 密钥。

在工程里用 Godot 打开 `project.godot` 后按 F5，也会进入同一个新 Demo。当前制作和验证版本为本机现有的 Godot 4.6.3，使用 Godot 4 的 CharacterBody2D、AnimatableBody2D、Area2D、Parallax2D 和 Camera2D。

原工程的故事入口仍保存在 `scenes/ui/TitleScreen.tscn`；新入口为 `scenes/exploration/ExplorationDemo.tscn`。

## 操作

| 操作 | 按键 |
| --- | --- |
| 左右移动 | A / D 或方向键 |
| 跳跃；取得能力后再次跳跃 | Space |
| 调查、转镜、剪线、拉杆、通行、存档 | E |
| 藤蔓攀爬；在后台取得能力后使用 | W / S |
| 短距离冲刺；井底取得能力后使用 | Shift |
| 完整地图；单击已经点亮的路灯返回该区域 | M |
| 笔记本 | Tab |
| 暂停或合上覆盖层 | Esc |
| 回到最近点亮的存档灯 | R |

路灯恢复生命并保存。门框是地图出口，靠近会出现目的地名称。蓝白发光物是记忆或能力；红色地形会先预警再进入危险窗口。长距离坠落会重生。

## 地图和探索流程

世界有 18 个独立场景、23 对双向连接，即 46 个有向出口。镇口、西环、广场、东环构成表层回环；档案室、西环、剧院、后台、排水闸构成可开启的返程捷径。每个区域都有存档灯，井底与钟楼另设中途存档点。

主线可按以下路线完成：

1. 镇口拾取信件，越过短坑，进入西环。
2. 西环进入蜡像巷，再到蜡像馆，在熔炉另一侧取得大剪刀。
3. 下到七镜地下室，调查墙边刻度说明。七面镜子的目标刻度为 `2、3、4、1、2、4、3`。光线连通后取得蜡像印记；在后台取得二段跳后，可回来跃上左侧高台，探索档案室并打开西环捷径。
4. 沿广场到东环，凭大剪刀进入剧院。剪断三条红线，打开后台。完整布偶给予剧院印记、二段跳与藤蔓攀爬。拉开舞台侧门后可以回西环，或从后台回东环。
5. 带着布偶进入枯井。沿藤蔓和平台向下，避免直接跳到底。拿到合照和井底印记，获得冲刺。黑泥随后开始上升，可向上攀爬，或拉开左侧排水闸经地下室逃离。
6. 三枚印记开启广场中央的钟楼门。沿七层平台与升降台向上，到达钟楼顶。
7. 调查发条处的记忆，触发最终循环。同一镇区会切换为火海外观，并开放最终火海关卡。
8. 可选择帮助拧发条结束探索；或进入火海，重访井底找回完整记忆，再前往停钟之处做出最终选择。完成条件后，右侧出口通向清晨火车站。

`world-map.png` 为 3840×2160 的全域地图。它与游戏内 M 地图共用 `world.json`，平台轮廓、连接和锁定条件都来自运行数据。

## 已完成的范围

完成：18 个连通区域、独立地图场景、三层视差、前景装饰、真实地形碰撞、单向平台、机械升降台、环境危险、井底上升黑泥、基本跑跳、能力解锁、七镜谜题、红线机关、快捷通路、存档、死亡重生、笔记本、全域地图、同场景火海切换、循环计数与三种结局条件及基础文字展示。

这是以场景和探索为重点的 Demo。角色采用简化绘制。文档中的完整居民 AI、攻击与多阶段 Boss 战、魂穿章节、完整镜头闪回、角色演出与 New Game+ 尚未在新入口实现；不应将本版视为文档所有战斗和剧情条目已经验收完成。

## 美术资源规格

资源目录为 `assets/environments/exploration/`。由内置图像生成工具制作 18 张独立环境 PNG：11 张背景、3 张地形、4 张透明装饰。确切尺寸、透明通道和 SHA-256 见 `asset-manifest.json`，提示词见 `ART_PROMPTS.md`。

| 资源 | 规格和用途 |
| --- | --- |
| `backgrounds/town、wax、theater、well、clocktower、fire、station.png` | 每张 1672×941 RGB；用于远景，不承担碰撞 |
| `backgrounds/museum、basement、dry_well、backstage.png` | 每张 1672×941 RGB；对应熔炉内景、镜室、暴雨树林和后台仓库 |
| `terrain/stone、wood、brass.png` | 每张 2172×724 RGBA；原始完整图，含透明留白 |
| `terrain/*.tres` | AtlasTexture 区域，取到实体顶边，供 Godot 重用 |
| `props/arch.png` | 1024×1536 RGBA；通道门框 |
| `props/lantern.png` | 724×2172 RGBA；存档路灯 |
| `props/foreground.png` | 1536×1024 RGBA；底部树根、铁栏与枝条 |
| `props/mirror.png` | 1024×1536 RGBA；可独立使用的古董立镜 |

运行场景层级为 `BG_03_Far → BG_02_Mid → BG_01_Near → Gameplay → Interactables → Foreground`。三个背景层采用不同 scroll_scale；碰撞只在 Gameplay 中生成。图片使用线性过滤。系统字体通过 `assets/ui/exploration/chinese.tres` 引用，不要求额外安装字体。

每个地图场景可单独 F6 运行。地图文件位于 `scenes/exploration/maps/`，名称与 `world.json` 中的 id 一一对应。重用平台时，将 `EnvironmentPlatform.tscn` 拖入场景；Inspector 可设置 dimensions、theme、one_way、travel 和 period。

## 数据和代码

`data/exploration/world.json` 是地图尺寸、平台、出生点、门、存档点、机关和大地图位置的统一来源。`tools/dev/build_exploration_world.py` 是其生成源，改关卡后运行它会更新 JSON 与地图包装场景。直接改 JSON 也能被游戏读取，但下一次运行生成器会覆盖这些直接修改。

脚本按职责分在 `scripts/exploration/`：Catalog 读取数据，Room 构建关卡，Platform 提供碰撞与地形，Backdrop 处理视差，Player 处理移动，Interactable 与 Actions 处理调查和谜题，Session 维护进度，HUD 与 WorldMap 展示界面，Demo 编排流程。

保存走现有 SaveManager，新版本单独使用 `exploration_v2.json`；旧故事存档 `slot_0.save` 不会被新 Demo 覆盖。QA 和截图分别使用独立的 `exploration_qa`、`exploration_preview` 存档槽。Windows 默认存档位于 `%APPDATA%/Godot/app_userdata/回环镇 Loop Town/saves/`。

## 验证

本机实际执行 `tools/dev/validate_exploration.gd`：35 项通过、0 项失败。包括真实输入跑跳、190px 坑、受伤无敌、死亡返回、全部 46 个出口安全落地、七层钟楼连续 37 次跳跃到顶、升降台、二段跳、冲刺、攀爬、黑泥触发、谜题与章节门、结局分支和存读档。

另执行全工程脚本解析：104 份脚本，0 个失败。七种区域已从实际运行画面截图检查。独立 EXE 已在其自身目录中启动并完成剧院场景渲染，日志没有脚本或资源错误。

这是自动化物理与流程检查，加上实际渲染检查；尚不等同于完整的人工作品游玩和关卡节奏评审。

测试命令：

```powershell
& 'G:\Godot_v4.6.3-stable_win64.exe\Godot_v4.6.3-stable_win64_console.exe' --headless --path 'G:\新建游戏项目' --fixed-fps 60 --script res://tools/dev/validate_exploration.gd
```

独立包由 `build_exploration_pack.gd` 根据允许清单构建。它不包含 `.env`、账户配置或编辑器插件。打包时附带本机现有 Godot 二进制，因此体积大于使用专用发行模板的构建，但可直接离线启动。
