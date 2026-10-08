from PIL import Image, ImageDraw
S=4
im=Image.new('RGBA',(80*S,76*S)); d=ImageDraw.Draw(im)
def line(points,color,width):
 p=[(round(x*S),round(y*S)) for x,y in points]; d.line(p,fill=color,width=round(width*S),joint='curve')
 r=width*S/2
 for x,y in p: d.ellipse((x-r,y-r,x+r,y+r),fill=color)
def polygon(p,color):d.polygon([(x*S,y*S) for x,y in p],fill=color)
# Rounded black silhouette and white cart face.
line([(8,7),(18,7),(31,42),(65,42),(75,14),(22,14)],'#101010',9)
polygon([(22,14),(75,14),(65,42),(31,42)],'#ffffff')
line([(8,7),(17,7),(29,39)],'#ffffff',3)
line([(31,42),(23,53),(65,53)],'#101010',10)
line([(31,44),(25,51),(64,51)],'#ffffff',4)
for x in [29,61]:
 d.ellipse(((x-10)*S,55*S,(x+10)*S,75*S),fill='#101010')
 d.ellipse(((x-5)*S,60*S,(x+5)*S,70*S),fill='white')
im.resize((320,304),Image.Resampling.LANCZOS).save('assets/archive/legacy-ui/cart.png')
