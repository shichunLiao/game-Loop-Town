"""Export a native SVG diagram from the same geometry used by the game."""
import json
from html import escape
from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]
rooms=json.loads((ROOT/'data/exploration/world.json').read_text(encoding='utf-8'))['rooms']
chosen=['passage_05','passage_08','well_interior','clock_tower']
svg=['<svg xmlns="http://www.w3.org/2000/svg" width="1680" height="1050" viewBox="0 0 1680 1050">','<rect width="1680" height="1050" fill="#111d24"/>',
     '<g font-family="Microsoft YaHei, sans-serif" fill="#e4d7b6"><text x="48" y="50" font-size="28">回环镇 Demo 8 · 竖向建筑路线</text>',
     '<text x="48" y="80" font-size="15" fill="#9eb9ba">读取实际关卡数据：宽台分层 / 墙边挑台 / 侧廊调查 / 上层解锁的返程吊笼。各栏纵向比例独立。</text>']
for i,key in enumerate(chosen):
    r=rooms[key]; w,h=r['size']; sx=320/w; sy=780/h; ox=50+i*410; oy=155
    def rect(x,y,width,height,color):
        return f'<rect x="{ox+x*sx:.1f}" y="{oy+y*sy:.1f}" width="{width*sx:.1f}" height="{max(2,height*sy):.1f}" fill="{color}"/>'
    svg += [f'<text x="{ox}" y="122" font-size="21">{escape(r["name"])} · {key}</text>',f'<text x="{ox}" y="143" font-size="12" fill="#9eb9ba">{w} × {h} / {len(r["route_layout"]["rests"])} 个宽台层</text>',rect(0,0,w,h,'#1c2c35')]
    for p in r['platforms']:
        x,y,pw,ph=p['rect']
        if p.get('geometry')=='lift':continue
        svg.append(rect(x,y,pw,min(ph,h-y),'#3d5058' if p.get('geometry')=='wall' else '#c19a60'))
    route=r['route_layout']
    if route['lift']:
        lx=ox+route['shaft_x']*sx
        svg.append(f'<path d="M {lx:.1f} {oy+route["rests"][-1]*sy:.1f} V {oy+r["floor"]*sy:.1f}" fill="none" stroke="#81d0c9" stroke-width="4" stroke-dasharray="9 5"/>')
    for obj in r['objects']:
        if obj['kind'] not in ('memory','relic','true_memory','lift_call','checkpoint'):continue
        px,py=obj['pos']; color='#81d0c9' if obj['kind']=='lift_call' else '#c7e0ad'
        svg.append(f'<circle cx="{ox+px*sx:.1f}" cy="{oy+py*sy-5:.1f}" r="4" fill="{color}"/>')
    for e in r['exits']:
        px,py=e['pos']
        svg.append(f'<circle cx="{ox+px*sx:.1f}" cy="{oy+py*sy-7:.1f}" r="7" fill="#e8ad7c"/><text x="{ox+px*sx-8:.1f}" y="{oy+py*sy-20:.1f}" font-size="13">出口</text>')
svg += ['<text x="48" y="986" font-size="16">灰蓝：实体侧墙　金色：可站立地形　青线：返程吊笼　浅绿点：线索 / 路灯　橙点：实际换图出口</text>',
        '<text x="48" y="1017" font-size="14" fill="#9eb9ba">每段攀登先靠墙起步，再跨越中央空隙，进入宽台后继续下一层；支撑拱券和后景构件在游戏中呈现。</text></g></svg>']
(ROOT/'docs/exploration-demo/v8-route-layout.svg').write_text('\n'.join(svg),encoding='utf-8')
print('Exported v8-route-layout.svg from world geometry')
