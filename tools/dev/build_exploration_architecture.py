"""Place authored, world-anchored architecture and its physical interactions."""
from __future__ import annotations
import json
from pathlib import Path

HOUSE_NAMES = {
    "florist":"无人花店", "bakery":"熄炉面包房", "apothecary":"蓝瓶药铺", "bookshop":"旧书商的店",
    "watermill":"空桶水车工坊", "boardinghouse":"三窗旅舍", "clockshop":"修表匠的铺子", "postoffice":"无回信邮局",
    "wax_shop":"蜡面陈列店", "wax_workshop":"莫里斯的工棚", "theater_entry":"剧院售票亭", "costume_shop":"红线戏服间",
    "well_shelter":"井边守夜屋", "clock_works":"发条工房", "burnt_house":"余烬民居", "station_office":"晨光候车室",
}
CLUES = {
    "florist":("没有送出的花","柜台上压着一束枯花。包装纸被拆开又折好，像每天都在等同一个人来取。"),
    "bakery":("第二份早餐","账本上每天都有一份没有结清的早餐。日期变了，笔迹却没有变。"),
    "apothecary":("贴错的标签","药瓶的标签被反复撕贴。最后一张只写着：别在钟响前睡着。"),
    "bookshop":("折起的页角","同一页被翻开了太多次，纸张已经发亮。页角遮住了一句话的后半截。"),
    "watermill":("干涸的刻度","木桶内侧有一道旧水线。水早已干了，桶沿却依旧湿冷。"),
    "boardinghouse":("未退的房间","钥匙下压着一张旅客登记纸。姓名被涂黑，只留下一个帽子的简笔画。"),
    "clockshop":("慢了一拍","抽屉里的小表都慢同样的一拍。修表匠没有把它们调回去。"),
    "postoffice":("空白信封","柜台下堆着没有署名的信封。每封的折痕都完全相同。"),
    "wax_shop":("陈列架的空位","蜡滴绕开了最中间的空位。这里像是一直缺着最后一件作品。"),
    "wax_workshop":("擦拭过的工具","雕刻刀的握柄被磨得很亮。蜡屑里混着一小片烧焦的布。"),
    "theater_entry":("验过两次的票","检票口里卡着一张票。边缘有两次检票留下的缺口。"),
    "costume_shop":("没有剪完的线","针插上系着一根红线，线的另一头伸进墙缝。有人停在了最后一针之前。"),
    "well_shelter":("朝向井口的椅子","屋里只有一把椅子，椅背朝着炉火，座位朝着井口。"),
    "clock_works":("手掌的磨痕","发条柄上有一道很深的掌纹。握过它的人似乎很久没有松开手。"),
    "burnt_house":("门后的水桶","门后留着半只烧裂的木桶。桶把上缠着一块灰色布条。"),
    "station_office":("空着的长椅","候车室的长椅被擦得很干净。窗边留着一个放帽子的位置。"),
}


def add_architecture(rooms):
    region_file=Path(__file__).resolve().parents[2]/"data/exploration/art-regions.json"
    regions=json.loads(region_file.read_text(encoding="utf-8")) if region_file.exists() else {}
    placements = {
        "town_entrance":[("florist",610,420),("boardinghouse",2050,470),("postoffice",2780,340)],
        "ring_west":[("watermill",650,440),("bookshop",1860,450),("apothecary",2870,480)],
        "town_hub":[("bakery",980,390),("clockshop",2110,450),("postoffice",3480,360),("boardinghouse",4380,490)],
        "ring_east":[("apothecary",610,490),("costume_shop",2220,400),("theater_entry",3010,350)],
        "wax_lane":[("wax_shop",660,440),("wax_workshop",1920,400),("wax_mid",2970,450,2)],
        "wax_museum":[("wax_mid",650,450,0),("wax_workshop",1740,430),("wax_mid",3390,550,1)],
        "wax_basement":[("wax_mid",850,410,3)],
        "hidden_archive":[("bookshop",900,430)],
        "old_theater":[("theater_entry",670,470),("theater_mid",1800,510,0),("theater_mid",3050,490,1),("costume_shop",4120,390)],
        "back_stage":[("costume_shop",650,430),("theater_mid",1650,450,3)],
        "dry_well":[("well_shelter",650,400),("well_mid",1950,420,0),("well_mid",2900,450,1)],
        "well_interior":[("well_mid",1350,440,2,2700),("well_mid",550,440,3,1640),("well_shelter",1300,390,-1,520)],
        "clock_exterior":[("clockshop",700,450),("clock_works",1680,520)],
        "clock_tower":[("clock_mid",1250,500,0,4550),("clock_mid",550,510,2,3400),("clock_works",1260,510,-1,2260),("clock_mid",540,510,1,1080)],
        "clock_top":[("clock_works",680,510),("clock_mid",1690,470,1)],
        "fire_town":[("burnt_house",580,430),("fire_mid",1930,490,1),("fire_mid",3130,440,2),("fire_mid",4140,480,3),("fire_mid",5460,410,0)],
        "shadow_roof":[("clock_mid",650,450,2),("clock_mid",1580,480,3)],
        "train_station":[("station_office",670,400),("station_mid",1750,380,1)],
    }
    for key,r in rooms.items():
        r["buildings"]=[]
        r["street_props"]=[]
        if key=="town_entrance":
            for o in r["objects"]:
                if o.get("item")=="letter":
                    o["pos"][0]=240
        entries=placements.get(key,[])
        if r.get("region_pair"):
            # Connecting roads use structural landmarks, never copies of the
            # houses in the neighbouring districts or copies at several depths.
            pool={"town":[("street_props_a",0),("street_props_a",1),("street_props_b",2)],
                  "wax":[("wax_mid",0),("wax_mid",3),("street_props_b",0)],
                  "theater":[("theater_mid",2),("theater_mid",3),("street_props_a",3)],
                  "well":[("well_mid",0),("well_mid",2),("street_props_b",1)],
                  "clocktower":[("clock_mid",0),("clock_mid",2),("street_props_b",3)],
                  "fire":[("fire_mid",1),("fire_mid",2),("street_props_a",2)],
                  "station":[("station_mid",0),("station_mid",2),("street_props_b",2)]}[r["theme"]]
            index=int(key.rsplit("_",1)[1])
            for j in range(2 if r["vertical"] else 1):
                asset,cell=pool[(index+j)%len(pool)]
                r["street_props"].append(dict(asset=asset,cell=cell,pos=[450+j*580,r["floor"]-j*744],height=250+j*75,folder="midgrounds"))
        for j,entry in enumerate(entries):
            asset,x,height=entry[:3]
            cell=entry[3] if len(entry)>3 else -1
            y=entry[4] if len(entry)>4 else r["floor"]
            is_house=asset in HOUSE_NAMES
            region=regions.get(f"{asset}/{cell}",[0,0,690,440])
            scale=min(height/region[3],690/region[2]) if is_house else 1
            shown_width,shown_height=region[2]*scale,region[3]*scale
            ident=f"building_{key}_{j}"
            title,text=CLUES.get(asset,("留下的痕迹","表面上有一道反复擦拭留下的痕迹。没有人解释它为什么会在这里。"))
            interior=("wax_room" if r["theme"]=="wax" else "theater_room" if r["theme"]=="theater" else "mechanical_room" if r["theme"] in ("well","clocktower","fire") else "town_room")
            r["buildings"].append(dict(id=ident,asset=asset,cell=cell,folder="architecture" if is_house else "midgrounds",pos=[x,y],height=height,max_width=690 if is_house else 760,
                name=HOUSE_NAMES.get(asset, r["blocks"][min(j,len(r["blocks"])-1)]["name"]),enterable=is_house,interior=interior,
                balcony=is_house and j%2==0 and not r["vertical"],terrain=r["terrain"],clue_title=title,clue_text=text,
                clue_item=f"{ident}_note"))
            if is_house and not r["vertical"]:
                # Clear ornamental platforms crossing the new facade. Keep
                # ground, moving lifts and explicitly authored access/secret
                # ledges (the latter have no generic material tag).
                left,right=x-shown_width*.5,x+shown_width*.5
                r["platforms"]=[p for p in r["platforms"] if not (
                    p.get("one_way") and "material" in p and "travel" not in p and not clue_step(r,p)
                    and p["rect"][0]<right-25 and p["rect"][0]+p["rect"][2]>left+25
                    and y-shown_height+70<p["rect"][1]<y-35)]
            if is_house and r["vertical"]:
                r["platforms"].append(dict(rect=[max(0,x-180),y,min(360,r["size"][0]-max(0,x-180)),50],one_way=True,material=r["terrain"],variant=j%4))
        if r.get("main_region"):
            for j,block in enumerate(r["blocks"]):
                # Small independent props change the street rhythm without
                # covering doorways or repeating a second full facade.
                r["street_props"].append(dict(asset="street_props_a" if j%2==0 else "street_props_b",cell=(j+list(rooms).index(key))%4,
                    pos=[max(100,min(r["size"][0]-100,block["x"]-280)),block["y"]],height=95+(j%3)*30,folder="midgrounds"))


def architecture_memories(rooms):
    return {b["clue_item"]:dict(title=b["clue_title"],text=b["clue_text"],room=key)
            for key,r in rooms.items() for b in r.get("buildings",[]) if b["enterable"]}


def clue_step(room,platform):
    x,y,w,_=platform["rect"]
    for o in room["objects"]:
        ox,oy=o["pos"]
        if oy>=room["floor"]-80:
            continue
        if abs(y-oy)<4 and x<=ox<=x+w:
            return True
        if abs(y-(oy+120))<4 and x<=ox-140<=x+w:
            return True
    return False
