-- Run in Studio Server through MCP. Uses an isolated Mock store, never player keys.
local ProfileStore = require(game.ServerStorage.ServerPackages.ProfileStore)
local Schema = require(game.ServerScriptService.PlayerData.Schema)
local Config = require(game.ServerScriptService.PlayerData.Config)
local Http = game:GetService("HttpService")
local function clone(value)
	if type(value) ~= "table" then
		return value
	end
	local result = {}
	for key, child in value do
		result[key] = clone(child)
	end
	return result
end
assert(Config.StoreName(true) ~= Config.StoreName(false), "Store namespaces overlap")
local data = clone(Schema.Template)
assert(Schema.Validate(data), "Template invalid")
data.lastSeen = 1000
data.pets = { { id = "pet-a", equipped = true } }
data.eggs = { { id = "egg-b", x = 0, z = 0, hatchesAt = 1010 } }
Schema.AccrueOffline(data, 1020)
assert(data.offline == 150, "Offline egg earnings incorrect")
data.offline = 0
Schema.AccrueOffline(data, 1000000)
assert(data.offline == Config.OfflineLimitSeconds * 5 + (Config.OfflineLimitSeconds - 10) * 5, "Offline cap incorrect")
local invalid = clone(Schema.Template)
invalid.cash = math.huge
assert(not Schema.Validate(invalid), "Infinity accepted")
invalid.cash = 0 / 0
assert(not Schema.Validate(invalid), "NaN accepted")
invalid = clone(Schema.Template)
invalid.pets = { { id = "duplicate", equipped = true }, { id = "duplicate", equipped = false } }
assert(not Schema.Validate(invalid), "Duplicate IDs accepted")
invalid = clone(Schema.Template)
invalid.schemaVersion += 1
assert(not Schema.Validate(invalid), "Future schema accepted")

local store = ProfileStore.New("PlayerDataQA", Schema.Template).Mock
local key = "QA_" .. Http:GenerateGUID(false)
local profile = assert(store:StartSessionAsync(key), "Mock session failed")
local duplicateAllowed = pcall(function()
	store:StartSessionAsync(key)
end)
assert(not duplicateAllowed, "Duplicate active session accepted")
profile.Data.cash = 777
profile.Data.settings.MusicVolume = nil
profile.Data.carriedKind = "Egg"
local released = false
profile.OnSessionEnd:Connect(function()
	released = true
end)
profile:EndSession()
local deadline = os.clock() + 5
while not released and os.clock() < deadline do
	task.wait(0.05)
end
assert(released and not profile:IsActive(), "Session not released")
local restored = assert(store:StartSessionAsync(key), "Session failed to reload")
restored:Reconcile()
assert(restored.Data.cash == 777 and restored.Data.carriedKind == "Egg", "Mock round trip failed")
assert(restored.Data.settings.MusicVolume == 1, "Reconcile failed")
assert(Schema.Validate(restored.Data), "Restored data invalid")
Http:JSONEncode(restored.Data)
restored:EndSession()
task.wait(0.1)
assert(store:RemoveAsync(key), "Mock test cleanup failed")
return "PASS: namespaces, validation, offline earnings/cap, locking, release/reload, reconciliation, JSON serialization"
