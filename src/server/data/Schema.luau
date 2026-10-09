local PetConfig = require(game.ReplicatedStorage.PetConfig)
local Game = require(game.ReplicatedStorage.GameConfig)
local DataConfig = require(script.Parent.Config)
local Schema = {}
Schema.Version = 1
Schema.Template = {
	schemaVersion = Schema.Version,
	initialized = false,
	legacyMigrationCompleted = false,
	cash = PetConfig.StartCash,
	speed = 16,
	slowMode = false,
	capacity = PetConfig.StartCapacity,
	pets = {},
	eggs = {},
	backpackEggs = {},
	discovered = false,
	rewardClaimed = false,
	settings = { MusicVolume = 1, SFXVolume = 1, ViewMyPets = true, ViewOthersPets = true, ViewMyEggs = true },
	offline = 0,
	income = 0,
	lastSeen = 0,
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
}
local function number(value, minimum, maximum)
	return typeof(value) == "number" and value == value and value >= minimum and value <= maximum
end
local function array(value, maximum)
	if type(value) ~= "table" or #value > maximum then
		return false
	end
	local count = 0
	for key in value do
		if type(key) ~= "number" or key % 1 ~= 0 or key < 1 or key > #value then
			return false
		end
		count += 1
	end
	return count == #value
end
function Schema.Validate(data)
	if type(data) ~= "table" or data.schemaVersion ~= Schema.Version then
		return false, "Unsupported profile version"
	end
	for _, key in { "cash", "offline", "speed", "income", "lastSeen" } do
		if not number(data[key], 0, 1e18) then
			return false, "Invalid " .. key
		end
	end
	if not number(data.capacity, 2, PetConfig.MaxCapacity) or data.capacity % 1 ~= 0 then
		return false, "Invalid capacity"
	end
	for _, key in { "initialized", "legacyMigrationCompleted", "slowMode", "discovered", "rewardClaimed" } do
		if type(data[key]) ~= "boolean" then
			return false, "Invalid " .. key
		end
	end
	if data.carriedKind ~= "" and data.carriedKind ~= "Pet" and data.carriedKind ~= "Egg" then
		return false, "Invalid carried item"
	end
	if
		not array(data.pets, PetConfig.MaxPets)
		or not array(data.eggs, PetConfig.MaxEggs)
		or not array(data.backpackEggs, PetConfig.MaxPets)
		or #data.pets + #data.eggs + #data.backpackEggs > PetConfig.MaxPets
	then
		return false, "Invalid inventory"
	end
	local ids, equipped = {}, 0
	for _, pet in data.pets do
		if
			type(pet) ~= "table"
			or type(pet.id) ~= "string"
			or #pet.id == 0
			or #pet.id > 100
			or ids[pet.id]
			or type(pet.equipped) ~= "boolean"
		then
			return false, "Invalid pet"
		end
		ids[pet.id] = true
		if pet.equipped then
			equipped += 1
		end
		if pet.kind ~= nil and not Game.ByPet[pet.kind] then
			return false, "Unknown pet type"
		end
		if pet.weight ~= nil and not number(pet.weight, 0.1, 1e12) then
			return false, "Invalid pet weight"
		end
		for _, key in { "x", "z" } do
			if pet[key] ~= nil and not number(pet[key], -1e6, 1e6) then
				return false, "Invalid pet position"
			end
		end
	end
	if equipped > data.capacity then
		return false, "Equipped pets exceed capacity"
	end
	for _, egg in data.eggs do
		if type(egg) ~= "table" or type(egg.id) ~= "string" or #egg.id == 0 or #egg.id > 100 or ids[egg.id] then
			return false, "Invalid egg"
		end
		ids[egg.id] = true
		if not number(egg.x, -1e6, 1e6) or not number(egg.z, -1e6, 1e6) or not number(egg.hatchesAt, 0, 1e18) then
			return false, "Invalid egg position or time"
		end
		if egg.kind ~= nil and not Game.ByPet[egg.kind] then
			return false, "Unknown egg contents"
		end
		if egg.weight ~= nil and not number(egg.weight, 0.1, 1e12) then
			return false, "Invalid egg weight"
		end
	end
	for _, egg in data.backpackEggs do
		if
			type(egg) ~= "table"
			or type(egg.id) ~= "string"
			or #egg.id == 0
			or #egg.id > 100
			or ids[egg.id]
			or not Game.ByPet[egg.kind]
			or not number(egg.weight, 0.1, 1e12)
		then
			return false, "Invalid backpack egg"
		end
		ids[egg.id] = true
	end
	if type(data.settings) ~= "table" then
		return false, "Invalid settings"
	end
	for _, key in { "MusicVolume", "SFXVolume" } do
		if not number(data.settings[key], 0, 1) then
			return false, "Invalid volume"
		end
	end
	for _, key in { "ViewMyPets", "ViewOthersPets", "ViewMyEggs" } do
		if type(data.settings[key]) ~= "boolean" then
			return false, "Invalid visibility"
		end
	end
	for key, maximum in
		{
			pickaxe = #Game.Pickaxes,
			trail = #Game.Trails,
			penLevel = #Game.PenCosts + 1,
			treadmillLevel = #Game.Treadmills,
			satchelLevel = 8,
		}
	do
		if not number(data[key], 1, maximum) or data[key] % 1 ~= 0 then
			return false, "Invalid " .. key
		end
	end
	for key, maximum in { ownedPickaxes = #Game.Pickaxes, ownedTrails = #Game.Trails } do
		if not array(data[key], maximum) then
			return false, "Invalid " .. key
		end
		local seen = {}
		for _, index in data[key] do
			if not number(index, 1, maximum) or index % 1 ~= 0 or seen[index] then
				return false, "Invalid owned item"
			end
			seen[index] = true
		end
	end
	if not table.find(data.ownedPickaxes, data.pickaxe) or not table.find(data.ownedTrails, data.trail) then
		return false, "Equipped item not owned"
	end
	if not array(data.discoveries, #Game.Pets + 1) then
		return false, "Invalid discoveries"
	end
	for _, key in data.discoveries do
		if not Game.ByPet[key] then
			return false, "Unknown discovery"
		end
	end
	if data.carriedPet ~= false then
		if
			type(data.carriedPet) ~= "table"
			or not Game.ByPet[data.carriedPet.kind]
			or not number(data.carriedPet.weight, 0.1, 1e12)
		then
			return false, "Invalid carried pet"
		end
	end
	if not number(data.playtime, 0, 1e12) or type(data.freeRewardClaimed) ~= "boolean" then
		return false, "Invalid progress"
	end
	return true
end
-- Reconcile supplies the new array to version-one profiles. Convert the old
-- single carried item once, preserving pets already represented by their ID.
function Schema.MigrateBackpack(data)
	local carried = data.carriedPet
	if data.carriedKind ~= "" and type(carried) == "table" then
		local exists = false
		if data.carriedKind == "Pet" then
			for _, pet in data.pets do
				if pet.id == carried.id then
					exists = true
					break
				end
			end
		end
		if not exists then
			local item = {
				id = game:GetService("HttpService"):GenerateGUID(false),
				kind = carried.kind,
				weight = carried.weight,
			}
			if data.carriedKind == "Egg" then
				table.insert(data.backpackEggs, item)
			else
				item.equipped = false
				table.insert(data.pets, item)
			end
		end
	end
	data.carriedKind = ""
	data.carriedPet = false
end
function Schema.AccrueOffline(data, now)
	if data.lastSeen <= 0 then
		return
	end
	local finish = math.min(now, data.lastSeen + DataConfig.OfflineLimitSeconds)
	local seconds = math.max(0, finish - data.lastSeen)
	local equipped = 0
	for _, pet in data.pets do
		if pet.equipped then
			equipped += 1
		end
	end
	local reward = 0
	for _, pet in data.pets do
		if pet.equipped then
			reward += seconds * Game.income(pet)
		end
	end
	-- Eggs finishing while away can fill free active slots and begin earning too.
	local eggs = table.clone(data.eggs)
	table.sort(eggs, function(a, b)
		return a.hatchesAt < b.hatchesAt
	end)
	for _, egg in eggs do
		if egg.hatchesAt <= now and equipped < data.capacity then
			equipped += 1
			reward += math.max(0, finish - math.max(data.lastSeen, egg.hatchesAt)) * Game.income(egg)
		end
	end
	data.offline += reward
end
function Schema.Snapshot(player, state)
	local pets, eggs, backpackEggs = {}, {}, {}
	for _, pet in state.pets do
		local item = { id = pet.id, kind = pet.kind or "TestChick", weight = pet.weight or 1, equipped = pet.equipped }
		if pet.model and pet.position then
			local p = state.base.BaseAnchor.CFrame:PointToObjectSpace(pet.position)
			item.x, item.z = p.X, p.Z
		end
		table.insert(pets, item)
	end
	for _, egg in state.eggs do
		local p = state.base.BaseAnchor.CFrame:PointToObjectSpace(egg.position)
		table.insert(
			eggs,
			{ id = egg.id, x = p.X, z = p.Z, hatchesAt = egg.hatchesAt, kind = egg.kind, weight = egg.weight }
		)
	end
	for _, egg in state.backpackEggs do
		table.insert(backpackEggs, { id = egg.id, kind = egg.kind, weight = egg.weight })
	end
	local income = 0
	for _, pet in pets do
		if pet.equipped then
			income += Game.income(pet)
		end
	end
	local discoveries = {}
	for key in state.discoveries or {} do
		table.insert(discoveries, key)
	end
	table.sort(discoveries)
	return {
		schemaVersion = Schema.Version,
		initialized = true,
		cash = state.cash,
		speed = player:GetAttribute("Speed") or 16,
		slowMode = player:GetAttribute("SlowMode") == true,
		capacity = state.capacity,
		pets = pets,
		eggs = eggs,
		backpackEggs = backpackEggs,
		discovered = state.discovered,
		rewardClaimed = state.rewardClaimed,
		settings = table.clone(state.settings),
		offline = state.offline,
		income = income,
		lastSeen = os.time(),
		carriedKind = state.carriedKind or "",
		carriedPet = state.carriedPet or false,
		discoveries = discoveries,
		ownedPickaxes = table.clone(state.ownedPickaxes),
		ownedTrails = table.clone(state.ownedTrails),
		pickaxe = state.pickaxe,
		trail = state.trail,
		penLevel = state.penLevel,
		treadmillLevel = state.treadmillLevel,
		satchelLevel = state.satchelLevel,
		playtime = state.playtime,
		freeRewardClaimed = state.freeRewardClaimed,
	}
end
return Schema
