#!/usr/bin/env python3
"""Measure packaged art and compose a gaze preview; never draw character/scenery pixels."""
from pathlib import Path
from PIL import Image,ImageChops
import json,shutil
ROOT=Path(__file__).resolve().parents[2]
def main():
 m=json.loads((ROOT/'data/exploration/animations.json').read_text());report={}
 heights={'may_idle':235,'may_windup':262,'may_slash':228,'may_summon':250,'may_brush':245,'may_brush_strike':232,'may_statue':180,'void_idle':210,'void_command':238,'void_lash':200,'void_frenzy':222,'void_puppet':104,'keeper_back':124,'keeper_hidden':118,'keeper_unmasked':118,'ling_crouch':78,'ling_giant':600,'ling_hand':96,'fury_idle':118,'fury_lunge':118,'fury_punch':118,'hero':105,'detective':120,'keeper_limb':122,'enemies_a_0':98,'enemies_a_1':110,'enemies_a_3':64,'enemies_b_0':67,'enemies_b_1':100,'enemies_b_2':116,'enemies_b_3':103}
 for name,v in m['clips'].items():
  im=Image.open(ROOT/v['path'].removeprefix('res://'));w,h=v['width'],v['height'];bottom=[]
  for i in range(8):
   a=v.get('offset',0)+i;x=a%v['columns']*w;y=a//v['columns']*h
   box=im.crop((x,y,x+w,y+h)).getchannel('A').point(lambda a:255 if a>128 else 0).getbbox();bottom.append(box[3])
  source=v['source']+(f'_{v["cell"]}' if v['cell']>=0 else '')
  height=heights.get(source,120)
  report[name]={'bottom_pixels':bottom,'range_pixels':max(bottom)-min(bottom),'target_baseline':v['baseline'],'display_height':height,'drift_world_pixels':(max(bottom)-min(bottom))*height/h}
  assert report[name]['drift_world_pixels']<=2,(name,report[name])
 old=Image.open(ROOT/'tmp/demo9-anim/before/museum.png').convert('RGBA');new=Image.open(ROOT/'assets/environments/exploration/backgrounds/museum.png').convert('RGBA');diff=ImageChops.difference(old,new)
 for r in [(58,407,297,550),(644,407,866,551),(1380,408,1615,550)]:diff.paste((0,0,0,0),r)
 assert not any(c.getbbox() for c in diff.split()),'museum changed outside portrait interiors'
 (ROOT/'docs/demo9-animation-contact-validation.json').write_text(json.dumps({'clips':report,'museum_outside_portraits_unchanged':True},indent=2)+'\n')
 backup=ROOT/'docs/demo9-animation-before';backup.mkdir(exist_ok=True)
 for n in ['keeper_unmasked','museum']:shutil.copy2(ROOT/f'tmp/demo9-anim/before/{n}.png',backup/f'{n}.png')
 e=json.loads((ROOT/'data/exploration/museum-eyes.json').read_text());frames=[]
 for t in [-1,-.5,0,.5,1,.5,0,-.5]:
  im=new.copy()
  for v in e['eyes']:
   iris=Image.open(ROOT/v['path'].removeprefix('res://'));x,y=v['center'];dx,dy=v['travel'];im.alpha_composite(iris,(round(x-3.5+t*dx),round(y-3.5+t*dy)))
  frames.append(im.crop((690,425,820,520)).resize((650,475),Image.Resampling.NEAREST).convert('RGB'))
 frames[0].save(ROOT/'docs/demo9-museum-gaze-closeup.gif',save_all=True,append_images=frames[1:],duration=180,loop=0)
 print('77 contact baselines pass; max drift %.4f world pixels; museum exterior pixels identical'%max(v['drift_world_pixels'] for v in report.values()))
if __name__=='__main__':main()
