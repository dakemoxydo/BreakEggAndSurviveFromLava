local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Http = game:GetService("HttpService")
local DataService = require(script.Parent.PlayerData.Service)
local Schema = require(script.Parent.PlayerData.Schema)
local Config = require(RS:WaitForChild("PetConfig"))
local World = require(script.Parent.PetWorld)
local Game = require(RS:WaitForChild("GameConfig"))
local Adventure = require(script.Parent.Adventure)
local MergeSelection = require(script.Parent.MergeSelection)
local bases = workspace:WaitForChild("Map"):WaitForChild("StartZone"):WaitForChild("PlayerBases")
local states = {}
local remote = Instance.new("RemoteFunction")
remote.Name = "UIAction"
assert(not RS:FindFirstChild(remote.Name), "UIAction already exists")
remote.Parent = RS
local random = Random.new()
local PET_EDGE_MARGIN = Config.PetEdgeMargin
local function inventoryCount(state)
	return #state.pets + #state.eggs + #state.backpackEggs
end
-- Tool instances are a view of saved ownership, never the source of ownership.
local function reconcileTools(player, state)
	local backpack, character = player:FindFirstChildOfClass("Backpack"), player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not state.ready or not backpack or not humanoid or humanoid.Health <= 0 then
		return
	end
	Schema.MigrateBackpack(state)
	local wanted, present = {}, {}
	for _, pet in state.pets do
		if not pet.equipped then
			wanted[pet.id] = { kind = "Pet", data = pet }
		end
	end
	for _, egg in state.backpackEggs do
		wanted[egg.id] = { kind = "Egg", data = egg }
	end
	for _, container in { backpack, character } do
		for _, tool in container:GetChildren() do
			if tool:IsA("Tool") and tool:GetAttribute("PlacementKind") then
				local id = tool:GetAttribute("InventoryId")
				local item = id and wanted[id]
				if item and item.kind == tool:GetAttribute("PlacementKind") and not present[id] then
					present[id] = tool
				else
					tool:Destroy()
				end
			end
		end
	end
	for id, item in wanted do
		if not present[id] then
			local tool = World.tool(item.kind, item.data)
			tool:SetAttribute("InventoryId", id)
			tool.Parent = backpack
		end
	end
end

local function cleanup(player)
	local state = states[player]
	if not state then
		return
	end
	state.ready = false
	states[player] = nil
	for _, connection in state.connections or {} do
		connection:Disconnect()
	end
	if state.contents then
		state.contents:Destroy()
	end
	if state.base then
		state.base:SetAttribute("OwnerUserId", nil)
		state.base:SetAttribute("PenLevel", nil)
	end
	player:SetAttribute("PetDataReady", false)
	player:SetAttribute("BaseName", nil)
end
DataService.SessionEnded:Connect(cleanup)

local function reply(success, message)
	return { success = success, message = message }
end
local function equippedCount(state)
	local count = 0
	for _, pet in state.pets do
		if pet.equipped then
			count += 1
		end
	end
	return count
end
local function sync(player, state)
	reconcileTools(player, state)
	local inventory, eggs, income = {}, {}, 0
	for _, pet in state.pets do
		local info = Game.pet(pet.kind)
		table.insert(inventory, {
			id = pet.id,
			kind = pet.kind or "TestChick",
			weight = pet.weight or 1,
			name = info.name,
			icon = info.icon,
			rarity = info.rarity,
			income = math.floor(Game.income(pet)),
			equipped = pet.equipped,
		})
		if pet.equipped then
			income += Game.income(pet)
		end
	end
	for _, egg in state.eggs do
		local remaining = math.max(0, math.ceil(egg.hatchesAt - os.time()))
		table.insert(eggs, {
			id = egg.id,
			name = Game.pet(egg.kind).name .. " Egg",
			icon = "egg",
			status = "Hatches in " .. remaining .. "s",
		})
	end
	income = math.floor(income * Game.rebirthIncome(state.rebirths))
	state.income = income
	player:SetAttribute("PetInventory", Http:JSONEncode(inventory))
	player:SetAttribute("GrowingEggs", Http:JSONEncode(eggs))
	player:SetAttribute("PetCapacity", state.capacity)
	player:SetAttribute("PetSlotCost", Config.SlotCost)
	player:SetAttribute("GrowAllCost", Config.GrowAllCost)
	player:SetAttribute("Cash", state.cash)
	player:SetAttribute("Income", income)
	player:SetAttribute("OfflineCash", state.offline)
	local discoveries = {}
	for key in state.discoveries do
		table.insert(discoveries, Game.pet(key).name)
	end
	player:SetAttribute("DiscoveredPets", Http:JSONEncode(discoveries))
	player:SetAttribute("UnlockedPets", #discoveries)
	player:SetAttribute("TotalPets", #Game.Pets)
	player:SetAttribute("OwnedPickaxes", Http:JSONEncode(state.ownedPickaxes))
	player:SetAttribute("OwnedTrails", Http:JSONEncode(state.ownedTrails))
	for key, value in
		{
			PickaxeLevel = state.pickaxe,
			TrailLevel = state.trail,
			PenLevel = state.penLevel,
			TreadmillLevel = state.treadmillLevel,
			SatchelLevel = state.satchelLevel,
			Playtime = state.playtime,
			Multiplier = Game.Trails[state.trail].multiplier,
			Rebirths = state.rebirths,
		}
	do
		player:SetAttribute(key, value)
	end
	player:SetAttribute("CollectionRewardClaimed", state.rewardClaimed)
	player:SetAttribute("DailyRewardAt", state.dailyRewardAt)
	player:SetAttribute("RewardStreak", state.rewardStreak)
	player:SetAttribute("RewardStreakAt", state.rewardStreakAt)
end
local function position(state, x, z)
	local p = state.base.BaseAnchor.CFrame:PointToWorldSpace(Vector3.new(x, 0, z))
	return Vector3.new(p.X, state.floor, p.Z)
end
local function randomPosition(state)
	return position(
		state,
		random:NextNumber(-Config.PenHalfWidth + PET_EDGE_MARGIN, Config.PenHalfWidth - PET_EDGE_MARGIN),
		random:NextNumber(-Config.PenHalfDepth + PET_EDGE_MARGIN, Config.PenHalfDepth - PET_EDGE_MARGIN)
	)
end
local function spawnPet(player, state, pet, at, placedYaw)
	if pet.model then
		pet.model:Destroy()
	end
	local start = at or pet.position or randomPosition(state)
	local localStart = state.base.BaseAnchor.CFrame:PointToObjectSpace(start)
	start = position(
		state,
		math.clamp(localStart.X, -Config.PenHalfWidth + PET_EDGE_MARGIN, Config.PenHalfWidth - PET_EDGE_MARGIN),
		math.clamp(localStart.Z, -Config.PenHalfDepth + PET_EDGE_MARGIN, Config.PenHalfDepth - PET_EDGE_MARGIN)
	)
	local yaw = placedYaw or random:NextNumber(-math.pi, math.pi)
	local model = World.pet(pet.kind, pet.weight)
	model:SetAttribute("OwnerUserId", player.UserId)
	model:SetAttribute("PetId", pet.id)
	model:SetAttribute("PetKind", pet.kind or "TestChick")
	model:SetAttribute("PetVisual", true)
	model:SetAttribute("PetPosition", start)
	model:SetAttribute("PetYaw", yaw)
	model:SetAttribute("PetWalking", false)
	model:SetAttribute("AnimationOffset", random:NextNumber(0, math.pi * 2))
	model:PivotTo(CFrame.new(start) * CFrame.Angles(0, yaw, 0))
	local label = World.label(model, "+$" .. Game.number(Game.income(pet)) .. "/s")
	label.TextColor3 = Color3.fromRGB(110, 255, 0)
	model.Parent = state.contents
	pet.model = model
	pet.position = start
	pet.yaw = yaw
	pet.target = nil
	pet.restUntil = 0
end
local function addPet(player, state, at, placedYaw, kind, weight, shouldEquip)
	local pet = {
		id = Http:GenerateGUID(false),
		kind = kind or "TestChick",
		weight = weight or 1,
		equipped = shouldEquip ~= false and equippedCount(state) < state.capacity,
	}
	table.insert(state.pets, pet)
	state.discovered = true
	state.discoveries[pet.kind == "TestChick" and "Chicken" or pet.kind] = true
	if pet.equipped then
		spawnPet(player, state, pet, at, placedYaw)
	end
	return pet
end
local function hatch(player, state, index)
	local egg = table.remove(state.eggs, index)
	local at = egg.position
	egg.model:Destroy()
	addPet(player, state, at, nil, egg.kind, egg.weight)
end
local function hatchReady(player, state, now)
	table.sort(state.eggs, Schema.EggComesFirst)
	while state.eggs[1] and state.eggs[1].hatchesAt <= now do
		hatch(player, state, 1)
	end
end
local function findPlacementTool(player)
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
local function giveTool(player, state, kind, petData)
	if not state.ready or not DataService.IsActive(player) then
		return reply(false, "Loading your saved progress...")
	end
	if not state.base then
		return reply(false, "All bases are occupied. Try another server.")
	end
	if inventoryCount(state) >= Config.MaxPets and not (kind == "Pet" and petData and petData.id) then
		return reply(false, "Your pet inventory is full.")
	end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return reply(false, "Wait until you respawn.")
	end
	petData = petData or { kind = "TestChick", weight = 1 }
	if kind == "Egg" then
		petData = { id = Http:GenerateGUID(false), kind = petData.kind, weight = petData.weight or 1 }
		table.insert(state.backpackEggs, petData)
	else
		petData.equipped = false
		if petData.model then
			petData.model:Destroy()
			petData.model = nil
		end
	end
	reconcileTools(player, state)
	for _, tool in player.Backpack:GetChildren() do
		if tool:IsA("Tool") and tool:GetAttribute("InventoryId") == petData.id then
			humanoid:EquipTool(tool)
			break
		end
	end
	return reply(true)
end
local function validPlacement(player, state, at, kind)
	if typeof(at) ~= "Vector3" or not state.base then
		return false
	end
	for _, n in { at.X, at.Y, at.Z } do
		if n ~= n or math.abs(n) > 1e6 then
			return false
		end
	end
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not root or (root.Position - at).Magnitude > Config.PlacementRange then
		return false
	end
	local localPoint = state.base.BaseAnchor.CFrame:PointToObjectSpace(at)
	local margin = kind == "Pet" and PET_EDGE_MARGIN or 0
	if
		state.base:GetAttribute("OwnerUserId") ~= player.UserId
		or math.abs(localPoint.X) > Config.PenHalfWidth - margin
		or math.abs(localPoint.Z) > Config.PenHalfDepth - margin
		or math.abs(at.Y - state.floor) > 1
	then
		return false
	end
	for _, egg in state.eggs do
		if (egg.model:GetPivot().Position - at).Magnitude < 3.5 then
			return false
		end
	end
	return true
end
local function applySpeed(player)
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if humanoid and not player:GetAttribute("OnTreadmill") then
		humanoid.WalkSpeed = Game.walkSpeed(
			(player:GetAttribute("Speed") or 16) * Game.Trails[states[player] and states[player].trail or 1].multiplier,
			player:GetAttribute("SlowMode")
		) * ((player:GetAttribute("CarryingCount") or 0) > 0 and Game.CargoSlow or 1)
	end
end
-- Login reward: an egg needs a free inventory slot, so it is given first and a failure grants nothing.
local function grantReward(player, state, reward)
	if reward.pet then
		local result = giveTool(player, state, "Egg", { kind = reward.pet, weight = 1 })
		if not result.success then
			return result
		end
	end
	local parts = {}
	if reward.cash then
		state.cash = math.min(Game.MaxCash, state.cash + reward.cash)
		table.insert(parts, "$" .. Game.number(reward.cash))
	end
	if reward.speed then
		player:SetAttribute("Speed", math.min(Game.MaxSpeed, (player:GetAttribute("Speed") or 16) + reward.speed))
		table.insert(parts, "+" .. reward.speed .. " speed")
	end
	if reward.pet then
		table.insert(parts, "a " .. Game.pet(reward.pet).name .. " Egg")
	end
	return reply(true, "Received " .. table.concat(parts, " and ") .. "!")
end
local function perform(player, state, name, payload)
	if name == "PlaceEgg" or name == "PlacePet" then
		local kind = name == "PlaceEgg" and "Egg" or "Pet"
		local tool = findPlacementTool(player)
		if kind == "Pet" and equippedCount(state) >= state.capacity then
			return reply(false, "No free slots. Unequip a pet or buy a slot.")
		end
		if not tool or tool:GetAttribute("PlacementKind") ~= kind then
			return reply(false, "Take an egg or pet first.")
		end
		local item, itemIndex
		local items = kind == "Pet" and state.pets or state.backpackEggs
		for index, candidate in items do
			if candidate.id == tool:GetAttribute("InventoryId") then
				item = candidate
				itemIndex = index
				break
			end
		end
		if not item or (kind == "Pet" and item.equipped) then
			return reply(false, "Item is no longer in your backpack.")
		end
		if not validPlacement(player, state, payload.position, kind) then
			return reply(false, "Place inside your base, away from other eggs.")
		end
		if kind == "Egg" then
			if #state.eggs >= Config.MaxEggs then
				return reply(false, "Hatch your growing eggs first.")
			end
			local model = World.egg(nil, nil, "DefaultEgg")
			model:SetAttribute("OwnerUserId", player.UserId)
			model:SetAttribute("EggVisual", true)
			model:PivotTo(CFrame.new(payload.position.X, state.floor, payload.position.Z))
			model.Parent = state.contents
			table.insert(state.eggs, {
				id = item.id,
				position = Vector3.new(payload.position.X, state.floor, payload.position.Z),
				hatchesAt = os.time() + Config.HatchSeconds,
				kind = item.kind,
				weight = item.weight or 1,
				model = model,
				label = World.label(model, "Hatches in " .. Config.HatchSeconds .. "s"),
			})
			table.remove(state.backpackEggs, itemIndex)
		else
			local yaw = payload.yaw
			if typeof(yaw) ~= "number" or yaw ~= yaw or math.abs(yaw) > math.pi * 2 then
				yaw = nil
			end
			item.equipped = true
			spawnPet(player, state, item, payload.position, yaw)
		end
		tool:Destroy()
		return reply(true, kind == "Egg" and "Egg placed!" or "Pet placed!")
	elseif name == "EquipPet" or name == "UnequipPet" then
		for _, pet in state.pets do
			if pet.id == payload.pet then
				local equip = name == "EquipPet"
				if equip and not pet.equipped and equippedCount(state) >= state.capacity then
					return reply(false, "No free slots. Unequip a pet or buy a slot.")
				end
				if equip and not state.base then
					return reply(false, "You need a free base.")
				end
				pet.equipped = equip
				if equip then
					spawnPet(player, state, pet)
				elseif pet.model then
					pet.model:Destroy()
					pet.model = nil
				end
				return reply(true)
			end
		end
		return reply(false, "Pet not found.")
	elseif name == "EquipBestPets" then
		if not state.base then
			return reply(false, "You need a free base.")
		end
		-- Income ranks pets; IDs make ties stable.
		table.sort(state.pets, function(a, b)
			local first, second = Game.income(a), Game.income(b)
			return first == second and a.id < b.id or first > second
		end)
		for i, pet in state.pets do
			pet.equipped = i <= state.capacity
			if pet.equipped and not pet.model then
				spawnPet(player, state, pet)
			elseif not pet.equipped and pet.model then
				pet.model:Destroy()
				pet.model = nil
			end
		end
		return reply(true)
	elseif name == "AddPetSlot" then
		if state.capacity >= Config.MaxCapacity then
			return reply(false, "Maximum slots reached.")
		end
		if state.cash < Config.SlotCost then
			return reply(false, "You need $" .. Config.SlotCost .. " for a slot.")
		end
		state.cash -= Config.SlotCost
		state.capacity += 1
		return reply(true)
	elseif name == "GrowAllEggs" then
		if #state.eggs == 0 then
			return reply(false, "Place an egg on your base first.")
		end
		if state.cash < Config.GrowAllCost then
			return reply(false, "You need $" .. Config.GrowAllCost .. " to hatch all eggs.")
		end
		state.cash -= Config.GrowAllCost
		hatchReady(player, state, math.huge)
		return reply(true, "All eggs hatched!")
	elseif name == "ClaimOffline" then
		if state.offline <= 0 then
			return reply(false, "No offline cash to claim.")
		end
		state.cash = math.min(Game.MaxCash, state.cash + state.offline)
		state.offline = 0
		return reply(true)
	elseif name == "ClaimCollectionReward" then
		for _, pet in Game.Pets do
			if pet.biome == "Forest" and not state.discoveries[pet.key] then
				return reply(false, "Discover all 8 Forest animals first.")
			end
		end
		if state.rewardClaimed then
			return reply(false, "Reward already claimed.")
		end
		state.rewardClaimed = true
		state.cash = math.min(Game.MaxCash, state.cash + 100)
		player:SetAttribute("Speed", math.min(Game.MaxSpeed, (player:GetAttribute("Speed") or 16) + 60))
		return reply(true, "Received $100 and +60 speed!")
	elseif name == "BuyPickaxe" or name == "BuyTrail" then
		local index = payload.index
		local list = name == "BuyPickaxe" and Game.Pickaxes or Game.Trails
		local owned = name == "BuyPickaxe" and state.ownedPickaxes or state.ownedTrails
		if type(index) ~= "number" or index % 1 ~= 0 or not list[index] then
			return reply(false, "Item not found.")
		end
		if not table.find(owned, index) then
			if state.cash < list[index].cost then
				return reply(false, "Need $" .. Game.number(list[index].cost - state.cash) .. " more.")
			end
			state.cash -= list[index].cost
			table.insert(owned, index)
		end
		if name == "BuyPickaxe" then
			state.pickaxe = index
			Adventure.equipPickaxe(player, index)
		else
			state.trail = index
			Adventure.applyTrail(player, state)
			applySpeed(player)
		end
		return reply(true, "Equipped " .. list[index].name .. "!")
	elseif name == "UpgradePen" then
		local cost = Game.PenCosts[state.penLevel]
		if not cost then
			return reply(false, "Your pen is fully upgraded.")
		end
		if state.cash < cost then
			return reply(false, "Need $" .. Game.number(cost - state.cash) .. " more.")
		end
		state.cash -= cost
		state.penLevel += 1
		state.capacity = math.min(Config.MaxCapacity, math.max(state.capacity, 8 + (state.penLevel - 1) * 4))
		World.updateBase(player, state)
		return reply(true, "Pen upgraded! " .. state.capacity .. " active pets.")
	elseif name == "UpgradeTreadmill" then
		local tier = Game.Treadmills[state.treadmillLevel + 1]
		if not tier then
			return reply(false, "Your treadmill is fully upgraded.")
		end
		if state.cash < tier.cost then
			return reply(false, "Need $" .. Game.number(tier.cost - state.cash) .. " more.")
		end
		state.cash -= tier.cost
		state.treadmillLevel += 1
		World.updateBase(player, state)
		return reply(true, "Treadmill upgraded! +" .. Game.number(tier.gain) .. "/Step")
	elseif name == "UpgradeSatchel" then
		if state.satchelLevel >= 8 then
			return reply(false, "Maximum satchel reached.")
		end
		local cost = 1000 * 25 ^ (state.satchelLevel - 1)
		if state.cash < cost then
			return reply(false, "Need $" .. Game.number(cost - state.cash) .. " more.")
		end
		state.cash -= cost
		state.satchelLevel += 1
		return reply(true, "Carry up to " .. state.satchelLevel .. " animals per run!")
	elseif name == "CarryPet" then
		for _, pet in state.pets do
			if pet.id == payload.pet then
				local result = giveTool(player, state, "Pet", pet)
				if not result.success then
					return result
				end
				pet.equipped = false
				if pet.model then
					pet.model:Destroy()
					pet.model = nil
				end
				return result
			end
		end
		return reply(false, "Pet not found.")
	elseif name == "MergePets" then
		local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		if not humanoid or humanoid.Health <= 0 then
			return reply(false, "Wait until you respawn.")
		end
		local kind = payload.kind
		if not Game.ByPet[kind] then
			return reply(false, "Select a pet to merge.")
		end
		if not state.base then
			return reply(false, "All bases are occupied. Try another server.")
		end
		local matches, weight = MergeSelection.resolve(state.pets, kind, payload.pets)
		if not matches then
			return reply(false, weight)
		end
		for _, item in matches do
			if item.pet.model then
				item.pet.model:Destroy()
			end
			table.remove(state.pets, item.index)
		end
		return giveTool(player, state, "Egg", { kind = kind, weight = weight })
	elseif name == "ClaimDailyReward" then
		local now = os.time()
		if now - state.dailyRewardAt < Game.RewardDay then
			return reply(false, "Your daily reward is not ready yet.")
		end
		local result = grantReward(player, state, Game.DailyReward)
		if result.success then
			state.dailyRewardAt = now
		end
		return result
	elseif name == "ClaimStreakReward" then
		local now = os.time()
		local claimed, ready = Game.rewardStreak(state.rewardStreak, state.rewardStreakAt, now)
		if payload.day ~= claimed + 1 then
			return reply(false, "Claim the days in order.")
		end
		if not ready then
			return reply(false, "Come back tomorrow for Day " .. claimed + 1 .. ".")
		end
		local result = grantReward(player, state, Game.StreakRewards[claimed + 1])
		if result.success then
			state.rewardStreak = claimed + 1
			state.rewardStreakAt = now
		end
		return result
	elseif name == "ClaimFreeReward" then
		if state.freeRewardClaimed then
			return reply(false, "Reward already claimed.")
		end
		state.freeRewardClaimed = true
		state.cash = math.min(Game.MaxCash, state.cash + 100)
		player:SetAttribute("Speed", math.min(Game.MaxSpeed, (player:GetAttribute("Speed") or 16) + 60))
		return reply(true, "Received $100 and +60 speed!")
	elseif name == "ReturnBase" then
		if Adventure.hasCargo(player) then
			return reply(false, "Carry stolen animals back through the Safe Zone first.")
		end
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if not root or player:GetAttribute("OnTreadmill") then
			return reply(false, "Leave the treadmill first.")
		end
		root.CFrame = CFrame.new(state.base.BaseAnchor.Position + Vector3.new(0, 4, -44))
		return reply(true)
	elseif name == "SetSlowMode" then
		if typeof(payload.enabled) ~= "boolean" then
			return reply(false)
		end
		player:SetAttribute("SlowMode", payload.enabled)
		applySpeed(player)
		return reply(true)
	elseif name == "SetSetting" then
		local setting, value = payload.setting, payload.value
		if setting == "MusicVolume" or setting == "SFXVolume" then
			if typeof(value) ~= "number" or value ~= value then
				return reply(false)
			end
			value = math.clamp(value, 0, 1)
		elseif setting == "ViewOthersPets" or setting == "ViewMyPets" or setting == "ViewMyEggs" then
			if typeof(value) ~= "boolean" then
				return reply(false)
			end
		else
			return reply(false)
		end
		state.settings[setting] = value
		player:SetAttribute(setting, value)
		return reply(true)
	elseif name == "Rebirth" then
		local cost = Game.rebirthCost(state.rebirths)
		if cost > Game.MaxCash then
			return reply(false, "You reached the maximum rebirth.")
		end
		if state.cash < cost then
			return reply(false, "You need $" .. Game.number(cost - state.cash) .. " more to rebirth.")
		end
		state.cash = 0
		state.rebirths += 1
		player:SetAttribute("Speed", 16)
		return reply(true, "Rebirth " .. state.rebirths .. "! Income x" .. Game.rebirthIncome(state.rebirths) .. ".")
	elseif name == "SetHotbar" then
		-- Keep only items the player owns now, so the saved layout cannot grow without bound.
		local layout, owned = payload.layout, {}
		for _, pet in state.pets do
			owned[pet.id] = true
		end
		for _, egg in state.backpackEggs do
			owned[egg.id] = true
		end
		if not Schema.ValidHotbar(layout) then
			return reply(false)
		end
		local kept = {}
		for key, slot in layout do
			if owned[key] or Schema.HotbarTools[key] then
				kept[key] = slot
			end
		end
		state.hotbar = kept
		return reply(true)
	end
	return reply(false, "This purchase is not available yet.")
end
remote.OnServerInvoke = function(player, name, payload)
	local state = states[player]
	if not state or not state.ready or not DataService.IsActive(player) then
		return reply(false, "Loading your saved progress...")
	end
	if typeof(name) ~= "string" or typeof(payload) ~= "table" then
		return reply(false)
	end
	local now = os.clock()
	if now - state.lastAction < 0.12 then
		return reply(false, "Please wait a moment.")
	end
	state.lastAction = now
	local result = perform(player, state, name, payload)
	if result.success then
		sync(player, state)
		DataService.Commit(player)
		if
			name == "ClaimOffline"
			or name == "ClaimCollectionReward"
			or name == "ClaimDailyReward"
			or name == "ClaimStreakReward"
			or name == "Rebirth"
		then
			DataService.RequestSave(player)
		end
	end
	return result
end

local function join(player)
	if states[player] then
		return
	end
	local state = {
		pets = {},
		eggs = {},
		backpackEggs = {},
		cash = Config.StartCash,
		capacity = Config.StartCapacity,
		offline = 0,
		income = 0,
		discovered = false,
		rewardClaimed = false,
		settings = {},
		hotbar = {},
		lastAction = 0,
		ready = false,
		connections = {},
		carriedKind = "",
		carriedPet = false,
		discoveries = {},
		ownedPickaxes = { 1 },
		ownedTrails = { 1 },
		pickaxe = 1,
		trail = 1,
		penLevel = 1,
		treadmillLevel = 1,
		satchelLevel = 1,
		playtime = 0,
		freeRewardClaimed = false,
		dailyRewardAt = 0,
		rewardStreak = 0,
		rewardStreakAt = 0,
		rebirths = 0,
	}
	states[player] = state
	local list = bases:GetChildren()
	table.sort(list, function(a, b)
		return a.Name < b.Name
	end)
	for _, base in list do
		if base:FindFirstChild("BaseAnchor") and not base:GetAttribute("OwnerUserId") then
			state.base = base
			base:SetAttribute("OwnerUserId", player.UserId)
			state.floor = World.floor(base)
			base:SetAttribute("FloorY", state.floor)
			base:SetAttribute("PenHalfWidth", Config.PenHalfWidth)
			base:SetAttribute("PenHalfDepth", Config.PenHalfDepth)
			state.contents = Instance.new("Folder")
			state.contents.Name = "PetContents"
			state.contents.Parent = base
			player:SetAttribute("BaseName", base.Name)
			break
		end
	end
	if not state.base then
		cleanup(player)
		player:Kick("All bases are occupied. Please join another server.")
		return
	end
	local saved = DataService.Load(player)
	if not saved then
		cleanup(player)
		return
	end
	if states[player] ~= state then
		DataService.Release(player)
		return
	end
	state.cash = saved.cash
	state.capacity = math.max(8, saved.capacity)
	state.discovered = saved.discovered
	state.rewardClaimed = saved.rewardClaimed
	state.settings = table.clone(saved.settings)
	state.hotbar = table.clone(saved.hotbar)
	player:SetAttribute("HotbarLayout", Http:JSONEncode(state.hotbar))
	state.offline = saved.offline
	state.carriedKind = saved.carriedKind
	state.carriedPet = saved.carriedPet
	for _, egg in saved.backpackEggs do
		table.insert(state.backpackEggs, table.clone(egg))
	end
	for _, key in saved.discoveries do
		state.discoveries[key == "TestChick" and "Chicken" or key] = true
	end
	for _, key in
		{
			"pickaxe",
			"trail",
			"penLevel",
			"treadmillLevel",
			"satchelLevel",
			"playtime",
			"freeRewardClaimed",
			"dailyRewardAt",
			"rewardStreak",
			"rewardStreakAt",
			"rebirths",
		}
	do
		state[key] = saved[key]
	end
	state.ownedPickaxes = table.clone(saved.ownedPickaxes)
	state.ownedTrails = table.clone(saved.ownedTrails)
	player:SetAttribute("Speed", saved.speed)
	player:SetAttribute("SlowMode", saved.slowMode)
	for _, savedPet in saved.pets do
		local pet = table.clone(savedPet)
		table.insert(state.pets, pet)
		if pet.equipped then
			local at = pet.x
					and pet.z
					and position(
						state,
						math.clamp(pet.x, -Config.PenHalfWidth, Config.PenHalfWidth),
						math.clamp(pet.z, -Config.PenHalfDepth, Config.PenHalfDepth)
					)
				or nil
			spawnPet(player, state, pet, at)
		end
	end
	local sortedEggs = table.clone(saved.eggs)
	table.sort(sortedEggs, Schema.EggComesFirst)
	for _, savedEgg in sortedEggs do
		local egg = table.clone(savedEgg)
		local at = position(
			state,
			math.clamp(egg.x, -Config.PenHalfWidth, Config.PenHalfWidth),
			math.clamp(egg.z, -Config.PenHalfDepth, Config.PenHalfDepth)
		)
		if egg.hatchesAt <= os.time() then
			addPet(player, state, at, nil, egg.kind, egg.weight)
		else
			egg.model = World.egg(nil, nil, "DefaultEgg")
			egg.position = at
			egg.model:SetAttribute("OwnerUserId", player.UserId)
			egg.model:SetAttribute("EggVisual", true)
			egg.model:PivotTo(CFrame.new(at))
			egg.model.Parent = state.contents
			egg.label = World.label(egg.model, "Growing")
			table.insert(state.eggs, egg)
		end
	end
	for key, value in state.settings do
		player:SetAttribute(key, value)
	end
	player:SetAttribute("Multiplier", Game.Trails[state.trail].multiplier)
	state.ready = true
	DataService.SetSnapshot(player, function()
		if state.ready and states[player] == state then
			return Schema.Snapshot(player, state)
		end
		return nil
	end)
	local function restoreCarried()
		reconcileTools(player, state)
	end
	table.insert(
		state.connections,
		player:GetAttributeChangedSignal("Speed"):Connect(function()
			applySpeed(player)
			DataService.Commit(player)
		end)
	)
	table.insert(
		state.connections,
		player:GetAttributeChangedSignal("CarryingCount"):Connect(function()
			applySpeed(player)
		end)
	)
	table.insert(
		state.connections,
		player.CharacterAdded:Connect(function(character)
			character:WaitForChild("Humanoid", 10)
			if player.Character == character and state.ready then
				applySpeed(player)
				Adventure.equipPickaxe(player, state.pickaxe)
				Adventure.applyTrail(player, state)
				restoreCarried()
			end
		end)
	)
	sync(player, state)
	player:SetAttribute("PetDataReady", true)
	applySpeed(player)
	restoreCarried()
	Adventure.equipPickaxe(player, state.pickaxe)
	Adventure.applyTrail(player, state)
	World.setupBase(player, state, function(name)
		if not state.ready or not DataService.IsActive(player) then
			return
		end
		local result = perform(player, state, name, {})
		if result.success then
			sync(player, state)
			DataService.Commit(player)
		end
		Adventure.notice(player, result.message)
	end)
end
Players.PlayerAdded:Connect(join)
for _, player in Players:GetPlayers() do
	task.spawn(join, player)
end
Players.PlayerRemoving:Connect(function(player)
	DataService.Release(player)
	cleanup(player)
end)
task.spawn(function()
	while true do
		task.wait(1)
		for player, state in states do
			if not state.ready or not DataService.IsActive(player) then
				continue
			end
			local now = os.time()
			hatchReady(player, state, now)
			for _, egg in state.eggs do
				egg.label.Text = "Hatches in " .. (egg.hatchesAt - now) .. "s"
			end
			sync(player, state)
			state.cash = math.min(Game.MaxCash, state.cash + state.income)
			state.playtime += 1
			player:SetAttribute("Cash", state.cash)
			DataService.Commit(player)
		end
	end
end)
Adventure.start({
	states = states,
	world = World,
	sync = sync,
	commit = DataService.Commit,
	active = DataService.IsActive,
	bank = function(player, kind, weight)
		local state = states[player]
		if
			not state
			or not state.ready
			or not DataService.IsActive(player)
			or inventoryCount(state) >= Config.MaxPets
		then
			return false
		end
		addPet(player, state, nil, nil, kind, weight, false)
		reconcileTools(player, state)
		sync(player, state)
		DataService.Commit(player)
		return true
	end,
	action = function(player, name, payload)
		local state = states[player]
		if not state or not state.ready then
			return reply(false, "Loading...")
		end
		local result = perform(player, state, name, payload or {})
		if result.success then
			sync(player, state)
			DataService.Commit(player)
		end
		return result
	end,
})
require(script.Parent.DevTools).start({
	states = states,
	sync = sync,
	commit = DataService.Commit,
	addPet = addPet,
	spawnPet = spawnPet,
	equippedCount = equippedCount,
	giveTool = giveTool,
	reconcileTools = reconcileTools,
	hatchReady = hatchReady,
	inventoryCount = inventoryCount,
	world = World,
	adventure = Adventure,
})
local elapsed = 0
RunService.Heartbeat:Connect(function(dt)
	elapsed += dt
	if elapsed < 0.1 then
		return
	end
	local step = math.min(elapsed, 0.3)
	elapsed = 0
	for player, state in states do
		if not state.ready or not DataService.IsActive(player) then
			continue
		end
		for _, pet in state.pets do
			if not pet.model then
				continue
			end
			local at = pet.position or randomPosition(state)
			local localAt = state.base.BaseAnchor.CFrame:PointToObjectSpace(at)
			at = position(
				state,
				math.clamp(localAt.X, -Config.PenHalfWidth + PET_EDGE_MARGIN, Config.PenHalfWidth - PET_EDGE_MARGIN),
				math.clamp(localAt.Z, -Config.PenHalfDepth + PET_EDGE_MARGIN, Config.PenHalfDepth - PET_EDGE_MARGIN)
			)
			local walking = false
			if os.clock() >= pet.restUntil then
				if not pet.target then
					pet.target = randomPosition(state)
				end
				local delta = pet.target - at
				if delta.Magnitude < 0.3 then
					pet.target = nil
					pet.restUntil = os.clock() + random:NextNumber(0.5, 2)
				else
					local direction = delta.Unit
					at += direction * math.min(Config.PetSpeed * step, delta.Magnitude)
					pet.yaw = math.atan2(-direction.X, -direction.Z)
					walking = true
				end
			end
			pet.position = at
			if pet.model:GetAttribute("PetPosition") ~= at then
				pet.model:SetAttribute("PetPosition", at)
			end
			if pet.model:GetAttribute("PetYaw") ~= pet.yaw then
				pet.model:SetAttribute("PetYaw", pet.yaw)
			end
			if pet.model:GetAttribute("PetWalking") ~= walking then
				pet.model:SetAttribute("PetWalking", walking)
			end
		end
	end
end)
