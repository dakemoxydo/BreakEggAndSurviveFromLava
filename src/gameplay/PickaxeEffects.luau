local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local Game = require(game.ReplicatedStorage.GameConfig)
local Effects = {}
local active = setmetatable({}, {__mode="k"})
local eggAnimations = setmetatable({}, {__mode="k"})
local random = Random.new()
local player = Players.LocalPlayer

local function sound(parent, asset, volume, pitch)
 local s=Instance.new("Sound");s.Name="PickaxeSFX";s.SoundId=asset
 s.Volume=volume*(player:GetAttribute("SFXVolume") or 1);s.PlaybackSpeed=pitch or 1
 s.RollOffMaxDistance=65;s.RollOffMinDistance=8;s.Parent=parent;s:Play();Debris:AddItem(s,2)
end

-- Angles are in torso space, so R6 and R15 shoulder bases share the pose.
local poses={
 {time=0, shoulder={0,0,0}, elbow=0, waist={0,0,0}, wrist=0},
 {time=.14, shoulder={65,-18,18}, elbow=35, waist={-8,-18,5}, wrist=-18},
 {time=Game.SwingImpactTime, shoulder={-25,8,-12}, elbow=8, waist={12,12,-6}, wrist=12},
 {time=Game.SwingImpactTime+.045, shoulder={-42,10,-10}, elbow=5, waist={15,14,-7}, wrist=20},
 {time=.44, shoulder={0,0,0}, elbow=0, waist={0,0,0}, wrist=0},
}
local function rotation(values)
 return CFrame.Angles(math.rad(values[1]),math.rad(values[2]),math.rad(values[3]))
end
function Effects.swing(character, contactOnly)
 local tool=character and character:FindFirstChildOfClass("Tool")
 local humanoid=character and character:FindFirstChildOfClass("Humanoid")
 if not tool or not humanoid or humanoid.Health<=0 then return end
 if active[character] then active[character]() end
 local joints={}
 for _,joint in character:GetDescendants() do
  if joint:IsA("Motor6D") or joint:IsA("AnimationConstraint") then
   local kind=({RightShoulder="shoulder",["Right Shoulder"]="shoulder",RightElbow="elbow",Waist="waist",RootJoint="waist"})[joint.Name]
   if kind then table.insert(joints,{joint=joint,base=joint.C0,transform=joint.Transform,kind=kind}) end
  end
 end
 local grip=tool.Grip
 local trail=tool:FindFirstChild("PickaxeSwingTrail",true)
 local started=os.clock()-(contactOnly and Game.SwingImpactTime or 0)
 local connection,preAnimation,finished
 local function stop()
  if finished then return end;finished=true
  if connection then connection:Disconnect() end
  if preAnimation then preAnimation:Disconnect() end
  for _,item in joints do if item.joint.Parent then item.joint.Transform=item.transform end end
  if tool.Parent then tool.Grip=grip end
  if trail and trail.Parent then trail.Enabled=false end
  active[character]=nil
 end
 active[character]=stop
 -- Remove our previous offset before Animator computes this frame's pose.
 -- Apply the next offset after Animator, without accumulating joint rotations.
 preAnimation=RunService.PreAnimation:Connect(function()
  for _,item in joints do if item.joint.Parent then item.joint.Transform=item.transform end end
 end)
 if not contactOnly and tool:FindFirstChild("Handle") then
  task.delay(.12,function()if not finished then sound(tool.Handle,"rbxasset://sounds/swordslash.wav",.35,1.15) end end)
 end
 connection=RunService.PreSimulation:Connect(function()
  local elapsed=os.clock()-started
  if tool.Parent~=character or not character.Parent or humanoid.Health<=0 or elapsed>=poses[#poses].time then stop();return end
  local a,b=poses[1],poses[2]
  for i=2,#poses do if elapsed<=poses[i].time then a,b=poses[i-1],poses[i];break end end
  local alpha=math.clamp((elapsed-a.time)/(b.time-a.time),0,1)
  if b==poses[2] or b==poses[#poses] then alpha=alpha*alpha*(3-2*alpha) else alpha=1-(1-alpha)^2 end
  for _,item in joints do
   local offset
   if item.kind=="elbow" then offset=CFrame.Angles(math.rad(a.elbow+(b.elbow-a.elbow)*alpha),0,0)
   else offset=rotation(a[item.kind]):Lerp(rotation(b[item.kind]),alpha) end
   if item.joint.Parent then
    item.transform=item.joint.Transform
    item.joint.Transform=item.base.Rotation:Inverse()*offset*item.base.Rotation*item.transform
   end
  end
  tool.Grip=grip*CFrame.Angles(math.rad(a.wrist+(b.wrist-a.wrist)*alpha),0,0)
  if trail then trail.Enabled=elapsed>=.13 and elapsed<=Game.SwingImpactTime+.06 end
 end)
 return stop
end

local function part(name,position,size,color)
 local p=Instance.new("Part");p.Name=name;p.Size=size;p.Position=position;p.Color=color
 p.Anchored=true;p.CanCollide=false;p.CanTouch=false;p.CanQuery=false;p.CastShadow=false
 p.Material=Enum.Material.Neon;p.Parent=workspace;return p
end
local function fade(p,duration,goal)
 TweenService:Create(p,TweenInfo.new(duration,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),goal):Play()
 Debris:AddItem(p,duration+.05)
end

local function recoil(model)
 if not model or not model.Parent or model:GetAttribute("Hatching") then return end
 if eggAnimations[model] then eggAnimations[model]() end
 local originals={}
 for _,p in model:GetChildren() do if p:IsA("BasePart") and p.Name~="NestTwig" then table.insert(originals,{part=p,cf=p.CFrame}) end end
 local pivot=model:GetPivot();local started=os.clock();local connection,finished
 local function stop()
  if finished then return end;finished=true
  if connection then connection:Disconnect() end
  for _,item in originals do if item.part.Parent then item.part.CFrame=item.cf end end
  eggAnimations[model]=nil
 end
 eggAnimations[model]=stop
 connection=RunService.RenderStepped:Connect(function()
  local t=(os.clock()-started)/.25
  if t>=1 or not model.Parent or model:GetAttribute("Hatching") then stop();return end
  local angle=math.sin(t*math.pi*4)*(1-t)*.09
  local offset=pivot*CFrame.Angles(angle,0,angle*.65)*pivot:Inverse()
  for _,item in originals do if item.part.Parent then item.part.CFrame=offset*item.cf end end
 end)
end

function Effects.stopEggRecoil(model)
 if eggAnimations[model] then eggAnimations[model]() end
end

function Effects.hit(at,data)
 if typeof(at)~="Vector3" or type(data)~="table" then return end
 local camera=workspace.CurrentCamera
 if camera and (camera.CFrame.Position-at).Magnitude>120 then return end
 local reduced=player:GetAttribute("ReducedMotion")
 local model=data.model
 local scale=math.clamp(data.scale or 1,1,3)
 local origin=at+Vector3.new(0,2.3*scale,0)
 local root=data.character and data.character:FindFirstChild("HumanoidRootPart")
 local normal=root and (root.Position-origin) or Vector3.new(0,0,1)
 normal=normal.Magnitude>.01 and normal.Unit or Vector3.new(0,0,1)
 local impact=origin+normal*1.5*scale
 local color=data.color or Color3.fromRGB(255,218,110)
 local anchor=part("EggImpact",impact,Vector3.one*.12,color);anchor.Transparency=1
 Debris:AddItem(anchor,.75)
 sound(anchor,"rbxasset://sounds/action_footsteps_plastic.mp3",.65,random:NextNumber(.7,.9))
 local flash=Instance.new("Highlight");flash.Name="EggHitFlash";flash.Adornee=model
 flash.FillColor=Color3.new(1,1,1);flash.FillTransparency=.25;flash.OutlineTransparency=1
 flash.DepthMode=Enum.HighlightDepthMode.Occluded;flash.Parent=anchor
 TweenService:Create(flash,TweenInfo.new(.16),{FillTransparency=1}):Play()
 local orb=part("EggHitSpark",impact,Vector3.one*.55,color);orb.Shape=Enum.PartType.Ball
 fade(orb,.18,{Size=Vector3.one*1.8,Transparency=1})
 local ring=Instance.new("BillboardGui");ring.Name="ImpactRing";ring.Size=UDim2.fromScale(1,1);ring.AlwaysOnTop=false;ring.Parent=anchor
 local circle=Instance.new("Frame");circle.Size=UDim2.fromScale(1,1);circle.BackgroundTransparency=1;circle.Parent=ring
 local corner=Instance.new("UICorner");corner.CornerRadius=UDim.new(1,0);corner.Parent=circle
 local stroke=Instance.new("UIStroke");stroke.Thickness=3;stroke.Color=color;stroke.Parent=circle
 TweenService:Create(ring,TweenInfo.new(.2),{Size=UDim2.fromScale(3.5,3.5)}):Play()
 TweenService:Create(stroke,TweenInfo.new(.2),{Transparency=1}):Play()
 if not reduced then
  recoil(model)
  for i=1,8 do
   local direction=Vector3.new(random:NextNumber(-1,1),random:NextNumber(.2,1.3),random:NextNumber(-1,1)).Unit
   local chip=part("EggShellChip",impact,Vector3.new(.18,.25,.18)*scale,i%2==0 and color or Color3.new(1,1,1))
   chip.CFrame*=CFrame.Angles(random:NextNumber(),random:NextNumber(),random:NextNumber())
   fade(chip,.3,{CFrame=chip.CFrame+direction*random:NextNumber(1.5,3.5)*scale,Transparency=1,Size=Vector3.one*.03})
  end
 end
 local gui=Instance.new("BillboardGui");gui.Name="EggDamage";gui.Size=UDim2.fromOffset(160,65);gui.StudsOffsetWorldSpace=Vector3.new(0,1,0);gui.AlwaysOnTop=false;gui.Parent=anchor
 local label=Instance.new("TextLabel");label.Size=UDim2.fromScale(1,1);label.BackgroundTransparency=1
 label.Font=Enum.Font.GothamBlack;label.TextSize=36;label.TextColor3=Color3.fromRGB(255,235,138);label.Text="-"..Game.number(data.damage or 0);label.Parent=gui
 local outline=Instance.new("UIStroke");outline.Thickness=3;outline.Parent=label
 TweenService:Create(gui,TweenInfo.new(.5),{StudsOffsetWorldSpace=Vector3.new(0,2.5,0)}):Play()
 TweenService:Create(label,TweenInfo.new(.2,Enum.EasingStyle.Linear,Enum.EasingDirection.Out,0,false,.3),{TextTransparency=1}):Play()
 TweenService:Create(outline,TweenInfo.new(.2,Enum.EasingStyle.Linear,Enum.EasingDirection.Out,0,false,.3),{Transparency=1}):Play()
end
return Effects
