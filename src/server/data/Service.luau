local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local DataStoreService = game:GetService("DataStoreService")
local ProfileStore = require(ServerStorage:WaitForChild("ServerPackages"):WaitForChild("ProfileStore"))
local Config = require(script.Parent.Config)
local Schema = require(script.Parent.Schema)
local Service = {}
local records, loading = {}, {}
local isStudio = RunService:IsStudio()
local isMock = isStudio and Config.StudioMode == "Mock"
assert(Config.StudioMode == "Persistent" or Config.StudioMode == "Mock", "Invalid Studio save mode")
ProfileStore.SetConstant("AUTO_SAVE_PERIOD", Config.AutoSaveSeconds)
ProfileStore.SetConstant("START_SESSION_TIMEOUT", Config.LoadTimeoutSeconds)
local store = ProfileStore.New(Config.StoreName(isStudio), Schema.Template)
if isMock then
	store = store.Mock
end
Service.StoreName = store.Name
Service.Mode = isMock and "Mock" or "Persistent"
local ended = Instance.new("BindableEvent")
ended.Name = "SessionEnded"
ended.Parent = script
Service.SessionEnded = ended.Event

local function report(player, message)
	warn("[PlayerData] " .. message .. " (user " .. player.UserId .. ")")
	if player.Parent == Players then
		player:Kick("Couldn't load your saved progress. Please rejoin.")
	end
end
local function writable(player)
	local record = records[player]
	return not ProfileStore.IsClosing and record and not record.closing and record.profile:IsActive() and record or nil
end
function Service.IsActive(player)
	return writable(player) ~= nil
end
function Service.GetData(player)
	local record = writable(player)
	return record and record.profile.Data or nil
end
local function commitRecord(player, record)
	if not record.snapshot then
		return true
	end
	local data = record.snapshot()
	if not data then
		return true
	end
	-- Reconciliation/migration flags belong to the data service, not gameplay snapshots.
	data.legacyMigrationCompleted = record.profile.Data.legacyMigrationCompleted
	local valid, reason = Schema.Validate(data)
	if not valid then
		report(player, "Rejected invalid save snapshot: " .. reason)
		return false
	end
	for key, value in data do
		record.profile.Data[key] = value
	end
	return true
end
function Service.Commit(player)
	local record = writable(player)
	return record ~= nil and commitRecord(player, record)
end
function Service.SetSnapshot(player, snapshot)
	local record = writable(player)
	assert(record, "An active profile is required")
	record.snapshot = snapshot
	return commitRecord(player, record)
end
function Service.RequestSave(player)
	local record = writable(player)
	if not record or not Service.Commit(player) then
		return false
	end
	if os.clock() - record.lastRequestedSave < 10 then
		return true
	end
	record.lastRequestedSave = os.clock()
	record.profile:Save()
	return true
end
local function migrateLegacy(player, profile)
	local data = profile.Data
	if data.legacyMigrationCompleted then
		return true
	end
	if not isStudio and Config.MigrateLegacyLive and not data.initialized then
		local ok, legacy = pcall(function()
			return DataStoreService:GetDataStore(Config.LegacyLiveStoreName):GetAsync(tostring(player.UserId))
		end)
		if not ok then
			return false, "Legacy data read failed"
		end
		if legacy ~= nil then
			if type(legacy) ~= "table" then
				return false, "Invalid legacy data"
			end
			for key in Schema.Template do
				if legacy[key] ~= nil then
					data[key] = legacy[key]
				end
			end
			profile:Reconcile()
		end
	end
	data.legacyMigrationCompleted = true
	return true
end

local function deepCopy(value)
	if type(value) ~= "table" then
		return value
	end
	local result = {}
	for key, child in value do
		result[key] = deepCopy(child)
	end
	return result
end
function Service.Load(player)
	if records[player] or loading[player] then
		return nil
	end
	loading[player] = true
	player:SetAttribute("PetDataReady", false)
	player:SetAttribute("DataSavingEnabled", false)
	local deadline = os.clock() + Config.LoadTimeoutSeconds
	while ProfileStore.DataStoreState == "NotReady" and os.clock() < deadline and player.Parent == Players do
		task.wait(0.1)
	end
	if player.Parent ~= Players or ProfileStore.IsClosing then
		loading[player] = nil
		return nil
	end
	if not isMock and ProfileStore.DataStoreState ~= "Access" then
		loading[player] = nil
		local message = "Persistent DataStore unavailable: " .. ProfileStore.DataStoreState
		warn("[PlayerData] " .. message)
		if isStudio then
			player:Kick("Enable Studio Access to API Services in Game Settings > Security to use Studio saves.")
		else
			report(player, message)
		end
		return nil
	end
	local ok, profile = pcall(function()
		return store:StartSessionAsync(tostring(player.UserId), {
			Cancel = function()
				return player.Parent ~= Players or os.clock() > deadline
			end,
		})
	end)
	loading[player] = nil
	if not ok or not profile then
		report(player, "Profile session failed to load")
		return nil
	end
	if player.Parent ~= Players or ProfileStore.IsClosing then
		profile:EndSession()
		return nil
	end
	local original = deepCopy(profile.Data)
	-- Reject malformed data and migration errors through the same release path.
	local prepared, valid, invalidReason = pcall(function()
		profile:AddUserId(player.UserId)
		profile:Reconcile()
		local migrated, reason = migrateLegacy(player, profile)
		if not migrated then
			return false, reason
		end
		if profile.Data.discovered and type(profile.Data.discoveries) == "table" and #profile.Data.discoveries == 0 then
			table.insert(profile.Data.discoveries, "TestChick")
		end
		if profile.Data.carriedKind ~= "" and profile.Data.carriedPet == false then
			profile.Data.carriedPet = { kind = "TestChick", weight = 1 }
		end
		Schema.MigrateOffline(profile.Data)
		local accepted, validationReason = Schema.Validate(profile.Data)
		if not accepted then
			return false, validationReason
		end
		Schema.MigrateBackpack(profile.Data)
		return Schema.Validate(profile.Data)
	end)
	if not prepared or not valid then
		profile.Data = original
		profile:EndSession()
		report(player, tostring(prepared and invalidReason or valid))
		return nil
	end
	if player.Parent ~= Players or not profile:IsActive() then
		profile:EndSession()
		return nil
	end
	Schema.AccrueOffline(profile.Data, os.time())
	profile.Data.lastSeen = os.time()
	local record = { profile = profile, snapshot = nil, closing = false, lastRequestedSave = -math.huge }
	records[player] = record
	profile.OnSave:Connect(function()
		commitRecord(player, record)
	end)
	profile.OnSessionEnd:Connect(function()
		if records[player] ~= record then
			return
		end
		local wasClosing = record.closing
		record.closing = true
		records[player] = nil
		player:SetAttribute("PetDataReady", false)
		player:SetAttribute("DataSavingEnabled", false)
		ended:Fire(player)
		if not wasClosing and not ProfileStore.IsClosing and player.Parent == Players then
			player:Kick("Your saved progress opened on another server. Please rejoin.")
		end
	end)
	profile.OnAfterSave:Connect(function()
		if player.Parent == Players then
			player:SetAttribute("LastDataSaveAt", os.time())
		end
	end)
	player:SetAttribute("DataSavingEnabled", not isMock)
	player:SetAttribute("DataStoreEnvironment", isStudio and "Studio" or "Live")
	player:SetAttribute("DataStoreMode", Service.Mode)
	return profile.Data
end
function Service.Release(player)
	local record = writable(player)
	if not record then
		return
	end
	commitRecord(player, record)
	record.closing = true
	record.profile:EndSession()
end
ProfileStore.OnError:Connect(function(message, name, key)
	warn("[PlayerData] " .. tostring(name) .. "/" .. tostring(key) .. ": " .. tostring(message))
end)
-- ProfileStore itself handles final saving and waiting at shutdown. OnSave snapshots
-- remain attached until OnSessionEnd, including when another server takes the lock.
return Service
