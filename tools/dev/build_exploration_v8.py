"""Repair street architecture and explicitly anchor all middle scenery."""
from pathlib import Path
import json

ROOT=Path(__file__).resolve().parents[2]


def upgrade_v8(rooms):
    for key,r in rooms.items():
        if r.get('interior'):
            continue
        if r['theme']=='town' and not r.get('vertical'):
            repair_street(key,r)
        # Every freestanding rear object has the same authored ground plane.
        for entry in r.get('rear_scenery',[]):
            entry['pos'][1]=r['floor']+5
            entry['mount']='ground'
        for entry in r.get('street_props',[]):
            entry['pos'][1]=r['floor']+4
            entry['mount']='ground'
        # Wall details belong to a real deck, not arbitrary offsets in the air.
        for entry in r.get('shaft_details',[]):
            x,y=entry['pos']
            floors=[p for p in r['platforms'] if p.get('geometry') not in ('wall','lift')
                    and p['rect'][0]<=x<=p['rect'][0]+p['rect'][2]]
            if floors:
                floor=min(floors,key=lambda p:abs(p['rect'][1]-y))['rect'][1]
                entry['pos'][1]=floor+5
                entry['mount']='deck'
    # Gate investigation markers must follow the new grounded street doors.
    path=ROOT/'data/exploration/quests.json'
    quests=json.loads(path.read_text(encoding='utf-8'))
    for gate_id,gate in quests['gates'].items():
        r=rooms.get(gate.get('room',''),{})
        exit=next((e for e in r.get('exits',[]) if e.get('gate_id')==gate_id),None)
        if exit:
            gate['pos']=exit['pos'].copy()
    path.write_text(json.dumps(quests,ensure_ascii=False,indent=2),encoding='utf-8')


def repair_street(key,r):
    floor=r['floor']; width=r['size'][0]
    r['street_architecture']=True
    # Existing houses are the architecture: never fill the street in front
    # of their windows with generic challenge platforms or masonry wedges.
    r['platforms']=[p for p in r['platforms'] if not p.get('one_way') and p.get('geometry')=='ground']
    for b in r.get('buildings',[]):
        b['balcony']=False
    r['street_access']=[]
    for e in r['exits']:
        if e['pos'][1]<floor-80 or 230<e['pos'][0]<width-230:
            e['manual_entry']=True
            e['pos'][1]=floor
            e['spawn']=[e['pos'][0]-145 if e['direction']=='right' else e['pos'][0]+145,floor-3]
            e['gate_type']='clock_door' if 'clock_exterior' in e['id'] else e.get('gate_type','street_door')
    # Keep the back-stage service door beside the theater, clear of its
    # separate interior door and of the eastern automatic map boundary.
    if key=='ring_east':
        for e in r['exits']:
            if e['id'].startswith('back_stage--'):
                e['pos'][0]=3330
            elif e['id'].startswith('ring_east--dry_well'):
                e['pos'][0]=2580
            if e.get('manual_entry'):
                e['spawn']=[e['pos'][0]-145,floor-3]
    # Limited optional roof walks follow actual painted roof contours.
    choices={'town_entrance':'postoffice','ring_west':'bookshop',
             'town_hub':'postoffice','ring_east':'costume_shop'}
    house=next((b for b in r.get('buildings',[]) if b['asset']==choices.get(key)),None)
    if house:
        regions=json.loads((ROOT/'data/exploration/art-regions.json').read_text(encoding='utf-8'))
        _,_,aw,ah=regions[house['asset']+'/-1']
        scale=min(house['height']/ah,house['max_width']/aw)
        bw=aw*scale; bh=ah*scale; cx,cy=house['pos']
        if house['asset']=='postoffice':
            contour=[[-.49,-.46],[-.37,-.77],[-.09,-.76],[.02,-.94],[.13,-.76],[.37,-.76],[.49,-.46]]
        elif house['asset']=='bookshop':
            contour=[[-.38,-.47],[-.28,-.82],[.30,-.81],[.38,-.47]]
        else:
            # Follow the costume shop's roof and lower storage canopy.
            contour=[[-.47,-.48],[-.26,-.73],[-.03,-.72],[.06,-.91],[.25,-.52],[.46,-.36]]
        points=[[round(cx+nx*bw),round(cy+ny*bh)] for nx,ny in contour]
        r['street_access'].append(dict(kind='roof',points=points,house=house['id']))
        start_x=points[0][0]; top_y=points[0][1]
        run=max(190,round((floor-top_y)*1.55))
        r['street_access'].append(dict(kind='stairs',points=[[max(45,start_x-run),floor],[start_x+8,top_y]],house=house['id']))
        # Optional documents now rest on the house, not an absent stone step.
        for o in r['objects']:
            if o.get('item') in ('resident_note','old_rooftops'):
                a,b=points[1:3] if len(points)>2 else points
                o['pos']=[round((a[0]+b[0])/2),round((a[1]+b[1])/2)]
                o.pop('style',None)
    for o in r['objects']:
        if o['kind']=='sign':
            o['pos'][1]=floor
