from pathlib import Path
from PIL import Image,ImageDraw,ImageChops
import json
root=Path(__file__).resolve().parents[2];work=root/'tmp/demo9-anim'
raw=Image.open('/Users/tsun/.codex/generated_images/01a1cb32-5101-7641-b0fb-ad61f4ab7e88/exec-20f592b0-f197-4d90-9053-c4e658d8685e.png').convert('RGBA')
blank=Image.open('/Users/tsun/.codex/generated_images/01a1cb32-5101-7641-b0fb-ad61f4ab7e88/exec-e8f48504-a687-4188-abba-69b976c57965.png').convert('RGBA').resize(raw.size,Image.Resampling.LANCZOS)
bg=Image.open(work/'before/museum.png').convert('RGBA')
# Only original painting interiors change. Frames and all room pixels remain byte-identical.
for rect in [(58,407,297,550),(644,407,866,551),(1380,408,1615,550)]:bg.paste(raw.crop(rect),rect)
# Original-image iris crops are the art for independent pupil layers; generated blank sclera is the base.
centers=[(165,471),(201,471),(738,463),(776,463),(1485,471),(1521,471)]
eye_dir=root/'assets/environments/exploration/portraits';eye_dir.mkdir(parents=True,exist_ok=True)
eyes=[]
for i,(x,y) in enumerate(centers):
 rect=(x-6,y-3,x+7,y+4)
 # Alpha masks only extract existing generated paint; no eye pixels are drawn.
 mask=Image.new('L',(13,7));ImageDraw.Draw(mask).ellipse((0,0,12,6),fill=255)
 bg.paste(blank.crop(rect),rect,mask)
 iris=raw.crop((x-3,y-3,x+4,y+4));alpha=Image.new('L',iris.size);ImageDraw.Draw(alpha).ellipse((0,0,6,6),fill=255);iris.putalpha(alpha)
 p=eye_dir/f'portrait_{i//2+1}_{"left" if i%2==0 else "right"}_iris.png';iris.save(p)
 eyes.append({'id':p.stem,'portrait':i//2+1,'center':[x+.5,y+.5],'path':'res://'+str(p.relative_to(root)),'size':[7,7],'travel':[2.2,0.8],'sclera_patch':list(rect)})
bg.save(root/'assets/environments/exploration/backgrounds/museum.png')
(root/'data/exploration/museum-eyes.json').write_text(json.dumps({'canvas':list(bg.size),'eyes':eyes},indent=2)+'\n')
preview=bg.copy()
for eye in eyes:
 im=Image.open(root/eye['path'].removeprefix('res://'));preview.alpha_composite(im,(round(eye['center'][0]-3.5),round(eye['center'][1]-3.5)))
preview.save(root/'docs/demo9-museum-portraits.png')
