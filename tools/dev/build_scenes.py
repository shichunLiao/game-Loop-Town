"""生成《回环镇》Demo 的 Godot 场景与资源文件。

设计决定：**地图场景刻意保持极小**。
每张地图的 .tscn 只有骨架节点（Background / Gameplay / Enemies / ... 和 MapRoot），
地形、出生点、出口、检查点全部由 MapRoot 依据 data/maps/<id>.tres 在运行时构建。
好处：
  - .tscn 不会因为手写坐标出错而变成一堆难以维护的数字
  - 地图尺寸/出口/条件只有一处真相（MapData）
  - 新增地图 = 加一行 MAPS

用法：
    python .tools/build_scenes.py
"""

from __future__ import annotations

import sys
from pathlib import Path

PROJECT = Path(r"G:\新建游戏项目")

# 物理层编号，必须与 project.godot 的 [layer_names] 一致
L_WORLD = 1
L_PLAYER = 2
L_ENEMY = 3
L_PLAYER_HITBOX = 4
L_ENEMY_HITBOX = 5
L_INTERACTABLE = 6
L_ONE_WAY = 7
L_HAZARD = 8
L_PICKUP = 9
L_PLAYER_ATTACK = 10
L_ENEMY_ATTACK = 11

# 玩家动画：动画名 -> (图集文件名, 帧数)。帧尺寸统一 64x64。
PLAYER_ANIMATIONS: list[tuple[str, str, int]] = [
    ("idle", "player_idle.png", 6),
    ("run", "player_run.png", 8),
    ("jump", "player_jump.png", 3),
    ("fall", "player_fall.png", 3),
    ("attack", "player_attack.png", 6),
    ("hit", "player_hit.png", 2),
    ("death", "player_death.png", 6),
    ("interact", "player_interact.png", 4),
    ("climb", "player_climb.png", 4),
]
PLAYER_STATES = [
    "idle", "run", "jump", "fall", "attack", "hit", "death", "interact", "climb",
]
FRAME = 64


def bit(layer: int) -> int:
    return 1 << (layer - 1)


def mask(*layers: int) -> int:
    total = 0
    for layer in layers:
        total |= bit(layer)
    return total


def write(relative: str, text: str) -> None:
    path = PROJECT / relative
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text, encoding="utf-8")
    print("  wrote " + relative)


# ---------------------------------------------------------------------------
# 玩家场景
# ---------------------------------------------------------------------------

def build_player() -> None:
    ext: list[tuple[str, str, str]] = []
    ids: dict[str, str] = {}

    def e(type_name: str, path: str) -> str:
        if path in ids:
            return ids[path]
        res_id = f"{len(ext) + 1}_{type_name.lower()}"
        ext.append((type_name, path, res_id))
        ids[path] = res_id
        return res_id

    sub: list[tuple[str, list[str]]] = []

    def s(type_name: str, props: list[str]) -> str:
        res_id = f"{type_name.lower()}_{len(sub) + 1}"
        sub.append((type_name, [res_id] + props))
        return res_id

    # --- SpriteFrames ---
    anim_entries: list[str] = []
    for anim_name, file_name, frame_count in PLAYER_ANIMATIONS:
        tex_id = e("Texture2D", f"res://assets/characters/player/{file_name}")
        frames: list[str] = []
        for index in range(frame_count):
            atlas = s("AtlasTexture", [
                f'atlas = ExtResource("{tex_id}")',
                f"region = Rect2({index * FRAME}, 0, {FRAME}, {FRAME})",
            ])
            frames.append('{\n"duration": 1.0,\n"texture": SubResource("%s")\n}' % atlas)
        anim_entries.append(
            '{\n"frames": [%s],\n"loop": true,\n"name": &"%s",\n"speed": 10.0\n}'
            % (", ".join(frames), anim_name)
        )
    sprite_frames = s("SpriteFrames", ["animations = [%s]" % ", ".join(anim_entries)])

    # --- 形状 ---
    body_shape = s("CapsuleShape2D", ["radius = 13.0", "height = 46.0"])
    hurt_shape = s("CapsuleShape2D", ["radius = 15.0", "height = 48.0"])
    attack_shape = s("RectangleShape2D", ["size = Vector2(46, 34)"])
    interact_shape = s("CircleShape2D", ["radius = 56.0"])

    player_script = e("Script", "res://scripts/player/player_controller.gd")
    sm_script = e("Script", "res://scripts/utils/state_machine.gd")
    health_script = e("Script", "res://scripts/combat/health_component.gd")
    hurt_script = e("Script", "res://scripts/combat/hurt_box.gd")
    hit_script = e("Script", "res://scripts/combat/hit_box.gd")
    shaker_script = e("Script", "res://scripts/utils/camera_shaker.gd")
    state_ids = {
        st: e("Script", f"res://scripts/player/states/{st}.gd") for st in PLAYER_STATES
    }

    nodes: list[str] = []

    def node(name: str, type_name: str, parent: str, props: list[str],
             groups: list[str] | None = None) -> None:
        header = f'[node name="{name}" type="{type_name}"'
        if parent:
            header += f' parent="{parent}"'
        header += "]"
        lines = [header]
        if groups:
            lines.append("groups=[%s]" % ", ".join('"%s"' % g for g in groups))
        lines.extend(props)
        nodes.append("\n".join(lines))

    node("Player", "CharacterBody2D", "", [
        f"collision_layer = {bit(L_PLAYER)}",
        f"collision_mask = {mask(L_WORLD, L_ONE_WAY)}",
        # motion_mode 保持默认的 0 (MOTION_MODE_GROUNDED)。
        # 绝不能写成 1 —— 在 Godot 4 里 1 是 MOTION_MODE_FLOATING，
        # 会导致 is_on_floor() 永远为 false，角色完全无法站立。
        "floor_snap_length = 8.0",
        f'script = ExtResource("{player_script}")',
    ], groups=["player"])
    node("AnimatedSprite2D", "AnimatedSprite2D", ".", [
        f'sprite_frames = SubResource("{sprite_frames}")',
        'animation = &"idle"',
        'autoplay = "idle"',
        # 帧高 64、图片中心在 -32；胶囊体脚底在 -48（中心 -26、高 46），
        # 偏移 = 32 - 48 = -16，脚才正好落在地面上。
        "position = Vector2(0, -16)",
    ])
    node("CollisionShape2D", "CollisionShape2D", ".", [
        "position = Vector2(0, -26)",
        f'shape = SubResource("{body_shape}")',
    ])
    node("HealthComponent", "Node", ".", [
        f'script = ExtResource("{health_script}")',
        "max_health = 100",
        "default_invincibility = 0.7",
    ])
    node("HurtBox", "Area2D", ".", [
        f"collision_layer = {bit(L_PLAYER)}",
        f"collision_mask = {bit(L_ENEMY_ATTACK)}",
        "monitoring = false",
        f'script = ExtResource("{hurt_script}")',
    ])
    node("CollisionShape2D", "CollisionShape2D", "HurtBox", [
        "position = Vector2(0, -26)",
        f'shape = SubResource("{hurt_shape}")',
    ])
    node("HitBox", "Area2D", ".", [
        f"collision_layer = {bit(L_PLAYER_ATTACK)}",
        f"collision_mask = {bit(L_ENEMY)}",
        "monitoring = false",
        f'script = ExtResource("{hit_script}")',
    ])
    node("CollisionShape2D", "CollisionShape2D", "HitBox", [
        "position = Vector2(0, -28)",
        f'shape = SubResource("{attack_shape}")',
    ])
    node("InteractionArea", "Area2D", ".", [
        "collision_layer = 0",
        f"collision_mask = {bit(L_INTERACTABLE)}",
    ])
    node("CollisionShape2D", "CollisionShape2D", "InteractionArea", [
        "position = Vector2(0, -28)",
        f'shape = SubResource("{interact_shape}")',
    ])
    node("Camera2D", "Camera2D", ".", [
        "position = Vector2(0, -40)",
        "position_smoothing_enabled = true",
        "position_smoothing_speed = 6.0",
    ])
    node("CameraShaker", "Node", "Camera2D", [
        f'script = ExtResource("{shaker_script}")',
    ])
    node("StateMachine", "Node", ".", [
        f'script = ExtResource("{sm_script}")',
        'initial_state = &"idle"',
    ])
    for state in PLAYER_STATES:
        node(state, "Node", "StateMachine", [
            f'script = ExtResource("{state_ids[state]}")',
        ])

    lines = [f"[gd_scene load_steps={len(ext) + len(sub) + 1} format=3]", ""]
    for type_name, path, res_id in ext:
        lines.append(f'[ext_resource type="{type_name}" path="{path}" id="{res_id}"]')
    lines.append("")
    for type_name, props in sub:
        lines.append(f'[sub_resource type="{type_name}" id="{props[0]}"]')
        lines.extend(props[1:])
        lines.append("")
    lines.extend(nodes)
    write("scenes/player/Player.tscn", "\n".join(lines) + "\n")


# ---------------------------------------------------------------------------
# 地图注册表（唯一真相）
# ---------------------------------------------------------------------------

MAPS: list[dict] = [
    {
        "id": "town_entrance", "name": "回环镇 · 镇口", "size": (5000, 1400),
        "audio": "Town", "spawn": "start",
        "exits": [("east", "town_hub", "west_gate", "", "")],
    },
    {
        "id": "town_hub", "name": "回环镇 · 中央广场", "size": (6000, 1500),
        "audio": "Town", "spawn": "center",
        "exits": [
            ("west_gate", "town_entrance", "east", "", ""),
            ("wax_lane", "wax_lane", "start", "", ""),
            ("theater", "old_theater", "foyer", "", ""),
            ("dry_well", "dry_well", "start", "", ""),
            ("clock_tower", "clock_tower", "base", "", ""),
        ],
    },
    {
        "id": "wax_lane", "name": "蜡像巷", "size": (3500, 1000),
        "audio": "Wax", "spawn": "start",
        "exits": [
            ("back_town", "town_hub", "wax_lane", "", ""),
            ("museum", "wax_museum", "hall", "", ""),
        ],
    },
    {
        "id": "wax_museum", "name": "蜡像馆", "size": (4000, 1300),
        "audio": "Wax", "spawn": "hall",
        "exits": [
            ("back_lane", "wax_lane", "museum", "", ""),
            ("basement", "wax_basement", "start", "flag:mirror_hint_seen",
             "地下室的入口被一排蜡像挡着。它们都面朝墙壁。"),
        ],
    },
    {
        "id": "wax_basement", "name": "蜡像馆 · 地下室", "size": (1800, 900),
        "audio": "Wax", "spawn": "start",
        "exits": [("up", "wax_museum", "basement", "", "")],
    },
    {
        "id": "old_theater", "name": "旧剧院", "size": (4500, 1400),
        "audio": "Theater", "spawn": "foyer",
        "exits": [
            ("back_town", "town_hub", "theater", "", ""),
            ("back_stage", "back_stage", "start", "flag:pierrot_defeated",
             "后台的门从里面锁着。"),
        ],
    },
    {
        "id": "back_stage", "name": "剧院 · 后台", "size": (2200, 1000),
        "audio": "Theater", "spawn": "start",
        "exits": [("back", "old_theater", "back_stage", "", "")],
    },
    {
        "id": "dry_well", "name": "枯井区域", "size": (3500, 1400),
        "audio": "Well", "spawn": "start",
        "exits": [
            ("back_town", "town_hub", "dry_well", "", ""),
            ("well", "well_interior", "top", "", ""),
        ],
    },
    {
        "id": "well_interior", "name": "井底", "size": (2200, 3000),
        "audio": "Well", "spawn": "top",
        "exits": [("out", "dry_well", "well", "", "")],
    },
    {
        "id": "clock_tower", "name": "大钟楼", "size": (1800, 5000),
        "audio": "ClockTower", "spawn": "base",
        "exits": [
            ("base", "town_hub", "clock_tower", "", ""),
            ("top", "shadow_boss", "start", "", ""),
        ],
    },
    {
        "id": "final_fire_town", "name": "回环镇 · 火海", "size": (6000, 1500),
        "audio": "Fire", "spawn": "start", "exits": [],
    },
    {
        "id": "shadow_boss", "name": "钟楼顶", "size": (2200, 1300),
        "audio": "Fire", "spawn": "start", "exits": [],
    },
    {
        "id": "train_station", "name": "火车站", "size": (2400, 1000),
        "audio": "Ending", "spawn": "start", "exits": [],
    },
]


def build_map_resources() -> None:
    for entry in MAPS:
        sub_links: list[tuple[str, list[str]]] = []
        for exit_id, target, spawn, condition, locked in entry["exits"]:
            props = [
                f'exit_id = &"{exit_id}"',
                f'target_map_id = &"{target}"',
                f'target_spawn_id = &"{spawn}"',
            ]
            if condition:
                props.append(f'condition = &"{condition}"')
            if locked:
                props.append(f'locked_message = "{locked}"')
            res_id = f"exitlink_{len(sub_links) + 1}"
            sub_links.append((res_id, props))

        lines = [
            '[gd_resource type="Resource" script_class="MapData" load_steps=%d format=3]'
            % (len(sub_links) + 3),
            "",
            '[ext_resource type="Script" path="res://scripts/world/map_data.gd" id="1_mapdata"]',
            '[ext_resource type="Script" path="res://scripts/world/map_exit_link.gd" id="2_exitlink"]',
            "",
        ]
        for res_id, props in sub_links:
            lines.append(f'[sub_resource type="Resource" id="{res_id}"]')
            lines.append('script = ExtResource("2_exitlink")')
            lines.extend(props)
            lines.append("")
        lines.append("[resource]")
        lines.append('script = ExtResource("1_mapdata")')
        lines.append(f'id = &"{entry["id"]}"')
        lines.append(f'display_name = "{entry["name"]}"')
        lines.append(f'scene_path = "res://scenes/maps/{entry["id"]}.tscn"')
        lines.append("map_size = Vector2i(%d, %d)" % entry["size"])
        lines.append(f'audio_area = &"{entry["audio"]}"')
        lines.append("reacts_to_world_state = true")
        if sub_links:
            joined = ", ".join(f'SubResource("{rid}")' for rid, _ in sub_links)
            lines.append(f"exits = [{joined}]")
        else:
            lines.append("exits = []")
        lines.append(f'default_spawn_id = &"{entry["spawn"]}"')
        write(f'data/maps/{entry["id"]}.tres', "\n".join(lines) + "\n")


def build_map_scene(entry: dict) -> None:
    """极小骨架：地形与出生点由 MapRoot 运行时构建。"""
    map_script = "res://scripts/world/map_root.gd"
    lines = [
        "[gd_scene load_steps=2 format=3]",
        "",
        f'[ext_resource type="Script" path="{map_script}" id="1_maproot"]',
        "",
        '[node name="Map" type="Node2D"]',
        f'script = ExtResource("1_maproot")',
        f'map_id = &"{entry["id"]}"',
        f'default_spawn_id = &"{entry["spawn"]}"',
        'player_scene_path = "res://scenes/player/Player.tscn"',
        "",
        '[node name="Background" type="Node2D" parent="."]',
        "",
        '[node name="Midground" type="Node2D" parent="."]',
        "",
        '[node name="Gameplay" type="Node2D" parent="."]',
        "",
        '[node name="Foreground" type="Node2D" parent="."]',
        "",
        '[node name="Enemies" type="Node2D" parent="."]',
        "",
        '[node name="Interactables" type="Node2D" parent="."]',
        "",
        '[node name="Triggers" type="Node2D" parent="."]',
        "",
        '[node name="PlayerSpawn" type="Node2D" parent="."]',
        "",
    ]
    write(f'scenes/maps/{entry["id"]}.tscn', "\n".join(lines))


def main() -> int:
    print("=== 玩家场景 ===")
    build_player()
    print("=== 地图资源 ===")
    build_map_resources()
    print("=== 地图场景骨架 ===")
    for entry in MAPS:
        build_map_scene(entry)
    print("完成：1 个玩家场景 + %d 张地图资源 + %d 张地图场景。" % (len(MAPS), len(MAPS)))
    return 0


if __name__ == "__main__":
    sys.exit(main())
