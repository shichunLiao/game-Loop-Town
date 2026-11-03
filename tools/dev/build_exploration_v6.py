"""Continuous scenery, safe village terrain, and direction-aware road landings."""
from __future__ import annotations

def upgrade_v6(rooms):
    for key,r in rooms.items():
        if r.get('interior'):
            continue
        # Actual district walls cover the complete height, not floating alpha panels.
        if r.get('vertical'):
            theme=r['theme']
            r['depth_background']='well_shaft' if theme=='well' else 'clock_shaft' if theme=='clocktower' else 'wax_shaft' if theme=='wax' else ''
            r['rear_scenery']=[]
            r['height_landmarks']=[]
            names={'well':['井口石环','根须回廊','沉积暗渠'],
                   'wax':['陈列层背墙','蒸汽维护廊','熔炉底座'],
                   'clocktower':['钟面与擒纵层','摆锤齿轮层','发条机房']}.get(theme,['上层拱廊','街区承重墙','地下石廊'])
            for j,name in enumerate(names):
                r['height_landmarks'].append(dict(name=name,y=round(r['size'][1]*(.16+j*.34))))
        for e in r['exits']:
            inset=145 if e['pos'][1]<r['floor']-100 else 210
            e['spawn_inset']=inset
            e['spawn']=[e['pos'][0]+(inset if e['direction']=='left' else -inset),e['pos'][1]-3]
    # Village means the full starting surface loop, including its street connections.
    village={'town_entrance','ring_west','town_hub','ring_east','clock_exterior'}
    for key,r in rooms.items():
        pair=r.get('region_pair',[])
        safe=key in village or (pair and set(pair)<=village)
        if safe:
            r['safe_village']=True
            r['platforms']=[p for p in r['platforms'] if p.get('one_way',False) or p.get('travel') or p['rect'][1]!=r['floor']]
            r['platforms'].insert(0,dict(rect=[0,r['floor'],r['size'][0],r['size'][1]-r['floor']],one_way=False,material=r['terrain'],variant=0))
            r['hazards']=[]
        if key=='ring_east':
            for block in r.get('blocks',[]):
                if block['name']=='断桥':
                    block['name']='修复石桥'
    # The surface ring wraps from the east street into the west edge of the entrance.
    for e in rooms['town_entrance']['exits']:
        if e['id'].startswith('ring_east--town_entrance'):
            e['pos']=[45,rooms['town_entrance']['floor']]
            e['direction']='left'
            e['spawn']=[255,e['pos'][1]-3]
    # The fire-town branch leaves the well district towards the west.
    for e in rooms['dry_well']['exits']:
        if e['id'].startswith('fire_town--dry_well'):
            e['pos'][0]-=450
            e['direction']='left'
            e['spawn']=[e['pos'][0]+145,e['pos'][1]-3]
            rooms['dry_well']['platforms'].append(dict(rect=[e['pos'][0]-60,e['pos'][1],650,52],one_way=True,material='stone',variant=2))
    # A return door in a connecting shaft faces away from the incoming movement.
    # This decouples stair height from horizontal approach, which was causing bounce-backs.
    for cid,c in rooms.items():
        if not c.get('region_pair'):
            continue
        width=c['size'][0]
        for back in c['exits']:
            source=rooms[back['target']]
            front=next(e for e in source['exits'] if e['target']==cid and e['id']==back['id'])
            incoming=front['direction']
            returning='right' if incoming=='left' else 'left'
            y=back['pos'][1]
            x=width-75 if returning=='right' else (355 if y<c['floor']-500 else 75)
            back['direction']=returning
            back['pos']=[x,y]
            back['spawn']=[x+(-210 if returning=='right' else 210),y-3]
            # Upper landings must extend under their safe arrival point.
            if y<c['floor']-500:
                c['platforms'].append(dict(rect=[280,y,width-280,52],one_way=True,material=c['terrain'],variant=1))
    rooms['wax_museum']['boss'].update(dict(hp=840,arena=[2350,3780],floor=rooms['wax_museum']['floor']))
    arena=rooms['wax_museum']
    arena['hazards']=[h for h in arena.get('hazards',[]) if h['rect'][0]+h['rect'][2]<2350 or h['rect'][0]>3780]
    arena['platforms']=[p for p in arena['platforms'] if not (p.get('one_way') and p['rect'][0]<3780 and p['rect'][0]+p['rect'][2]>2350 and p['rect'][1]>arena['floor']-330)]

    import json
    from pathlib import Path
    actor_file=Path(__file__).resolve().parents[2]/"data/exploration/actors.json"
    actors=json.loads(actor_file.read_text(encoding="utf-8"))
    actors["boss"].update(hp=840,phases=3,attacks=["fan","cleave","slam","rush","copies","rain"])
    actor_file.write_text(json.dumps(actors,ensure_ascii=False,indent=2),encoding="utf-8")
