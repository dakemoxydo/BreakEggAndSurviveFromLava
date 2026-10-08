local Visuals = {}
local Game = require(game.ReplicatedStorage:WaitForChild("GameConfig"))
-- All pickaxes share the Stone template's height; ScaleTo preserves every axis.
Visuals.PickaxeHeight = 4.875
Visuals.PickaxeToolScale = 0.65 * 1.5

local function part(parent, name, size, offset, color, shape)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = CFrame.new(offset)
	p.Color = color
	p.Shape = shape or Enum.PartType.Block
	p.Material = Enum.Material.Plastic
	p.MaterialVariant = (name:find("Eye") or name:find("Shine")) and "" or "ReferenceHDStuds"
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	if Game.StudTexture ~= "" and not name:find("Eye") and not name:find("Shine") then
		for _, face in {Enum.NormalId.Top, Enum.NormalId.Front, Enum.NormalId.Back, Enum.NormalId.Left, Enum.NormalId.Right} do
			local texture = Instance.new("Texture")
			texture.Name = "HDStuds"
			texture.Texture = Game.StudTexture
			texture.StudsPerTileU = 2
			texture.StudsPerTileV = 2
			texture.Color3 = color
			texture.Face = face
			texture.Parent = p
		end
	end
	return p
end

function Visuals.chick()
	local m = Instance.new("Model")
	m.Name = "Chicken"
	local white = Color3.fromRGB(248, 249, 255)
	local shade = Color3.fromRGB(233, 238, 250)
	local orange = Color3.fromRGB(255, 139, 19)
	local red = Color3.fromRGB(241, 29, 35)
	local body = part(m, "Body", Vector3.new(2.4, 2.1, 1.9), Vector3.new(0, 1.65, 0), white)
	m.PrimaryPart = body
	body.PivotOffset = CFrame.new(0, -1.65, 0)

	part(m, "CheekLeft", Vector3.new(0.7, 1.05, 1.25), Vector3.new(-1.2, 1.25, -0.02), shade)
	part(m, "CheekRight", Vector3.new(0.7, 1.05, 1.25), Vector3.new(1.2, 1.25, -0.02), white)
	part(m, "Tail", Vector3.new(0.58, 0.68, 0.62), Vector3.new(0, 1.15, 1.02), shade)

	part(m, "CombBase", Vector3.new(0.92, 0.42, 0.72), Vector3.new(0, 2.62, 0.02), red)
	part(m, "CombLeft", Vector3.new(0.48, 0.56, 0.62), Vector3.new(-0.34, 2.83, 0.02), red)
	part(m, "CombCenter", Vector3.new(0.62, 0.7, 0.62), Vector3.new(0.02, 2.98, 0.04), red)
	part(m, "CombRight", Vector3.new(0.48, 0.5, 0.6), Vector3.new(0.4, 2.76, 0.02), red)

	for _, sign in { -1, 1 } do
		local eyeX = sign * 0.52
		part(m, "Eye" .. sign, Vector3.new(0.3, 0.43, 0.16), Vector3.new(eyeX, 2.08, -1.02), Color3.fromRGB(15, 18, 20))
		part(
			m,
			"EyeShine" .. sign,
			Vector3.new(0.12, 0.15, 0.05),
			Vector3.new(eyeX - 0.04, 2.17, -1.115),
			Color3.fromRGB(255, 255, 255)
		)
	end

	part(m, "Beak", Vector3.new(0.7, 0.58, 0.66), Vector3.new(0, 1.7, -1.2), orange)
	part(m, "BeakShine", Vector3.new(0.5, 0.06, 0.45), Vector3.new(0, 2.02, -1.2), Color3.fromRGB(255, 190, 34))
	part(m, "Wattle", Vector3.new(0.38, 0.43, 0.34), Vector3.new(0, 1.13, -1.02), red)

	for _, sign in { -1, 1 } do
		local side = sign == -1 and "Left" or "Right"
		part(m, "Wing" .. side, Vector3.new(0.82, 0.9, 1.18), Vector3.new(sign * 1.31, 1.32, 0.05), sign == -1 and shade or white)
		part(m, "Leg" .. side, Vector3.new(0.38, 0.42, 0.38), Vector3.new(sign * 0.58, 0.42, -0.82), orange)
		part(m, "Foot" .. side, Vector3.new(0.72, 0.3, 0.82), Vector3.new(sign * 0.58, 0.15, -0.95), orange)
	end
	local outline = Instance.new("Highlight")
	outline.Name = "PetOutline"
	outline.Adornee = m
	outline.FillTransparency = 1
	outline.OutlineColor = Color3.fromRGB(16, 18, 22)
	outline.OutlineTransparency = 0.08
	outline.DepthMode = Enum.HighlightDepthMode.Occluded
	outline.Parent = m
	return m
end

function Visuals.egg(color, nest)
	local m = Instance.new("Model")
	m.Name = "Forest Egg"
	color = color or Color3.fromRGB(255, 204, 159)
	local shell = part(m, "Shell", Vector3.new(3.3, 1.5, 3.3), Vector3.new(0, 2.1, 0), color)
	m.PrimaryPart = shell
	shell.PivotOffset = CFrame.new(0, -2.1, 0)
	for i, tier in {{2.8,.7,.85},{3.1,.65,1.35},{3.05,.65,2.95},{2.5,.6,3.55},{1.9,.5,4.1},{1.05,.3,4.5}} do
		part(m,"ShellTier"..i,Vector3.new(tier[1],tier[2],tier[1]),Vector3.new(0,tier[3],0),color)
	end
	-- Beveled corners give the stepped egg the same broad, faceted silhouette as the reference.
	for _,sx in {-1,1} do for _,sz in {-1,1} do
		local edge=part(m,"ShellEdge",Vector3.new(.65,2.2,.65),Vector3.new(sx*1.28,2,sz*1.28),color)
		edge.CFrame *= CFrame.Angles(0,math.rad(45),0)
	end end
	if nest ~= false then
		for i=1,14 do
			local angle=i*math.pi*2/14
			local twig=part(m,"NestTwig",Vector3.new(1.8,.3,.48),Vector3.new(math.cos(angle)*1.85,.28,math.sin(angle)*1.85),Color3.fromRGB(161+(i%3)*14,103+(i%4)*9,59))
			twig.CFrame *= CFrame.Angles(0,-angle+.55,math.sin(i)*.1)
		end
	end
	return m
end

function Visuals.petScale(kind, weight)
	local info=Game.pet(kind)
	return (info.size or 1)*math.max(weight or 1,.1)^.15
end

function Visuals.pet(kind, weight)
	local info=Game.pet(kind)
	if info.shape=="chicken" then local model=Visuals.chick();model.Name=info.name;model:SetAttribute("Weight",weight or 1);model:ScaleTo(Visuals.petScale(kind,weight));return model end
	local m=Instance.new("Model");m.Name=info.name
	local color=info.color;local dark=color:Lerp(Color3.new(0,0,0),.32);local cream=Color3.fromRGB(244,230,201)
	local body=part(m,"Body",Vector3.new(2.6,2,3.4),Vector3.new(0,1.9,0),color);m.PrimaryPart=body;body.PivotOffset=CFrame.new(0,-1.9,0)
	local shape=info.shape
	local headY=(shape=="bear" or shape=="penguin" or shape=="owl") and 3.2 or 2.6
	local head=part(m,"Head",Vector3.new(2.1,1.65,1.8),Vector3.new(0,headY,-1.9),color)
	local function eyes(x,y,z)
		for _,sign in {-1,1} do
			part(m,"Eye"..sign,Vector3.new(.24,.37,.13),Vector3.new(sign*x,y,z),Color3.fromRGB(16,19,26))
			part(m,"EyeShine"..sign,Vector3.new(.09,.1,.03),Vector3.new(sign*x-.035,y+.1,z-.07),Color3.new(1,1,1))
		end
	end
	eyes(.56,headY+.1,-2.84)
	local nose=part(m,"Muzzle",Vector3.new(1.1,.64,.95),Vector3.new(0,headY-.45,-2.95),cream)
	part(m,"Nose",Vector3.new(.48,.24,.19),Vector3.new(0,headY-.25,-3.48),dark)
	for _,sign in {-1,1} do
		for _,z in {-1.05,1.08} do
			part(m,"Leg"..sign..z,Vector3.new(.6,1.1,.75),Vector3.new(sign*.85,.65,z),dark)
			part(m,"Foot"..sign..z,Vector3.new(.75,.35,1),Vector3.new(sign*.85,.18,z-.15),color)
		end
		local ear=part(m,"Ear"..sign,Vector3.new(.6,.85,.65),Vector3.new(sign*.8,headY+1,-1.8),dark)
		ear.CFrame*=CFrame.Angles(0,0,-sign*.18)
	end
	local tail=part(m,"Tail",Vector3.new(.6,.6,2),Vector3.new(0,2.15,2.1),dark);tail.CFrame*=CFrame.Angles(.35,0,0)
	if shape=="bat" or shape=="owl" or shape=="penguin" then
		body.Size=Vector3.new(2.2,2.6,1.7);body.Position=Vector3.new(0,2,0)
		nose.Size=Vector3.new(.7,.5,.5);nose.Color=Color3.fromRGB(255,161,30)
		for _,sign in {-1,1} do
			local span=shape=="bat" and 3.4 or 1.2
			local wing=part(m,"Wing"..sign,Vector3.new(span,1.6,.45),Vector3.new(sign*(1+span/2),2.25,0),dark)
			wing.CFrame*=CFrame.Angles(0,0,-sign*.22)
			if shape=="bat" then for j=1,3 do part(m,"WingFinger",Vector3.new(.22,1.4,.55),Vector3.new(sign*(1.4+j*.8),1.8,0),color) end end
		end
		tail:Destroy()
	elseif shape=="anteater" then nose.Size=Vector3.new(.75,.8,2.4);nose.Position=Vector3.new(0,2,-3.35)
	elseif shape=="rabbit" then for _,sign in {-1,1} do part(m,"LongEar",Vector3.new(.5,2,.65),Vector3.new(sign*.55,4,-1.8),color) end
	elseif shape=="lion" then part(m,"Mane",Vector3.new(2.8,2.5,1.5),Vector3.new(0,headY,-1.6),dark)
	elseif shape=="camel" then for _,z in {-.25,1.2} do part(m,"Hump",Vector3.new(1.7,1.5,1.2),Vector3.new(0,3,z),dark) end
	elseif shape=="snake" then
		body.Size=Vector3.new(2.1,2.4,1.6);head.Position=Vector3.new(0,4,-.9)
		part(m,"CobraHood",Vector3.new(3.1,2.7,.9),Vector3.new(0,3.3,-.25),dark)
	elseif shape=="scorpion" then
		for _,sign in {-1,1} do for i=1,3 do local leg=part(m,"Claw",Vector3.new(2,.32,.32),Vector3.new(sign*1.7,.7,i-2),dark);leg.CFrame*=CFrame.Angles(0,sign*.4,0) end end
		part(m,"Stinger",Vector3.new(.7,2.7,.7),Vector3.new(0,3.4,1.7),dark)
	elseif shape=="dragon" or shape=="dinosaur" or shape=="longneck" or shape=="cerberus" then
		body.Size=Vector3.new(3.2,2.8,4.6)
		for i=1,5 do part(m,"BackSpike",Vector3.new(.6,1.2,.8),Vector3.new(0,3.6,i-.8),dark) end
		if shape=="longneck" then part(m,"Neck",Vector3.new(1.5,5,1.5),Vector3.new(0,4,-2.4),color);head.Position=Vector3.new(0,6.8,-2.9) end
		if shape=="dragon" then
			for _,sign in {-1,1} do
				local wing=part(m,"DragonWing",Vector3.new(3.8,.32,3.1),Vector3.new(sign*3,3.7,.6),dark);wing.CFrame*=CFrame.Angles(0,sign*.2,sign*.35)
				part(m,"Horn",Vector3.new(.4,1.4,.4),Vector3.new(sign*.7,4,-1.7),cream)
			end
		end
		if shape=="cerberus" then for _,sign in {-1,1} do part(m,"SideHead",Vector3.new(1.7,1.5,1.8),Vector3.new(sign*1.7,2.7,-1.7),color) end end
		for _,sign in {-1,1} do part(m,"Tooth",Vector3.new(.26,.6,.26),Vector3.new(sign*.4,headY-.7,-3.25),cream) end
	end
	local headDelta=head.Position-Vector3.new(0,headY,-1.9)
	if headDelta.Magnitude>.01 then for _,p in m:GetChildren() do if p:IsA("BasePart") and (p.Name:find("Eye") or p.Name:find("Ear") or p.Name=="Muzzle" or p.Name=="Nose") then p.Position+=headDelta end end end
	m:SetAttribute("Weight",weight or 1)
	m:ScaleTo(Visuals.petScale(kind,weight))
	return m
end

function Visuals.pickaxe(index)
	local info=Game.Pickaxes[index] or Game.Pickaxes[1]
	local templates=game.ReplicatedStorage:FindFirstChild("PickaxeModels")
	local template=templates and templates:FindFirstChild(info.key)
	if template and template:IsA("MeshPart") then
		local model=Instance.new("Model");model.Name=info.name
		local handle=Instance.new("Part");handle.Name="Handle";handle.Size=Vector3.new(.25,.25,.25)
		handle.Transparency=1;handle.Anchored=true;handle.CanCollide=false;handle.CanTouch=false;handle.CanQuery=false;handle.Parent=model
		model.PrimaryPart=handle
		local mesh=template:Clone();mesh.Name="PickaxeMesh";mesh.Anchored=true;mesh.CanCollide=false;mesh.CanTouch=false;mesh.CanQuery=false;mesh.Massless=true;mesh.Parent=model
		-- Full-pack templates carry a grip pivot independent of their mesh center.
		if mesh:GetAttribute("SourcePackVersion") then
			mesh.Color=Color3.new(1,1,1)
			mesh:PivotTo(handle.CFrame)
		end
		model:ScaleTo(Visuals.PickaxeHeight / mesh.Size.Y)
		return model
	end
	local m=Instance.new("Model");m.Name=info.name
	local handle=part(m,"Handle",Vector3.new(.5,4,.55),Vector3.new(0,2,0),Color3.fromRGB(135,65,27));m.PrimaryPart=handle
	for _,y in {.55,1.9,3.3} do part(m,"IronBand",Vector3.new(.67,.32,.7),Vector3.new(0,y,0),Color3.fromRGB(171,188,213)) end
	part(m,"Head",Vector3.new(1.3,1,.85),Vector3.new(0,4.1,0),info.color)
	for _,sign in {-1,1} do
		local arm=part(m,"PickArc",Vector3.new(1.6,.85,.8),Vector3.new(sign*1.2,3.85,0),info.color);arm.CFrame*=CFrame.Angles(0,0,-sign*.36)
		local tip=part(m,"PickTip",Vector3.new(1.2,.65,.65),Vector3.new(sign*2.25,3.24,0),info.color);tip.CFrame*=CFrame.Angles(0,0,-sign*.8)
	end
	local gem=part(m,"Gem",Vector3.new(.55,.55,.15),Vector3.new(0,4.1,-.5),Color3.fromRGB(162,187,226));gem.CFrame*=CFrame.Angles(0,0,math.pi/4)
	-- Use the same lower-shaft grip origin as the imported meshes.
	handle.Name="Shaft"
	local grip=Instance.new("Part");grip.Name="Handle";grip.Size=Vector3.new(.25,.25,.25);grip.Transparency=1
	grip.Anchored=true;grip.CanCollide=false;grip.CanTouch=false;grip.CanQuery=false;grip.Parent=m
	for _,p in m:GetChildren() do if p:IsA("BasePart") and p~=grip then p.CFrame-=Vector3.new(0,.9,0) end end
	m.PrimaryPart=grip
	local _,size=m:GetBoundingBox()
	m:ScaleTo(Visuals.PickaxeHeight / size.Y)
	return m
end

function Visuals.placement(kind,petKind,weight)
	return kind == "Egg" and Visuals.egg() or Visuals.pet(petKind,weight)
end

return Visuals
