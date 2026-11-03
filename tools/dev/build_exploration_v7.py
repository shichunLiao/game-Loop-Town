"""Architectural level composition: solid towns, anchored shafts, rest floors and shortcuts."""
from __future__ import annotations
import math

def tile_for(theme):
    return {'town':0,'wax':1,'theater':1,'well':3,'clocktower':2,'fire':1,'station':0}[theme]

def platform(r,x,y,w,h=46,**kw):
    r['platforms'].append(dict(rect=[round(x),round(y),round(w),round(h)],material=r['terrain'],
                              one_way=kw.pop('one_way',True),variant=kw.pop('variant',0),
                              masonry=tile_for(r['theme']),**kw))

def upgrade_v7(rooms):
    pools={
      'town':[('town_depth_v7',i) for i in range(4)]+[('town_mid',i) for i in range(4)],
      'wax':[('wax_depth_v7',i) for i in range(4)]+[('wax_mid',i) for i in range(4)],
      'well':[('well_depth_v7',i) for i in range(4)]+[('well_mid',i) for i in range(4)],
      'theater':[('stage_depth_v7',2),('stage_depth_v7',3)]+[('theater_mid',i) for i in range(4)]+[('wax_depth_v7',1),('town_depth_v7',1)],
      'clocktower':[('stage_depth_v7',0),('stage_depth_v7',1)]+[('clock_mid',i) for i in range(4)]+[('wax_depth_v7',1),('wax_depth_v7',3)],
      'fire':[('town_depth_v7',1),('town_depth_v7',3)]+[('fire_mid',i) for i in range(4)]+[('wax_depth_v7',0),('wax_depth_v7',3)],
      'station':[('town_depth_v7',0),('town_depth_v7',1)]+[('station_mid',i) for i in range(4)]+[('town_depth_v7',2),('town_depth_v7',3)]
    }
    for key,r in list(rooms.items()):
        if r.get('interior'):
            continue
        r['masonry']=tile_for(r['theme'])
        if r.get('vertical'):
            compose_shaft(key,r,rooms)
        else:
            pool=pools[r['theme']]
            offset=sum(map(ord,key))%len(pool)
            count=min(len(pool),max(3,math.ceil(r['size'][0]/700)))
            r['rear_scenery']=[]
            for j in range(count):
                asset,cell=pool[(offset+j)%len(pool)]
                r['rear_scenery'].append(dict(asset=asset,cell=cell,pos=[260+j*(r['size'][0]-520)/max(1,count-1),r['floor']+12],height=[340,430,290,390,360][j%5],role='courtyard' if j%2==0 else 'rear_wall'))
            for p in r['platforms']:
                p['masonry']=r['masonry']
                if not p.get('one_way') and p['rect'][1]>=r['floor']:
                    p['rect'][3]=max(900,p['rect'][3])
                    p['geometry']='ground'
                elif p.get('one_way') and not p.get('travel'):
                    p['support']='arch' if p['rect'][1]<r['floor']-180 else 'corbel'
                    p['support_floor']=r['floor']+50
            if r.get('buildings'):
                r['blocks']=[dict(name=b['name'],x=b['pos'][0],y=b['pos'][1],variant=j%4) for j,b in enumerate(r['buildings'])]
        r['static_vertical_background']=bool(r.get('vertical'))
    # A house's persistent return address follows its authored front door.
    for r in rooms.values():
        for b in r.get('buildings',[]):
            inside=rooms.get(b.get('interior_scene',''))
            if inside:
                inside['return_pos']=[b['pos'][0]-78,b['pos'][1]-2]

def compose_shaft(key,r,rooms):
    w,h=r['size']; floor=r['floor']; wall=200
    identity=sum(map(ord,key))
    profile=int(key[-2:])%4 if key.startswith('passage_') else identity%4
    has_lift=key in ('clock_tower','well_interior') or (key.startswith('passage_') and int(key[-2:])%4==0)
    core_right=w-530 if has_lift else w-wall
    mid=(wall+core_right)/2
    if key=='clock_tower':
        rests=[floor,4210,3600,2970,2112,1380,624,190]
    elif key=='well_interior':
        rests=[floor,2240,1600,1080,520,190]
    else:
        rests=[floor,*[(1260,730),(1190,690),(1310,810),(1160,710)][profile],200]
    rests=sorted(set(rests),reverse=True)
    r['platforms']=[]; r['hazards']=[]
    r['route_layout']=dict(wall=wall,core_right=core_right,rests=rests,lift=has_lift,shaft_x=w-420)
    r['spawn']=[wall+100,floor-3]
    if r['checkpoint'][0]<wall+35:
        r['checkpoint']=[wall+100,floor-3]
    # Keep the upper exit at a wall, so reaching the lift never crosses an
    # automatic room-transition trigger left in the centre of the landing.
    if key in ('clock_tower','well_interior'):
        for e in r['exits']:
            if e['pos'][1]<floor-500:
                e['pos'][0]=w-75
                e['spawn']=[w-220,e['pos'][1]-3]
    r['buildings']=[b for b in r.get('buildings',[]) if b.get('enterable')]
    for b in r['buildings']:
        b['max_width']=470; b['height']=min(b['height'],390)
        b['pos'][0]=min(b['pos'][0],core_right-240)
    platform(r,0,floor,w,900,one_way=False,geometry='ground')
    # Large resting bridges divide the climb into readable architectural chambers.
    names={'town':['街道入口','石梯转廊','上层庭台','街道出口'],
           'wax':['熔炉检修口','管道回廊','陈列层歇脚台','藏品侧廊'],
           'well':['井底蓄水池','排水石环','根须歇脚层','旧水渠','井口守夜廊'],
           'clocktower':['发条底座','配重机房','摆锤歇脚层','传动齿轮廊','擒纵层','钟面回廊','上层灯室','记忆门庭'],
           'theater':['后台入口','吊景检修廊','配重歇脚台','剧场出口'],
           'fire':['旧街基座','余烬拱廊','钟墙检修层','旧日出口'],
           'station':['站台基座','货运歇脚层','检修回廊','站台出口']}[r['theme']]
    r['blocks']=[]
    for i,y in enumerate(rests):
        label=names[min(i,len(names)-1)]
        r['blocks'].append(dict(name=label,x=round(mid),y=y,variant=i%4))
        if y!=floor:
            if has_lift:
                platform(r,wall,y,core_right-wall,62,geometry='rest',support='arch',support_floor=min(floor,y+210))
                platform(r,w-310,y,290,62,geometry='rest',support='corbel',support_floor=min(floor,y+180))
            else:
                platform(r,wall,y,w-2*wall,62,geometry='rest',support='arch',support_floor=min(floor,y+220))
        if i==len(rests)-1:
            continue
        upper=rests[i+1]
        jumps=math.ceil((y-upper)/126)
        # A chamber climbs one wall, crosses the central void, then meets a broad landing.
        rhythm=(i+profile)%3
        pattern=(['left','left','right','right','left'] if rhythm==0 else
                 ['right','left','left','right','left'] if rhythm==1 else
                 ['left','right','right','left','right'])
        for j in range(1,jumps):
            sy=round(y-(y-upper)*j/jumps)
            side=pattern[(j-1)%len(pattern)]
            if side=='left':
                end=mid-(65 if j%2 else 95)
                x=wall; width=end-wall
            else:
                x=mid+(65 if j%2 else 85); width=core_right-x
            platform(r,x,sy,width,44,geometry='ledge',support='left_corbel' if side=='left' else 'right_corbel',
                     support_floor=min(y,sy+180),variant=(i+j)%4)
    # Continuous collision walls have real door recesses instead of covering exits.
    for side,x in [('left',0),('right',w-wall)]:
        cuts=[]
        for e in r['exits']:
            ex,ey=e['pos']
            if (side=='left' and ex<wall+30) or (side=='right' and ex>w-wall-30):
                cuts.append((max(0,ey-240),min(h,ey+55)))
                platform(r,0 if side=='left' else w-wall-80,ey,wall+80,58,geometry='rest',support='corbel',support_floor=ey+140)
        wall_segments(r,x,wall,h,cuts)
    if has_lift:
        # A separate narrow lift shaft opens onto the resting bridges.
        wall_segments(r,core_right,58,h,[(max(0,y-225),min(h,y+70)) for y in rests])
    # Every narrative fixture keeps a reachable ledge. Houses are side alcoves.
    for b in r['buildings']:
        bx,by=b['pos']
        start=max(wall,bx-210); end=min(core_right,bx+230)
        platform(r,start,by,max(160,end-start),46,geometry='alcove',support='right_corbel',support_floor=by+170)
    r['street_props']=[]
    kit='well_depth_v7' if r['theme']=='well' else 'stage_depth_v7' if r['theme'] in ('clocktower','theater') else 'wax_depth_v7' if r['theme']=='wax' else 'town_depth_v7'
    r['shaft_details']=[]
    for i,y in enumerate(rests[:-1]):
        cell=(i+sum(map(ord,key)))%4
        r['shaft_details'].append(dict(asset=kit,cell=cell,folder='midgrounds',pos=[wall+80 if i%2==0 else core_right-75,y+10],height=280+(i%3)*45,flip=i%2==1))
        if i%2==profile%2:
            r['shaft_details'].append(dict(asset=kit,cell=(cell+2)%4,folder='midgrounds',pos=[core_right-90 if i%2==0 else wall+90,y-260],height=160+(i%2)*40,flip=i%2==0))
    # Short side investigations give the rest floors a purpose besides crossing.
    if key.startswith('passage_'):
        y=rests[1]
        side_x=wall+95 if profile%2 else core_right-105
        notes=[
          ('检修廊的铜牌','这条廊道的承重拱一直伸入两侧墙体。上层的手柄能接通旧吊笼，回程就不用再跳一次。' if has_lift else '磨损的石阶通向上层，带灯的宽台可以歇脚。沿着墙体两侧的挑台攀登。'),
          ('墙龛里的旧记事','守夜人把旧灯留在歇脚层。名字已经磨掉，下一班值夜的日期却始终没有变。'),
          ('配重旁的工匠笔记','先沿墙边走，再跨过中央的空隙。工匠把每一层的落脚处都修在能看见下一盏灯的地方。'),
          ('石环上的刻痕','石环上有许多提着重物停步留下的划痕。有人在这里等过，也有人继续向上走了。')][profile]
        r['objects'].append(dict(kind='memory',pos=[side_x,y],title=notes[0],text=notes[1],item='shaft_note_'+key,uid='shaft_note_'+key,style='paper'))
    # Attach ground creatures to the new floors while keeping the authored chapter.
    for npc in r.get('npcs',[]):
        seat_actor(npc,r)
    for enemy in r.get('enemies',[]):
        if enemy.get('type') not in ('red_moth','well_wisp'):
            seat_actor(enemy,r)
    if key=='well_interior':
        r['vines']=[[w-420-65,rests[-1]+150,95,floor-rests[-1]-220]]
    else:
        r['vines']=[]
    if has_lift:
        lift_id='lift_'+key
        unlock=lift_id+'_unlocked'; up=lift_id+'_up'
        r['platforms'].append(dict(rect=[w-500,floor-24,160,35],one_way=True,material='brass' if r['theme']=='clocktower' else 'wood',
                                  geometry='lift',masonry=r['masonry'],manual_lift=True,lift_unlock=unlock,lift_up=up,
                                  travel=[0,rests[-1]-(floor-24)],lift_speed=430))
        top=rests[-1]
        top_x=core_right-150
        for e in r['exits']:
            if abs(e['pos'][1]-top)<80 and e['pos'][0]<core_right:
                top_x=e['pos'][0]+(270 if e['direction']=='left' else -270)
        top_x=max(wall+70,min(core_right-70,top_x))
        r['objects'] += [
            dict(kind='lift_call',pos=[top_x,top],title='接通 / 呼叫返程吊笼',unlock=unlock,flag=up,value=True,opens=True,uid=lift_id+':upper'),
            dict(kind='lift_call',pos=[core_right-130,floor],title='呼叫吊笼至下层',unlock=unlock,flag=up,value=False,uid=lift_id+':lower')]

def wall_segments(r,x,width,height,cuts):
    merged=[]
    for start,end in sorted(cuts):
        if merged and start<=merged[-1][1]:
            merged[-1][1]=max(merged[-1][1],end)
        else:
            merged.append([start,end])
    cursor=0
    for start,end in merged+[[height,height]]:
        if start>cursor:
            platform(r,x,cursor,width,start-cursor,one_way=False,geometry='wall')
        cursor=max(cursor,end)

def seat_actor(actor,r):
    x,y=actor['pos']
    candidates=[p for p in r['platforms'] if p.get('geometry') not in ('wall','lift') and p['rect'][0]+20<=x<=p['rect'][0]+p['rect'][2]-20]
    if candidates:
        best=min(candidates,key=lambda p:abs(p['rect'][1]-y))
        actor['pos'][1]=best['rect'][1]
