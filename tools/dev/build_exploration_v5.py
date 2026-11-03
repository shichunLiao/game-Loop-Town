"""Authored interiors, residents, journal routes, and architectural road mechanisms."""
from __future__ import annotations
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]

def upgrade_v5(rooms):
    interiors = {}
    for room_id, r in rooms.items():
        for i, obj in enumerate(r['objects']):
            obj['uid'] = f"{room_id}:object:{obj.get('item', obj.get('flag', i))}"
        # A different rear silhouette per block; placed once in world space.
        r['rear_scenery'] = []
        theme = r['theme']
        atlas, cells = ('rear_town', [0,1,2,3]) if theme in ('town','station') else ('rear_regions', {'wax':[0], 'theater':[1], 'well':[2], 'clocktower':[3], 'fire':[0,3]}.get(theme,[0]))
        count = max(1, int(r['size'][0]//1150))
        for j in range(count):
            r['rear_scenery'].append(dict(asset=atlas,cell=cells[(j+sum(map(ord,room_id)))%len(cells)],pos=[480+j*1150,r['floor']+180],height=750+(j%3)*65))
        if r.get('vertical'):
            r['rear_scenery'] += [dict(asset=atlas,cell=cells[j%len(cells)],pos=[r['size'][0]*.55,y],height=680) for j,y in enumerate(range(600,r['floor']-500,1000))]
        for b in r.get('buildings',[]):
            if not b['enterable']:
                continue
            ident = 'inside_'+b['id']
            b['interior_scene'] = ident
            floor = 960
            interiors[ident] = dict(id=ident,name=b['name']+' · 室内',theme=theme,terrain='wood' if theme not in ('clocktower','well') else 'brass',audio=r['audio'],size=[2300,1120],floor=floor,spawn=[350,floor-2],checkpoint=[350,floor-2],vertical=False,main_region=False,interior=True,interior_art=b['interior'],parent_region=room_id,house_asset=b['asset'],house_index=len(interiors),return_pos=[b['pos'][0]-78,b['pos'][1]-2],return_room=room_id,objects=[dict(kind='interior_exit',pos=[170,floor],title='推门返回街道',target=room_id,uid=ident+':door'),dict(kind='memory',pos=[1320+(len(interiors)%3)*150,floor],item=b['clue_item'],title=b['clue_title'],text=b['clue_text'],uid=b['clue_item'])],platforms=[dict(rect=[0,floor,2300,160],material='wood'),dict(rect=[720, floor-125,210,32],material='wood',one_way=True),dict(rect=[1670,floor-230,300,32],material='wood',one_way=True),dict(rect=[2100,floor-125,160,32],material='wood',one_way=True)],exits=[],npcs=[],enemies=[],buildings=[],street_props=[],blocks=[])
            interiors[ident]['objects'][1]['style']='paper'
    # Stable instance identities let residents share art without sharing dialogue state.
    actor_names=['lamplighter','mother','waterman','seamstress','bookseller','usher','clocksmith','conductor']
    for room_id,r in rooms.items():
        for i,n in enumerate(r.get('npcs',[])):
            n['type']=n['id']; n['id']=f"resident_{room_id}_{i}"; n['role']={'lamplighter':'镇口守灯人','mother':'面包房的母亲','waterman':'水车旁的老人','seamstress':'后台裁缝','bookseller':'档案书商','usher':'老检票员','clocksmith':'老修表匠','conductor':'站台列车员'}.get(n['type'],'街区居民')
    placements={
        'town_entrance':[('lamplighter',1170,'灯下的引路人'),('mother',2490,'等信的母亲')],
        'ring_west':[('waterman',420,'水车看守'),('bookseller',1720,'西街书商')],
        'town_hub':[('clocksmith',1940,'广场修表匠'),('lamplighter',2940,'广场巡灯人'),('mother',4050,'面包房常客')],
        'ring_east':[('seamstress',2050,'戏服裁缝'),('usher',2810,'东街检票员')],
        'wax_lane':[('waterman',460,'送蜡工'),('bookseller',2460,'订单抄写员')],
        'wax_museum':[('lamplighter',880,'熔炉守灯人')],
        'wax_basement':[('bookseller',140,'镜室管理员')],
        'hidden_archive':[('bookseller',1450,'档案誊写员')],
        'old_theater':[('usher',880,'前厅引座员'),('seamstress',3260,'舞台缝补师')],
        'back_stage':[('seamstress',1950,'布偶保管人')],
        'dry_well':[('waterman',950,'井边提桶人'),('mother',2620,'守夜屋访客')],
        'clock_exterior':[('clocksmith',1070,'钟门维修人')],
        'clock_tower':[('clocksmith',560,'底层发条师')],
        'clock_top':[('clocksmith',1860,'停钟值守者')],
        'train_station':[('conductor',1430,'晨班列车员')],
        'fire_town':[('mother',900,'火光中的旧影'),('lamplighter',4400,'最后的守灯人')],
    }
    for room_id,entries in placements.items():
        r=rooms[room_id]
        for j,(kind,x,role) in enumerate(entries):
            r.setdefault('npcs',[]).append(dict(id=f"guide_{room_id}_{j}",type=kind,pos=[x,r['floor']],role=role,echo=room_id=='fire_town'))
    for i,(ident,r) in enumerate(interiors.items()):
        kind=actor_names[i%8]
        if i%2==0:
            r['npcs']=[dict(id='host_'+ident,type=kind,pos=[1040,960],role='屋内的'+{'town':'居民','wax':'工匠','theater':'缝补者','well':'守夜人','clocktower':'发条师','fire':'旧日住户','station':'值班人'}[r['theme']])]
    rooms.update(interiors)

    steps=[
        ('letter','第一张纸页','调查镇口路灯左侧的信，再沿西环街进入蜡像馆。','town_entrance',[240,940]),
        ('scissors','蜡像馆的剪刃','沿西环街、蜡像巷进入蜡像馆，拾取大剪刀。','wax_museum',[550,1140]),
        ('boss_morris','熔炉前的阻拦','击败蜡像馆深处的莫里斯。J 连击，H 恢复。','wax_museum',[3060,1140]),
        ('wax_seal','七面镜子的光','打开馆后地窖门。参考墙牌，把七面镜子转到 2、3、4、1、2、4、3。','wax_basement',[850,840]),
        ('theater_seal','没有剪完的戏','从东街打开剧院侧门，剪断三组红线，再打开后台防火门，调查完整布偶。','back_stage',[1670,940]),
        ('well_seal','井底的合照','到枯井，带布偶打开井口检修门。沿藤蔓下井，取得合照后立刻撤离。','well_interior',[1680,2840]),
        ('warden_note','进入七层钟楼','三枚印记齐全，回广场启动钟门，沿实际楼梯登塔，在中层调查守钟人的笔记。','clock_tower',[650,2732]),
        ('clock_memory','让钟声停止','继续登塔，在顶层触碰那一夜的记忆。','clock_top',[1450,1140]),
        ('true_memory','再回一次井底','火光之后重访井底，听完被打断的话。','well_interior',[1060,2840]),
        ('zero_loop','放下帽子','前往影子屋顶，选择摘下帽子，再沿右侧道路前往车站。','shadow_roof',[1570,1140]),
    ]
    main=[dict(id='main_'+item,flag=item,title=title,text=text,room=room,pos=pos) for item,title,text,room,pos in steps]
    side=[]
    # Every side request has a specific obtainable indoor document and a return address.
    houses=[(key,r,b) for key,r in rooms.items() for b in r.get('buildings',[]) if b['enterable']]
    chosen=['florist','watermill','bakery','costume_shop','wax_workshop','well_shelter','clockshop','station_office']
    requests=['未送出的花','干涸的水线','第二份早餐','最后一针','工具上的灰','朝向井口的椅子','慢了一拍的表','留给帽子的位置']
    for i,asset in enumerate(chosen):
        key,r,b=next(t for t in houses if t[2]['asset']==asset)
        candidates=r.get('npcs',[])
        if not candidates:
            continue
        npc=min((n for n in candidates if 'quest_id' not in n),key=lambda n:abs(n['pos'][0]-b['pos'][0]),default=candidates[0])
        quest_id=f'request_{i}'
        npc['quest_id']=quest_id
        side.append(dict(id=quest_id,title=requests[i],giver=npc['id'],giver_name=npc.get('role','居民'),return_room=key,return_pos=npc['pos'],flag=b['clue_item'],room=b['interior_scene'],pos=interiors[b['interior_scene']]['objects'][1]['pos'],text=f"进入{b['name']}，寻找「{b['clue_title']}」，再回来交谈。",reward='恢复生命与墨光，并记录居民的回忆'))
    gate_info={
      'scissors':('shears_door','缠线的剧院侧门','东街检票员','ring_east','大剪刀在蜡像馆。拿到后可切开门锁旁的红线，按 E 推开侧门。'),
      'boss_morris':('cellar_door','蜡像馆地窖门','熔炉守灯人','wax_museum','先击败莫里斯，再拿大剪刀剪开门轴蜡封，按 E 打开地窖门。'),
      'wax_seal':('archive_door','镜室档案门','镜室管理员','wax_basement','七面镜子的刻度依次为 2、3、4、1、2、4、3。光汇聚后，档案门的机关才能工作。'),
      'double_jump':('archive_door','高处档案检修门','镜室管理员','wax_basement','后台布偶会带回二段跳。镜室印记与二段跳齐备，再操作检修门。'),
      'archive_shortcut':('drawbridge','西街折叠桥','档案誊写员','hidden_archive','从档案室内侧拉动桥柄，才能放下返回西街的折叠桥。'),
      'theater_shortcut':('drawbridge','剧院后巷翻板桥','前厅引座员','old_theater','剧院右侧有一根旧拉杆。从内侧拉动后，回西街的桥才能放下。'),
      'thread_0':('fire_door','后台防火门','舞台缝补师','old_theater','用 J 或 E 剪断剧院三处红线，再到后台门按 E 拉开防火门。'),
      'theater_seal':('street_door','东街防疫路障','东街检票员','ring_east','后台有一个完整布偶，带回它的印记。蜡像与剧院两枚印记可以释放东街的道路绞盘。'),
      'doll':('well_hatch','井口检修门','井边提桶人','dry_well','布偶在剧院后台。带着它来到井边，按 E 打开检修门，再沿井道下行。'),
      'well_shortcut':('drain_gate','排水隧道闸门','井边提桶人','dry_well','井底左侧有排水拉杆。先拉闸，再从排水隧道返回蜡像地下室。'),
      'clock_memory':('clock_door','钟顶封闭回廊','停钟值守者','clock_top','触碰顶层记忆后，钟顶通往旧日街道的门才会回应。'),
      'zero_loop':('station_door','清晨车站门','晨班列车员','train_station','先听完井底的话，在影子面前摘下帽子，再推开通向车站的门。'),
      'well_seal':('clock_door','广场钟楼大门','广场修表匠','town_hub','蜡像馆、剧院、井底各有一枚印记。收齐三枚后回广场，按 E 转动大门的钟钥。'),
    }
    gates={}
    for r in rooms.values():
        for e in r['exits']:
            requirements=e.get('requires',[])
            if not requirements:
                continue
            key='well_seal' if len(requirements)==3 and 'well_seal' in requirements else 'boss_morris' if 'boss_morris' in requirements else 'double_jump' if 'double_jump' in requirements else 'theater_seal' if 'wax_seal' in requirements and 'theater_seal' in requirements else str(requirements[0])
            kind,title,role,hint_room,text=gate_info.get(key,('street_door','街道封门','灯下的引路人','town_entrance','沿街寻找记忆。'))
            e['gate_type']=kind; e['gate_title']=title; e['kind']='passage'
            gate_id=e['id'].rsplit('_',1)[0]
            e['gate_id']=gate_id
            if gate_id not in gates or r.get('main_region',True):
                gates[gate_id]=dict(id=gate_id,title=title,text=text,giver_name=role,hint_room=hint_room,requires=requirements,room=r['id'],pos=e['pos'])
    journal=dict(main=main,side=side,gates=gates)
    (ROOT/'data/exploration/quests.json').write_text(json.dumps(journal,ensure_ascii=False,indent=2),encoding='utf-8')
    weapons=[dict(id='notebook',name='墨页短刃',requires='',cell=-1,damage=18,reach=92,color='b8f2e4',windup=.075,active=.14,recovery=.19),dict(id='shears',name='裁断大剪刀',requires='scissors',cell=0,damage=28,reach=128,color='d8e2d0',windup=.1,active=.15,recovery=.22),dict(id='thread',name='红线双剪',requires='theater_seal',cell=1,damage=32,reach=142,color='f28d9f',windup=.07,active=.17,recovery=.18),dict(id='ember',name='井火钩刃',requires='well_seal',cell=2,damage=36,reach=154,color='76e8df',windup=.09,active=.18,recovery=.21),dict(id='clock',name='钟钥细剑',requires='time_slow',cell=3,damage=40,reach=172,color='f4d08c',windup=.065,active=.14,recovery=.17)]
    (ROOT/'data/exploration/weapons.json').write_text(json.dumps(weapons,ensure_ascii=False,indent=2),encoding='utf-8')
    print(f"V5: {len(interiors)} separate interiors, {sum(len(r.get('npcs',[])) for r in rooms.values())} residents, {len(main)+len(side)} authored quests, {len(gates)} mechanisms")
