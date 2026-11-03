# 回环镇 Loop Town — Demo 开发说明

最新的 Demo 8 已接入 F5。直接运行 `dist/LoopTownDemo-v8/LoopTownDemo.exe` 也可游玩。
本版移除街道前的石柱挑战台，修正庭院图集裁切和中景落地锚点；街区支路由落地侧门进入，房屋高处通路依附实际屋檐与木楼梯。
详见 [Demo 8 说明](docs/exploration-demo/README-V8.md)；原故事入口保留为 `scenes/ui/TitleScreen.tscn`。
下文为早期故事系统开发记录；新版操作、内容与限制以 Demo 8 说明为准。

2D 横板动作冒险 · 时间循环 · 悬疑调查。
本文件是**开发者文档**（怎么跑、怎么改、当前做到哪一步）。
剧情设定以《回环镇·剧情 5.0》为准，本工程不得擅自改动核心设定。

---

## 1. 怎么运行

### 编辑器
1. 用 **Godot 4.6.3** 打开本目录（`G:\新建游戏项目`）。
   可执行文件：`G:\Godot_v4.6.3-stable_win64.exe\Godot_v4.6.3-stable_win64.exe`
2. 直接按 **F5**（主场景为 `res://scenes/exploration/ExplorationDemo.tscn`）。

### 主场景流程
标题界面 →「开始游戏」→ 序幕（镇口）→ 走过右侧出口 → 小镇 Hub → 蜡像巷 → 蜡像馆 → 莫里斯。

### 操作
| 按键 | 功能 |
|---|---|
| `A` / `D` | 左右移动 |
| `Space` | 跳跃（支持土狼时间与跳跃缓冲） |
| `J` | 普通攻击（前 / 后 / 斜上 / 斜下，三段连击） |
| `K` | 特殊动作 / 道具（预留） |
| `E` | 互动（对话、拾取、读木牌、转镜子） |
| `Q` | 切换道具（预留） |
| `Tab` | 打开笔记本 |
| `Esc` | 暂停菜单 |

---

## 2. 目录结构

```
res://
├── autoload/              7 个全局系统 + 3 个基础设施（见 §3）
├── scripts/
│   ├── player/            玩家控制器 + 9 个状态（states/）
│   ├── combat/            DamageInfo / HealthComponent / HitBox / HurtBox
│   ├── enemy/             敌人基类 + 蜡像 + 敌人状态
│   ├── npc/               镇民 NPC + NPC 状态（task / staggered / dazed / chase）
│   ├── boss/               Boss 基类 + 莫里斯 + 他的状态（states/morris/）
│   ├── world/             地图框架、出口、检查点、蜡像、雾、关卡加载
│   ├── puzzles/           解谜框架 + 镜面反射谜题
│   ├── dialogue/          对白数据与触发器
│   ├── memory/            记忆碎片数据与拾取物
│   ├── inventory/         道具数据
│   ├── save/              存档数据结构
│   ├── ui/                HUD / 暂停 / 笔记本 / 对话框 / GameHUD 容器
│   ├── effects/           命中特效、熔炉视觉
│   └── utils/             状态机、Actor 基类、相机震动、ActorFactory
├── scenes/
│   ├── player/Player.tscn
│   ├── maps/              13 张地图（骨架，内容运行时铺）
│   └── ui/                5 个 UI 场景 + GameHUD.tscn
├── data/
│   ├── maps/              13 份 MapData（尺寸 / 出口 / 音区）——地图的唯一真相
│   ├── levels/            13 份关卡内容 JSON（什么东西放在哪）
│   ├── memories/          13 条记忆 / 线索
│   ├── items/             6 件道具
│   └── dialogue/          10 段对白
├── assets/                程序化占位美术 + 程序化音频
└── tools/                 生成器与回归测试（见 §6）
```

---

## 3. 全局系统（autoload）

加载顺序即依赖顺序（`project.godot` 的 `[autoload]` 段）。

| 名称 | 文件 | 职责 |
|---|---|---|
| `ScreenTransition` | `autoload/ScreenTransition.gd` | 全屏淡入淡出，任何系统都可 `await` |
| `Combat` | `autoload/CombatManager.gd` | 顿帧 / 震屏 / 命中特效 / 闪白。**类名是 `CombatManager`，autoload 名是 `Combat`**（避免与原生类撞名） |
| `MapRegistry` | `autoload/MapRegistry.gd` | `地图 id → MapData` 映射，换图逻辑不认识任何具体关卡 |
| `GameManager` | `autoload/GameManager.gd` | 剧情 flag、地图切换、暂停、章节进度、重生 |
| `SaveManager` | `autoload/SaveManager.gd` | 存档唯一入口（原子写入 + 备份 + 防抖自动存档） |
| `WorldStateManager` | `autoload/WorldStateManager.gd` | 6 个世界阶段（黄昏→清晨），全局叠色 + 广播 |
| `DialogueManager` | `autoload/DialogueManager.gd` | 对白流程、条件分支、选项、效果执行 |
| `MemoryManager` | `autoload/MemoryManager.gd` | 记忆收集与解锁条件 |
| `LoopManager` | `autoload/LoopManager.gd` | 循环计数（247）、检查点、Boss 进度、结局判定 |
| `AudioManager` | `autoload/AudioManager.gd` | 区域音乐 / 环境声 / 音效 / 钟声，7 条音频总线 |

剧情 flag 的判定语法统一走 `GameManager.evaluate_condition()`：

```
flag:xxx          拥有该 flag
noflag:xxx        没有该 flag
memory:xxx        已收集该记忆
item:xxx          持有该道具
chapter:N         第 N 章已通关
memories>=N       记忆数量达标
and:a|b  or:a|b   组合条件
```

对白 / 交互物里的效果语法：

```
set:flag    clear:flag    memory:id    item:id    chapter:N    bell    sfx:id    checkpoint
```

---

## 4. 关卡数据怎么改

**两条数据链，改关卡不需要碰 .tscn：**

1. `data/maps/<id>.tres`（`MapData`）—— 地图尺寸、出口、跳转条件、音区。
   由 `tools/dev/build_scenes.py` 的 `MAPS` 表生成。
2. `data/levels/<id>.json` —— 敌人、NPC、道具、木牌、蜡像、雾、Boss 放在哪。
   由 `tools/dev/build_chapter1.py` 的 `CHAPTER1` 表生成。

改完重新跑生成器即可：

```powershell
$py = "C:\Users\Administrator\.dsh\dsh-runtimes\dsh-primary-runtime\dependencies\python\python.exe"
& $py tools\dev\build_scenes.py      # 地图尺寸 / 出口 / 玩家场景
& $py tools\dev\build_chapter1.py    # 关卡内容
```

地图地形（地面、两侧墙、出生点、出口、检查点）由 `MapRoot._build_map_geometry()`
在运行时按 `MapData` 生成。要手工摆美术细节，直接往 `Gameplay` / `Interactables`
容器里加节点即可，生成逻辑不会覆盖已有节点。

`data/levels/*.json` 支持的 `kind`：

| kind | 说明 |
|---|---|
| `fog` | 程序化大雾层 |
| `parallax` | `Parallax2D` 分层背景 |
| `townsman` | 镇民（`mood`: 0 可对话 / 1 只看你 / 2 敌对；敌对被打到会变**茫然**） |
| `wax_dummy` | 蜡像敌人（`variant`: 0 拳击 / 1 跳扑 / 2 包围） |
| `statue_row` | 一排会转头、会换姿势、会逼近的蜡像 |
| `wax_director` | 蜡像巷追踪节奏导演 |
| `memory_pickup` | 记忆碎片拾取物 |
| `signboard` | 木牌 / 海报（环境叙事文字） |
| `morris` | 第一章 Boss |
| `furnace` | 熔蜡炉视觉 |
| `arena_gate` | Boss 房闸门 |
| `mirror_puzzle` | 镜面反射谜题 |

---

## 5. 美术与音频

**全部是程序化占位，不是最终素材，但风格统一、接口稳定。**

| 内容 | 生成方式 | 重新生成 |
|---|---|---|
| 角色 / 敌人 / NPC / 道具 / UI / 背景 | `tools/generate_placeholder_art.py`（Pillow 程序化矢量） | `python tools/generate_placeholder_art.py` |
| 51 个音效 / 音乐 / 环境声 | `tools/generate_audio.py`（numpy 合成，可无缝循环） | `python tools/generate_audio.py` |
| 小镇图块（224 张 32×32） | 已有素材，位于 `comscene/village/` | 不需要 |

替换成正式素材时**只需覆盖同名文件**，逻辑代码不需要改：
角色动画图集按 `assets/characters/player/player_<动作>.png` 命名，
帧宽固定 64（莫里斯为 128），横向平铺。

音频清单与峰值 / 循环接缝数据见 `tools/audio_inventory.csv`。

---

## 6. 关卡效果图（设计意图确认用）

两套渲染器，对应两个层次的目标：

```powershell
$py = "C:\Users\Administrator\.dsh\dsh-runtimes\dsh-primary-runtime\dependencies\python\python.exe"
& $py tools\dev\render_level_mockups.py        # 关卡读取语言（地形/路线/分层）
& $py tools\dev\render_illustrated_mockups.py  # 插画化场景 + 完整 HUD 系统
```

### 6.1 关卡读取语言（`docs/mockups/01~03`）

| 文件 | 对应文档 | 落实的要求 |
|---|---|---|
| `01_town_entrance.png` | 【十一】序幕 | 黄昏、大雾、锈木牌「欢迎来到回环镇」、玩家从左进入、巨大钟楼明显高于其他建筑；前景栏杆·枯树·路灯·碎石；中景住宅·小巷·小店 |
| `02_town_hub.png` | 【十二】Hub | 中心钟楼、环形道路（地面呈拱形）、5~8 个 NPC 各有循环动作、上层环廊 |
| `03_wax_lane.png` | 【十三】蜡像巷 | 入口→蜡像街→小型战斗区→追逐区→蜡像馆；蜡·暖黄灯·暗红·玻璃·镜子·人形轮廓 |

**必须遵守的读取规则：**
1. 可站平面 = 一条厚亮带（骨白 → 中灰 → 体块向下渐暗），全地图统一
2. 深坑要有坑口亮角 + 受光坑壁 + 向下渐黑
3. 路线分层：主路 + 悬浮平台的第二层路线，共用同一套亮边语言
4. 空气透视：远景/中景各盖一层冷调薄雾推远，玩法平面不加
5. 物件颜色语言：暖黄＝可拾取　暗红菱形＝战斗单位　冷蓝菱形＝可交互　无标记＝装饰
6. 主角永远是画面里对比最强的元素

### 6.2 插画化场景 + HUD 系统（`docs/mockups/04~05`）

| 文件 | 场景 | 重点 |
|---|---|---|
| `04_clocktower_heart.png` | 第四章 钟楼心脏 | 赤红/火橙单色调、巨大钟面透光、黄铜齿条地板、前景齿轮与藤蔓压边、火焰容器 |
| `05_old_theater_boss.png` | 第二章 旧剧院 | 青绿/暗红、彩窗、观众席成排玩偶（缺右眼）、幕布、红线机制、浮动伤害数字 |

**HUD 构成（实现 UI 时按这个结构）：**

| 元件 | 位置 | 说明 |
|---|---|---|
| 生命容器 | 左上 | 一排面具，装在双层描边 + 四角铆钉的金属框内 |
| 灵魂/火焰容器 | 左上（紧接生命框） | 圆形金属框 + 内部液体；钟楼用火焰、剧院用灵魂 |
| 道具槽 | 左侧中部 | 圆形槽 + 图标 + 右下角数量 |
| 装备槽 | 右下 | 两格装饰方框 + 图标 + 下方名称 |
| 章节名 + Boss 条 | 顶部中央 | 章节名 + 分段血条（两端菱形装饰）+ Boss 名 + 英文副标 |
| 底部黑条 | 最下 | 引擎版本 / 项目名 |
| 浮动伤害数字 | 命中点 | 描边大字 |
| 交互提示 | 可交互物上方 | 圆形按键提示 |

> 效果图上的中文标注与左上角图名是**评审用**的，正式出图删掉 `_note()` 与 `title_card()` 调用。

---

## 7. 回归测试

改完任何东西都应该跑一遍：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools/dev/run_all_tests.ps1
```

四项检查：

| 套件 | 覆盖内容 |
|---|---|
| `validate_project` | 全部 `.gd` 能否解析、`class_name` 是否注册 |
| `validate_runtime` | 13 张地图能否实例化，地形 / 出生点 / 出口是否生成，玩家能否落到地面 |
| `validate_gameplay` | 移动 / 停住不漂移 / 跳跃落地 / 攻击有生效帧且能扣血 / 受伤 / 死亡状态 |
| `validate_transition` | 开始新游戏 → 走过出口 → 切图 → 内容重新生成 → 没有重复玩家 |

也可以单独跑：

```powershell
& "G:\Godot_v4.6.3-stable_win64.exe\Godot_v4.6.3-stable_win64_console.exe" `
  --headless --path "G:\新建游戏项目" --script "res://tools/dev/validate_gameplay.gd"
```

**两个必须知道的 Godot 4.6 坑**（已在代码注释里标注，不要改回去）：

1. `CharacterBody2D.motion_mode` 必须是 **0（GROUNDED）**。
   写成 1 是 `MOTION_MODE_FLOATING`，`is_on_floor()` 会永远返回 false，角色完全无法站立。
2. `.tres` 里不能用 `X.Y.Z` 形式的枚举常量（会报 `Unexpected identifier`），
   枚举一律写整数字面量；导出为强类型 Array 的字段（`Array[SomeClass]`）
   在加载裸 `SubResource` 时会触发容器类型校验失败，这类字段用无类型 `Array` + 内部转换。

### 当前进度

- 已完成：项目骨架、7+3 个全局系统、玩家（9 状态）、战斗系统、敌人与 NPC、地图框架、
  解谜框架与镜面谜题、莫里斯三阶段 Boss、序幕 / 小镇 Hub / 蜡像巷 / 蜡像馆 / 地下室内容、
  13 张地图骨架、程序化美术与音频、回归测试。**第一章可完整游玩。**
- 尚未完成：皮埃罗 / 小铃 / 看守 / 黑影四个 Boss 的实际战斗、第二至四章内容、
  第五章闪回、火海与火车站、三个结局的实际演出。
  这些章节目前有地图骨架、记忆碎片与音区配置，但还没有战斗与剧情内容。
