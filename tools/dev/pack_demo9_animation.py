#!/usr/bin/env python3
"""Package built-in image_gen drawings. No character or scenery drawing is performed here."""
from pathlib import Path
import json, math, statistics, shutil, hashlib
from PIL import Image, ImageDraw, ImageChops
ROOT=Path(__file__).resolve().parents[2]
WORK=ROOT/'tmp/demo9-anim'
ACT=ROOT/'assets/environments/exploration/actors'
OUT=ACT/'anim'

def source_for(name):
    if name.endswith('_actions'): name=name[:-8]
    if name.startswith('hero_'):return 'hero',-1
    if name.startswith(('enemies_','npcs_')):return name.rsplit('_',1)[0],int(name.rsplit('_',1)[1])
    return name,-1

def prepare(name,record,manifest):
    raw=Image.open(record['path']).convert('RGBA')
    cols,rows=(8,4) if name.endswith('_actions') else (4,2)
    source,cell=source_for(name)
    ref=Image.open(WORK/'input'/(source+(f'_{cell}' if cell>=0 else '')+'.png')).convert('RGBA')
    # Keep original pose aspect, margins and foot x. Every cel uses ONE scale, never fit independently.
    h=384;w=round(h*ref.width/ref.height)
    w=max(96,w)
    rb=ref.getchannel('A').point(lambda a:255 if a>64 else 0).getbbox()
    tiles=[];boxes=[]
    for j in range(cols*rows):
        x,y=j%cols,j//cols
        tile=raw.crop((round(x*raw.width/cols),round(y*raw.height/rows),round((x+1)*raw.width/cols),round((y+1)*raw.height/rows)))
        # Discard alpha encoder speckle only; preserve painted semitransparent boundaries.
        alpha=tile.getchannel('A').point(lambda a:0 if a<16 else a)
        tile.putalpha(alpha);box=alpha.point(lambda a:255 if a>64 else 0).getbbox()
        if not box:raise ValueError(f'empty {name} cel {j}')
        tiles.append(tile);boxes.append(box)
    target_h=(rb[3]-rb[1])/ref.height*h
    k=min(target_h/max(b[3]-b[1] for b in boxes), (w-4)/max(b[2]-b[0] for b in boxes))
    canvas=Image.new('RGBA',(w*cols,h*rows))
    baseline=round(rb[3]/ref.height*h)
    center=(rb[0]+rb[2])*.5/ref.width*w
    # Keep bottom contact mean fixed, including wide poses. Flying creatures use the same atlas anchor.
    def foot_x(tile,box):
        a=tile.getchannel('A');bottom=box[3]; xs=[]
        for yy in range(max(box[1],bottom-max(2,round((box[3]-box[1])*.035))),bottom):
            for xx in range(box[0],box[2]):
                if a.getpixel((xx,yy))>128:xs.append(xx)
        return statistics.mean(xs) if xs else (box[0]+box[2])*.5
    anchor=foot_x(ref,rb)/ref.width*w
    for j,(tile,box) in enumerate(zip(tiles,boxes)):
        crop=tile.crop(box);crop=crop.resize((max(1,round(crop.width*k)),max(1,round(crop.height*k))),Image.Resampling.LANCZOS)
        px=round(anchor-(foot_x(tile,box)-box[0])*k)
        py=baseline-crop.height
        px=max(1,min(w-crop.width-1,px));py=max(0,py)
        canvas.alpha_composite(crop,(j%cols*w+px,j//cols*h+py))
    OUT.mkdir(parents=True,exist_ok=True)
    # Base sheets retain original names so legacy art QA can identify source poses.
    path=OUT/(name+'.png');canvas.save(path,optimize=True)
    common={'path':'res://'+str(path.relative_to(ROOT)),'width':w,'height':h,'columns':cols,'source':source,'cell':cell,'frames':8,'foot_x':anchor/w,'baseline':baseline}
    if name.endswith('_actions'):
        for i,action in enumerate(['move','windup','active','recover']):
            clip=name[:-8]+'_'+action
            manifest['clips'][clip]={**common,'offset':i*8,'loop':action=='move','duration':.8 if action=='move' else .55}
        manifest['sources'].setdefault(f'{source}/{cell}',name[:-8]+'_move')
    else:
        loop=not any(x in name for x in ['windup','slash','summon','strike','lunge','punch','command','lash','hero_jump','hero_fall','hero_dash','hero_death','hero_active','hero_recover'])
        manifest['clips'][name]={**common,'loop':loop,'duration':1.2 if loop else .65}
        manifest['sources'][f'{source}/{cell}']=name if source!='hero' else 'hero_idle'
    return {'id':name,'generated_size':raw.size,'grid':[cols,rows],'sheet_size':canvas.size,'scale':k}

def main():
    jobs=json.loads((WORK/'generated.json').read_text())
    manifest={'version':9,'generator':'built-in image_gen','sources':{},'clips':{}}
    report=[]
    # Defaults must be registered before multi-action sheet variants.
    for name,record in sorted(jobs.items(),key=lambda x:x[0].endswith('_actions')):
        report.append(prepare(name,record,manifest))
    (ROOT/'data/exploration/animations.json').write_text(json.dumps(manifest,indent=2)+'\n')
    (ROOT/'docs/demo9-animation-pack.json').write_text(json.dumps(report,indent=2)+'\n')
    print(f'{len(jobs)} sheets; {len(manifest["clips"])} clips; {sum(x["frames"] for x in manifest["clips"].values())} cels')
if __name__=='__main__':main()
