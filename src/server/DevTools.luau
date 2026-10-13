-- Owner-only test commands. The UserId check here is the only gate; the client panel is just a view.
-- payload.target (UserId) picks the player a command acts on; it defaults to the caller.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TextService = game:GetService("TextService")
local HttpService = game:GetService("HttpService")
local LogService = game:GetService("LogService")
local Stats = game:GetService("Stats")
local Game = require(RS:WaitForChild("GameConfig"))
local Config = require(RS:WaitForChild("PetConfig"))
local DataService = require(script.Parent.PlayerData.Service)
local Schema = require(script.Parent.PlayerData.Schema)
local DataConfig = require(script.Parent.PlayerData.Config)
local DevTools = {}
DevTools.Owners = table.freeze({ [11789507527] = true })
-- Outside Studio, other players' saved data stays read-only: only these commands may target them.
DevTools.LiveOtherCommands = table.freeze({
	GetPlayer = true,
	GetProfile = true,
	GoTo = true,
	Bring = true,
	Teleport = true,
	Ragdoll = true,
	DropCargo = true,
	Respawn = true,
	Kick = true,
	Notice = true,
})
-- World commands ignore the target.
local GLOBAL = {
	StartLava = true,
	StopLava = true,
	SetLavaInterval = true,
	SetLavaOff = true,
	SpawnTitan = true,
	RefillEggs = true,
	Broadcast = true,
	GetServer = true,
	ClearServerLog = true,
}
-- Read-only commands: no tool reconcile, sync or commit afterwards.
local QUERIES = { GetPlayer = true, GetProfile = true, GetServer = true, ClearServerLog = true }
local OFFLINE_HOURS = { [1] = true, [8] = true, [24] = true, [48] = true }
local LOG_SIZE = 40
local INTERVALS = { [10] = true, [30] = true, [60] = true, [120] = true }

local function reply(success, message, data)
	return { success = success, message = message, data = data }
end
local function finite(value)
	return typeof(value) == "number" and value == value and math.abs(value) < math.huge
end
local function root(player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local part = character and character:FindFirstChild("HumanoidRootPart")
	if part and humanoid and humanoid.Health > 0 then
		return part
	end
end
local function teleport(player, at)
	local part = root(player)
	if not part then
		return reply(false, player.Name .. " has no character.")
	end
	if player:GetAttribute("OnTreadmill") then
		return reply(false, player.Name .. " is on a treadmill.")
	end
	part.CFrame = CFrame.new(at)
	return reply(true, "Teleported " .. player.Name .. ".")
end
local function find(list, id)
	for index, item in list do
		if item.id == id then
			return item, index
		end
	end
end

-- ctx: states, sync, commit, addPet, spawnPet, equippedCount, giveTool, reconcileTools, hatchReady,
-- inventoryCount, world, adventure
function DevTools.start(ctx)
	local remote = Instance.new("RemoteFunction")
	remote.Name = "DevAction"
	assert(not RS:FindFirstChild(remote.Name), "DevAction already exists")
	remote.Parent = RS

	-- Last server warnings and errors, plus a frame counter for the Server tab.
	local log, fps, frames, since = {}, 0, 0, os.clock()
	LogService.MessageOut:Connect(function(message, kind)
		if kind == Enum.MessageType.MessageWarning or kind == Enum.MessageType.MessageError then
			table.insert(log, {
				at = os.time(),
				error = kind == Enum.MessageType.MessageError,
				text = string.sub(message, 1, 300),
			})
			if #log > LOG_SIZE then
				table.remove(log, 1)
			end
		end
	end)
	RunService.Heartbeat:Connect(function()
		frames += 1
		if os.clock() - since >= 1 then
			fps, frames, since = frames / (os.clock() - since), 0, os.clock()
		end
	end)

	local function snapshot(player, state)
		local pets, backpackEggs, baseEggs = {}, {}, {}
		for _, pet in state.pets do
			local info = Game.pet(pet.kind)
			table.insert(pets, {
				id = pet.id,
				kind = pet.kind,
				name = info.name,
				rarity = info.rarity,
				icon = info.icon,
				weight = pet.weight or 1,
				income = math.floor(Game.income(pet)),
				equipped = pet.equipped == true,
			})
		end
		table.sort(pets, function(a, b)
			return a.income == b.income and a.id < b.id or a.income > b.income
		end)
		for _, egg in state.backpackEggs do
			local info = Game.pet(egg.kind)
			table.insert(
				backpackEggs,
				{ id = egg.id, name = info.name, rarity = info.rarity, weight = egg.weight or 1 }
			)
		end
		local now = os.time()
		for _, egg in state.eggs do
			local info = Game.pet(egg.kind)
			table.insert(baseEggs, {
				id = egg.id,
				name = info.name,
				rarity = info.rarity,
				weight = egg.weight or 1,
				seconds = math.max(0, egg.hatchesAt - now),
			})
		end
		local discovered = 0
		for _ in state.discoveries do
			discovered += 1
		end
		local part = root(player)
		local dev = ctx.adventure.dev
		return {
			dev = {
				immune = dev.immune[player] == true,
				oneHit = dev.oneHit[player] == true,
				rarity = dev.rarity[player],
				luck = dev.luck[player] or 1,
				lavaInterval = dev.lavaInterval or Game.LavaInterval,
				lavaOff = dev.lavaOff,
				lava = ctx.adventure.lavaState(),
			},
			userId = player.UserId,
			name = player.Name,
			displayName = player.DisplayName,
			stats = {
				cash = state.cash,
				speed = player:GetAttribute("Speed") or 16,
				income = state.income,
				offline = state.offline,
				rebirths = state.rebirths,
				capacity = state.capacity,
				equipped = ctx.equippedCount(state),
				penLevel = state.penLevel,
				treadmillLevel = state.treadmillLevel,
				satchelLevel = state.satchelLevel,
				pickaxe = Game.Pickaxes[state.pickaxe] and Game.Pickaxes[state.pickaxe].name or "?",
				trail = Game.Trails[state.trail] and Game.Trails[state.trail].name or "?",
				playtime = state.playtime,
				discovered = discovered,
				totalPets = #Game.Pets,
				base = state.base and state.base.Name or "-",
				carrying = player:GetAttribute("CarryingCount") or 0,
				place = not part and "No character"
					or player:GetAttribute("OnTreadmill") and "Treadmill"
					or player:GetAttribute("InField") and "Field"
					or "Safe Zone",
			},
			pets = pets,
			backpackEggs = backpackEggs,
			baseEggs = baseEggs,
		}
	end

	local function perform(owner, player, state, name, payload)
		if name == "GetPlayer" then
			return reply(true, nil, snapshot(player, state))
		elseif name == "GetProfile" then
			DataService.Commit(player)
			local data = DataService.GetData(player)
			if not data then
				return reply(false, player.Name .. ": profile is not active.")
			end
			-- One line per top-level key keeps the dump readable in the panel.
			local keys, lines = {}, {}
			for key in data do
				table.insert(keys, key)
			end
			table.sort(keys)
			for _, key in keys do
				table.insert(lines, key .. ": " .. HttpService:JSONEncode(data[key]))
			end
			return reply(true, nil, {
				userId = player.UserId,
				text = table.concat(lines, "\n"),
				bytes = #HttpService:JSONEncode(data),
				keys = #keys,
				store = DataService.StoreName,
				mode = DataService.Mode,
				version = data.schemaVersion,
			})
		elseif name == "SaveNow" then
			if not DataService.SaveNow(player) then
				return reply(false, player.Name .. ": profile is not active.")
			end
			return reply(true, player.Name .. ": save sent; Last save updates when the DataStore confirms.")
		elseif name == "SimulateOffline" then
			local hours = payload.hours
			if not OFFLINE_HOURS[hours] then
				return reply(false, "Bad hours.")
			end
			-- As if the player left now and came back after `hours`: the same formula as on join.
			local data = Schema.Snapshot(player, state)
			data.offline = 0
			Schema.AccrueOffline(data, data.lastSeen + hours * 3600)
			state.offline = math.min(Game.MaxCash, state.offline + data.offline)
			return reply(
				true,
				string.format(
					"%s: +$%s offline for %dh (counts up to %dh).",
					player.Name,
					Game.number(data.offline),
					hours,
					DataConfig.OfflineLimitSeconds / 3600
				)
			)
		elseif name == "ResetProfile" then
			if not RunService:IsStudio() then
				return reply(false, "Profile reset works only in Studio.")
			end
			if not DataService.Reset(player) then
				return reply(false, player.Name .. ": profile is not active.")
			end
			player:Kick("Your Studio profile was reset. Start Play again.")
			return reply(true, player.Name .. ": profile reset.")
		elseif name == "GetServer" then
			return reply(true, nil, {
				fps = fps,
				physics = workspace:GetRealPhysicsFPS(),
				memory = Stats:GetTotalMemoryUsageMb(),
				players = #Players:GetPlayers(),
				maxPlayers = Players.MaxPlayers,
				uptime = time(),
				instances = #workspace:GetDescendants(),
				jobId = game.JobId,
				version = game.PlaceVersion,
				store = DataService.StoreName,
				mode = DataService.Mode,
				log = log,
			})
		elseif name == "ClearServerLog" then
			table.clear(log)
			return reply(true, "Server log cleared.")
		elseif name == "AddCash" or name == "SetCash" then
			if not finite(payload.amount) then
				return reply(false, "Bad amount.")
			end
			local base = name == "AddCash" and state.cash or 0
			state.cash = math.clamp(math.floor(base + payload.amount), 0, Game.MaxCash)
			return reply(true, player.Name .. ": cash $" .. Game.number(state.cash))
		elseif name == "AddSpeed" or name == "SetSpeed" then
			if not finite(payload.amount) then
				return reply(false, "Bad amount.")
			end
			local base = name == "AddSpeed" and (player:GetAttribute("Speed") or 16) or 0
			-- The Speed attribute handler in Pets.server applies WalkSpeed and commits.
			player:SetAttribute("Speed", math.clamp(base + payload.amount, 16, Game.MaxSpeed))
			return reply(true, player.Name .. ": speed " .. Game.number(player:GetAttribute("Speed")))
		elseif name == "AddRebirth" then
			state.rebirths += 1
			return reply(true, player.Name .. ": rebirths " .. state.rebirths)
		elseif name == "ResetRebirths" then
			state.rebirths = 0
			return reply(true, player.Name .. ": rebirths 0")
		elseif name == "AddOffline" then
			if not finite(payload.amount) then
				return reply(false, "Bad amount.")
			end
			state.offline = math.clamp(state.offline + payload.amount, 0, Game.MaxCash)
			return reply(true, player.Name .. ": offline cash $" .. Game.number(state.offline))
		elseif name == "ResetRewards" then
			state.dailyRewardAt = 0
			state.rewardStreak = 0
			state.rewardStreakAt = 0
			state.rewardClaimed = false
			state.freeRewardClaimed = false
			return reply(true, player.Name .. ": daily, streak and one-time rewards are ready.")
		elseif name == "UnlockGear" then
			table.clear(state.ownedPickaxes)
			table.clear(state.ownedTrails)
			for i in Game.Pickaxes do
				table.insert(state.ownedPickaxes, i)
			end
			for i in Game.Trails do
				table.insert(state.ownedTrails, i)
			end
			return reply(true, player.Name .. ": all pickaxes and trails owned.")
		elseif name == "MaxBase" then
			state.penLevel = #Game.PenCosts + 1
			state.capacity = math.min(Config.MaxCapacity, math.max(state.capacity, 8 + (state.penLevel - 1) * 4))
			state.treadmillLevel = #Game.Treadmills
			state.satchelLevel = 8
			ctx.world.updateBase(player, state)
			return reply(true, player.Name .. ": pen, treadmill and satchel maxed.")
		elseif name == "GivePet" or name == "GiveEgg" then
			local info = Game.ByPet[payload.kind]
			local weight = payload.weight
			if not info or not finite(weight) or weight <= 0 or weight > 1e6 then
				return reply(false, "Bad pet.")
			end
			if ctx.inventoryCount(state) >= Config.MaxPets then
				return reply(false, player.Name .. ": inventory full (" .. Config.MaxPets .. ").")
			end
			if name == "GiveEgg" then
				local result = ctx.giveTool(player, state, "Egg", { kind = info.key, weight = weight })
				result.message = result.success and (player.Name .. " got a " .. info.name .. " Egg") or result.message
				return result
			end
			ctx.addPet(player, state, nil, nil, info.key, weight, false)
			return reply(true, player.Name .. " got a " .. info.name)
		elseif name == "DiscoverAll" then
			for _, pet in Game.Pets do
				state.discoveries[pet.key] = true
			end
			state.discovered = true
			return reply(true, player.Name .. ": every animal discovered.")
		elseif name == "HatchBaseEggs" then
			if #state.eggs == 0 then
				return reply(false, player.Name .. " has no eggs on the base.")
			end
			ctx.hatchReady(player, state, math.huge)
			return reply(true, player.Name .. ": base eggs hatched.")
		elseif name == "ClearPets" then
			for _, list in { state.pets, state.eggs } do
				for _, item in list do
					if item.model then
						item.model:Destroy()
					end
				end
				table.clear(list)
			end
			table.clear(state.backpackEggs)
			return reply(true, player.Name .. ": pets and eggs removed.")
		elseif name == "RemovePet" then
			local pet, index = find(state.pets, payload.pet)
			if not pet then
				return reply(false, "Pet not found.")
			end
			if pet.model then
				pet.model:Destroy()
			end
			table.remove(state.pets, index)
			return reply(true, player.Name .. ": removed " .. Game.pet(pet.kind).name)
		elseif name == "RemoveEgg" then
			local egg, index = find(state.backpackEggs, payload.egg)
			local list = state.backpackEggs
			if not egg then
				egg, index = find(state.eggs, payload.egg)
				list = state.eggs
			end
			if not egg then
				return reply(false, "Egg not found.")
			end
			if egg.model then
				egg.model:Destroy()
			end
			table.remove(list, index)
			return reply(true, player.Name .. ": removed " .. Game.pet(egg.kind).name .. " Egg")
		elseif name == "SetPetEquipped" then
			local pet = find(state.pets, payload.pet)
			if not pet or typeof(payload.equipped) ~= "boolean" then
				return reply(false, "Pet not found.")
			end
			if payload.equipped and not pet.equipped then
				if ctx.equippedCount(state) >= state.capacity then
					return reply(false, player.Name .. " has no free pet slots.")
				end
				pet.equipped = true
				ctx.spawnPet(player, state, pet)
			elseif not payload.equipped and pet.equipped then
				pet.equipped = false
				if pet.model then
					pet.model:Destroy()
					pet.model = nil
				end
			end
			return reply(
				true,
				player.Name .. ": " .. Game.pet(pet.kind).name .. (pet.equipped and " on base" or " in backpack")
			)
		elseif name == "SetPetWeight" then
			local pet = find(state.pets, payload.pet)
			local weight = payload.weight
			if not pet or not finite(weight) or weight <= 0 or weight > 1e6 then
				return reply(false, "Bad weight.")
			end
			pet.weight = weight
			if pet.model then
				-- Respawn in place so the model size and income label follow the new weight.
				ctx.spawnPet(player, state, pet, pet.position, pet.yaw)
			end
			return reply(true, player.Name .. ": " .. Game.pet(pet.kind).name .. " is " .. Game.number(weight) .. " kg")
		elseif name == "StartLava" then
			ctx.adventure.forceLava()
			return reply(true, "Lava wave started.")
		elseif name == "StopLava" then
			if not ctx.adventure.lavaState().active then
				return reply(false, "No lava wave is running.")
			end
			ctx.adventure.stopLava()
			return reply(true, "Lava wave stopped.")
		elseif name == "SetLavaInterval" then
			if payload.seconds ~= nil and not INTERVALS[payload.seconds] then
				return reply(false, "Bad interval.")
			end
			ctx.adventure.setLavaInterval(payload.seconds)
			return reply(true, "Lava every " .. (payload.seconds or Game.LavaInterval) .. " s.")
		elseif name == "SetLavaOff" then
			if typeof(payload.off) ~= "boolean" then
				return reply(false, "Bad value.")
			end
			ctx.adventure.dev.lavaOff = payload.off
			return reply(true, payload.off and "Lava waves paused." or "Lava waves resumed.")
		elseif name == "RefillEggs" then
			return reply(true, ctx.adventure.refillEggs() .. " field eggs back to full HP.")
		elseif name == "Broadcast" then
			local kind = payload.kind
			if typeof(payload.text) ~= "string" or (kind ~= "danger" and kind ~= "event" and kind ~= nil) then
				return reply(false, "Bad message.")
			end
			local text = string.sub(string.gsub(payload.text, "^%s+", ""), 1, 120)
			if text == "" then
				return reply(false, "Type a message first.")
			end
			-- Text other players see must pass Roblox filtering.
			local ok, filtered = pcall(function()
				return TextService:FilterStringAsync(text, owner.UserId, Enum.TextFilterContext.PublicChat)
					:GetNonChatStringForBroadcastAsync()
			end)
			if not ok then
				return reply(false, "Text filter is unavailable, try again.")
			end
			for _, other in Players:GetPlayers() do
				ctx.adventure.notice(other, filtered, kind)
			end
			return reply(true, "Sent to " .. #Players:GetPlayers() .. " players.")
		elseif name == "SetLavaImmune" or name == "SetOneHit" then
			if typeof(payload.on) ~= "boolean" then
				return reply(false, "Bad value.")
			end
			local list = name == "SetLavaImmune" and ctx.adventure.dev.immune or ctx.adventure.dev.oneHit
			list[player] = payload.on or nil
			return reply(
				true,
				player.Name
					.. (name == "SetLavaImmune" and ": lava immunity " or ": one-hit eggs ")
					.. (payload.on and "ON" or "OFF")
			)
		elseif name == "SetForceRarity" then
			local rarity = payload.rarity
			if rarity ~= nil and not Game.RarityIndex[rarity] then
				return reply(false, "Bad rarity.")
			end
			ctx.adventure.dev.rarity[player] = rarity
			return reply(true, player.Name .. ": hatches " .. (rarity or "roll normally"))
		elseif name == "SetLuck" then
			local value = payload.value
			if not finite(value) or value < 1 or value > 1e4 then
				return reply(false, "Bad luck.")
			end
			ctx.adventure.dev.luck[player] = value ~= 1 and value or nil
			return reply(true, player.Name .. ": luck x" .. Game.number(value))
		elseif name == "SpawnTitan" then
			ctx.adventure.forceTitan()
			return reply(true, "Titanic Egg spawned.")
		elseif name == "Notice" then
			local kind = payload.kind
			if kind ~= "danger" and kind ~= "event" and kind ~= nil then
				return reply(false, "Bad kind.")
			end
			ctx.adventure.notice(player, "Test notice: " .. (kind or "info"), kind)
			return reply(true, "Notice sent to " .. player.Name .. ".")
		elseif name == "Teleport" then
			local to = payload.to
			if to == "Base" then
				return teleport(player, state.base.BaseAnchor.Position + Vector3.new(0, 4, -44))
			elseif to == "Titan" then
				return teleport(player, Vector3.new(0, 8, -192))
			end
			local biome = typeof(to) == "string" and workspace.Map.Biomes:FindFirstChild(to)
			local spot = biome and biome:FindFirstChild("EggSpots") and biome.EggSpots:GetChildren()[1]
			if not spot then
				return reply(false, "Unknown place.")
			end
			return teleport(player, spot.Position + Vector3.new(0, 6, 0))
		elseif name == "GoTo" or name == "Bring" then
			if player == owner then
				return reply(false, "Pick another player.")
			end
			local from, to = owner, player
			if name == "Bring" then
				from, to = player, owner
			end
			local target = root(to)
			if not target then
				return reply(false, to.Name .. " has no character.")
			end
			return teleport(from, target.Position + target.CFrame.LookVector * 4 + Vector3.new(0, 2, 0))
		elseif name == "Ragdoll" then
			if not root(player) then
				return reply(false, player.Name .. " has no character.")
			end
			local angle = math.random() * math.pi * 2
			ctx.adventure.ragdoll(player, Vector3.new(math.cos(angle) * 30, 70, math.sin(angle) * 30), 3)
			return reply(true, player.Name .. " ragdolled.")
		elseif name == "DropCargo" then
			if (player:GetAttribute("CarryingCount") or 0) == 0 then
				return reply(false, player.Name .. " carries nothing.")
			end
			ctx.adventure.dropCargo(player, "A developer dropped your animals.")
			return reply(true, player.Name .. " dropped the cargo.")
		elseif name == "Respawn" then
			player:LoadCharacter()
			return reply(true, player.Name .. " respawned.")
		elseif name == "Kick" then
			if player == owner then
				return reply(false, "You cannot kick yourself.")
			end
			local reason = typeof(payload.reason) == "string" and string.sub(payload.reason, 1, 100) or ""
			player:Kick(reason ~= "" and reason or "Kicked by the developer.")
			return reply(true, player.Name .. " kicked.")
		end
		return reply(false, "Unknown command.")
	end

	remote.OnServerInvoke = function(owner, name, payload)
		if not DevTools.Owners[owner.UserId] then
			return reply(false, "Not allowed.")
		end
		if typeof(name) ~= "string" or typeof(payload) ~= "table" then
			return reply(false, "Bad request.")
		end
		local player = owner
		if payload.target ~= nil and not GLOBAL[name] then
			player = typeof(payload.target) == "number" and Players:GetPlayerByUserId(payload.target)
			if not player then
				return reply(false, "That player left.")
			end
		end
		if player ~= owner and not RunService:IsStudio() and not DevTools.LiveOtherCommands[name] then
			return reply(false, "Live servers: other players' data is read-only.")
		end
		local state = ctx.states[player]
		if not state or not state.ready then
			return reply(false, player.Name .. " is still loading.")
		end
		local result = perform(owner, player, state, name, payload)
		if result.success and not QUERIES[name] then
			if player ~= owner then
				print(string.format("[DevTools] %s -> %s: %s", owner.Name, player.Name, name))
			end
			if name ~= "Kick" and name ~= "ResetProfile" and ctx.states[player] == state and state.ready then
				ctx.reconcileTools(player, state)
				ctx.sync(player, state)
				ctx.commit(player)
			end
		end
		return result
	end

	local function mark(player)
		if DevTools.Owners[player.UserId] then
			player:SetAttribute("DevAccess", true)
		end
	end
	Players.PlayerAdded:Connect(mark)
	for _, player in Players:GetPlayers() do
		mark(player)
	end
end
return DevTools
