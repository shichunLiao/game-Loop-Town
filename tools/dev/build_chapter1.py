"""为每张地图生成第一章的关卡内容数据（data/levels/<map_id>.json）。

为什么输出 JSON 而不是 .tscn：
敌人与 NPC 需要 Body + Sprite + HurtBox + DetectionArea + StateMachine + 状态子节点，
手写 .tscn 极易漏掉某个子节点，而且同一套结构要在几十个位置重复。
因此这里只生成**纯数据**（在哪放什么、什么参数），由 MapRoot 在运行时调用
ActorFactory / 各个脚本正确装配 —— 只有一条代码路径，不会出现“有的敌人忘了加血条”。

用法：
    python .tools/build_chapter1.py
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

PROJECT = Path(r"G:\新建游戏项目")
OUT_DIR = PROJECT / "data" / "levels"

# 每张地图的地面高度（须与 data/maps/*.tres 的 map_size 一致）
GROUND_Y: dict[str, float] = {
    "town_entrance": 1200.0,
    "town_hub": 1300.0,
    "wax_lane": 800.0,
    "wax_museum": 1100.0,
    "wax_basement": 700.0,
    "old_theater": 1200.0,
    "back_stage": 800.0,
    "dry_well": 1200.0,
    "well_interior": 2800.0,
    "clock_tower": 4800.0,
    "final_fire_town": 1300.0,
    "shadow_boss": 1100.0,
    "train_station": 800.0,
}

# ---------------------------------------------------------------------------
# 第一章内容表
# ---------------------------------------------------------------------------

CHAPTER1: dict[str, list[dict]] = {
    # ------------------------------------------------------------- 序幕
    "town_entrance": [
        {"kind": "fog", "x": 0, "coverage": [5600, 800], "bands": 6, "alpha": 0.18},
        {"kind": "parallax", "x": 0, "layers": [
            ["res://assets/environments/bg_town_far.png", 0.15, -260.0, 0.55],
            ["res://assets/environments/bg_town_mid.png", 0.35, -120.0, 0.72],
            ["res://assets/environments/bg_town_near.png", 0.6, 40.0, 0.85],
        ]},
        {"kind": "signboard", "x": 620, "prompt": "查看木牌",
         "flag": "saw_welcome_sign",
         "message": "「欢迎来到回环镇」\n牌子锈得很厉害，字却是新刻上去的。"},
        {"kind": "memory_pickup", "x": 880, "memory": "letter_from_town",
         "prompt": "拾起那封信"},
        {"kind": "townsman", "x": 1500, "mood": 1,
         "dialogue": "res://data/dialogue/townsman_01.tres"},
        {"kind": "townsman", "x": 1850, "mood": 0,
         "dialogue": "res://data/dialogue/townsman_02.tres"},
        {"kind": "wax_dummy", "x": 2450, "variant": 2, "detection": 220.0},
        {"kind": "townsman", "x": 3000, "mood": 0,
         "dialogue": "res://data/dialogue/townsman_03.tres"},
        {"kind": "wax_dummy", "x": 3500, "variant": 0, "detection": 240.0},
        {"kind": "townsman", "x": 4100, "mood": 1,
         "dialogue": "res://data/dialogue/townsman_04.tres"},
    ],
    # --------------------------------------------------------- 小镇 Hub
    "town_hub": [
        {"kind": "fog", "x": 0, "coverage": [6600, 800], "bands": 6, "alpha": 0.15},
        {"kind": "parallax", "x": 0, "layers": [
            ["res://assets/environments/bg_town_far.png", 0.15, -300.0, 0.6],
            ["res://assets/environments/bg_town_mid.png", 0.4, -140.0, 0.75],
            ["res://assets/environments/bg_town_near.png", 0.65, 40.0, 0.9],
        ]},
        {"kind": "townsman", "x": 700, "mood": 1,
         "dialogue": "res://data/dialogue/townsman_01.tres"},
        {"kind": "townsman", "x": 1150, "mood": 0,
         "dialogue": "res://data/dialogue/townsman_02.tres"},
        {"kind": "townsman", "x": 1700, "mood": 0,
         "dialogue": "res://data/dialogue/townsman_03.tres"},
        {"kind": "townsman", "x": 2300, "mood": 1,
         "dialogue": "res://data/dialogue/townsman_04.tres"},
        {"kind": "townsman", "x": 2900, "mood": 2},
        {"kind": "townsman", "x": 3500, "mood": 0,
         "dialogue": "res://data/dialogue/townsman_05.tres"},
        {"kind": "townsman", "x": 4200, "mood": 0,
         "dialogue": "res://data/dialogue/townsman_06.tres"},
        {"kind": "townsman", "x": 4800, "mood": 2},
        {"kind": "memory_pickup", "x": 5300, "memory": "the_247",
         "prompt": "查看公告栏"},
        {"kind": "townsman", "x": 5650, "mood": 1},
    ],
    # ----------------------------------------------------------- 蜡像巷
    "wax_lane": [
        {"kind": "fog", "x": 0, "coverage": [4000, 700], "bands": 4, "alpha": 0.12},
        {"kind": "parallax", "x": 0, "layers": [
            ["res://assets/environments/bg_wax_lane.png", 0.2, -220.0, 0.62],
            ["res://assets/environments/bg_town_near.png", 0.55, 40.0, 0.85],
        ]},
        {"kind": "statue_row", "x": 520, "count": 9, "spacing": 330},
        {"kind": "wax_director",
         "trigger_positions": [900, 1500, 2100, 2700, 3150],
         "ambush_after": 3, "ambush_count": 4},
        {"kind": "wax_dummy", "x": 1700, "variant": 0, "detection": 280.0},
        {"kind": "wax_dummy", "x": 1980, "variant": 1, "detection": 320.0},
        {"kind": "wax_dummy", "x": 2600, "variant": 0, "detection": 280.0},
        {"kind": "wax_dummy", "x": 2880, "variant": 2, "detection": 300.0},
        {"kind": "signboard", "x": 1200, "prompt": "查看",
         "flag": "wax_lane_note",
         "message": "巷子两边全是蜡像。它们的脸朝着街心。\n每一张脸都不一样。"},
    ],
    # ----------------------------------------------------------- 蜡像馆
    "wax_museum": [
        {"kind": "fog", "x": 0, "coverage": [4500, 700], "bands": 3, "alpha": 0.10},
        {"kind": "parallax", "x": 0, "layers": [
            ["res://assets/environments/bg_wax_lane.png", 0.2, -240.0, 0.5],
            ["res://assets/environments/bg_town_near.png", 0.6, 40.0, 0.8],
        ]},
        {"kind": "statue_row", "x": 600, "count": 6, "spacing": 380},
        {"kind": "wax_dummy", "x": 1100, "variant": 0, "detection": 300.0},
        {"kind": "wax_dummy", "x": 1350, "variant": 1, "detection": 340.0},
        {"kind": "signboard", "x": 700, "prompt": "查看台阶",
         "flag": "mirror_hint_seen",
         "message": "展廊尽头有一道向下的台阶，被一排蜡像挡着。\n它们全都面朝墙壁，像是在看什么不该看的东西。"},
        {"kind": "arena_gate", "x": 2550},
        {"kind": "morris", "x": 3450},
        {"kind": "furnace", "x": 3760},
        {"kind": "arena_gate", "x": 4180},
        {"kind": "memory_pickup", "x": 3500, "memory": "morris_voice",
         "prompt": "倾听"},
        {"kind": "memory_pickup", "x": 3820, "memory": "wax_order",
         "prompt": "拾取订单"},
    ],
    # --------------------------------------------------------- 地下室
    "wax_basement": [
        {"kind": "parallax", "x": 0, "layers": [
            ["res://assets/environments/bg_wax_lane.png", 0.25, -180.0, 0.45],
        ]},
        {"kind": "mirror_puzzle", "x": 200,
         "puzzle_id": "wax_basement_mirrors",
         "solve_flag": "mirrors_solved",
         "reward_memory": "fire_brigade_tag"},
        {"kind": "memory_pickup", "x": 1300, "memory": "fire_brigade_tag",
         "prompt": "拾取金属牌"},
    ],
    # --------------------------------- 后续章节骨架（占位，后续逐个深入）
    "old_theater": [
        {"kind": "fog", "x": 0, "coverage": [5000, 700], "bands": 3, "alpha": 0.12},
        {"kind": "parallax", "x": 0, "layers": [
            ["res://assets/environments/bg_clocktower.png", 0.3, -200.0, 0.45],
        ]},
        {"kind": "signboard", "x": 900, "prompt": "查看海报",
         "flag": "theater_note",
         "message": "剧院的大门锁着。\n海报上写着《丰收祭之夜》，纸边被燎焦了。"},
        {"kind": "wax_dummy", "x": 1800, "variant": 0, "detection": 300.0},
        {"kind": "wax_dummy", "x": 2400, "variant": 2, "detection": 300.0},
    ],
    "back_stage": [
        {"kind": "fog", "x": 0, "coverage": [2600, 600], "bands": 3, "alpha": 0.14},
        {"kind": "memory_pickup", "x": 900, "memory": "four_children_voices",
         "prompt": "拿起那只布偶"},
    ],
    "dry_well": [
        {"kind": "fog", "x": 0, "coverage": [4000, 800], "bands": 5, "alpha": 0.2},
        {"kind": "parallax", "x": 0, "layers": [
            ["res://assets/environments/bg_town_far.png", 0.2, -260.0, 0.5],
        ]},
        {"kind": "signboard", "x": 1500, "prompt": "查看",
         "flag": "well_note",
         "message": "所有的树都朝同一个方向弯。\n叶子踩上去的声音，像有人在哭。"},
        {"kind": "memory_pickup", "x": 2900, "memory": "summer_camp_photo",
         "prompt": "拾起照片"},
    ],
    "well_interior": [
        {"kind": "fog", "x": 0, "coverage": [2600, 2600], "bands": 6, "alpha": 0.22},
        {"kind": "memory_pickup", "x": 900, "y": 2200,
         "memory": "well_full_memory", "prompt": "想起"},
    ],
    "clock_tower": [
        {"kind": "fog", "x": 0, "coverage": [2200, 4600], "bands": 6, "alpha": 0.14},
        {"kind": "parallax", "x": 0, "layers": [
            ["res://assets/environments/bg_clocktower.png", 0.3, -200.0, 0.5],
        ]},
        {"kind": "memory_pickup", "x": 900, "y": 4200,
         "memory": "warden_voice", "prompt": "倾听"},
    ],
    "final_fire_town": [
        {"kind": "parallax", "x": 0, "layers": [
            ["res://assets/environments/bg_town_far.png", 0.15, -300.0, 0.55],
            ["res://assets/environments/bg_town_mid.png", 0.4, -140.0, 0.72],
        ]},
        {"kind": "memory_pickup", "x": 3000, "memory": "seven_selves",
         "prompt": "看清"},
    ],
    "shadow_boss": [
        {"kind": "parallax", "x": 0, "layers": [
            ["res://assets/environments/bg_clocktower.png", 0.3, -200.0, 0.6],
        ]},
    ],
    "train_station": [
        {"kind": "parallax", "x": 0, "layers": [
            ["res://assets/environments/bg_town_far.png", 0.15, -300.0, 0.4],
        ]},
        {"kind": "memory_pickup", "x": 1200, "memory": "suzu_is_alive",
         "prompt": "站起来"},
    ],
}


def normalise(map_id: str, entries: list[dict]) -> dict:
    """补全每项的坐标（把 "ground" 解析成实际 y）并输出规范化结构。"""
    ground_y = GROUND_Y.get(map_id, 1000.0)
    normalised: list[dict] = []
    for entry in entries:
        item = dict(entry)
        item.setdefault("x", 0.0)
        raw_y = item.get("y", "ground")
        if raw_y == "ground":
            item["y"] = ground_y - 40.0
        else:
            item["y"] = float(raw_y)
        item["x"] = float(item["x"])
        normalised.append(item)
    return {
        "map_id": map_id,
        "ground_y": ground_y,
        "items": normalised,
    }


def main() -> int:
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    total = 0
    for map_id, entries in CHAPTER1.items():
        data = normalise(map_id, entries)
        dest = OUT_DIR / f"{map_id}.json"
        dest.write_text(
            json.dumps(data, ensure_ascii=False, indent=1),
            encoding="utf-8",
        )
        total += len(data["items"])
        print(f"  wrote data/levels/{map_id}.json  ({len(data['items'])} 项)")
    print(f"完成：{len(CHAPTER1)} 张地图，共 {total} 项关卡内容。")
    return 0


if __name__ == "__main__":
    sys.exit(main())
