local Players=game:GetService("Players")
local RunService=game:GetService("RunService")
local Tween=game:GetService("TweenService")
local Debris=game:GetService("Debris")
local Game=require(game.ReplicatedStorage.GameConfig)
local PickaxeEffects=require(game.ReplicatedStorage.PickaxeEffects)
local player=Players.LocalPlayer
local Effects={}
local running=setmetatable({},{__mode="k"})
local watched=setmetatable({},{__mode="k"})
local random=Random.new()

local function part(parent,name,at,size,color)
 local p=Instance.new("Part");p.Name=name;p.Size=size;p.Position=at;p.Color=color
 p.Anchored=true;p.CanCollide=false;p.CanTouch=false;p.CanQuery=false;p.CastShadow=false
 p.Material=Enum.Material.Neon;p.Parent=parent;return p
end
local function fade(object,time,properties)
 Tween:Create(object,TweenInfo.new(time,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),properties):Play()
end
local function sound(parent,asset,volume,pitch)
 local s=Instance.new("Sound");s.Name="HatchSFX";s.SoundId=asset;s.Volume=volume*(player:GetAttribute("SFXVolume") or 1)
 s.PlaybackSpeed=pitch;s.RollOffMaxDistance=90;s.RollOffMinDistance=10;s.Parent=parent;s:Play();Debris:AddItem(s,2)
end
local function smooth(t)return t*t*(3-2*t)end
local function luckText(value)return string.format("x%.2f Luck",value)end

local function burst(shell,at,scale,color,reduced)
 local folder=Instance.new("Folder");folder.Name="HatchBurst";folder.Parent=workspace;Debris:AddItem(folder,.85)
 local flash=part(folder,"HatchFlash",at+Vector3.new(0,2*scale,0),Vector3.one*scale,color)
 flash.Shape=Enum.PartType.Ball;fade(flash,.35,{Size=Vector3.one*5*scale,Transparency=1})
 local ring=part(folder,"HatchRing",at+Vector3.new(0,.12,0),Vector3.new(.1,2,2)*scale,color)
 ring.Shape=Enum.PartType.Cylinder;ring.CFrame*=CFrame.Angles(0,0,math.pi/2)
 fade(ring,.55,{Size=Vector3.new(.05,9,9)*scale,Transparency=1})
 sound(flash,"rbxasset://sounds/electronicpingshort.wav",.6,.85)
 if not reduced then
  for i=1,14 do
   local angle=i*math.pi*2/14
   local direction=Vector3.new(math.cos(angle),random:NextNumber(.25,1),math.sin(angle))
   local spark=part(folder,"HatchSpark",at+Vector3.new(0,2.5*scale,0),Vector3.one*.18*scale,i%2==0 and color or Color3.new(1,1,1))
   fade(spark,.6,{Position=spark.Position+direction*random:NextNumber(3,6)*scale,Transparency=1,Size=Vector3.one*.03})
  end
 end
 if shell then
  for _,p in shell:GetChildren() do if p:IsA("BasePart") then
   if reduced then p.Transparency=1 else
    local delta=p.Position-(at+Vector3.new(0,2*scale,0));local direction=delta.Magnitude>.01 and delta.Unit or Vector3.new(0,1,0)
    fade(p,.45,{CFrame=(p.CFrame+direction*3*scale+Vector3.new(0,scale,0))*CFrame.Angles(random:NextNumber(-1,1),random:NextNumber(-1,1),random:NextNumber(-1,1)),Transparency=1,Size=p.Size*.4})
   end
  end end
  Debris:AddItem(shell,.5)
 end
end

function Effects.begin(model)
 if not model or not model:IsA("Model") or not model.PrimaryPart or running[model] or not model:GetAttribute("Hatching") then return end
 local started=model:GetAttribute("HatchStarted")
 if type(started)~="number" then return end
 local duration=model:GetAttribute("HatchDuration") or Game.FieldHatchDuration
 if workspace:GetServerTimeNow()-started>=duration then return end
 PickaxeEffects.stopEggRecoil(model)
 local reduced=player:GetAttribute("ReducedMotion")
 local baseScale=model:GetScale();local pivot=model:GetPivot();local at=pivot.Position
 local growth=model:GetAttribute("HatchGrowth") or Game.FieldHatchGrowth
 local luck=model:GetAttribute("HatchLuck") or 1
 local shell=model:Clone();shell.Name="HatchingEggVisual"
 for name in shell:GetAttributes()do shell:SetAttribute(name,nil)end
 for _,child in shell:GetChildren()do
  if child.Name=="NestTwig" or not child:IsA("BasePart") then child:Destroy()end
 end
 local originals={}
 for _,p in model:GetChildren()do if p:IsA("BasePart") and p.Name~="NestTwig" then
  originals[p]=p.LocalTransparencyModifier;p.LocalTransparencyModifier=1
 end end
 shell.Parent=workspace
 for _,p in shell:GetDescendants()do
  if p:IsA("BasePart")then p.Color=Color3.new(1,1,1);p.Material=Enum.Material.Neon;p.MaterialVariant=""
  elseif p:IsA("Texture") or p:IsA("Decal")then p.Transparency=1 end
 end
 local color=Color3.fromRGB(255,224,100)
 local folder=Instance.new("Folder");folder.Name="HatchCharge";folder.Parent=workspace
 local anchor=part(folder,"HatchLuckAnchor",at,Vector3.one*.1,color);anchor.Transparency=1
 local gui=Instance.new("BillboardGui");gui.Name="HatchLuckCounter";gui.Size=UDim2.fromOffset(310,80);gui.MaxDistance=180
 gui.AlwaysOnTop=false;gui.Adornee=anchor;gui.Parent=anchor
 local label=Instance.new("TextLabel");label.Name="Luck";label.BackgroundTransparency=1;label.Size=UDim2.fromScale(1,1)
 label.Font=Enum.Font.GothamBlack;label.TextSize=36;label.TextColor3=Color3.fromRGB(171,255,72);label.Text=luckText(0);label.Parent=gui
 local stroke=Instance.new("UIStroke");stroke.Thickness=3;stroke.Color=Color3.fromRGB(20,30,17);stroke.Parent=label
 local glow=Instance.new("Highlight");glow.Name="HatchGlow";glow.Adornee=shell;glow.FillColor=Color3.new(1,1,1);glow.FillTransparency=.7
 glow.OutlineColor=Color3.new(1,1,1);glow.OutlineTransparency=.3;glow.DepthMode=Enum.HighlightDepthMode.Occluded;glow.Parent=folder
 local light=Instance.new("PointLight");light.Color=Color3.new(1,1,1);light.Brightness=1;light.Range=12*baseScale;light.Parent=anchor
 local motes={}
 if not reduced then for i=1,8 do table.insert(motes,part(folder,"HatchMote",at,Vector3.one*.12*baseScale,color))end end
 local connection,destroying,finished
 local sourceGone=false
 local function cleanup(explode)
  if finished then return end;finished=true
  if connection then connection:Disconnect()end;if destroying then destroying:Disconnect()end
  running[model]=nil
  if not explode then for p,value in originals do if p.Parent then p.LocalTransparencyModifier=value end end end
  if explode then
   label.Text=luckText(luck);label.TextColor3=color
   fade(label,.35,{TextTransparency=1});fade(stroke,.35,{Transparency=1})
   for _,mote in motes do mote:Destroy()end
   glow:Destroy();light:Destroy();Debris:AddItem(folder,.4)
   burst(shell,at,baseScale,color,reduced)
  else folder:Destroy();shell:Destroy()end
 end
 running[model]=cleanup
 destroying=model.Destroying:Connect(function()
  sourceGone=true
  if workspace:GetServerTimeNow()-started<duration-.12 then cleanup(false)end
 end)
 local lastTick=-1
 connection=RunService.RenderStepped:Connect(function()
  local elapsed=workspace:GetServerTimeNow()-started;local t=math.clamp(elapsed/duration,0,1)
  if not sourceGone and not model.Parent then cleanup(false);return end
  if elapsed>=duration then cleanup(true);return end
  local progress=smooth(t)
  local scale=baseScale*(1+(growth-1)*progress)
  local vibration=reduced and 0 or (.012+.075*t*t)*math.sin(elapsed*(18+22*t))
  local bounce=reduced and 0 or math.abs(math.sin(elapsed*(8+10*t)))*.08*baseScale*t
  shell:ScaleTo(scale)
  shell:PivotTo(pivot*CFrame.new(0,bounce,0)*CFrame.Angles(vibration,0,vibration*.7))
  anchor.Position=at+Vector3.new(0,2.3*scale+bounce,0)
  gui.StudsOffsetWorldSpace=Vector3.new(0,2.4*scale+1,0)
  label.Text=luckText(luck*progress);label.TextSize=36+math.floor(8*progress)
  glow.FillTransparency=.7-progress*.35;glow.OutlineTransparency=.3-progress*.2;light.Brightness=1+progress*2
  for i,mote in motes do
   local angle=i*math.pi/4+elapsed*(1.2+progress*2)
   local radius=2.1*scale
   mote.Position=at+Vector3.new(math.cos(angle)*radius,(1.3+math.sin(angle*2)*.8+progress)*scale,math.sin(angle)*radius)
  end
  local tick=math.floor(progress*5)
  if tick~=lastTick then lastTick=tick;sound(anchor,"rbxasset://sounds/electronicpingshort.wav",.15,.8+progress*.8)end
 end)
end

local function reveal(model)
 if running[model] then return end
 local count=0;for _,child in model:GetChildren()do if child:IsA("BasePart")then count+=1 end end
 if count<(model:GetAttribute("HatchRevealPartCount") or math.huge)then return end
 local started=model:GetAttribute("HatchRevealStarted")
 if type(started)~="number" then return end
 local duration=model:GetAttribute("HatchRevealDuration") or Game.FieldRevealDuration
 if workspace:GetServerTimeNow()-started>=duration then return end
 local scale=model:GetScale();local pivot=model:GetPivot();local reduced=player:GetAttribute("ReducedMotion")
 local visual=model:Clone();visual.Name="HatchingPetVisual"
 for name in visual:GetAttributes()do visual:SetAttribute(name,nil)end
 for _,child in visual:GetDescendants()do if child:IsA("BillboardGui") or child:IsA("ProximityPrompt")then child:Destroy()end end
 local originals={}
 for _,child in model:GetChildren()do if child:IsA("BasePart")then originals[child]=child.LocalTransparencyModifier;child.LocalTransparencyModifier=1 end end
 visual.Parent=workspace
 local connection,finished
 local function stop()
  if finished then return end;finished=true
  if connection then connection:Disconnect()end
  for child,value in originals do if child.Parent then child.LocalTransparencyModifier=value end end
  visual:Destroy()
  running[model]=nil
 end
 running[model]=stop
 connection=RunService.RenderStepped:Connect(function()
  if not model.Parent then stop();return end
  local t=math.clamp((workspace:GetServerTimeNow()-started)/duration,0,1)
  if t>=1 then stop();return end
  local factor
  if reduced then factor=.8+.2*smooth(t)
  elseif t<.58 then
   local x=t/.58;factor=.16+.96*(1-(1-x)^3)
  else factor=1.12-.12*smooth((t-.58)/.42)end
  visual:ScaleTo(scale*factor)
  local jump=reduced and 0 or math.sin(t*math.pi)*.9*scale
  local turn=reduced and 0 or math.sin(t*math.pi)*math.rad(22)
  visual:PivotTo(pivot*CFrame.new(0,jump,0)*CFrame.Angles(0,turn,0))
 end)
end

local function watch(model)
 if not model:IsA("Model") or watched[model]then return end
 local connections={};watched[model]=connections
 local function update()
  if not model.PrimaryPart then return end
  if model:GetAttribute("Hatching")then Effects.begin(model)end
  if model:GetAttribute("HatchRevealStarted")then reveal(model)end
 end
 table.insert(connections,model.AttributeChanged:Connect(update))
 table.insert(connections,model.ChildAdded:Connect(function()if model.PrimaryPart then update()end end))
 table.insert(connections,model:GetPropertyChangedSignal("PrimaryPart"):Connect(update))
 table.insert(connections,model.Destroying:Connect(function()
  for _,c in connections do c:Disconnect()end;watched[model]=nil
 end))
 if model.PrimaryPart then update()end
end
function Effects.watch(folder)
 folder.ChildAdded:Connect(watch)
 for _,model in folder:GetChildren()do watch(model)end
end
return Effects
