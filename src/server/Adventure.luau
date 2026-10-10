local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Http = game:GetService("HttpService")
local Game = require(RS:WaitForChild("GameConfig"))
local Visuals = require(RS:WaitForChild("PetVisuals"))
local Adventure = {}
local services, field, remote, feedback
local eggs, guards, cargo, lastSwing, stunned = {}, {}, {}, {}, {}
local random = Random.new()
local function character(player)
	local model = player.Character
	local root = model and model:FindFirstChild("HumanoidRootPart")
	local humanoid = model and model:FindFirstChildOfClass("Humanoid")
	if root and humanoid and humanoid.Health > 0 then
		return root, humanoid
	end
end
function Adventure.notice(player, message)
	if not message then
		return
	end
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
local function clearCargo(player, reason)
	if not cargo[player] then
		return
	end
	for _, item in cargo[player] do
		if item.model then
			item.model:Destroy()
		end
	end
	cargo[player] = nil
	player:SetAttribute("CarryingCount", 0)
	player:SetAttribute("CarryingName", nil)
	if reason then
		Adventure.notice(player, reason)
	end
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
	gui.Size = UDim2.new(8, 0, 3.5, 0)
	gui.MaxDistance = 140
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
local function roll(info)
	if info.biome == "Titanic" then
		return "TitanDragon"
	end
	local options, total = {}, 0
	local index = 0
	for _, pet in Game.Pets do
		if pet.biome == info.biome then
			index += 1
			local weight = pet.weight * math.max(0.5, info.luck) ^ ((index - 1) * 0.45)
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
	if record.info.biome ~= "Titanic" then
		task.delay(delay, function()
			if field.Parent then
				spawnEgg(record.info, record.at, record.scale)
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
local function hatch(record, player)
	if record.status ~= "Egg" then
		return
	end
	record.status = "Hatching"
	local started = workspace:GetServerTimeNow()
	record.model:SetAttribute("HatchStarted", started)
	record.model:SetAttribute("HatchDuration", Game.FieldHatchDuration)
	record.model:SetAttribute("HatchGrowth", Game.FieldHatchGrowth)
	record.model:SetAttribute("HatchLuck", record.info.luck)
	-- Roll up front so clients can build the rarity reveal; the result is fixed either way.
	record.pet = roll(record.info)
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
		{ model = record.model, started = started, duration = Game.FieldHatchDuration, luck = record.info.luck }
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
spawnEgg = function(info, at, scale)
	local model = Visuals.egg(info.color)
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
	local root, humanoid = character(player)
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
	local damage = math.min(record.hp, Game.Pickaxes[state.pickaxe].power * (crit and Game.CritMultiplier or 1))
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
			local target, humanoid = character(other)
			if target and target.Position.Z < Game.SafeZ and (target.Position - root.Position).Magnitude < 10 then
				local delta = target.Position - root.Position
				local direction = delta.Magnitude > 0.01 and delta.Unit or root.CFrame.LookVector
				clearCargo(other, "You dropped your animals!")
				target.AssemblyLinearVelocity = direction * 65 + Vector3.new(0, 30, 0)
				humanoid:TakeDamage(10)
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
	local shops = workspace.Map.StartZone.Shops
	for _, model in shops:GetChildren() do
		if model:IsA("Model") then
			local _, size = model:GetBoundingBox()
			local cf = model:GetPivot()
			local name = model.Name == "BlueShopStand" and "Pickaxe Shop" or "Trails Shop"
			local base = model:FindFirstChildWhichIsA("BasePart", true)
			if base then
				prompt(base, "Open", name, function(player)
					openShop(player, name)
				end)
			end
		end
	end
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
local function guardian(kind, at, biome)
	local model = Visuals.pet(kind, 1)
	model:ScaleTo(model:GetScale() * 4)
	model.Name = biome .. "Guardian"
	model:SetAttribute("Guardian", true)
	-- Clients smooth and animate guardians from these attributes, like base pets.
	model:SetAttribute("PetPosition", at)
	model:SetAttribute("PetYaw", 0)
	model:SetAttribute("PetWalking", false)
	model:PivotTo(CFrame.new(at))
	model.Parent = field
	services.world.label(model, "GUARDIAN")
	local item = { model = model, home = at, at = at, biome = biome, cooldown = 0 }
	table.insert(guards, item)
	return item
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
		end
	end)
	for biomeIndex, biome in { "Forest", "Desert", "Snow" } do
		local zone = workspace.Map.Biomes[biome]
		local floor = zone.Floor
		local surface = floor.Position.Y + floor.Size.Y / 2
		for row = 1, 4 do
			for col = 1, 4 do
				local rarity = (row == 4 and col % 2 == 0) and 3 or (row == 3 and col == 3) and 2 or 1
				local info = Game.Eggs[(biomeIndex - 1) * 3 + rarity]
				local at = Vector3.new(
					-56 + (col - 1) * 37,
					surface,
					floor.Position.Z + floor.Size.Z / 2 - 18 - (row - 1) * 40
				)
				spawnEgg(info, at, random:NextNumber(0.72, 1.28) * (rarity == 3 and 1.5 or 1))
			end
		end
	end
	guardian("Chicken", Vector3.new(76, 0.1, -153), "Forest")
	guardian("Lion", Vector3.new(-75, 0.1, -330), "Desert")
	guardian("Yeti", Vector3.new(77, 0.1, -510), "Snow")
	setupPrompts()
	local nextLava = os.clock() + Game.LavaInterval
	local nextTitan = os.clock() + Game.TitanInterval
	local wave, waveZ, waveEnd
	local scan = 0
	RunService.Heartbeat:Connect(function(dt)
		scan += dt
		if scan < 0.1 then
			return
		end
		local step = math.min(scan, 0.3)
		scan = 0
		local now = os.clock()
		workspace:SetAttribute("LavaCountdown", math.max(0, math.ceil(nextLava - now)))
		workspace:SetAttribute("TitanCountdown", math.max(0, math.ceil(nextTitan - now)))
		if now >= nextTitan then
			nextTitan = now + Game.TitanInterval
			local record = spawnEgg(Game.Eggs[#Game.Eggs], Vector3.new(0, 0.1, -192), 4)
			task.delay(Game.TitanDuration, function()
				if record.model and record.model.Parent then
					respawn(record, 0)
				end
			end)
		end
		if not wave and now >= nextLava then
			wave = Instance.new("Part")
			wave.Name = "LavaWave"
			wave.Anchored = true
			wave.CanCollide = false
			wave.Material = Enum.Material.Neon
			wave.Color = Color3.fromRGB(255, 89, 6)
			wave.Transparency = 0.13
			wave.Size = Vector3.new(238, 12, 18)
			waveZ = -588
			wave.Position = Vector3.new(0, 5, waveZ)
			wave.Parent = field
			local light = Instance.new("PointLight")
			light.Color = wave.Color
			light.Range = 60
			light.Brightness = 3
			light.Parent = wave
			workspace:SetAttribute("LavaActive", true)
			for _, player in Players:GetPlayers() do
				Adventure.notice(player, "LAVA! Get back to the Safe Zone!")
			end
		end
		if wave then
			waveZ += Game.LavaSpeed * step
			wave.Position = Vector3.new(0, 5, waveZ)
			if waveZ > Game.SafeZ - 10 then
				wave:Destroy()
				wave = nil
				nextLava = now + Game.LavaInterval
				workspace:SetAttribute("LavaActive", false)
			end
		end
		for _, player in Players:GetPlayers() do
			player:SetAttribute("EventRemaining", math.max(0, math.ceil(nextLava - now)))
			local root, humanoid = character(player)
			player:SetAttribute("InField", root and root.Position.Z < Game.SafeZ or false)
			local held = cargo[player]
			if held then
				if not root then
					clearCargo(player, "You lost your stolen animals.")
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
			if
				root
				and wave
				and root.Position.Z < Game.SafeZ
				and math.abs(root.Position.Z - waveZ) < 14
				and root.Position.Y < 17
			then
				clearCargo(player)
				humanoid.Health = 0
			end
		end
		for _, guard in guards do
			local target, minimum = nil, math.huge
			local zone = workspace.Map.Biomes[guard.biome].Floor
			for _, player in Players:GetPlayers() do
				if Adventure.hasCargo(player) then
					local root = character(player)
					if
						root
						and root.Position.Z < Game.SafeZ
						and math.abs(root.Position.Z - zone.Position.Z) < zone.Size.Z / 2 + 12
					then
						local distance = (root.Position - guard.at).Magnitude
						if distance < minimum then
							target = player
							minimum = distance
						end
					end
				end
			end
			local root = target and character(target)
			local goal = root and Vector3.new(root.Position.X, 0.1, root.Position.Z) or guard.home
			local delta = goal - guard.at
			local walking = delta.Magnitude > 1
			if walking then
				local direction = delta.Unit
				guard.at += direction * math.min((root and 24 or 10) * step, delta.Magnitude)
				guard.model:SetAttribute("PetPosition", guard.at)
				guard.model:SetAttribute("PetYaw", math.atan2(-direction.X, -direction.Z))
			end
			if guard.model:GetAttribute("PetWalking") ~= walking then
				guard.model:SetAttribute("PetWalking", walking)
			end
			if root and minimum < 8 and now > guard.cooldown then
				guard.cooldown = now + 2
				clearCargo(target, "The guardian caught you! Your animals were dropped.")
				local _, humanoid = character(target)
				if humanoid then
					humanoid:TakeDamage(25)
					root.AssemblyLinearVelocity = (root.Position - guard.at + Vector3.new(0, 2, 0)).Unit * 65
				end
			end
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		clearCargo(player)
		lastSwing[player] = nil
	end)
end
return Adventure
