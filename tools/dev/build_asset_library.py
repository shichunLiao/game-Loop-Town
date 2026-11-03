"""建立规范化的资源库。

解决的问题（用户反馈）：
  1. 资源没有分类：角色 / 敌人 / Boss / NPC / 环境 / 道具 / UI / 特效 / 音频 混在一起
  2. 资源没有定义文件：只有 PNG，编辑器里点开看不到「这是什么、多少帧、怎么用」
  3. 只有 F5 运行才看得到：没有清单，也没有可单独查看的资源

本脚本产出：
  data/assets/actors/*.tres    每个可动角色一份定义（贴图 + 帧数 + 体型 + 碰撞 + 状态）
  data/assets/environments/*.tres  每层背景一份定义（视差系数 + 垂直偏移 + 透明度）
  data/assets/props/*.tres     每个道具一份定义（图标 + 名称 + 用途）
  data/assets/manifest.json    机器可读总清单（供校验脚本与文档生成）
  assets/README.md             人读的资源库说明（分类 / 命名 / 替换方式）

用法：
    python tools/dev/build_asset_library.py
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

PROJECT = Path(r"G:\新建游戏项目")
ASSETS = PROJECT / "assets"
DATA = PROJECT / "data" / "assets"

# ---------------------------------------------------------------------------
# 角色资源表
#
# sheet        : 图集文件名（不含扩展名）
# frames       : 每个动画的帧数
# frame        : 单帧尺寸
# collision    : (宽, 高) —— 胶囊体直径与总高
# script       : 运行时脚本
# states       : 状态脚本目录
# ---------------------------------------------------------------------------
ACTORS: list[dict] = [
    # ---------------------------------------------------------- 玩家
    {
        "id": "player", "kind": "player", "display": "侦探（主角）",
        "dir": "characters/player", "script": "res://scripts/player/player_controller.gd",
        "frame": 64, "collision": (26, 46),
        "animations": {
            "idle": ("player_idle", 6), "run": ("player_run", 8),
            "jump": ("player_jump", 3), "fall": ("player_fall", 3),
            "attack": ("player_attack", 6), "hit": ("player_hit", 2),
            "death": ("player_death", 6), "interact": ("player_interact", 4),
            "climb": ("player_climb", 4),
        },
        "states_dir": "res://scripts/player/states",
        "states": ["idle", "run", "jump", "fall", "attack", "hit", "death",
                   "interact", "climb"],
        "note": "巨大侦探帽 + 右脸烧伤 + 空白笔记本。帽檐下只见琥珀色眼部高光。",
    },
    # ---------------------------------------------------------- 敌人
    {
        "id": "wax_dummy", "kind": "enemy", "display": "蜡像敌人",
        "dir": "enemies", "script": "res://scripts/enemy/wax_dummy.gd",
        "frame": 64, "collision": (26, 52),
        "animations": {
            "idle": ("wax_dummy_idle", 4), "walk": ("wax_dummy_walk", 6),
            "attack": ("wax_dummy_attack", 5), "hit": ("wax_dummy_hit", 2),
            "death": ("wax_dummy_death", 5),
        },
        "states_dir": "res://scripts/enemy/states",
        "states": ["idle", "patrol", "chase", "jump_lunge", "attack", "hit", "death"],
        "note": "淡蜡黄、边缘融化滴落、**没有眼睛**。三种变体：拳击 / 跳扑 / 包围。",
    },
    {
        "id": "child_ghost", "kind": "enemy", "display": "孩童幽灵",
        "dir": "enemies", "script": "res://scripts/enemy/enemy_base.gd",
        "frame": 64, "collision": (22, 40),
        "animations": {"idle": ("child_ghost_idle", 4), "float": ("child_ghost_float", 4)},
        "states_dir": "res://scripts/enemy/states",
        "states": ["idle", "chase", "attack", "hit", "death"],
        "note": "半透明低 alpha、拖尾雾丝。第三章枯井区域使用。",
    },
    # ---------------------------------------------------------- NPC
    {
        "id": "townsman", "kind": "npc", "display": "镇民",
        "dir": "enemies", "script": "res://scripts/npc/townsman.gd",
        "frame": 64, "collision": (28, 54),
        "animations": {
            "idle": ("townsman_idle", 4), "task": ("townsman_task", 6),
            "walk": ("townsman_idle", 4), "dazed": ("townsman_dazed", 3),
            "hit": ("townsman_dazed", 3), "death": ("townsman_dazed", 3),
        },
        "states_dir": "res://scripts/npc/states",
        "states": ["task", "staggered", "dazed", "chase", "hit", "death"],
        "note": "灰衣。三种情绪：可对话 / 只看你 / 敌对；被击败后变茫然（不是自愿攻击）。",
    },
    # ---------------------------------------------------------- Boss
    {
        "id": "morris", "kind": "boss", "display": "莫里斯（第一章 Boss · 蜡像师）",
        "dir": "enemies", "script": "res://scripts/boss/morris.gd",
        "frame": 128, "collision": (30, 62),
        "animations": {
            "idle": ("morris_idle", 4), "spray": ("morris_spray", 6),
            "summon": ("morris_summon", 5), "hit": ("morris_hit", 2),
            "death": ("morris_death", 8),
        },
        "states_dir": "res://scripts/boss/morris/states",
        "states": ["idle", "chase", "melee", "spray", "summon", "hurt", "death"],
        "note": "右脸黑色烧伤印记 + 全镇唯一穿彩色衣服（青绿围裙）。"
                "**眼里有琥珀色高光，替身没有** —— 这是二阶段解谜的唯一线索。",
    },
]

# ---------------------------------------------------------------------------
# 环境层资源表（每张地图 3 层视差）
# ---------------------------------------------------------------------------
ENVIRONMENT_LAYERS: dict[str, list[tuple[str, float, float, float]]] = {
    # 地图 id: [(图集名, 视差系数, 垂直偏移, 透明度)]
    "town_entrance": [
        ("bg_town_far", 0.15, -260.0, 0.62),
        ("bg_town_mid", 0.35, -120.0, 0.78),
        ("bg_town_near", 0.60, 40.0, 0.90),
    ],
    "town_hub": [
        ("bg_town_far", 0.15, -300.0, 0.66),
        ("bg_town_mid", 0.40, -140.0, 0.80),
        ("bg_town_near", 0.65, 40.0, 0.92),
    ],
    "wax_lane": [
        ("bg_wax_lane", 0.20, -220.0, 0.70),
        ("bg_town_mid", 0.45, -100.0, 0.55),
        ("bg_town_near", 0.60, 40.0, 0.88),
    ],
    "wax_museum": [
        ("bg_wax_lane", 0.20, -240.0, 0.60),
        ("bg_clocktower", 0.45, -120.0, 0.45),
        ("bg_town_near", 0.62, 40.0, 0.85),
    ],
    "wax_basement": [
        ("bg_wax_lane", 0.25, -180.0, 0.50),
        ("bg_clocktower", 0.50, -80.0, 0.35),
    ],
    "old_theater": [
        ("bg_clocktower", 0.30, -200.0, 0.55),
        ("bg_wax_lane", 0.55, -60.0, 0.45),
    ],
    "back_stage": [
        ("bg_wax_lane", 0.30, -180.0, 0.50),
    ],
    "dry_well": [
        ("bg_town_far", 0.20, -260.0, 0.60),
        ("bg_town_mid", 0.48, -120.0, 0.45),
    ],
    "well_interior": [
        ("bg_clocktower", 0.25, -400.0, 0.55),
    ],
    "clock_tower": [
        ("bg_clocktower", 0.30, -200.0, 0.60),
        ("bg_town_far", 0.60, -60.0, 0.35),
    ],
    "final_fire_town": [
        ("bg_town_far", 0.15, -300.0, 0.70),
        ("bg_town_mid", 0.40, -140.0, 0.80),
        ("bg_town_near", 0.65, 40.0, 0.90),
    ],
    "shadow_boss": [
        ("bg_clocktower", 0.30, -200.0, 0.65),
    ],
    "train_station": [
        ("bg_town_far", 0.15, -300.0, 0.50),
        ("bg_town_mid", 0.42, -140.0, 0.40),
    ],
}

# ---------------------------------------------------------------------------
# 道具资源表
# ---------------------------------------------------------------------------
PROPS: list[dict] = [
    {"id": "letter", "display": "居民的信", "file": "letter.png",
     "use": "序幕拾取，开启主线：请找到小铃，带她回家。", "size": 32},
    {"id": "notebook", "display": "空白笔记本", "file": "notebook.png",
     "use": "主角随身物，每获得线索自动浮现文字；Tab 打开。", "size": 32},
    {"id": "big_scissors", "display": "大剪刀", "file": "big_scissors.png",
     "use": "第二章核心道具，用于剪断皮埃罗控制木偶的红线。", "size": 64},
    {"id": "button", "display": "纽扣", "file": "button.png",
     "use": "第二章纽扣眼谜题，插入玩偶缺失的右眼。", "size": 32},
    {"id": "rag_doll", "display": "双马尾女孩布偶", "file": "rag_doll.png",
     "use": "全场唯一没有破损的布偶。第三章交给井底的小铃。", "size": 32},
    {"id": "mirror", "display": "立式镜子", "file": "mirror.png",
     "use": "蜡像馆地下室镜面反射谜题，可旋转八档。", "size": 32},
    {"id": "mirror_handle", "display": "镜面摇柄", "file": "mirror.png",
     "use": "转动镜子的工具（预留）。", "size": 32},
    {"id": "wax_statue_a", "display": "蜡像 · 姿势 A", "file": "wax_statue_a.png",
     "use": "蜡像巷路边的装饰蜡像，会缓慢转头、换姿势、逼近玩家。", "size": 32},
    {"id": "wax_statue_b", "display": "蜡像 · 姿势 B", "file": "wax_statue_b.png",
     "use": "同上，三种姿势之一。", "size": 32},
    {"id": "wax_statue_c", "display": "蜡像 · 姿势 C", "file": "wax_statue_c.png",
     "use": "同上，三种姿势之一。", "size": 32},
    {"id": "checkpoint_lamp", "display": "街灯（存档点）", "file": "checkpoint_lamp.png",
     "use": "存档点。激活后灯光变暖变亮。", "size": 64},
    {"id": "signboard", "display": "木牌", "file": "signboard.png",
     "use": "环境叙事载体：镇口欢迎牌、海报、公告栏。", "size": 64},
]

# ---------------------------------------------------------------------------
# 特效与 UI
# ---------------------------------------------------------------------------
VFX: list[dict] = [
    {"id": "hit_spark", "display": "命中火花", "file": "hit_spark.png",
     "frames": 4, "frame": 32, "use": "攻击命中时的溅射特效。"},
    {"id": "white_flash", "display": "受击闪白", "file": "white_flash.png",
     "frames": 1, "frame": 64, "use": "受击时覆盖在角色上的纯白剪影。"},
    {"id": "marker_interact", "display": "交互标记", "file": "marker_interact.png",
     "frames": 1, "frame": 32, "use": "可交互物上方的提示标记。"},
    {"id": "marker_danger", "display": "危险标记", "file": "marker_danger.png",
     "frames": 1, "frame": 32, "use": "战斗单位上方的警示标记。"},
]

UI_ASSETS: list[dict] = [
    {"id": "panel_dark", "display": "深色面板", "file": "panel_dark.png",
     "size": 64, "border": 16, "use": "对话框 / 笔记本 / 暂停菜单的九宫格底。"},
    {"id": "hp_pip_full", "display": "生命容器（满）", "file": "hp_pip_full.png",
     "size": 24, "use": "HUD 生命面具，已填充状态。"},
    {"id": "hp_pip_empty", "display": "生命容器（空）", "file": "hp_pip_empty.png",
     "size": 24, "use": "HUD 生命面具，空槽状态。"},
    {"id": "hat_icon", "display": "帽子图标", "file": "hat_icon.png",
     "size": 24, "use": "HUD 上的主角标识。"},
]

AUDIO_GROUPS: dict[str, str] = {
    "sfx": "音效：玩家动作、敌人、Boss、叙事音（钟声 / 童谣 / 火焰 / 风声）",
    "music": "音乐：按区域与章节，全部无缝循环 24 秒",
    "ambient": "环境声：按区域与世界状态，无缝循环 20 秒",
}


# ---------------------------------------------------------------------------
# 生成
# ---------------------------------------------------------------------------

def gd_str(text: str) -> str:
    return '"' + text.replace("\\", "\\\\").replace('"', '\\"') + '"'


def write_text(path: Path, text: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text, encoding="utf-8")


# --- 角色定义 -------------------------------------------------------------

def build_actor_resource(actor: dict) -> str:
    """生成一个 ActorDefinition .tres。

    动画条目是独立的全局类 AnimationEntry —— 内部类从 .tres 读回来
    无法判定类型，会静默失效（MapData.ExitLink 上已踩过这个坑）。
    """
    rel = f"assets/{actor['dir']}"
    ext: list[tuple[str, str, str]] = []
    subs: list[tuple[str, list[str]]] = []

    def e(path: str) -> str:
        for t, p, i in ext:
            if p == path:
                return i
        res_id = f"{len(ext) + 1}_tex"
        ext.append(("Texture2D", path, res_id))
        return res_id

    anim_ids: list[str] = []
    for anim_name, (sheet, frames) in actor["animations"].items():
        path = f"res://{rel}/{sheet}.png"
        if not (PROJECT / rel / f"{sheet}.png").exists():
            print(f"    ! 缺少图集 {path}")
            continue
        tex_id = e(path)
        sub_id = f"anim_{anim_name}"
        subs.append((sub_id, [
            'script = ExtResource("2_anim")',
            f'name = &"{anim_name}"',
            f'path = "{path}"',
            f"frames = {frames}",
            f'texture = ExtResource("{tex_id}")',
        ]))
        anim_ids.append(sub_id)

    width, height = actor["collision"]
    lines: list[str] = []
    lines.append('[gd_resource type="Resource" script_class="ActorDefinition" '
                 'load_steps=%d format=3]' % (len(ext) + len(subs) + 3))
    lines.append("")
    lines.append('[ext_resource type="Script" '
                 'path="res://scripts/assets/actor_definition.gd" id="1_def"]')
    lines.append('[ext_resource type="Script" '
                 'path="res://scripts/assets/animation_entry.gd" id="2_anim"]')
    for type_name, path, res_id in ext:
        lines.append(f'[ext_resource type="{type_name}" path="{path}" id="{res_id}"]')
    lines.append("")
    for sub_id, props in subs:
        lines.append(f'[sub_resource type="Resource" id="{sub_id}"]')
        lines.extend(props)
        lines.append("")
    lines.append("[resource]")
    lines.append('script = ExtResource("1_def")')
    lines.append(f'id = &"{actor["id"]}"')
    lines.append(f'kind = {_kind_value(actor["kind"])}')
    lines.append(f"display_name = {gd_str(actor['display'])}")
    lines.append(f"source_dir = {gd_str(rel)}")
    lines.append(f"script_path = {gd_str(actor['script'])}")
    lines.append(f"frame_size = {actor['frame']}")
    lines.append(f"body_size = Vector2({width}, {height})")
    lines.append(f"states_dir = {gd_str(actor['states_dir'])}")
    # 注意：PackedStringArray 的元素必须是普通字符串字面量，
    # 写成 &"idle" 会报 Parse Error: Expected string。
    # StringName 数组在赋值时会自动转换。
    states = ", ".join(f'"{s}"' for s in actor["states"])
    lines.append(f"state_names = PackedStringArray({states})")
    lines.append(f"note = {gd_str(actor['note'])}")
    if anim_ids:
        joined = ", ".join(f'SubResource("{sid}")' for sid in anim_ids)
        lines.append(f"animations = [{joined}]")
    else:
        lines.append("animations = []")
    return "\n".join(lines) + "\n"


def _kind_value(kind: str) -> int:
    """ActorDefinition.Kind 的整数值（.tres 里不能写点号常量）。"""
    return {"player": 0, "enemy": 1, "npc": 2, "boss": 3}.get(kind, 1)


# --- 环境层定义 -----------------------------------------------------------

def build_environment_resource(map_id: str,
                               layers: list[tuple[str, float, float, float]]) -> str:
    ext: list[tuple[str, str]] = []
    subs: list[tuple[str, list[str]]] = []
    for index, (sheet, scroll, offset_y, alpha) in enumerate(layers):
        rel = f"assets/environments/{sheet}.png"
        if not (PROJECT / rel).exists():
            print(f"    ! 缺少背景层 assets/environments/{sheet}.png")
            continue
        res_id = f"{len(ext) + 1}_bg"
        ext.append((f"res://{rel}", res_id))
        sub_id = f"layer_{index + 1}"
        subs.append((sub_id, [
            'script = ExtResource("2_layer")',
            f'name = &"{sheet}"',
            f'texture_path = "res://{rel}"',
            f"scroll_scale = {scroll}",
            f"offset_y = {offset_y}",
            f"modulate_a = {alpha}",
            f'texture = ExtResource("{res_id}")',
        ]))

    lines = ['[gd_resource type="Resource" script_class="EnvironmentDefinition" '
             'load_steps=%d format=3]' % (len(ext) + len(subs) + 3), ""]
    lines.append('[ext_resource type="Script" '
                 'path="res://scripts/assets/environment_definition.gd" id="1_env"]')
    lines.append('[ext_resource type="Script" '
                 'path="res://scripts/assets/environment_layer.gd" id="2_layer"]')
    for path, res_id in ext:
        lines.append(f'[ext_resource type="Texture2D" path="{path}" id="{res_id}"]')
    lines.append("")
    for sub_id, props in subs:
        lines.append(f'[sub_resource type="Resource" id="{sub_id}"]')
        lines.extend(props)
        lines.append("")
    lines.append("[resource]")
    lines.append('script = ExtResource("1_env")')
    lines.append(f'map_id = &"{map_id}"')
    if subs:
        joined = ", ".join(f'SubResource("{sid}")' for sid, _ in subs)
        lines.append(f"layers = [{joined}]")
    else:
        lines.append("layers = []")
    return "\n".join(lines) + "\n"


# --- 道具定义 -------------------------------------------------------------

def build_prop_resource(prop: dict) -> str:
    rel = f"assets/props/{prop['file']}"
    lines = ['[gd_resource type="Resource" script_class="PropDefinition" '
             'load_steps=3 format=3]', ""]
    lines.append('[ext_resource type="Script" '
                 'path="res://scripts/assets/prop_definition.gd" id="1_prop"]')
    lines.append(f'[ext_resource type="Texture2D" path="res://{rel}" id="2_icon"]')
    lines.append("")
    lines.append("[resource]")
    lines.append('script = ExtResource("1_prop")')
    lines.append(f'id = &"{prop["id"]}"')
    lines.append(f"display_name = {gd_str(prop['display'])}")
    lines.append(f"texture_path = {gd_str('res://' + rel)}")
    lines.append(f"icon_size = {prop['size']}")
    lines.append(f"usage = {gd_str(prop['use'])}")
    lines.append('icon = ExtResource("2_icon")')
    return "\n".join(lines) + "\n"


# --- 主流程 ---------------------------------------------------------------

def main() -> int:
    print("=== 角色资源定义 ===")
    for actor in ACTORS:
        path = DATA / "actors" / f"{actor['id']}.tres"
        write_text(path, build_actor_resource(actor))
        print(f"  wrote data/assets/actors/{actor['id']}.tres")

    print("=== 环境层定义 ===")
    for map_id, layers in ENVIRONMENT_LAYERS.items():
        path = DATA / "environments" / f"{map_id}.tres"
        write_text(path, build_environment_resource(map_id, layers))
        print(f"  wrote data/assets/environments/{map_id}.tres")

    print("=== 道具定义 ===")
    for prop in PROPS:
        path = DATA / "props" / f"{prop['id']}.tres"
        write_text(path, build_prop_resource(prop))
        print(f"  wrote data/assets/props/{prop['id']}.tres")

    # --- 机器可读总清单 ---
    print("=== 总清单 ===")
    manifest = {
        "actors": [
            {
                "id": a["id"], "kind": a["kind"], "display_name": a["display"],
                "dir": f"assets/{a['dir']}", "frame_size": a["frame"],
                "collision": list(a["collision"]), "script": a["script"],
                "animations": {k: v[1] for k, v in a["animations"].items()},
                "definition": f"data/assets/actors/{a['id']}.tres",
                "note": a["note"],
            }
            for a in ACTORS
        ],
        "environments": [
            {
                "map_id": map_id,
                "layers": [
                    {"sheet": s, "path": f"assets/environments/{s}.png",
                     "scroll_scale": sc, "offset_y": oy, "modulate_a": al}
                    for s, sc, oy, al in layers
                ],
                "definition": f"data/assets/environments/{map_id}.tres",
            }
            for map_id, layers in ENVIRONMENT_LAYERS.items()
        ],
        "props": [
            {"id": p["id"], "display_name": p["display"],
             "path": f"assets/props/{p['file']}", "icon_size": p["size"],
             "usage": p["use"], "definition": f"data/assets/props/{p['id']}.tres"}
            for p in PROPS
        ],
        "vfx": [
            {"id": v["id"], "display_name": v["display"],
             "path": f"assets/vfx/{v['file']}", "frames": v["frames"],
             "frame_size": v["frame"], "usage": v["use"]}
            for v in VFX
        ],
        "ui": [
            {"id": u["id"], "display_name": u["display"],
             "path": f"assets/ui/{u['file']}", "size": u["size"],
             "usage": u["use"]}
            for u in UI_ASSETS
        ],
        "audio": {
            group: {
                "description": desc,
                "dir": f"assets/audio/{group}",
                "files": sorted(
                    f.name for f in (ASSETS / "audio" / group).glob("*.wav")
                ) if (ASSETS / "audio" / group).exists() else [],
            }
            for group, desc in AUDIO_GROUPS.items()
        },
        "tiles": {
            "dir": "comscene",
            "description": "小镇图块集（224 张 32×32），来自外部素材包",
            "subdirs": sorted(
                d.name for d in (PROJECT / "comscene").iterdir() if d.is_dir()
            ) if (PROJECT / "comscene").exists() else [],
        },
    }
    write_text(DATA / "manifest.json", json.dumps(manifest, ensure_ascii=False, indent=1))
    print("  wrote data/assets/manifest.json")

    total_actors = len(manifest["actors"])
    total_anims = sum(len(a["animations"]) for a in manifest["actors"])
    total_env = len(manifest["environments"])
    print("")
    print(f"完成：{total_actors} 个角色（共 {total_anims} 个动画）、"
          f"{total_env} 张地图的环境层定义、{len(PROPS)} 个道具定义。")
    return 0


if __name__ == "__main__":
    sys.exit(main())
