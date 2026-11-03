"""Version 3: authored districts, physical connecting corridors and actor placement."""
from __future__ import annotations

import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]

NPCS = [
    ("lamplighter", "点灯人", "npcs_a", 0, "灯会记得你走过的路。别怕绕远，我总会在这里点亮下一盏。", "我认得这顶帽子……钟声一响，我又想不起来了。"),
    ("mother", "抱着布包的女人", "npcs_a", 1, "我在等一个人。他每一次都说，还有最后一趟。", "你的右脸……不，对不起。我又说错了。"),
    ("waterman", "提水老人", "npcs_a", 2, "水桶是空的，我还是得把它送过去。西边的楼梯通向蜡像巷。", "楼梯一层一层地走。你从前背着人，也这样走过。"),
    ("seamstress", "缝衣匠", "npcs_a", 3, "红线绷得太紧了。大剪刀能剪开它们，也能挡开那些坏掉的木偶。", "后台那只双马尾布偶，眼睛一直完好。"),
    ("bookseller", "旧书商", "npcs_b", 0, "七面镜子，七个方向。被烧掉的书页里，还压着一枚金属牌。", "纸上的指控，和纸上的证词，有时是同一句话。"),
    ("usher", "检票人", "npcs_b", 1, "戏还没散场。顺着红线往上，找到后台的门。", "最后一张票不卖。那是给一个不该被忘记的人留的。"),
    ("clocksmith", "钟表修理匠", "npcs_b", 2, "三枚印记才开得了钟楼。发条外庭的楼梯通往上层，不要跳过台阶。", "你听得见齿轮的间隙了吗？握住那一瞬，时间就会慢下来。"),
    ("conductor", "站务员", "npcs_b", 3, "有一班车，一直在等一个肯摘下帽子的人。", "这一次，可以出发了。"),
]

ENEMIES = [
    dict(id="wax_walker", name="踉跄蜡像", atlas="enemies_a", cell=0, hp=50, speed=64, damage=12, behavior="patrol", height=98, range=80),
    dict(id="wax_spitter", name="烛泪喷吐者", atlas="enemies_a", cell=1, hp=65, speed=25, damage=14, behavior="ranged", height=110, range=420),
    dict(id="puppet", name="断线木偶", atlas="enemies_a", cell=2, hp=45, speed=105, damage=13, behavior="lunge", height=104, range=140),
    dict(id="red_moth", name="红线飞蛾", atlas="enemies_a", cell=3, hp=30, speed=90, damage=9, behavior="fly", height=64, range=110),
    dict(id="mud_crawler", name="黑泥爬行者", atlas="enemies_b", cell=0, hp=60, speed=88, damage=14, behavior="patrol", height=67, range=76),
    dict(id="well_wisp", name="井底回声", atlas="enemies_b", cell=1, hp=35, speed=68, damage=10, behavior="fly", height=100, range=125),
    dict(id="gear_sentry", name="发条哨兵", atlas="enemies_b", cell=2, hp=95, speed=50, damage=19, behavior="guard", height=116, range=105),
    dict(id="ember_resident", name="火中的居民", atlas="enemies_b", cell=3, hp=40, speed=42, damage=3, behavior="hesitant", height=103, range=70),
]


def platform(r, x, y, w, *, one=True, height=52, **kw):
    r["platforms"].append(dict(rect=[round(x), round(y), round(w), height], one_way=one, **kw))


def upgrade(rooms):
    main_keys = list(rooms)
    links = []
    seen = set()
    for a in main_keys:
        for e in rooms[a]["exits"]:
            if e["id"] not in seen:
                b = e["target"]
                rev = next(x for x in rooms[b]["exits"] if x["id"] == e["id"])
                links.append((a, b, e.copy(), rev.copy()))
                seen.add(e["id"])
        rooms[a]["exits"] = []

    # Each district has an authored silhouette and distinct block landmarks.
    landmarks = {
        "town_entrance": ["入镇石桥", "无人花店", "折翼天使门楼"],
        "ring_west": ["水车院", "悬挑民居", "书商的连廊"],
        "town_hub": ["环形喷泉", "钟表匠工坊", "高架钟庭", "弧形集市"],
        "ring_east": ["斜屋顶", "断桥", "双层晾衣廊"],
        "wax_lane": ["蜡面橱窗", "倾斜陈列亭", "烛泪桥"],
        "wax_museum": ["雕像陈列廊", "熔炉战场", "通往镜室的斜井"],
        "wax_basement": ["七镜光路", "蜡池暗渠"],
        "hidden_archive": ["封存书架", "消防志愿队档案"],
        "old_theater": ["前厅包厢", "红线舞台", "坍塌乐池", "后台吊台"],
        "back_stage": ["戏服走廊", "缝纫桌", "布偶摇篮"],
        "dry_well": ["同向枯林", "淹水石径", "旧井房"],
        "well_interior": ["破裂井环", "根须层", "回声暗渠", "倒悬井底"],
        "clock_exterior": ["发条门庭", "雕花扶梯"],
        "clock_tower": ["摆锤层", "齿轮层", "钟面层", "红光层", "发条层", "回声层", "记忆层"],
        "clock_top": ["巨钟背面", "停摆的发条"],
        "fire_town": ["燃烧石桥", "坍塌民居", "旧井返程", "炭化广场", "余烬高架"],
        "shadow_roof": ["无声钟台", "长夜的尽头"],
        "train_station": ["铁轨边缘", "等待的长椅", "晨光站台"],
    }
    for index, key in enumerate(main_keys):
        r = rooms[key]
        r["seed"] = int(hashlib.sha256(key.encode()).hexdigest()[:7], 16)
        r["main_region"] = True
        r["npcs"], r["enemies"] = [], []
        r["blocks"] = []
        names = landmarks[key]
        for j, name in enumerate(names):
            x = (j+.5)*r["size"][0]/len(names)
            y = r["floor"] if not r["vertical"] else r["floor"]-j*(r["floor"]-250)/max(1,len(names)-1)
            r["blocks"].append(dict(name=name, x=round(x), y=round(y), variant=(j+index)%4))
        # Replace generic balconies with districts of different span, material and cadence.
        if not r["vertical"]:
            r["platforms"] = [p for p in r["platforms"] if not p.get("one_way")]
            for j, block in enumerate(r["blocks"]):
                x, floor = block["x"], r["floor"]
                if key in ["wax_basement", "hidden_archive", "train_station"]:
                    continue
                if r["theme"] == "theater":
                    profile = [(-280,120,210),(-20,235,370),(385,115,155)]
                elif r["theme"] == "fire":
                    profile = [(-300,95,170),(-90,210,230),(180,325,290),(510,170,140)]
                elif r["theme"] == "well":
                    profile = [(-250,105,200),(5,220,245),(315,115,160)]
                elif j % 2:
                    profile = [(-280,110,205),(-30,225,280),(305,340,245),(600,190,170)]
                else:
                    profile = [(-230,125,195),(15,245,330),(400,125,180)]
                for dx, rise, width in profile:
                    px = max(12,min(r["size"][0]-width-12,x+dx))
                    platform(r,px,floor-rise,width,material=("wood" if j%3==1 else r["terrain"]),variant=(j+index)%4)
            # Optional memory ledges are explicitly approached, not left floating.
            for o in r["objects"]:
                if o["pos"][1] < r["floor"]-100:
                    ox, oy = o["pos"]
                    platform(r,max(0,ox-220),oy+120,180)
                    platform(r,max(0,ox-90),oy,230)
        for j,p in enumerate(r["platforms"]):
            p.setdefault("variant",(index+j)%4)
            p.setdefault("material",r["terrain"])

    npc_positions = [
        ("town_entrance",730), ("town_hub",1080), ("ring_west",960),
        ("back_stage",730), ("hidden_archive",620), ("old_theater",620),
        ("clock_exterior",650), ("train_station",960),
    ]
    for n,(room,x) in zip(NPCS,npc_positions):
        rooms[room]["npcs"].append(dict(id=n[0],pos=[x,rooms[room]["floor"]]))
    placements = {
        "town_entrance":[("wax_walker",2280)],
        "ring_west":[("wax_walker",1850),("wax_spitter",2570)],
        "wax_lane":[("wax_walker",1220),("wax_spitter",2040),("wax_walker",2940)],
        "wax_museum":[("wax_walker",1080),("wax_spitter",1600)],
        "old_theater":[("puppet",1260),("red_moth",2220),("puppet",3050),("red_moth",3940)],
        "ring_east":[("puppet",1280),("red_moth",2880)],
        "dry_well":[("mud_crawler",1230),("well_wisp",1940),("mud_crawler",2780)],
        "well_interior":[("well_wisp",1120,2356),("mud_crawler",1530),("well_wisp",600,1020)],
        "clock_tower":[("gear_sentry",620,3972),("red_moth",1060,3000),("gear_sentry",620,2484),("well_wisp",600,1500)],
        "clock_top":[("gear_sentry",1090)],
        "fire_town":[("ember_resident",1240),("ember_resident",2250),("ember_resident",3490),("ember_resident",4880),("wax_spitter",5400)],
    }
    for key,entries in placements.items():
        r=rooms[key]
        for j,e in enumerate(entries):
            r["enemies"].append(dict(id=f"{key}_{j}",type=e[0],pos=[e[1],e[2] if len(e)>2 else r["floor"]],patrol=240))
    rooms["wax_museum"]["boss"] = dict(type="morris",pos=[3060,rooms["wax_museum"]["floor"]],arena=[2350,3700])
    # Defeating Morris opens the mirror workshop; skill acquisition is staged.
    for a,b,ea,eb in links:
        if {a,b} == {"wax_museum","wax_basement"}:
            ea["requires"]=["scissors","boss_morris"]
            eb["requires"]=["scissors","boss_morris"]
            ea["hint"]=eb["hint"]="先在熔炉战场击败莫里斯，镜室的机械锁才会松开。"
    for o in rooms["wax_museum"]["objects"]:
        if o.get("item")=="scissors":
            o["text"]="获得大剪刀：J 的近战范围与伤害提升；K 剪刃突进。W / S + J 可向上 / 下攻击。击败熔炉前的莫里斯，打开镜室通路。"
    for o in rooms["clock_tower"]["objects"]:
        if o.get("item")=="warden_note":
            o["grants"]=["time_slow"]
            o["text"]+="\n获得发条缓时：Q 让身边敌人、弹幕与机关暂时减速。"
    for o in rooms["town_hub"]["objects"]:
        if o["kind"]=="sign":
            o["text"]="西环的上行楼梯通向蜡像馆；东环的上层通向剧院，下层通向枯井。三枚印记能开启钟楼。地图只标记路线，所有道路都需实际走过。"
    for o in rooms["town_entrance"]["objects"]:
        if o["kind"]=="sign":
            o["text"]="A / D 移动，Space 跳跃，J 攻击，H 消耗墨光恢复生命。\nS + Space 可穿下单向平台。路灯按 E 保存。道路走到尽头自动通行，高台常藏着支路。M 查看全域地图，Tab 查看记忆与能力。"
    for o in rooms["dry_well"]["objects"]:
        if o["kind"]=="sign":
            o["text"]+="\nS + Space 可穿下脚边的平台。井道要逐层下降，不要直接跳到底。"

    # A physical corridor is built for each map edge. Vertical edges require
    # climbing an actual stairwell; there are no interaction teleports.
    for index,(a,b,ea,eb) in enumerate(links):
        ra,rb=rooms[a],rooms[b]
        ac=[ra["map_rect"][0]+ra["map_rect"][2]/2,ra["map_rect"][1]+ra["map_rect"][3]/2]
        bc=[rb["map_rect"][0]+rb["map_rect"][2]/2,rb["map_rect"][1]+rb["map_rect"][3]/2]
        dy=bc[1]-ac[1]
        vertical=abs(dy)>.85
        cid=f"passage_{index:02d}"
        w,h=(1540,1900) if vertical else (1720,980)
        floor=h-160
        c=dict(id=cid,name=("上行楼梯" if dy<0 else "下行井道") if vertical else "环路连廊",
               theme=ra["theme"],terrain=ra["terrain"],background=ra.get("background",ra["theme"]),size=[w,h],floor=floor,
               vertical=vertical,main_region=False,region_pair=[a,b],seed=index*311+73,
               map_rect=[(ac[0]+bc[0])/2-.15,(ac[1]+bc[1])/2-.15,.3,.3],
               spawn=[160,floor],checkpoint=[160,floor],objects=[],hazards=[],vines=[],npcs=[],enemies=[],blocks=[],
               audio=ra["audio"],platforms=[],exits=[])
        if vertical:
            # 124px risers, 200px horizontal gaps fit the unupgraded jump.
            platform(c,0,floor,w,one=False,height=160)
            for j,y in enumerate(range(floor-124,200,-124)):
                platform(c,320 if j%2==0 else 850,y,390)
            platform(c,280,200,w-280)
            platform(c,1210,floor-420,230,travel=[0,-900],period=8.0)
            ca,cb=([180,floor],[1130,200]) if dy<0 else ([1130,200],[180,floor])
        else:
            platform(c,0,floor,w,one=False,height=160)
            for j in range(3):
                platform(c,370+j*370,floor-100-(j%2)*115,230+(index+j)%3*45)
            ca,cb=([80,floor],[w-80,floor]) if bc[0]>=ac[0] else ([w-80,floor],[80,floor])
        for source,target,old,cp,side in [(ra,rb,ea,ca,"a"),(rb,ra,eb,cb,"b")]:
            x,y=old["pos"]
            # Preserve authored upper landings in the well and clock tower.
            if y<source["floor"]-500:
                platform(source,max(20,x-200),y,420)
                endpoint=[x,y]
                approach="right"
            elif x<230 or x>source["size"][0]-300:
                toward_right=(bc[0]>=ac[0]) if side=="a" else (ac[0]>=bc[0])
                # Horizontal corridors leave on the geographic side shown
                # on the atlas. Vertical shafts keep their authored landing.
                if not vertical and {a,b}!={"ring_east","town_entrance"}:
                    x=source["size"][0]-45 if toward_right else 45
                else:
                    x=45 if x<230 else source["size"][0]-45
                endpoint=[x,source["floor"]]
                approach="left" if x<source["size"][0]*.5 else "right"
            else:
                # Branches sit on a raised side street so passing on the main
                # ground never accidentally switches rooms.
                x=max(380,min(source["size"][0]-380,x))
                y=source["floor"]-360
                platform(source,x-330,y+240,180)
                platform(source,x-100,y+120,185)
                platform(source,x+130,y,245)
                endpoint=[x+315,y]
                approach="right"
            if any(abs(p["pos"][0]-endpoint[0])<140 and abs(p["pos"][1]-endpoint[1])<150 for p in source["exits"]):
                # Separate competing streets with a raised branch, never
                # place two automatic boundaries on the same strip of ground.
                pivot=420 if endpoint[0]<source["size"][0]*.5 else source["size"][0]-420
                y=source["floor"]-360
                if endpoint[0]<source["size"][0]*.5:
                    platform(source,pivot+150,y+240,180)
                    platform(source,pivot-85,y+120,185)
                    platform(source,pivot-375,y,245)
                    endpoint=[pivot-315,y]
                    approach="left"
                else:
                    platform(source,pivot-330,y+240,180)
                    platform(source,pivot-100,y+120,185)
                    platform(source,pivot+130,y,245)
                    endpoint=[pivot+315,y]
                    approach="right"
            tag=old["id"]+"_"+side
            source["exits"].append(dict(id=tag,target=cid,pos=endpoint,spawn=[endpoint[0]+(110 if approach=="left" else -110),endpoint[1]-3],
                requires=old["requires"],hint=old.get("hint",""),label=target["name"],direction=approach,corridor=True))
            direction="left" if cp[0]<w*.5 else "right"
            c["exits"].append(dict(id=tag,target=source["id"],pos=cp,spawn=[cp[0]+(110 if direction=="left" else -110),cp[1]-3],
                requires=[],label=source["name"],direction=direction,corridor=True))
        c["blocks"]=[dict(name=f"{ra['name']} → {rb['name']}",x=w//2,y=floor,variant=index%4)]
        if vertical:
            c["blocks"] += [dict(name="井壁中层",x=w*2//3,y=floor-650,variant=(index+1)%4),
                            dict(name="上层平台",x=w//3,y=200,variant=(index+2)%4)]
        rooms[cid]=c

    output=dict(npcs={n[0]:dict(id=n[0],name=n[1],atlas=n[2],cell=n[3],lines=list(n[4:])) for n in NPCS},
                enemies={e["id"]:e for e in ENEMIES},
                boss=dict(id="morris",name="莫里斯 · 第 247 张脸",hp=620,damage=22,height=210),
                skills=[dict(id="notebook",stage="初到镇口",keys="J / 方向 + J",name="笔记本挥击"),
                        dict(id="scissors",stage="蜡像馆",keys="J / K",name="剪刃连击 / 剪刃突进"),
                        dict(id="double_jump",stage="剧院后台",keys="Space × 2",name="记忆二段跳"),
                        dict(id="vine",stage="剧院后台",keys="W / S",name="藤蔓攀爬"),
                        dict(id="dash",stage="井底",keys="Shift",name="余烬冲刺"),
                        dict(id="time_slow",stage="钟楼中层",keys="Q",name="发条缓时")])
    (ROOT/"data/exploration/actors.json").write_text(json.dumps(output,ensure_ascii=False,indent=2),encoding="utf-8")
