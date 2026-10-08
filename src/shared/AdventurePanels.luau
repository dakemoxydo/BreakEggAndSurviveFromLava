local React=require(game.ReplicatedStorage.Packages.React)
local Game=require(game.ReplicatedStorage.GameConfig)
local UI=require(script.Parent.UI)
local Theme=require(script.Parent.Theme)
local Preview=require(script.Parent.ModelPreview)
local e=React.createElement
local C=Theme.colors
local function AdventurePanels(p)
 local body={}
 local compact=p.width<580
 local available=math.max(140,p.height-p.headerH)
 if p.kind=="Satchel Shop" then
  local level=p.data.SatchelLevel or 1
  body.Title=UI.text("Carry more animals per run!",20,12,p.width-40,48,compact and 24 or 34,C.gold)
  body.Amount=UI.text("Your satchel: "..level.." Animals",20,68,p.width-40,50,compact and 28 or 40)
  body.Description=UI.text("Bring stolen animals back to the Safe Zone.\nGuardians and lava make you lose your cargo.",24,126,p.width-48,94,compact and 21 or 26)
  body.Buy=e(UI.Button,{name="UpgradeSatchel",x=24,y=234,w=p.width-48,h=58,color=C.green,label=level>=8 and "MAX LEVEL" or "+1 Animal  ·  $"..Game.number(1000*25^(level-1)),disabled=p.busy or level>=8,textSize=compact and 23 or 30,onClick=function()p.onAction("UpgradeSatchel",{})end})
  return e("ScrollingFrame",{Position=UDim2.fromOffset(0,p.headerH),Size=UDim2.fromOffset(p.width,available),CanvasSize=UDim2.fromOffset(0,316),BackgroundTransparency=1,BorderSizePixel=0,ScrollBarThickness=5,Active=true},body)
 else
  body.Hint=UI.text("Merge 3 matching animals into a heavier egg.\nPlace the egg on your base to hatch it.",16,14,p.width-32,95,27)
  local counts={}
  for _,pet in p.pets do local item=counts[pet.kind];if not item then item={kind=pet.kind,name=pet.name,count=0};counts[pet.kind]=item end;item.count+=1 end
  local rows={Layout=e("UIListLayout",{Padding=UDim.new(0,18),SortOrder=Enum.SortOrder.LayoutOrder})}
  local i=0
  for _,pet in Game.Pets do local item=counts[pet.key]
   if item then i+=1;rows[pet.key]=e("Frame",{Name="Merge"..pet.key,Size=UDim2.fromOffset(p.width-44,compact and 158 or 110),BackgroundTransparency=1,LayoutOrder=i},{
    Surface=e(UI.Surface,{w=p.width-44,h=compact and 158 or 110,color=C.muted,quiet=true,children={
     Image=e(Preview,{kind=pet.key,x=6,y=6,w=compact and 72 or 90,h=compact and 72 or 90}),
     Title=UI.text(pet.name,compact and 84 or 106,8,compact and p.width-142 or p.width-370,46,compact and 21 or 26,nil,Enum.TextXAlignment.Left),
     Count=UI.text(item.count.." / 3 Animals",compact and 84 or 106,54,compact and p.width-142 or p.width-370,36,20,item.count>=3 and C.green or C.white,Enum.TextXAlignment.Left),
     Merge=e(UI.Button,{name="Merge"..pet.key,label="Merge 3",x=compact and 12 or p.width-242,y=compact and 97 or 26,w=compact and p.width-68 or 180,h=48,color=C.green,textSize=25,disabled=p.busy or item.count<3,onClick=function()p.onAction("MergePets",{kind=pet.key})end}),
    }})
   }) end
  end
  if i==0 then rows.Empty=UI.text("Steal animals from the field to start your collection.",16,16,p.width-76,100,26) end
  body.List=e("ScrollingFrame",{Name="MergeList",Position=UDim2.fromOffset(22,125),Size=UDim2.fromOffset(p.width-44,math.max(80,available-157)),BackgroundTransparency=1,BorderSizePixel=0,CanvasSize=UDim2.fromOffset(0,math.max(150,i*(compact and 176 or 128))),ScrollBarThickness=5,Active=true},rows)
 end
 return e("Frame",{Position=UDim2.fromOffset(0,p.headerH),Size=UDim2.fromOffset(p.width,p.height-p.headerH),BackgroundTransparency=1},body)
end
return AdventurePanels
