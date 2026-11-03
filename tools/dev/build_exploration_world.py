"""Author the playable exploration world's room geometry and reciprocal links.

Regenerates only data/exploration and scenes/exploration/maps; original story
maps are kept separately. Pixel coordinates are world units, not image pixels.
"""
from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
ROOMS: dict[str, dict] = {}


def room(key, name, theme, size, map_rect, *, gaps=(), vertical=False, terrain=None):
    w, h = size
    floor = h - 160
    platforms = []
    cursor = 0
    for gx, gw in sorted(gaps):
        platforms.append({"rect": [cursor, floor, gx-cursor, 240], "one_way": False})
        cursor = gx+gw
    platforms.append({"rect": [cursor, floor, w-cursor, 240], "one_way": False})
    if vertical:
        step = 0
        for y in range(floor-124, 180, -124):
            x = 430 if step % 2 == 0 else 900
            platforms.append({"rect": [x, y, 400, 62], "one_way": True})
            step += 1
        platforms.append({"rect": [300, 190, 1200, 70], "one_way": True})
    else:
        # Alternative balcony routes, always approached via 120px steps.
        for x in range(600, w-300, 850):
            platforms.extend([
                {"rect": [x-180, floor-120, 256, 62], "one_way": True},
                {"rect": [x+100, floor-240, 384, 62], "one_way": True},
                {"rect": [x+500, floor-120, 224, 62], "one_way": True},
            ])
    r = dict(id=key, name=name, theme=theme, terrain=terrain or
             ("wood" if theme == "theater" else "brass" if theme == "clocktower" else "stone"),
             size=list(size), map_rect=list(map_rect), spawn=[160, floor-2],
             floor=floor, vertical=vertical, platforms=platforms, exits=[],
             objects=[], hazards=[], vines=[], checkpoint=[350, floor],
             audio={"town": "Town", "wax": "Wax", "theater": "Theater",
                    "well": "Well", "clocktower": "ClockTower", "fire": "Fire", "station": "Ending"}[theme])
    ROOMS[key] = r
    return r


def obj(key, kind, x, y=None, **extra):
    r = ROOMS[key]
    data = dict(kind=kind, pos=[x, r["floor"] if y is None else y], **extra)
    r["objects"].append(data)
    return data


def connect(a, b, ax, bx, *, ay=None, by=None, requires=(), reverse_requires=None,
            hint="", label=None):
    ra, rb = ROOMS[a], ROOMS[b]
    tag = a + "--" + b
    for source, target, x, y, req in [
        (ra, rb, ax, ay, requires), (rb, ra, bx, by, requires if reverse_requires is None else reverse_requires)
    ]:
        source["exits"].append(dict(id=tag, target=target["id"],
            pos=[x, source["floor"] if y is None else y],
            requires=list(req), hint=hint, label=label or target["name"]))


def build():
    room("town_entrance", "雾中镇口", "town", (3200, 1100), (0.4, 3.8, 2.3, 0.9), gaps=[(1540, 190)])
    room("town_hub", "钟楼广场", "town", (5000, 1400), (6.1, 3.6, 3.2, 1.25))
    room("ring_west", "西环 · 无尽街", "town", (3500, 1200), (3.2, 3.6, 2.4, 1.0), gaps=[(1450, 160)])
    room("wax_lane", "蜡像巷", "wax", (3500, 1100), (1.1, 2.1, 2.2, 1.0), gaps=[(1420, 180), (2450, 180)])
    room("wax_museum", "蜡像馆 · 熔炉", "wax", (4000, 1300), (0.5, 0.6, 2.6, 1.0), gaps=[(2000, 160)])
    room("wax_basement", "七镜地下室", "wax", (1800, 1000), (0.5, 5.4, 2.0, 1.0))
    room("hidden_archive", "被遗忘的档案室", "wax", (1800, 1000), (3.1, 5.6, 1.8, 0.8))
    room("old_theater", "旧剧院 · 红线舞台", "theater", (4500, 1400), (10.6, 2.0, 3.0, 1.15), gaps=[(1500, 160), (3180, 160)])
    room("back_stage", "后台 · 完整的布偶", "theater", (2200, 1100), (14.1, 2.2, 2.1, 0.95))
    room("ring_east", "东环 · 屋顶回廊", "town", (3500, 1300), (10.0, 3.8, 2.5, 0.95), gaps=[(1680, 160)])
    room("dry_well", "枯井 · 风向相同的树", "well", (3500, 1400), (10.5, 5.5, 2.7, 1.0), gaps=[(1500, 160)])
    room("well_interior", "倒悬之井", "well", (2200, 3000), (12.0, 7.0, 1.2, 2.6), vertical=True)
    room("clock_exterior", "钟楼外庭", "town", (2200, 1600), (6.8, 2.0, 1.8, 1.0))
    room("clock_tower", "七层钟楼", "clocktower", (1800, 5000), (7.05, -1.5, 1.3, 3.1), vertical=True)
    room("clock_top", "钟楼顶 · 发条之心", "clocktower", (2200, 1300), (6.0, -3.0, 3.3, 1.0))
    room("fire_town", "最终循环 · 火海", "fire", (6000, 1500), (5.8, 6.2, 4.6, 1.0), gaps=[(1400, 190), (2820, 190), (4380, 190)])
    room("shadow_roof", "停钟之处", "clocktower", (2200, 1300), (6.1, 8.0, 2.7, 0.9))
    room("train_station", "第零次 · 火车站", "station", (2400, 1000), (1.2, 8.0, 3.2, 1.0))

    # Two true surface rings and three cross-region shortcut loops.
    connect("town_entrance", "ring_west", 3020, 170)
    connect("ring_west", "town_hub", 3320, 180)
    connect("town_hub", "ring_east", 4800, 180)
    connect("ring_east", "town_entrance", 3320, 2720)
    connect("ring_west", "wax_lane", 720, 3240)
    connect("wax_lane", "wax_museum", 180, 3800)
    connect("wax_museum", "wax_basement", 740, 1580, requires=["scissors"], hint="先在熔炉另一侧找到大剪刀")
    connect("wax_basement", "hidden_archive", 220, 170, ay=440, requires=["wax_seal", "double_jump"], hint="上方档案室需要蜡像印记和二段跳")
    connect("hidden_archive", "ring_west", 1610, 2150, requires=["archive_shortcut"], hint="从档案室一侧拉开门闩")
    connect("town_hub", "clock_exterior", 2480, 180, requires=["wax_seal", "theater_seal", "well_seal"], hint="钟楼门上还缺三枚记忆印记")
    connect("clock_exterior", "clock_tower", 1990, 180)
    connect("clock_tower", "clock_top", 1250, 180, ay=190)
    connect("ring_east", "old_theater", 700, 180, requires=["scissors"], hint="门缝被红线封住，需要大剪刀")
    connect("ring_west", "old_theater", 2910, 4110, requires=["theater_shortcut"], hint="从舞台侧拉开返程拉杆")
    connect("old_theater", "back_stage", 4300, 180, requires=["thread_0", "thread_1", "thread_2"], hint="舞台仍系着三道红线，靠近后按 E 剪断")
    connect("back_stage", "ring_east", 1990, 2660, requires=["theater_seal"], hint="先找到完整布偶")
    connect("ring_east", "dry_well", 2100, 180, requires=["wax_seal", "theater_seal"], hint="先带回蜡像与剧院的两枚印记")
    connect("dry_well", "well_interior", 3000, 1250, by=190, requires=["doll"], hint="铁栅栏旁留着一个布偶形状的凹槽")
    connect("well_interior", "wax_basement", 180, 1180, requires=["well_shortcut"], hint="从井底找到并打开排水闸")
    connect("clock_top", "fire_town", 1980, 180, requires=["clock_memory"], hint="先触碰发条旁的记忆")
    connect("fire_town", "dry_well", 3100, 2600, requires=["clock_memory"], hint="火海中的旧井房")
    connect("fire_town", "shadow_roof", 5780, 180)
    connect("shadow_roof", "train_station", 1990, 180, requires=["zero_loop"], hint="停下时钟，放下审判")

    # Save lanterns are deliberate safe islands before each challenge.
    obj("town_entrance", "memory", 510, item="letter", title="一封没有署名的信", text="请找到小铃，带她回家。")
    obj("town_entrance", "sign", 1100, title="欢迎来到回环镇", text="A / D 移动 · Space 跳跃\n靠近发光物按 E。M 查看完整大地图，Tab 翻阅笔记本。\n白亮边缘可以站立；红色地形会受伤。")
    obj("town_hub", "sign", 1700, title="所有路，都会回到钟楼", text="西环通向蜡像馆；东环通向剧院与枯井。\n三枚印记能开启钟楼。已点亮的灯可以在大地图中快速返回。")
    obj("ring_west", "memory", 1320, ROOMS["ring_west"]["floor"]-240, item="resident_note", title="反复擦拭的窗", text="他们总在同一个动作里停住。有人说：你看起来好眼熟。")
    obj("wax_lane", "sign", 900, title="橱窗里的空位", text="记住每一张脸。\n蜡像馆在巷子的西端。熔蜡池每隔一段时间喷涌，观察亮起的预兆。")
    obj("wax_museum", "ability", 550, item="scissors", title="大剪刀", text="获得大剪刀。现在可以剪断剧院门口与舞台的红线。")
    obj("wax_museum", "sign", 2480, title="永远未完成的订单", text="全镇居民尺寸蜡像一套。数量：247。\n地下室入口藏在熔炉左侧，那里留下了七面镜子。")
    for i in range(7):
        obj("wax_basement", "mirror", 310+i*175, index=i)
    obj("wax_basement", "sign", 100, title="镜框后的刻度", text="七镜的正确刻度依次为：\n2 · 3 · 4 · 1 · 2 · 4 · 3\n每按一次 E 转动一格。所有角度吻合时，光会沿着七面镜子传向未完成的蜡块。")
    obj("hidden_archive", "memory", 780, item="fire_tag", title="磨平的消防志愿队牌", text="金属牌上没有姓名。\n不是她。还有另一个走进火场的人，被压在这段记忆里。")
    obj("hidden_archive", "switch", 1370, flag="archive_shortcut", title="档案室门闩", text="一条通向西环的近路打开了。")
    for i,x in enumerate([1120, 2380, 3660]):
        obj("old_theater", "thread", x, flag=f"thread_{i}", requires=["scissors"], title="红色控制线", text="剪断一根控制线。舞台深处的门松动了一些。")
    obj("old_theater", "switch", 3920, flag="theater_shortcut", title="舞台返程拉杆", text="返程侧门打开，现在可以直接回到西环。")
    obj("back_stage", "relic", 1670, item="theater_seal", grants=["doll", "double_jump", "vine", "final_ticket"], title="完整的双眼", text="所有破旧的布偶中，只有这一只没有裂痕。\n获得女孩布偶、剧院印记、二段跳与藤蔓攀爬。\n新的能力让旧地图的上层支路变得可达。")
    obj("back_stage", "memory", 1040, ROOMS["back_stage"]["floor"]-240, item="pierrot_note", title="最后的戏票", text="本券可作为『不被忘记』的凭证。票边卷曲，那不是血迹，是焦痕。")
    obj("dry_well", "sign", 2170, title="铁栅栏下的童谣", text="这里的歌声只有反复的半句。\n带着布偶进入井底；藤蔓旁按 W / S 攀爬。\n井底获得印记后可以打开通往地下室的排水闸。")
    obj("well_interior", "relic", 1680, item="well_seal", grants=["summer_photo", "dash"], title="夏令营合照", text="最后一天，他说要玩一个游戏。\n获得井底印记与短距离冲刺（Shift）。\n沿井壁返回，或者从排水闸离开。")
    obj("well_interior", "switch", 430, flag="well_shortcut", title="排水闸", text="井底与蜡像馆地下室重新连通。")
    obj("well_interior", "true_memory", 1060, title="那句话的后半截", text="来不及了，再进去就出不来了——把他拉出来！\n这一次，你终于听完了那句话。", requires=["clock_memory"])
    obj("clock_exterior", "sign", 850, title="过分正常的建筑", text="楼下所有线条都已扭曲，这里却依然精确。\n钟楼共七层，单向平台、升降台与齿轮连成向上的路线。")
    obj("clock_tower", "memory", 650, 2732, item="warden_note", title="越靠近上层，光越红", text="不要继续。你已经做得够多了。回去吧。")
    obj("clock_top", "flashback", 1450, item="clock_memory", title="七年前 · 那一夜", text="他冲进去。一趟，又一趟。\n最后一趟是为了小铃。他把她从井口拉上来，用外套裹住，背起来。\n横梁砸中右脸。意识断开前，他只听见：『来不及了——』")
    obj("clock_top", "ending", 880, ending="keeper", title="我帮你拧发条", requires=["clock_memory"])
    obj("fire_town", "sign", 1000, title="最后一趟", text="同一座小镇，终于显出了那一夜的颜色。\n前往停钟之处，或者再回一次枯井，找回那句话的后半截。")
    obj("shadow_roof", "ending", 920, ending="loop", title="举起武器")
    obj("shadow_roof", "ending", 1570, ending="accept", title="摘下帽子")
    obj("train_station", "ending", 1720, ending="zero", title="第零次循环")

    # Optional high-route fragments reward revisiting with the second jump.
    for key, item, title, text in [
        ("ring_east", "old_rooftops", "另一圈路", "你曾经从这里背着人跑过。现在只剩窗里的光。"),
        ("wax_lane", "wax_faces", "不会消失的脸", "如果我停下制作，蜡像就会开始流血。"),
        ("fire_town", "seven_selves", "七个自己", "七年，七个部分。你不需要抹去它们，才能离开这里。"),
    ]:
        obj(key, "memory", 1080, ROOMS[key]["floor"]-240, item=item, title=title, text=text)

    # Story-specific backgrounds and an optional ability-gated return route.
    for key, background in {"wax_museum":"museum", "wax_basement":"basement", "hidden_archive":"basement", "dry_well":"dry_well", "back_stage":"backstage"}.items():
        ROOMS[key]["background"] = background
    ROOMS["wax_basement"]["platforms"].append(dict(rect=[80,440,310,62],one_way=True))

    # Environment traversal instructions are kept with the room data.
    for o in ROOMS["dry_well"]["objects"]:
        if o["kind"] == "sign":
            o["text"] = "带着布偶进入井底。藤蔓旁按 W / S 攀爬；长距离坠落会失去生命。取得印记会唤醒黑泥。左侧排水闸是一条逃生近路。"
    for o in ROOMS["well_interior"]["objects"]:
        if o.get("item") == "well_seal":
            o["text"] = "最后一天，他说要玩一个游戏。获得井底印记与冲刺（Shift）。黑泥开始上涌！抓住藤蔓返回，或拉开左侧排水闸，从近路离开。"

    # Actual hazards live on solid islands, and gaps never exceed a base jump.
    for key, xs, kind in [
        ("wax_lane", [1850, 2780], "wax"), ("wax_museum", [1350, 2820], "wax"),
        ("old_theater", [1840, 2830], "thread"), ("fire_town", [1900, 3540, 5100], "fire"),
    ]:
        r = ROOMS[key]
        r["hazards"] = [dict(rect=[x, r["floor"]-18, 160, 20], kind=kind, period=3.8, phase=i*1.4) for i,x in enumerate(xs)]
    for key in ["well_interior", "clock_tower"]:
        r = ROOMS[key]
        r["vines"] = [[800, 250, 120, r["floor"]-250]]
        for j,y in enumerate(range(r["floor"]-420, 400, -740)):
            r["platforms"].append(dict(rect=[1300, y, 256, 64], one_way=True, travel=[0, -310], period=5.2+j*.3))
    for y in [3600, 2112, 624]:
        obj("clock_tower", "checkpoint", 1100, y)
    obj("well_interior", "checkpoint", 1100, 1600)
    ROOMS["clock_tower"]["vines"] = []
    # Every room has one high secret ledge reachable only with double jump.
    for r in ROOMS.values():
        if not r["vertical"] and r["id"] not in ["train_station", "wax_basement"]:
            r["platforms"].append(dict(rect=[1020, r["floor"]-240, 224, 62], one_way=True))
        w, h = r["size"]
        r["platforms"] = [p for p in r["platforms"] if p["rect"][0] < w and p["rect"][1] < h]
        for p in r["platforms"]:
            p["rect"][2] = min(p["rect"][2], w-p["rect"][0])
            p["rect"][3] = min(p["rect"][3], h-p["rect"][1])

    from build_exploration_upgrade import upgrade
    upgrade(ROOMS)
    from build_exploration_architecture import add_architecture, architecture_memories
    add_architecture(ROOMS)
    from build_exploration_v5 import upgrade_v5
    upgrade_v5(ROOMS)
    from build_exploration_v6 import upgrade_v6
    upgrade_v6(ROOMS)
    from build_exploration_v7 import upgrade_v7
    upgrade_v7(ROOMS)
    from build_exploration_v8 import upgrade_v8
    upgrade_v8(ROOMS)
    memories = {o["item"]: dict(title=o["title"], text=o.get("text", ""), room=k)
                for k,r in ROOMS.items() for o in r["objects"] if o["kind"] == "memory"}
    memories.update({
        "wax_seal": dict(title="蜡像订单", text="全镇居民尺寸蜡像一套。数量：247。订购人的名字被涂黑。"),
        "final_ticket": dict(title="最后的戏票", text="本券可作为『不被忘记』的凭证。"),
        "summer_photo": dict(title="夏令营合照", text="最后一天，他说要玩一个游戏。"),
        "clock_memory": dict(title="七年前的火光", text="他冲进去。一趟，又一趟。最后只听见：『来不及了——』"),
        "true_memory": dict(title="完整的记忆", text="来不及了，再进去就出不来了——把他拉出来！"),
    })
    memories.update(architecture_memories(ROOMS))
    result = dict(version=8, rooms=ROOMS, memories=memories, mirror_solution=[1,2,3,0,1,3,2],
                  themes={k: dict(accent=v) for k,v in {"town":"82c7d2", "wax":"dbb66d", "theater":"c97983", "well":"75c7b7", "clocktower":"e5ae63", "fire":"e28761", "station":"d1ddc9"}.items()})
    data_path = ROOT / "data/exploration/world.json"
    data_path.parent.mkdir(parents=True, exist_ok=True)
    data_path.write_text(json.dumps(result, ensure_ascii=False, indent=2), encoding="utf-8")
    scenes = ROOT / "scenes/exploration/maps"
    scenes.mkdir(parents=True, exist_ok=True)
    for key in ROOMS:
        (scenes/f"{key}.tscn").write_text(
            '[gd_scene load_steps=2 format=3]\n\n'
            '[ext_resource type="Script" path="res://scripts/exploration/exploration_room.gd" id="1"]\n\n'
            f'[node name="{key}" type="Node2D"]\nscript = ExtResource("1")\nroom_id = "{key}"\n', encoding="utf-8")
    print(f"Authored {len(ROOMS)} independent rooms, {sum(len(r['exits']) for r in ROOMS.values())} directed exits")


if __name__ == "__main__":
    build()
