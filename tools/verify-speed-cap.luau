-- Edit-only fixture: executes the actual treadmill heartbeat with isolated data.
local source = game.ServerScriptService.TreadmillTraining.Source
local function evaluate(code, variables)
	local chunk = assert(loadstring(code))
	setfenv(chunk, setmetatable(variables, { __index = getfenv() }))
	return chunk()
end
local Game = evaluate(game.ReplicatedStorage.GameConfig.Source, {})
local first = assert(source:find("local function speedValue", 1, true))
local last = assert(source:find("local function detach", first, true))
local speedValue = evaluate(source:sub(first, last - 1) .. "\nreturn speedValue", { Game = Game })
local attrs = { Speed = Game.MaxSpeed - 128, Multiplier = 1000, PetDataReady = true }
local player = {
	Character = {},
	GetAttribute = function(_, key) return attrs[key] end,
	SetAttribute = function(_, key, value) attrs[key] = value end,
}
local session = {
	character = player.Character,
	root = { Parent = true },
	humanoid = { Health = 100 },
	station = {
		IsDescendantOf = function() return true end,
		GetAttribute = function() return 1000 end,
	},
	elapsed = 0,
	walkSpeed = 16,
}
local heartbeat
local start = assert(source:find("local scanElapsed = 0", 1, true))
evaluate(source:sub(start), {
	active = { [player] = session },
	cooldown = {}, occupied = {},
	Game = Game, Config = { ScanInterval = 10, SpeedPerSecond = 1 },
	speedValue = speedValue,
	RunService = { Heartbeat = { Connect = function(_, callback) heartbeat = callback end } },
	Players = { GetPlayers = function() return {} end },
	detach = function() error("Unexpected detach") end,
})
heartbeat(1)
assert(attrs.Speed == Game.MaxSpeed, "Training exceeds the saved speed limit")
heartbeat(1)
assert(attrs.Speed == Game.MaxSpeed, "Capped speed keeps growing")
attrs.Speed = Game.MaxSpeed + 1024
assert(speedValue(player, 16) == Game.MaxSpeed, "Existing overshoot is not clamped")
attrs.Speed = 0 / 0
assert(speedValue(player, 16) == 16, "Invalid speed fallback changed")
return "PASS: treadmill saturation, repeated tick, existing overshoot, NaN fallback"
