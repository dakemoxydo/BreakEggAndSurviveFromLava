local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local player = Players.LocalPlayer
local Config = require(RS:WaitForChild("PetConfig"))
local PetAnimation = require(RS:WaitForChild("PetAnimation"))
local PetVisuals = require(RS:WaitForChild("PetVisuals"))
local remote = RS:WaitForChild("UIAction")
local highlight = Instance.new("Highlight")
highlight.Name = "MyBaseHighlight"
highlight.FillTransparency = 0.94
highlight.OutlineTransparency = 0.15
highlight.OutlineColor = Color3.fromRGB(100, 255, 0)
highlight.Enabled = false
highlight.Parent = workspace
local preview, previewKind, previewOutline
local previewParts = {}
local point, valid, placing = nil, false, false
local function attribute(name, value)
	if player:GetAttribute(name) ~= value then
		player:SetAttribute(name, value)
	end
end
local function heldTool()
	local character = player.Character
	if not character then
		return nil
	end
	for _, tool in character:GetChildren() do
		if tool:IsA("Tool") and tool:GetAttribute("PlacementKind") then
			return tool
		end
	end
	return nil
end
local function getBase()
	local map = workspace:FindFirstChild("Map")
	local start = map and map:FindFirstChild("StartZone")
	local bases = start and start:FindFirstChild("PlayerBases")
	local base = bases and bases:FindFirstChild(player:GetAttribute("BaseName") or "")
	if base and base:GetAttribute("OwnerUserId") == player.UserId and base:FindFirstChild("BaseAnchor") then
		return base
	end
	return nil
end

local function createPreview(kind, petKind, weight)
	local key = kind .. (petKind or "TestChick") .. tostring(weight or 1)
	if preview and previewKind == key then
		return
	end
	if preview then
		preview:Destroy()
	end
	preview = PetVisuals.placement(kind, petKind, weight)
	preview.Name = "PlacementPreview"
	previewKind = key
	table.clear(previewParts)
	for _, item in preview:GetDescendants() do
		if item:IsA("BasePart") then
			item.Anchored = true
			item.CanCollide = false
			item.CanTouch = false
			item.CanQuery = false
			item.CastShadow = false
			item.Transparency = 0.48
			item.LocalTransparencyModifier = 1
			table.insert(previewParts, item)
		elseif item:IsA("Highlight") then
			item.Enabled = false
		end
	end
	previewOutline = Instance.new("Highlight")
	previewOutline.Name = "PlacementPreviewOutline"
	previewOutline.Adornee = preview
	previewOutline.FillTransparency = 0.85
	previewOutline.OutlineTransparency = 0.08
	previewOutline.DepthMode = Enum.HighlightDepthMode.Occluded
	previewOutline.Parent = preview
	previewOutline.Enabled = false
	preview.Parent = workspace
end

local function setPreviewVisible(visible)
	if not preview then
		return
	end
	for _, item in previewParts do
		item.LocalTransparencyModifier = visible and 0 or 1
	end
	previewOutline.Enabled = visible
end

local function update(screenPoint)
	local tool, base = heldTool(), getBase()
	local kind = tool and tool:GetAttribute("PlacementKind")
	if player:GetAttribute("PlacementKind") ~= kind then
		attribute("PlacementError", nil)
	end
	attribute("PlacementKind", kind)
	highlight.Adornee = base
	highlight.Enabled = kind ~= nil and base ~= nil and not player:GetAttribute("UIWindowOpen")
	point, valid = nil, false
	if not tool or not base or player:GetAttribute("UIWindowOpen") then
		setPreviewVisible(false)
		attribute("PlacementValid", false)
		return
	end
	createPreview(kind, tool:GetAttribute("PetKind"), tool:GetAttribute("PetWeight"))
	local camera = workspace.CurrentCamera
	if not camera then
		setPreviewVisible(false)
		attribute("PlacementValid", false)
		return
	end
	local ray
	if screenPoint then
		ray = camera:ViewportPointToRay(screenPoint.X, screenPoint.Y)
	else
		local mouse = UIS:GetMouseLocation()
		-- GetMouseLocation includes the top bar; use viewport coordinates without a second inset.
		ray = camera:ViewportPointToRay(mouse.X, mouse.Y)
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local excluded = { player.Character, preview, base.BaseAnchor }
	if base:FindFirstChild("PetContents") then
		table.insert(excluded, base.PetContents)
	end
	params.FilterDescendantsInstances = excluded
	local hit = workspace:Raycast(ray.Origin, ray.Direction * 500, params)
	if hit then
		local floor = base:GetAttribute("FloorY")
		if typeof(floor) ~= "number" or math.abs(hit.Position.Y - floor) >= 1 or hit.Normal.Y < 0.99 then
			setPreviewVisible(false)
			attribute("PlacementValid", false)
			return
		end
		-- Intersect the same cursor ray with the placement floor, preserving cursor alignment.
		if ray.Direction.Y >= -0.001 then
			setPreviewVisible(false)
			attribute("PlacementValid", false)
			return
		end
		local distance = (floor - ray.Origin.Y) / ray.Direction.Y
		if distance < 0 or distance > 500 then
			setPreviewVisible(false)
			attribute("PlacementValid", false)
			return
		end
		local target = ray.Origin + ray.Direction * distance
		local localPoint = base.BaseAnchor.CFrame:PointToObjectSpace(target)
		local halfWidth = base:GetAttribute("PenHalfWidth") or Config.PenHalfWidth
		local halfDepth = base:GetAttribute("PenHalfDepth") or Config.PenHalfDepth
		local insideBase = math.abs(localPoint.X) <= halfWidth and math.abs(localPoint.Z) <= halfDepth
		if not insideBase then
			setPreviewVisible(false)
			attribute("PlacementValid", false)
			return
		end
		point = target
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		local clearOfEggs = true
		local contents = base:FindFirstChild("PetContents")
		if contents then
			for _, model in contents:GetChildren() do
				if
					model:IsA("Model")
					and model:GetAttribute("EggVisual") == true
					and (model:GetPivot().Position - point).Magnitude < 3.5
				then
					clearOfEggs = false
					break
				end
			end
		end
		valid = root ~= nil
			and (root.Position - point).Magnitude <= Config.PlacementRange
			and clearOfEggs
			and (
				kind ~= "Pet"
				or (
					math.abs(localPoint.X) <= halfWidth - Config.PetEdgeMargin
					and math.abs(localPoint.Z) <= halfDepth - Config.PetEdgeMargin
				)
			)
		preview:PivotTo(CFrame.new(point))
		previewOutline.OutlineColor = valid and Color3.fromRGB(100, 255, 0) or Color3.fromRGB(245, 36, 37)
		previewOutline.FillColor = previewOutline.OutlineColor
		setPreviewVisible(true)
	else
		setPreviewVisible(false)
	end
	attribute("PlacementValid", valid)
end
local function place(screenPoint)
	if placing or player:GetAttribute("UIWindowOpen") then
		return
	end
	update(screenPoint)
	local tool = heldTool()
	if not tool then
		return
	end
	if not valid or not point then
		attribute("PlacementError", "Aim at the ground inside your base.")
		return
	end
	placing = true
	local name = tool:GetAttribute("PlacementKind") == "Egg" and "PlaceEgg" or "PlacePet"
	local at = point
	local ok, result = pcall(function()
		return remote:InvokeServer(name, { position = at, yaw = 0 })
	end)
	placing = false
	attribute("PlacementError", ok and result.message or "Couldn't place. Try again.")
end
local previewRenderName = "PetPlacementPreview"
RunService:BindToRenderStep(previewRenderName, Enum.RenderPriority.Camera.Value + 1, function()
	update()
end)
UIS.InputBegan:Connect(function(input, processed)
	if processed then
		return
	end
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		task.spawn(place)
	elseif input.KeyCode == Enum.KeyCode.Escape and heldTool() then
		local humanoid = player.Character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid:UnequipTools()
		end
	end
end)
UIS.TouchTapInWorld:Connect(function(at, processed)
	if not processed then
		task.spawn(place, at)
	end
end)

local function refreshModel(model)
	local owner = model:GetAttribute("OwnerUserId")
	local isPet, isEgg = model:GetAttribute("PetVisual"), model:GetAttribute("EggVisual")
	if not isPet and not isEgg then
		return
	end
	local mine = owner == player.UserId
	local visible = isPet and player:GetAttribute(mine and "ViewMyPets" or "ViewOthersPets") ~= false
		or isEgg and (not mine or player:GetAttribute("ViewMyEggs") ~= false)
	for _, v in model:GetDescendants() do
		if v:IsA("BasePart") then
			v.LocalTransparencyModifier = visible and 0 or 1
		elseif v:IsA("BillboardGui") or v:IsA("Highlight") then
			v.Enabled = visible
		end
	end
end
local function refreshVisibility()
	local baseRoot = workspace:FindFirstChild("Map")
	if not baseRoot then
		return
	end
	for _, model in baseRoot:GetDescendants() do
		if model:IsA("Model") then
			refreshModel(model)
		end
	end
end
local petVisuals = setmetatable({}, { __mode = "k" })
-- Carry pose is cosmetic on every client; ownership and banking stay server-side.
local carryPoses = setmetatable({}, { __mode = "k" })
RunService.PreAnimation:Connect(function()
	for character, state in carryPoses do
		for _, item in state.joints do
			if item.joint.Parent then
				item.joint.Transform = item.base
			end
		end
	end
end)
RunService.PreSimulation:Connect(function(dt)
	for _, owner in Players:GetPlayers() do
		local character = owner.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local carrying = humanoid and humanoid.Health > 0 and (owner:GetAttribute("CarryingCount") or 0) > 0
		local state = character and carryPoses[character]
		if carrying and not state then
			state = { weight = 0, joints = {} }
			carryPoses[character] = state
			for _, joint in character:GetDescendants() do
				if joint:IsA("Motor6D") or joint:IsA("AnimationConstraint") then
					local sign = ({
						RightShoulder = 1,
						["Right Shoulder"] = 1,
						LeftShoulder = -1,
						["Left Shoulder"] = -1,
					})[joint.Name]
					local elbow = joint.Name == "RightElbow" or joint.Name == "LeftElbow"
					if sign or elbow then
						table.insert(
							state.joints,
							{ joint = joint, base = joint.Transform, sign = sign, elbow = elbow }
						)
					end
				end
			end
		end
		if state then
			state.weight += ((carrying and 1 or 0) - state.weight) * (1 - math.exp(-dt * 18))
			for _, item in state.joints do
				if item.joint.Parent then
					local joint = item.joint
					item.base = joint.Transform
					local rotation = item.elbow and CFrame.Angles(math.rad(25), 0, 0)
						or CFrame.Angles(math.rad(155), 0, math.rad(item.sign * 12))
					local basis = joint.C0.Rotation
					local pose = CFrame.new(item.base.Position) * basis:Inverse() * rotation * basis
					joint.Transform = item.base:Lerp(pose, state.weight)
				end
			end
		end
	end
	for character, state in carryPoses do
		if not character.Parent or state.weight < 0.001 then
			for _, item in state.joints do
				if item.joint.Parent then
					item.joint.Transform = item.base
				end
			end
			carryPoses[character] = nil
		end
	end
end)
local function attachPetVisual(model)
	local animated = model:GetAttribute("PetVisual") == true or model:GetAttribute("Guardian") == true
	if not model:IsA("Model") or not animated or petVisuals[model] then
		return
	end
	local rig = PetAnimation.bind(model)
	if not rig then
		local body = model.PrimaryPart or model:FindFirstChild("Body")
		if not body or not body:IsA("BasePart") then
			return
		end
		rig = { Body = body, generic = true }
	end
	local initial = model:GetPivot()
	local state = {
		rig = rig,
		current = initial,
		target = initial,
		phase = model:GetAttribute("AnimationOffset") or 0,
		idleTime = model:GetAttribute("AnimationOffset") or 0,
		walkWeight = 0,
		walking = model:GetAttribute("PetWalking") == true,
	}
	-- Imported rigs carry their own Idle/Walk clips; tracks play locally on every client.
	local animator = model:FindFirstChild("Animator", true)
	local animations = model:FindFirstChild("Animations")
	if rig.generic and animator and animations then
		local tracks = {}
		for _, name in { "Idle", "Walk" } do
			local animation = animations:FindFirstChild(name)
			if animation and animation:IsA("Animation") and animation.AnimationId ~= "" then
				local track = animator:LoadAnimation(animation)
				track.Looped = true
				track:Play(0, 0.001)
				tracks[name] = track
			end
		end
		state.tracks = next(tracks) and tracks or nil
	end
	petVisuals[model] = state
	local function refreshTarget()
		local at = model:GetAttribute("PetPosition")
		local yaw = model:GetAttribute("PetYaw")
		if typeof(at) == "Vector3" then
			state.target = CFrame.new(at) * CFrame.Angles(0, typeof(yaw) == "number" and yaw or 0, 0)
		end
		state.walking = model:GetAttribute("PetWalking") == true
	end
	model:GetAttributeChangedSignal("PetPosition"):Connect(refreshTarget)
	model:GetAttributeChangedSignal("PetYaw"):Connect(refreshTarget)
	model:GetAttributeChangedSignal("PetWalking"):Connect(refreshTarget)
	model.Destroying:Connect(function()
		petVisuals[model] = nil
	end)
	refreshTarget()
end
workspace.DescendantAdded:Connect(function(v)
	if v:IsA("Model") or v:IsA("BasePart") or v:IsA("BillboardGui") then
		task.defer(function()
			local model = v:IsA("Model") and v or v:FindFirstAncestorOfClass("Model")
			if model then
				refreshModel(model)
				attachPetVisual(model)
			end
		end)
	end
end)
for _, model in workspace:GetDescendants() do
	if model:IsA("Model") then
		attachPetVisual(model)
	end
end
RunService.RenderStepped:Connect(function(dt)
	local alpha = 1 - math.exp(-dt * 16)
	for model, state in petVisuals do
		if not model.Parent then
			petVisuals[model] = nil
			continue
		end
		state.current = state.current:Lerp(state.target, alpha)
		if (state.current.Position - state.target.Position).Magnitude < 0.015 then
			state.current = state.target
		end
		state.idleTime += dt
		local walkTarget = state.walking and 1 or 0
		state.walkWeight += (walkTarget - state.walkWeight) * (1 - math.exp(-dt * 12))
		if state.walking then
			state.phase = (state.phase + dt * PetAnimation.WalkCycleSpeed) % (math.pi * 2)
		end
		if state.rig.Body.Parent and state.rig.Body.LocalTransparencyModifier < 1 then
			if state.tracks then
				model:PivotTo(state.current)
				for name, track in state.tracks do
					local weight = name == "Walk" and state.walkWeight or 1 - state.walkWeight
					track:AdjustWeight(math.max(weight, 0.001), 0)
				end
			elseif state.rig.generic then
				model:PivotTo(
					state.current * CFrame.new(0, math.abs(math.sin(state.phase)) * 0.12 * state.walkWeight, 0)
				)
			else
				PetAnimation.apply(model, state.rig, state.current, state.phase, state.walkWeight, state.idleTime)
			end
		end
	end
end)
for _, key in { "ViewMyPets", "ViewOthersPets", "ViewMyEggs" } do
	player:GetAttributeChangedSignal(key):Connect(refreshVisibility)
end
local weightGui = Instance.new("BillboardGui")
weightGui.Name = "PetWeightHover"
weightGui.Size = UDim2.fromOffset(180, 48)
weightGui.AlwaysOnTop = true
weightGui.MaxDistance = 140
weightGui.Enabled = false
weightGui.Parent = player:WaitForChild("PlayerGui")
local weightText = Instance.new("TextLabel")
weightText.Size = UDim2.fromScale(1, 1)
weightText.BackgroundTransparency = 1
weightText.Font = Enum.Font.GothamBlack
weightText.TextSize = 28
weightText.TextColor3 = Color3.new(1, 1, 1)
weightText.Parent = weightGui
local weightStroke = Instance.new("UIStroke")
weightStroke.Thickness = 3
weightStroke.Color = Color3.fromRGB(20, 22, 26)
weightStroke.Parent = weightText
local hoveredPet, hoverElapsed = nil, 0
-- Pet parts are non-queryable so placement rays still reach the pen floor.
-- Intersect their visual bounds separately for the hover tooltip.
local function rayBox(origin, direction, cf, size)
	local o = cf:PointToObjectSpace(origin)
	local d = cf:VectorToObjectSpace(direction)
	local half = size / 2
	local near, far = 0, 140
	for _, axis in { "X", "Y", "Z" } do
		if math.abs(d[axis]) < 1e-6 then
			if math.abs(o[axis]) > half[axis] then
				return
			end
		else
			local a = (-half[axis] - o[axis]) / d[axis]
			local b = (half[axis] - o[axis]) / d[axis]
			near = math.max(near, math.min(a, b))
			far = math.min(far, math.max(a, b))
			if near > far then
				return
			end
		end
	end
	return near
end
local hoverRayParams = RaycastParams.new()
hoverRayParams.FilterType = Enum.RaycastFilterType.Exclude
RunService.RenderStepped:Connect(function(dt)
	hoverElapsed += dt
	if player:GetAttribute("UIWindowOpen") or not UIS.MouseEnabled then
		hoveredPet = nil
	end
	if hoverElapsed >= 0.05 then
		hoverElapsed = 0
		hoveredPet = nil
		local camera = workspace.CurrentCamera
		if camera and UIS.MouseEnabled and not player:GetAttribute("UIWindowOpen") then
			local cursor = UIS:GetMouseLocation()
			local ray = camera:ViewportPointToRay(cursor.X, cursor.Y)
			local closest = 140
			hoverRayParams.FilterDescendantsInstances = player.Character and { player.Character } or {}
			local obstacle = workspace:Raycast(ray.Origin, ray.Direction * 140, hoverRayParams)
			if obstacle then
				closest = obstacle.Distance
			end
			for model, state in petVisuals do
				if
					model.Parent
					and model:IsDescendantOf(workspace.Map.StartZone.PlayerBases)
					and model.PrimaryPart
					and state.rig.Body.LocalTransparencyModifier < 1
					and typeof(model:GetAttribute("Weight")) == "number"
				then
					local cf, size = model:GetBoundingBox()
					local distance = rayBox(ray.Origin, ray.Direction, cf, size)
					if distance and distance < closest then
						closest = distance
						hoveredPet = model
					end
				end
			end
		end
	end
	if hoveredPet and hoveredPet.Parent and hoveredPet.PrimaryPart then
		local cf, size = hoveredPet:GetBoundingBox()
		weightGui.Adornee = hoveredPet.PrimaryPart
		weightGui.StudsOffsetWorldSpace = Vector3.new(cf.Position.X, cf.Position.Y + size.Y / 2 + 0.65, cf.Position.Z)
			- hoveredPet.PrimaryPart.Position
		local value = hoveredPet:GetAttribute("Weight")
		weightText.Text = string.format("%.1f", value):gsub("%.0$", "") .. " kg"
		weightGui.Enabled = true
	else
		weightGui.Enabled = false
		weightGui.Adornee = nil
	end
end)
-- Settings volume is applied per SoundGroup by Audio.
require(RS:WaitForChild("Audio")).start()
refreshVisibility()
script.Destroying:Connect(function()
	RunService:UnbindFromRenderStep(previewRenderName)
	if preview then
		preview:Destroy()
	end
	highlight:Destroy()
end)
