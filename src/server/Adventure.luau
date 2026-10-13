local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Http = game:GetService("HttpService")
local Game = require(RS:WaitForChild("GameConfig"))
local Visuals = require(RS:WaitForChild("PetVisuals"))
local Adventure = {}
local services, field, remote, feedback
local eggs, cargo, lastSwing, stunned = {}, {}, {}, {}
-- DevTools test switches; per-player tables are keyed by Player and cleared when they leave.
Adventure.dev = {
	lavaInterval = nil, -- seconds between waves; nil = Game.LavaInterval
	lavaOff = false,
	immune = {},
	oneHit = {},
	rarity = {}, -- forced rarity key of eggs this player breaks
	luck = {}, -- extra luck multiplier
}
local dev = Adventure.dev
local random = Random.new()
local function character(player)
	local model = player.Character
	local root = model and model:FindFirstChild("HumanoidRootPart")
	local humanoid = model and model:FindFirstChildOfClass("Humanoid")
	if root and humanoid and humanoid.Health > 0 then
		return root, humanoid
	end
end
-- kind: "danger" | "event" | nil (info); the client colors the toast and picks its sound.
function Adventure.notice(player, message, kind)
	if not message then
		return
	end
	player:SetAttribute("GameplayNoticeKind", kind)
	player:SetAttribute("GameplayNotice", message)
	player:SetAttribute("GameplayNoticeAt", os.clock())
end
function Adventure.hasCargo(player)
	return cargo[player] and #cargo[player] > 0
end
local function prompt(parent, action, object, callback)
	local p = Instance.new("ProximityPrompt")
	p.ActionText = action
	p.ObjectText = object
	p.RequiresLineOfSight = false
	p.MaxActivationDistance = 12
	p.HoldDuration = 0.15
	p.Parent = parent
	p.Triggered:Connect(callback)
	return p
end
-- Swaps rig joints for ball sockets and flings every limb; the server owns the
-- parts while limp so the push is not lost to client ownership.
local function ragdoll(player, velocity, duration)
	local model = player.Character
	local root, humanoid = character(player)
	if not root then
		return
	end
	local token = {}
	local already = stunned[player] and stunned[player].model == model
	if not already then
		local joints, sockets = {}, {}
		for _, joint in model:GetDescendants() do
			if (joint:IsA("Motor6D") or joint:IsA("AnimationConstraint")) and joint.Enabled and joint.Part1 then
				-- Kinematic AnimationConstraint exposes the same C0/C1/Part0/Part1 as Motor6D.
				local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
				a0.CFrame, a1.CFrame = joint.C0, joint.C1
				a0.Parent, a1.Parent = joint.Part0, joint.Part1
				local socket = Instance.new("BallSocketConstraint")
				socket.Attachment0, socket.Attachment1 = a0, a1
				socket.LimitsEnabled, socket.TwistLimitsEnabled = true, true
				socket.UpperAngle, socket.TwistLowerAngle, socket.TwistUpperAngle = 60, -45, 45
				socket.Parent = joint.Part1
				table.insert(sockets, a0)
				table.insert(sockets, a1)
				table.insert(joints, joint)
				joint.Enabled = false
			end
		end
		humanoid.RequiresNeck = false
		humanoid.PlatformStand = true
		stunned[player] = { model = model, joints = joints, sockets = sockets }
	end
	stunned[player].token = token
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") and not part.Anchored then
			if part:CanSetNetworkOwnership() then
				part:SetNetworkOwner(nil)
			end
			part.AssemblyLinearVelocity = velocity
		end
	end
	task.delay(duration, function()
		local state = stunned[player]
		if not state or state.token ~= token then
			return
		end
		stunned[player] = nil
		for _, joint in state.joints do
			joint.Enabled = true
		end
		for _, attachment in state.sockets do
			attachment:Destroy()
		end
		if model.Parent and root.Parent and humanoid.Health > 0 then
			local look = root.CFrame.LookVector * Vector3.new(1, 0, 1)
			root.CFrame = CFrame.lookAt(
				root.Position + Vector3.new(0, 2, 0),
				root.Position + Vector3.new(0, 2, 0) + (look.Magnitude > 0.01 and look or Vector3.zAxis)
			)
			root.AssemblyLinearVelocity = Vector3.zero
			humanoid.PlatformStand = false
			humanoid.RequiresNeck = true
			if root:CanSetNetworkOwnership() then
				root:SetNetworkOwner(player)
			end
		end
	end)
end
function Adventure.equipPickaxe(player, index)
	local backpack = player:FindFirstChildOfClass("Backpack")
	if not backpack then
		return
	end
	for _, container in { backpack, player.Character } do
		if container then
			for _, tool in container:GetChildren() do
				if tool:IsA("Tool") and (tool:GetAttribute("Pickaxe") or tool:GetAttribute("TemporaryModel")) then
					tool:Destroy()
				end
			end
		end
	end
	local tool = services.world.tool("Pickaxe", nil, index)
	tool.Parent = backpack
	local _, humanoid = character(player)
	if humanoid and not player:GetAttribute("PlacementKind") then
		humanoid:EquipTool(tool)
	end
end
function Adventure.applyTrail(player, state)
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	for _, d in root:GetChildren() do
		if d.Name == "EquippedTrail" or d.Name == "TrailTop" or d.Name == "TrailBottom" then
			d:Destroy()
		end
	end
	if state.trail <= 1 then
		return
	end
	local info = Game.Trails[state.trail]
	local a = Instance.new("Attachment")
	a.Name = "TrailTop"
	a.Position = Vector3.new(0, 1, 0.7)
	a.Parent = root
	local b = Instance.new("Attachment")
	b.Name = "TrailBottom"
	b.Position = Vector3.new(0, -1, 0.7)
	b.Parent = root
	local trail = Instance.new("Trail")
	trail.Name = "EquippedTrail"
	trail.Attachment0 = a
	trail.Attachment1 = b
	trail.Lifetime = 0.4
	trail.MinLength = 0.12
	trail.LightEmission = 1
	trail.Color = ColorSequence.new(info.color, Color3.new(1, 1, 1))
	trail.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.12), NumberSequenceKeypoint.new(1, 1) })
	trail.Parent = root
end
local function eggLabel(model, info, hp)
	local gui = Instance.new("BillboardGui")
	gui.Name = "EggLabel"
	gui.Size = UDim2.fromScale(8, 3.5)
	gui.AlwaysOnTop = false
	gui.Adornee = model.PrimaryPart
	gui.Parent = model
	local _, size = model:GetBoundingBox()
	gui.StudsOffsetWorldSpace = Vector3.new(0, size.Y * 0.65 + 1, 0)
	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.fromScale(1, 0.64)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.GothamBlack
	title.TextScaled = true
	title.TextColor3 = Color3.new(1, 1, 1)
	title.Text = info.name .. "\n" .. info.rarity
	title.Parent = gui
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 3
	stroke.Parent = title
	local bar = Instance.new("Frame")
	bar.Name = "Health"
	bar.Size = UDim2.fromScale(0.92, 0.3)
	bar.Position = UDim2.fromScale(0.04, 0.68)
	bar.BackgroundColor3 = Color3.fromRGB(24, 24, 24)
	bar.BorderSizePixel = 2
	bar.Visible = false
	bar.Parent = gui
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = Color3.fromRGB(133, 255, 0)
	fill.BorderSizePixel = 0
	fill.Parent = bar
	local studs = Instance.new("ImageLabel")
	studs.Image = Game.StudTexture
	studs.ImageColor3 = fill.BackgroundColor3
	studs.BackgroundTransparency = 1
	studs.Size = UDim2.fromScale(1, 1)
	studs.ScaleType = Enum.ScaleType.Tile
	studs.TileSize = UDim2.fromOffset(20, 20)
	studs.Parent = fill
	local value = Instance.new("TextLabel")
	value.Name = "Value"
	value.BackgroundTransparency = 1
	value.Size = UDim2.fromScale(1, 1)
	value.Font = Enum.Font.GothamBlack
	value.TextScaled = true
	value.TextColor3 = Color3.new(1, 1, 1)
	value.Text = Game.number(hp) .. "/" .. Game.number(hp) .. " HP"
	value.Parent = bar
	local outline = Instance.new("UIStroke")
	outline.Thickness = 2
	outline.Parent = value
	return gui
end
-- `luck` already includes the breaker's rebirth bonus.
local function roll(info, luck, forced)
	if info.biome == "Titanic" then
		return "TitanDragon"
	end
	if forced then
		for _, pet in Game.Pets do
			if pet.biome == info.biome and pet.rarity == forced then
				return pet.key
			end
		end
	end
	local options, total = {}, 0
	local index = 0
	for _, pet in Game.Pets do
		if pet.biome == info.biome then
			index += 1
			local weight = pet.weight * math.max(0.5, luck) ^ ((index - 1) * 0.45)
			total += weight
			table.insert(options, { pet = pet, total = total })
		end
	end
	local value = random:NextNumber() * total
	for _, item in options do
		if value <= item.total then
			return item.pet.key
		end
	end
	return options[1].pet.key
end
local spawnEgg
local function respawn(record, delay)
	eggs[record.id] = nil
	if record.model then
		record.model:Destroy()
		record.model = nil
	end
	-- Dropped animals have no egg info and never come back as eggs.
	if record.info and record.info.biome ~= "Titanic" then
		task.delay(delay, function()
			if field.Parent then
				spawnEgg(record.info, record.at, record.scale, record.skin)
			end
		end)
	end
end
local function steal(player, record)
	local state = services.states[player]
	local root = character(player)
	if not state or not state.ready or not services.active(player) or not root or record.status ~= "Hatched" then
		return
	end
	if (root.Position - record.at).Magnitude > 14 then
		return
	end
	local held = cargo[player] or {}
	if #held >= state.satchelLevel then
		Adventure.notice(player, "Satchel full. Bring your animals back or upgrade it.")
		return
	end
	if #state.pets + #state.eggs + #state.backpackEggs + #held >= require(RS.PetConfig).MaxPets then
		Adventure.notice(player, "Your inventory is full.")
		return
	end
	record.status = "Stolen"
	local model = Visuals.pet(record.pet, record.weight)
	model.Name = "StolenAnimal"
	local head = player.Character:FindFirstChild("Head")
	if not head then
		model:Destroy()
		record.status = "Hatched"
		return
	end
	model:SetAttribute("CarriedPet", true)
	model:SetAttribute("OwnerUserId", player.UserId)
	local height = head.Size.Y / 2 + 0.25
	for _, item in held do
		if item.model and item.model.Parent then
			local _, size = item.model:GetBoundingBox()
			height += size.Y + 0.25
		end
	end
	model:PivotTo(head.CFrame * CFrame.new(0, height, 0))
	local body = model.PrimaryPart
	for _, p in model:GetDescendants() do
		if p:IsA("BasePart") then
			p.Anchored = false
			p.Massless = true
			p.CanCollide = false
			p.CanTouch = false
			p.CanQuery = false
			if p ~= body then
				local weld = Instance.new("WeldConstraint")
				weld.Part0 = body
				weld.Part1 = p
				weld.Parent = p
			end
		end
	end
	local weld = Instance.new("WeldConstraint")
	weld.Name = "HeadCarry"
	weld.Part0 = head
	weld.Part1 = body
	weld.Parent = body
	model.Parent = player.Character
	local humanoid = player.Character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid:UnequipTools()
	end
	table.insert(held, { kind = record.pet, weight = record.weight, model = model })
	cargo[player] = held
	player:SetAttribute("CarryingCount", #held)
	player:SetAttribute("CarryingName", Game.pet(record.pet).name)
	respawn(record, Game.EggRespawnSeconds)
end
-- A dropped animal hops from where it was carried to the ground and can be stolen again.
local function dropAnimal(item, from, ground)
	local info = Game.pet(item.kind)
	local model = Visuals.pet(item.kind, item.weight)
	model.Name = "DroppedAnimal"
	model:SetAttribute("FieldAnimal", true)
	model:PivotTo(CFrame.new(ground))
	local box, size = model:GetBoundingBox()
	local rest = CFrame.new(ground + Vector3.new(0, ground.Y - (box.Y - size.Y / 2), 0))
		* CFrame.Angles(0, random:NextNumber(0, 2 * math.pi), 0)
	model:PivotTo(rest.Rotation + from)
	model.Parent = field
	local record = {
		id = Http:GenerateGUID(false),
		pet = item.kind,
		weight = item.weight,
		at = rest.Position,
		model = model,
		status = "Dropping",
	}
	eggs[record.id] = record
	model:SetAttribute("EggId", record.id)
	services.world.label(
		model,
		info.name .. "\n+$" .. Game.number(Game.income({ kind = item.kind, weight = item.weight })) .. "/s"
	)
	prompt(model.PrimaryPart, "Steal", info.name, function(visitor)
		steal(visitor, record)
	end)
	task.spawn(function()
		local started = os.clock()
		while model.Parent do
			local t = math.min((os.clock() - started) / 0.45, 1)
			model:PivotTo(rest.Rotation + from:Lerp(rest.Position, t) + Vector3.new(0, math.sin(t * math.pi) * 2.5, 0))
			if t >= 1 then
				break
			end
			task.wait()
		end
		if record.status == "Dropping" then
			record.status = "Hatched"
		end
	end)
	task.delay(45, function()
		if record.status == "Hatched" or record.status == "Dropping" then
			record.status = "Expired"
			respawn(record, 1)
		end
	end)
end
-- Knocked-off cargo lands around the carrier instead of vanishing (GP-02: it still leaves the carrier).
local function dropCargo(player, reason)
	local held = cargo[player]
	if not held then
		return
	end
	cargo[player] = nil
	player:SetAttribute("CarryingCount", 0)
	player:SetAttribute("CarryingName", nil)
	local ignore = { field }
	for _, other in Players:GetPlayers() do
		table.insert(ignore, other.Character)
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignore
	for i, item in held do
		local from = item.model and item.model.Parent and item.model:GetPivot().Position
		if item.model then
			item.model:Destroy()
		end
		if from then
			local angle = (i / #held + random:NextNumber(0, 0.2)) * 2 * math.pi
			local side = Vector3.new(math.cos(angle), 0, math.sin(angle)) * random:NextNumber(3, 5)
			local hit = workspace:Raycast(from + side + Vector3.new(0, 2, 0), Vector3.new(0, -200, 0), params)
			if hit then
				dropAnimal(item, from, hit.Position)
			end
		end
	end
	Adventure.notice(player, reason, "danger")
end
local function hatch(record, player)
	if record.status ~= "Egg" then
		return
	end
	record.status = "Hatching"
	local started = workspace:GetServerTimeNow()
	record.model:SetAttribute("HatchStarted", started)
	record.model:SetAttribute("HatchDuration", Game.FieldHatchDuration)
	record.model:SetAttribute("HatchGrowth", Game.FieldHatchGrowth)
	local breaker = player and services.states[player]
	local luck = record.info.luck
		* Game.rebirthLuck(breaker and breaker.rebirths or 0)
		* (player and dev.luck[player] or 1)
	record.model:SetAttribute("HatchLuck", luck)
	-- Roll up front so clients can build the rarity reveal; the result is fixed either way.
	record.pet = roll(record.info, luck, player and dev.rarity[player])
	record.weight = math.max(0.1, math.floor(record.scale ^ 3 * random:NextNumber(0.7, 2.4) * 10) / 10)
	record.model:SetAttribute("HatchRarity", Game.pet(record.pet).rarity)
	if player then
		record.model:SetAttribute("HatchedBy", player.UserId)
	end
	record.model:SetAttribute("Hatching", true)
	if record.label then
		record.label.Enabled = false
	end
	feedback:FireAllClients(
		"Hatch",
		record.at,
		{ model = record.model, started = started, duration = Game.FieldHatchDuration, luck = luck }
	)
	task.delay(Game.FieldHatchDuration, function()
		if record.status ~= "Hatching" or not record.model or not record.model.Parent then
			return
		end
		local shell = record.model
		local model = Visuals.pet(record.pet, record.weight)
		model:SetAttribute("FieldAnimal", true)
		model:SetAttribute("EggId", record.id)
		model:SetAttribute("HatchRarity", Game.pet(record.pet).rarity)
		if player then
			model:SetAttribute("HatchedBy", player.UserId)
		end
		model:SetAttribute("HatchRevealStarted", workspace:GetServerTimeNow())
		model:SetAttribute("HatchRevealDuration", Game.FieldRevealDuration)
		local partCount = 0
		for _, child in model:GetChildren() do
			if child:IsA("BasePart") then
				partCount += 1
			end
		end
		model:SetAttribute("HatchRevealPartCount", partCount)
		model:PivotTo(CFrame.new(record.at))
		model.Parent = field
		record.model = model
		record.status = "Revealing"
		shell:Destroy()
		local info = Game.pet(record.pet)
		services.world.label(
			model,
			info.name .. "\n+$" .. Game.number(Game.income({ kind = record.pet, weight = record.weight })) .. "/s"
		)
		local label = model:FindFirstChild("WorldLabel")
		if label then
			label.Enabled = false
		end
		local pickup = prompt(model.PrimaryPart, "Steal", info.name, function(visitor)
			steal(visitor, record)
		end)
		pickup.Enabled = false
		task.delay(Game.FieldRevealDuration, function()
			if record.status ~= "Revealing" or not model.Parent then
				return
			end
			record.status = "Hatched"
			pickup.Enabled = true
			if label then
				label.Enabled = true
			end
			task.delay(45, function()
				if record.status == "Hatched" then
					record.status = "Expired"
					respawn(record, 1)
				end
			end)
		end)
	end)
end
spawnEgg = function(info, at, scale, skin)
	-- A respawn keeps its skin; a new egg picks one of its rarity's imported shells.
	skin = skin or info.models and info.models[random:NextInteger(1, #info.models)]
	local model = Visuals.egg(info.color, nil, skin)
	model:ScaleTo(scale or 1)
	model:PivotTo(CFrame.new(at))
	-- Only field shells participate in aiming; base eggs and pets stay non-queryable.
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") and part.Name:sub(1, 5) == "Shell" then
			part.CanQuery = true
		end
	end
	model.Parent = field
	local record = {
		id = Http:GenerateGUID(false),
		info = info,
		at = at,
		scale = scale or 1,
		skin = skin,
		model = model,
		status = "Egg",
		hp = info.hp,
	}
	model.Name = info.name .. "_" .. info.rarity
	model:SetAttribute("EggId", record.id)
	model:SetAttribute("BreakableEgg", true)
	model:SetAttribute("HP", info.hp)
	model:SetAttribute("MaxHP", info.hp)
	record.label = eggLabel(model, info, info.hp)
	eggs[record.id] = record
	return record
end
local function swing(player, id)
	local state = services.states[player]
	local root = character(player)
	if
		not state
		or not state.ready
		or not services.active(player)
		or not root
		or player:GetAttribute("OnTreadmill")
		or Adventure.hasCargo(player)
	then
		return
	end
	local tool = player.Character:FindFirstChildOfClass("Tool")
	if not tool or not tool:GetAttribute("Pickaxe") then
		return
	end
	if (lastSwing[player] or -1e6) + Game.SwingCooldown > os.clock() then
		return
	end
	lastSwing[player] = os.clock()
	local record = type(id) == "string" and eggs[id]
	if not record or record.status ~= "Egg" or (root.Position - record.at).Magnitude > Game.SwingRange then
		feedback:FireAllClients("ToolSwing", root.Position, player.Character)
		return
	end
	local crit = random:NextNumber() < Game.CritChance
	local damage = dev.oneHit[player] and record.hp
		or math.min(record.hp, Game.Pickaxes[state.pickaxe].power * (crit and Game.CritMultiplier or 1))
	record.hp = math.max(0, record.hp - damage)
	record.model:SetAttribute("HP", record.hp)
	record.model:SetAttribute("LastHit", os.clock())
	local bar = record.label.Health
	bar.Visible = true
	bar.Fill.Size = UDim2.fromScale(record.hp / record.info.hp, 1)
	bar.Value.Text = Game.number(record.hp) .. "/" .. Game.number(record.info.hp) .. " HP"
	feedback:FireAllClients("EggHit", record.at, {
		model = record.model,
		character = player.Character,
		damage = damage,
		scale = record.scale,
		color = record.info.color,
		crit = crit,
		final = record.hp <= 0,
	})
	if record.hp <= 0 then
		hatch(record, player)
	end
end
local function bat(player)
	local state = services.states[player]
	local root = character(player)
	if
		not state
		or not state.ready
		or not services.active(player)
		or not root
		or player:GetAttribute("OnTreadmill")
		or Adventure.hasCargo(player)
		or stunned[player]
	then
		return
	end
	local tool = player.Character:FindFirstChildOfClass("Tool")
	if not tool or tool.Name ~= "Lava Bat" then
		return
	end
	if (lastSwing[player] or -1e6) + 0.8 > os.clock() then
		return
	end
	lastSwing[player] = os.clock()
	feedback:FireAllClients("ToolSwing", root.Position, player.Character)
	if root.Position.Z >= Game.SafeZ then
		return
	end
	for _, other in Players:GetPlayers() do
		if other ~= player then
			local target = character(other)
			if target and target.Position.Z < Game.SafeZ and (target.Position - root.Position).Magnitude < 10 then
				local delta = target.Position - root.Position
				local direction = delta.Magnitude > 0.01 and delta.Unit or root.CFrame.LookVector
				dropCargo(other, "You dropped your animals!")
				ragdoll(other, direction * 75 + Vector3.new(0, 60, 0), 2)
			end
		end
	end
end
local function openShop(player, name)
	if feedback then
		feedback:FireClient(player, "Open", name)
	end
end
local function setupPrompts()
	-- Pickaxe and Trails stands have no prompt: the client opens them from their TouchZone.
	local details = workspace.Map.StartZone:FindFirstChild("ReferenceDetails")
	if details then
		for _, p in details:GetDescendants() do
			if p:IsA("BasePart") and p:GetAttribute("Interaction") then
				local kind = p:GetAttribute("Interaction")
				prompt(p, kind == "Free" and "Claim" or "Open", p.Name, function(player)
					if kind == "Free" then
						local result = services.action(player, "ClaimFreeReward")
						Adventure.notice(player, result.message)
					else
						openShop(player, kind)
					end
				end)
			end
		end
	end
end
function Adventure.start(options)
	assert(not services, "Adventure already started")
	services = options
	field = Instance.new("Folder")
	field.Name = "Adventure"
	field.Parent = workspace.Map
	remote = Instance.new("RemoteEvent")
	remote.Name = "GameplayAction"
	remote.Parent = RS
	feedback = Instance.new("RemoteEvent")
	feedback.Name = "GameplayFeedback"
	feedback.Parent = RS
	remote.OnServerEvent:Connect(function(player, name, payload)
		if name == "Swing" then
			swing(player, payload)
		elseif name == "Bat" then
			bat(player)
		elseif name == "Drop" then
			dropCargo(player)
		end
	end)
	for biomeIndex, biome in { "Forest", "Desert", "Snow" } do
		-- Egg spots are authored on the map (tools/build-parkour-field.luau); rarer eggs sit higher.
		for _, spot in workspace.Map.Biomes[biome].EggSpots:GetChildren() do
			local rarity = spot:GetAttribute("Rarity")
			local info = Game.Eggs[(biomeIndex - 1) * 3 + rarity]
			spawnEgg(info, spot.Position, random:NextNumber(0.72, 1.28) * (rarity == 3 and 1.5 or 1))
		end
	end
	setupPrompts()
	local function lavaInterval()
		return dev.lavaInterval or Game.LavaInterval
	end
	local nextLava = os.clock() + lavaInterval()
	local nextTitan = os.clock() + Game.TitanInterval
	local waveAt -- server time when the current lava wave started
	local scan = 0
	-- DevTools: bring the next timed event forward to now.
	function Adventure.forceLava()
		nextLava = os.clock()
	end
	-- Ends a running wave on the next tick; clients stop drawing once LavaWaveAt is far in the past.
	function Adventure.stopLava()
		if waveAt then
			waveAt = -math.huge
			workspace:SetAttribute("LavaWaveAt", 0)
		end
	end
	function Adventure.setLavaInterval(seconds)
		dev.lavaInterval = seconds
		nextLava = math.min(nextLava, os.clock() + lavaInterval())
	end
	-- Every unbroken field egg back to full HP.
	function Adventure.refillEggs()
		local count = 0
		for _, record in eggs do
			if record.status == "Egg" and record.model then
				record.hp = record.info.hp
				record.model:SetAttribute("HP", record.hp)
				record.label.Health.Visible = false
				count += 1
			end
		end
		return count
	end
	function Adventure.lavaState()
		return { active = waveAt ~= nil, nextIn = math.max(0, math.ceil(nextLava - os.clock())) }
	end
	function Adventure.forceTitan()
		nextTitan = os.clock()
	end
	Adventure.ragdoll = ragdoll
	Adventure.dropCargo = dropCargo
	RunService.Heartbeat:Connect(function(dt)
		scan += dt
		if scan < 0.1 then
			return
		end
		scan = 0
		local now = os.clock()
		workspace:SetAttribute("LavaCountdown", math.max(0, math.ceil(nextLava - now)))
		if now >= nextTitan then
			nextTitan = now + Game.TitanInterval
			local record = spawnEgg(Game.Eggs[#Game.Eggs], Vector3.new(0, 0.1, -192), 4)
			for _, player in Players:GetPlayers() do
				Adventure.notice(player, "TITANIC EGG has appeared in the field! Break it together!", "event")
			end
			task.delay(Game.TitanDuration, function()
				-- Only an unbroken egg vanishes; a hatched Titan keeps its normal reveal and expiry.
				if record.status == "Egg" and record.model and record.model.Parent then
					respawn(record, 0)
				end
			end)
		end
		if dev.lavaOff and not waveAt then
			nextLava = math.max(nextLava, now + lavaInterval())
		end
		if not waveAt and now >= nextLava then
			waveAt = workspace:GetServerTimeNow()
			workspace:SetAttribute("LavaWaveAt", waveAt)
			workspace:SetAttribute("LavaActive", true)
			for _, player in Players:GetPlayers() do
				Adventure.notice(player, "LAVA IS RISING! Climb high or get back to the Safe Zone!", "danger")
			end
		end
		local lavaY = waveAt and Game.lavaHeight(workspace:GetServerTimeNow() - waveAt)
		if waveAt and not lavaY then
			waveAt = nil
			nextLava = now + lavaInterval()
			workspace:SetAttribute("LavaActive", false)
		end
		for _, player in Players:GetPlayers() do
			player:SetAttribute("EventRemaining", math.max(0, math.ceil(nextLava - now)))
			local root = character(player)
			player:SetAttribute("InField", root and root.Position.Z < Game.SafeZ or false)
			local held = cargo[player]
			if held then
				if not root then
					dropCargo(player, "You lost your stolen animals.")
				elseif root.Position.Z >= Game.SafeZ then
					for i = #held, 1, -1 do
						local item = held[i]
						if services.bank(player, item.kind, item.weight) then
							if item.model then
								item.model:Destroy()
							end
							table.remove(held, i)
						end
					end
					if #held == 0 then
						cargo[player] = nil
						player:SetAttribute("CarryingCount", 0)
						player:SetAttribute("CarryingName", nil)
					end
				end
			end
			-- The root sits ~3 studs above the feet: feet in the lava drop the cargo and fling the
			-- player up and toward the Safe Zone, aimed at its edge (the ragdoll slide carries it inside).
			if
				root
				and lavaY
				and not stunned[player]
				and root.Position.Z < Game.SafeZ
				and root.Position.Y - 3 < lavaY
				and not dev.immune[player]
			then
				dropCargo(player)
				Adventure.notice(player, "The lava threw you back!", "danger")
				local flight = 2 * Game.LavaFling.up / workspace.Gravity
				local away = math.clamp((Game.SafeZ - root.Position.Z) / flight, 40, Game.LavaFling.maxAway)
				ragdoll(player, Vector3.new(0, Game.LavaFling.up, away), Game.LavaFling.duration)
			end
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		-- Leaving mid-run drops the cargo like a knock-off, so others can still grab it.
		dropCargo(player)
		lastSwing[player] = nil
		stunned[player] = nil
		for _, list in { dev.immune, dev.oneHit, dev.rarity, dev.luck } do
			list[player] = nil
		end
	end)
end
return Adventure
