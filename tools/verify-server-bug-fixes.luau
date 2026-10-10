-- Run in MCP Edit. Fresh source evaluation avoids require caches.
-- All characters, ownership and stations are isolated; no player profiles are read.
local RS, server = game.ReplicatedStorage, game.ServerScriptService
local modules = {}
local function evaluate(source, extras)
	local environment = setmetatable(extras or {}, { __index = getfenv() })
	environment.require = function(module)
		return modules[module] or require(module)
	end
	local chunk = assert(loadstring(source))
	setfenv(chunk, environment)
	return chunk()
end
local Game = evaluate(RS.GameConfig.Source)
modules[RS.GameConfig] = Game
local DataConfig = evaluate(server.PlayerData.Config.Source, { script = server.PlayerData.Config })
modules[server.PlayerData.Config] = DataConfig
local Schema = evaluate(server.PlayerData.Schema.Source, { script = server.PlayerData.Schema })
modules[server.PlayerData.Schema] = Schema
local function copy(value)
	if type(value) ~= "table" then
		return value
	end
	local result = {}
	for key, child in value do
		result[key] = copy(child)
	end
	return result
end
local fixture = Instance.new("Folder")
fixture.Name = "ServerBugFixQA"
local function model()
	local object = Instance.new("Model", fixture)
	local part = Instance.new("Part", object)
	part.Anchored = true
	object.PrimaryPart = part
	return object
end
local function player(id, at)
	local object = { UserId = id, attributes = {} }
	object.Character = model()
	object.Character.PrimaryPart.Name = "HumanoidRootPart"
	object.Character.PrimaryPart.Position = at or Vector3.zero
	Instance.new("Humanoid", object.Character)
	object.Backpack = Instance.new("Backpack", fixture)
	function object:GetAttribute(key)
		return self.attributes[key]
	end
	function object:SetAttribute(key, value)
		self.attributes[key] = value
	end
	function object:FindFirstChildOfClass(kind)
		return kind == "Backpack" and self.Backpack or nil
	end
	return object
end
local function tool(kind, data)
	local object = Instance.new("Tool")
	object.Name = data.kind
	object.RequiresHandle = false
	object:SetAttribute("PlacementKind", kind)
	return object
end
local source = server.PetGameplay.Source
source = string.sub(source, 1, assert(string.find(source, "remote.OnServerInvoke =", 1, true)) - 1)
local function stub(pattern, replacement)
	local count
	source, count = string.gsub(source, pattern, replacement)
	assert(count == 1, "Stub mismatch: " .. pattern)
end
stub("local DataService = require%(script.Parent.PlayerData.Service%)", "local DataService = __data")
stub("local World = require%(script.Parent.PetWorld%)", "local World = __world")
stub("local Adventure = require%(script.Parent.Adventure%)", "local Adventure = __adventure")
stub('assert%(not RS:FindFirstChild%(remote.Name%), "UIAction already exists"%)', "")
stub("remote.Parent = RS", "remote.Parent = __fixture")
source ..= "\nreturn {perform=perform,reconcile=reconcileTools,hatchReady=hatchReady}"
local api = evaluate(source, {
	script = server.PetGameplay,
	__fixture = fixture,
	__data = {
		IsActive = function()
			return true
		end,
		SessionEnded = { Connect = function() end },
	},
	__world = {
		tool = tool,
		pet = model,
		egg = model,
		label = function()
			return {}
		end,
	},
	__adventure = {
		hasCargo = function()
			return false
		end,
	},
})
local ok, result = pcall(function()
	assert(DataConfig.OfflineLimitSeconds == 24 * 3600, "Offline window is not 24 hours")
	assert(Game.ByPet.TitanDragon.income == 240000000, "Titan balance mismatch")
	local oldOverflow = copy(Schema.Template)
	oldOverflow.offline = 2707200000000000000
	Schema.MigrateOffline(oldOverflow)
	assert(
		oldOverflow.offline == Game.MaxCash and Schema.Validate(oldOverflow),
		"Old offline overflow still blocks login"
	)
	oldOverflow.offline = math.huge
	Schema.MigrateOffline(oldOverflow)
	assert(not Schema.Validate(oldOverflow), "Offline recovery accepts infinity")
	oldOverflow.offline = 0 / 0
	Schema.MigrateOffline(oldOverflow)
	assert(not Schema.Validate(oldOverflow), "Offline recovery accepts NaN")
	local income = Game.income({ kind = "TitanDragon", weight = 1e12 })
	local day = copy(Schema.Template)
	day.lastSeen = 1000
	day.pets = { { id = "titan", kind = "TitanDragon", weight = 1e12, equipped = true } }
	local twoDays = copy(day)
	Schema.AccrueOffline(day, 1000 + 24 * 3600)
	Schema.AccrueOffline(twoDays, 1000 + 48 * 3600)
	assert(day.offline == income * 24 * 3600 and day.offline == twoDays.offline, "Income continues after 24 hours")
	local capped = copy(Schema.Template)
	capped.lastSeen = 1000
	capped.capacity = 40
	capped.offline = Game.MaxCash - 100
	for i = 1, 40 do
		capped.pets[i] = { id = tostring(i), kind = "TitanDragon", weight = 1e12, equipped = true }
	end
	Schema.AccrueOffline(capped, 1000 + 48 * 3600)
	assert(capped.offline == Game.MaxCash and Schema.Validate(capped), "Offline reward invalidates profile")
	local deferred = copy(Schema.Template)
	for i = 1, 200 do
		deferred.pets[i] = { id = tostring(i), kind = "Chicken", weight = 1, equipped = false }
	end
	deferred.carriedKind = "Egg"
	deferred.carriedPet = { kind = "Chicken", weight = 5 }
	Schema.MigrateBackpack(deferred)
	assert(Schema.Validate(deferred) and deferred.carriedKind == "Egg", "Full migration lost item or blocks login")
	local p = player(991)
	local base = model()
	base.PrimaryPart.Name = "BaseAnchor"
	base:SetAttribute("OwnerUserId", p.UserId)
	deferred.ready, deferred.base, deferred.floor, deferred.contents = true, base, 0, fixture
	api.reconcile(p, deferred)
	p.Backpack:FindFirstChildOfClass("Tool").Parent = p.Character
	assert(api.perform(p, deferred, "PlacePet", { position = Vector3.zero }).success)
	assert(deferred.carriedKind == "Egg", "Placement erased deferred item")
	for _ = 1, 3 do
		table.remove(deferred.pets)
	end
	api.reconcile(p, deferred)
	assert(deferred.carriedKind == "" and #deferred.backpackEggs == 1, "Deferred item not restored after space freed")
	local id = deferred.backpackEggs[1].id
	api.reconcile(p, deferred)
	assert(#deferred.backpackEggs == 1 and deferred.backpackEggs[1].id == id, "Migration duplicates item")
	local found = false
	for _, t in p.Backpack:GetChildren() do
		if t:GetAttribute("InventoryId") == id then
			found = true
		end
	end
	assert(found, "Migrated egg has no Tool")
	local state = {
		pets = {},
		eggs = {},
		backpackEggs = {},
		base = base,
		floor = 0,
		contents = fixture,
		capacity = 8,
		cash = 100,
		discoveries = {},
	}
	for i = 1, 7 do
		state.pets[i] = { id = "active-" .. i, kind = "Chicken", weight = 1, equipped = true }
	end
	state.eggs = {
		{ id = "late", kind = "Chicken", weight = 1, hatchesAt = 1002, position = Vector3.zero, model = model() },
		{ id = "early", kind = "TitanDragon", weight = 1, hatchesAt = 1001, position = Vector3.zero, model = model() },
	}
	api.hatchReady(p, state, 1003)
	assert(
		state.pets[8].kind == "TitanDragon" and state.pets[8].equipped and not state.pets[9].equipped,
		"Later egg takes earlier egg's slot"
	)
	assert(Schema.EggComesFirst({ id = "a", hatchesAt = 1 }, { id = "b", hatchesAt = 1 }), "Egg ties not stable")
	state.cash, state.offline = Game.MaxCash - 100, 200
	assert(
		api.perform(p, state, "ClaimOffline", {}).success and state.cash == Game.MaxCash and state.offline == 0,
		"Claim exceeds numeric limit"
	)
	local attacker, target = player(992, Vector3.new(0, 3, -100)), player(993, Vector3.new(1, 3, -100))
	local bat = Instance.new("Tool", attacker.Character)
	bat.Name, bat.RequiresHandle = "Lava Bat", false
	local adventureSource = server.Adventure.Source
	adventureSource =
		string.sub(adventureSource, 1, assert(string.find(adventureSource, "local function openShop", 1, true)) - 1)
	adventureSource =
		string.gsub(adventureSource, 'local Players = game:GetService%("Players"%)', "local Players = __players")
	adventureSource ..= "\nreturn {bat=bat,setup=function(s,f,c) services=s feedback=f cargo=c lastSwing={} end}"
	local adventure = evaluate(
		adventureSource,
		{ __players = {
			GetPlayers = function()
				return { attacker, target }
			end,
		} }
	)
	local function attack(ready, active, training, carrying, safe)
		target.Character.Humanoid.Health = 100
		target.Character.PrimaryPart.Position = Vector3.new(1, 3, safe and Game.SafeZ or -100)
		attacker:SetAttribute("OnTreadmill", training)
		attacker.Character.PrimaryPart.Position = Vector3.new(0, 3, safe and Game.SafeZ - 1 or -100)
		local cargo = { [target] = { { kind = "Chicken", weight = 1 } } }
		if carrying then
			cargo[attacker] = { { kind = "Chicken", weight = 1 } }
		end
		adventure.setup({
			states = { [attacker] = { ready = ready } },
			active = function()
				return active
			end,
		}, { FireAllClients = function() end }, cargo)
		adventure.bat(attacker)
		return target.Character.Humanoid.Health, target:GetAttribute("CarryingCount")
	end
	assert(attack(false, true, false, false, false) == 100, "Bat before profile ready")
	assert(attack(true, false, false, false, false) == 100, "Bat after session loss")
	assert(attack(true, true, true, false, false) == 100, "Bat while training")
	assert(attack(true, true, false, true, false) == 100, "Bat while carrying")
	assert(attack(true, true, false, false, true) == 100, "Bat hits safe target")
	local health, cargoCount = attack(true, true, false, false, false)
	assert(health == 90 and cargoCount == 0, "Valid field bat no longer works")
	local worldSource = server.PetWorld.Source
	local first = assert(string.find(worldSource, "function World.updateBase", 1, true))
	local last = assert(string.find(worldSource, "function World.floor", first, true))
	local station = workspace.Map.StartZone.Treadmills:GetChildren()[1]:Clone()
	station.Parent = fixture
	for _ = 1, 3 do
		local light = Instance.new("PointLight", station.TrainingCenter)
		light.Name = "UpgradeGlow"
	end
	local update = evaluate(
		"local World={} local Game=require(game.ReplicatedStorage.GameConfig)\n"
			.. string.sub(worldSource, first, last - 1)
			.. "\nreturn World.updateBase",
		{
			workspace = {
				Map = {
					StartZone = { Treadmills = {
						FindFirstChild = function()
							return station
						end,
					} },
				},
			},
		}
	)
	local treadmill = { base = { Name = "QA" }, penLevel = 1, treadmillLevel = 5 }
	for _ = 1, 3 do
		update(p, treadmill)
	end
	local function glows()
		local count = 0
		for _, child in station:GetDescendants() do
			if child.Name == "UpgradeGlow" then
				count += 1
			end
		end
		return count
	end
	assert(glows() == 1, "Duplicate treadmill lights survive")
	treadmill.treadmillLevel = 1
	update(p, treadmill)
	assert(glows() == 0 and station:GetAttribute("TrainingGain") == 1, "Old owner light survives level reset")
	return "PASS: 24h cap, Titan balance, currency bounds, full legacy migration/deferred recovery, placement preservation, chronological hatch, Bat gates/safe zone, treadmill light deduplication/reset"
end)
fixture:Destroy()
assert(ok, result)
return result
