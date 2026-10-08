local World = {}
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PetVisuals = require(ReplicatedStorage:WaitForChild("PetVisuals"))
local Game = require(ReplicatedStorage:WaitForChild("GameConfig"))
-- Rojo-created MeshParts can lose their intrinsic geometry dimensions.
-- Copy the complete mesh metadata from the imported storage templates.
local assets = game:GetService("ServerStorage"):FindFirstChild("Assets")
local items = assets and assets:FindFirstChild("Items")
local pickaxes = items and items:FindFirstChild("Pickaxes")
local storedTemplates = pickaxes and pickaxes:FindFirstChild("Templates")
local runtimeTemplates = ReplicatedStorage:FindFirstChild("PickaxeModels")
if storedTemplates and runtimeTemplates then
	for _, template in runtimeTemplates:GetChildren() do
		local source = storedTemplates:FindFirstChild(template.Name)
		if template:IsA("MeshPart") and source and source:IsA("MeshPart")
			and template.MeshId == source.MeshId and source.MeshSize.X > 0
			and (template.MeshSize - source.MeshSize).Magnitude > .0001 then
			local size = template.Size
			template:ApplyMesh(source)
			template.Size = size
		end
	end
end
World.chick = PetVisuals.chick
World.pet = PetVisuals.pet
World.egg = PetVisuals.egg
function World.label(model, text)
	local gui = Instance.new("BillboardGui")
	gui.Name = "WorldLabel"
	gui.Size = UDim2.fromOffset(240, 64)
	local _,size=model:GetBoundingBox()
	gui.StudsOffsetWorldSpace = Vector3.new(0, size.Y+1.4, 0)
	gui.MaxDistance = 200
	gui.AlwaysOnTop = false
	gui.Adornee = model.PrimaryPart
	gui.Parent = model
	local label = Instance.new("TextLabel")
	label.Name = "Text"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBlack
	label.TextSize = 22
	label.TextWrapped = true
	label.TextColor3 = Color3.new(1, 1, 1)
	label.Text = text
	label.Parent = gui
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2
	stroke.Color = Color3.fromRGB(15, 17, 15)
	stroke.Parent = label
	return label
end
function World.tool(kind, petData, index)
	local tool = Instance.new("Tool")
	petData=petData or {kind="TestChick",weight=1}
	local info=Game.pet(petData.kind)
	tool.Name = kind=="Pickaxe" and Game.Pickaxes[index or 1].name or kind=="Egg" and info.name.." Egg" or info.name
	if kind=="Pet" then tool:SetAttribute("Weight",petData.weight or 1)end
	if kind=="Pickaxe" then
		tool:SetAttribute("Pickaxe",true);tool:SetAttribute("Power",Game.Pickaxes[index or 1].power);tool:SetAttribute("UIIcon","pickaxe"..Game.Pickaxes[index or 1].key)
	else
		tool:SetAttribute("PlacementKind", kind);tool:SetAttribute("PetKind",petData.kind);tool:SetAttribute("PetWeight",petData.weight or 1);tool:SetAttribute("UIIcon",kind=="Egg" and "egg" or info.icon)
	end
	tool.CanBeDropped = false
	tool.RequiresHandle = true
	local visual = kind=="Pickaxe" and PetVisuals.pickaxe(index) or kind == "Egg" and World.egg(nil,false) or World.pet(petData.kind,petData.weight)
	if kind=="Pickaxe" then
		visual:ScaleTo(visual:GetScale() * PetVisuals.PickaxeToolScale)
	elseif kind=="Egg" then
		visual:ScaleTo(0.65)
	end
	local handle = visual.PrimaryPart
	handle.Name = "Handle"
	-- The standard tool-hold pose already keeps local Y upright. Turn only
	-- the head into the swing plane, leaving the shaft centered in the fist.
	tool.Grip = kind=="Pickaxe" and CFrame.Angles(0,math.pi/2,0) or CFrame.new(0, -0.4, -0.5)
	if kind=="Pickaxe" then
		local mesh=visual:FindFirstChild("PickaxeMesh")
		local head=mesh or visual:FindFirstChild("Head")
		local headAnchor=mesh and mesh:FindFirstChild("PickaxeHead")
		local headPosition=headAnchor and handle.CFrame:PointToObjectSpace(headAnchor.WorldPosition).Y
			or (head and head.Position.Y+(mesh and mesh.Size.Y*.32 or 0) or 1.8)
		local trailHalfWidth=.85 * visual:GetScale() / .65
		local a=Instance.new("Attachment");a.Name="SwingTrailInner";a.Position=Vector3.new(-trailHalfWidth,headPosition,0);a.Parent=handle
		local b=Instance.new("Attachment");b.Name="SwingTrailOuter";b.Position=Vector3.new(trailHalfWidth,headPosition,0);b.Parent=handle
		local trail=Instance.new("Trail");trail.Name="PickaxeSwingTrail";trail.Attachment0=a;trail.Attachment1=b
		trail.Color=ColorSequence.new(Game.Pickaxes[index or 1].color,Color3.new(1,1,1));trail.Lifetime=.12
		trail.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,.15),NumberSequenceKeypoint.new(1,1)})
		trail.LightEmission=.8;trail.FaceCamera=true;trail.MinLength=.05;trail.Enabled=false;trail.Parent=handle
	end
	for _, p in visual:GetChildren() do
		if p:IsA("BasePart") then
			p.Anchored = false
			p.CanCollide = false; p.CanTouch = false; p.CanQuery = false
			p.Massless = true
			if p ~= handle then
				local weld = Instance.new("WeldConstraint")
				weld.Part0 = handle
				weld.Part1 = p
				weld.Parent = p
			end
			p.Parent = tool
		end
	end
	visual:Destroy()
	return tool
end

function World.board(parent,name,cf,title,action)
	local board=Instance.new("Part");board.Name=name;board.Size=Vector3.new(11,6,.7);board.CFrame=cf;board.Color=Color3.fromRGB(22,35,99);board.Material=Enum.Material.Plastic;board.Anchored=true;board.CanCollide=false;board.Parent=parent
	for _,face in {Enum.NormalId.Front,Enum.NormalId.Back} do local texture=Instance.new("Texture");texture.Texture=Game.StudTexture;texture.Color3=board.Color;texture.Face=face;texture.StudsPerTileU=2;texture.StudsPerTileV=2;texture.Parent=board end
	local gui=Instance.new("SurfaceGui");gui.Name="BoardUI";gui.Face=Enum.NormalId.Front;gui.CanvasSize=Vector2.new(550,300);gui.LightInfluence=0;gui.Parent=board
	local function text(name,value,y,h,color)
		local label=Instance.new("TextLabel");label.Name=name;label.Text=value;label.Font=Enum.Font.GothamBlack;label.TextSize=47;label.TextColor3=color or Color3.new(1,1,1);label.BackgroundTransparency=1;label.Size=UDim2.new(1,-30,0,h);label.Position=UDim2.fromOffset(15,y);label.Parent=gui
		local stroke=Instance.new("UIStroke");stroke.Thickness=4;stroke.Parent=label;return label
	end
	text("Title",title,8,68);text("Level","Lv. 1 > Lv. 2",81,68,Color3.fromRGB(107,255,5))
	local face=Instance.new("Frame");face.Name="PriceFace";face.Size=UDim2.new(1,-40,0,100);face.Position=UDim2.fromOffset(20,182);face.BackgroundColor3=Color3.fromRGB(110,255,5);face.BorderSizePixel=3;face.Parent=gui
	text("Price","$100",195,73)
	local prompt=Instance.new("ProximityPrompt");prompt.ActionText="Upgrade";prompt.ObjectText=title;prompt.MaxActivationDistance=14;prompt.RequiresLineOfSight=false;prompt.Parent=board
	prompt.Triggered:Connect(action)
	return board
end
function World.setupBase(player,state,action)
	local center=state.base.BaseAnchor.Position
	state.penBoard=World.board(state.contents,"UpgradePen",CFrame.new(center.X+12,4.6,101),"Upgrade Pen",function(visitor)if visitor==player then action("UpgradePen")end end)
	state.treadmillBoard=World.board(state.contents,"UpgradeTreadmill",CFrame.new(center.X-29,4.6,94)*CFrame.Angles(0,math.rad(-15),0),"Upgrade Treadmill",function(visitor)if visitor==player then action("UpgradeTreadmill")end end)
	local pole=Instance.new("Part");pole.Name="BaseMarker";pole.Size=Vector3.one;pole.Transparency=1;pole.Anchored=true;pole.CanCollide=false;pole.Position=Vector3.new(center.X,15,center.Z+24);pole.Parent=state.contents
	local gui=Instance.new("BillboardGui");gui.Name="BaseMarkerUI";gui.Size=UDim2.fromOffset(260,205);gui.AlwaysOnTop=false;gui.MaxDistance=500;gui.Adornee=pole;gui.Parent=pole
	local thumb=Instance.new("ImageLabel");thumb.Name="OwnerHead";thumb.BackgroundTransparency=1;thumb.Size=UDim2.fromOffset(145,145);thumb.Position=UDim2.fromOffset(57,0);thumb.Image="rbxthumb://type=AvatarHeadShot&id="..player.UserId.."&w=150&h=150";thumb.Parent=gui
	local label=Instance.new("TextLabel");label.Name="OwnerTitle";label.Size=UDim2.fromOffset(260,55);label.Position=UDim2.fromOffset(0,145);label.BackgroundTransparency=1;label.Font=Enum.Font.GothamBlack;label.TextSize=30;label.TextColor3=Color3.new(1,1,1);label.Text="@"..player.Name;label.Parent=gui
	local stroke=Instance.new("UIStroke");stroke.Thickness=3;stroke.Parent=label
	World.updateBase(player,state)
end
function World.updateBase(player,state)
	for _,item in {{state.penBoard,state.penLevel,Game.PenCosts[state.penLevel]},{state.treadmillBoard,state.treadmillLevel,Game.Treadmills[state.treadmillLevel+1] and Game.Treadmills[state.treadmillLevel+1].cost}} do
		local board,level,cost=item[1],item[2],item[3]
		if board then board.BoardUI.Level.Text=cost and "Lv. "..level.." > Lv. "..(level+1) or "MAX LEVEL";board.BoardUI.Price.Text=cost and "$"..Game.number(cost) or "MAX";board.ProximityPrompt.Enabled=cost~=nil end
	end
	local station=workspace.Map.StartZone.Treadmills:FindFirstChild("Treadmill_"..state.base.Name)
	if station then
		station:SetAttribute("OwnerUserId",player.UserId);station:SetAttribute("TrainingGain",Game.Treadmills[state.treadmillLevel].gain)
		for _,p in station:GetDescendants() do if p:IsA("BasePart") and p.Name~="TrainingCenter" and p.Name~="BeltCollision" then
			if p:GetAttribute("ReferenceColor")==nil then p:SetAttribute("ReferenceColor",p.Color) end
			local original=p:GetAttribute("ReferenceColor")
			if original.B>original.R*1.2 or state.treadmillLevel>=5 then p.Color=Game.Treadmills[state.treadmillLevel].color end
		end end
		if state.treadmillLevel>=5 and not station:FindFirstChild("UpgradeGlow") then local light=Instance.new("PointLight");light.Name="UpgradeGlow";light.Range=15;light.Brightness=2;light.Parent=station.TrainingCenter end
		for _,d in station:GetDescendants() do if d:IsA("PointLight") then d.Color=Game.Treadmills[state.treadmillLevel].color end end
		local label=station:FindFirstChild("GainDisplay")
		if not label then label=Instance.new("BillboardGui");label.Name="GainDisplay";label.Size=UDim2.fromOffset(270,70);label.StudsOffsetWorldSpace=Vector3.new(0,5,0);label.Adornee=station.TrainingCenter;label.Parent=station;local t=Instance.new("TextLabel");t.Name="Text";t.Size=UDim2.fromScale(1,1);t.BackgroundTransparency=1;t.Font=Enum.Font.GothamBlack;t.TextSize=32;t.TextColor3=Color3.fromRGB(30,198,255);t.Parent=label;local s=Instance.new("UIStroke");s.Thickness=3;s.Parent=t end
		label.Text.Text="+"..Game.number(Game.Treadmills[state.treadmillLevel].gain).."/Step"
	end
end
function World.floor(base)
	local anchor = base.BaseAnchor
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { base }
	local hit = workspace:Raycast(anchor.Position + Vector3.new(0, 15, 0), Vector3.new(0, -50, 0), params)
	return hit and hit.Position.Y or anchor.Position.Y - 0.4
end
return World
