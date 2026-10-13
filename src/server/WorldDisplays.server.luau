local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local DataStoreService = game:GetService("DataStoreService")
local Game = require(game.ReplicatedStorage:WaitForChild("GameConfig"))
local DataConfig = require(script.Parent.PlayerData.Config)
local details = workspace:WaitForChild("Map"):WaitForChild("StartZone"):WaitForChild("ReferenceDetails", 30)
if not details then
	return
end
local mock = RunService:IsStudio() and DataConfig.StudioMode == "Mock"
local namespace = RunService:IsStudio() and "Studio" or "Live"
local entries = { { "TopMoney", "Cash" }, { "TopSpeed", "Speed" }, { "TopPlaytime", "Playtime" } }
local rankings, stores, names, snapshots = {}, {}, {}, {}
for _, entry in entries do
	stores[entry[2]] = DataStoreService:GetOrderedDataStore("EggRanks_" .. namespace .. "_" .. entry[2] .. "_v1")
end
local function capture(player)
	if player:GetAttribute("DataSavingEnabled") ~= true then
		return
	end
	local data = { userId = player.UserId, name = player.Name }
	for _, entry in entries do
		data[entry[2]] = math.floor(math.clamp(player:GetAttribute(entry[2]) or 0, 0, 1e18))
	end
	snapshots[player] = data
end
local function write(data)
	if mock or not data then
		return
	end
	for _, entry in entries do
		pcall(function()
			stores[entry[2]]:SetAsync(tostring(data.userId), data[entry[2]])
		end)
	end
end
local function username(id)
	if names[id] then
		return names[id]
	end
	local player = Players:GetPlayerByUserId(id)
	if player then
		names[id] = player.Name
		return player.Name
	end
	local ok, name = pcall(Players.GetNameFromUserIdAsync, Players, id)
	names[id] = ok and name or "Player " .. id
	return names[id]
end
local function refreshGlobal()
	if mock then
		return
	end
	for _, entry in entries do
		local ok, page = pcall(function()
			return stores[entry[2]]:GetSortedAsync(false, 8):GetCurrentPage()
		end)
		if ok then
			local list = {}
			for _, row in page do
				local id = tonumber(row.key)
				if id then
					table.insert(list, { userId = id, name = username(id), value = row.value })
				end
			end
			rankings[entry[2]] = list
		end
	end
end
local function display()
	for _, entry in entries do
		local model = details:FindFirstChild(entry[1])
		if not model then
			continue
		end
		local combined = {}
		for _, item in rankings[entry[2]] or {} do
			combined[item.userId] = table.clone(item)
		end
		for _, player in Players:GetPlayers() do
			if player:GetAttribute("PetDataReady") then
				combined[player.UserId] =
					{ userId = player.UserId, name = player.Name, value = player:GetAttribute(entry[2]) or 0 }
			end
		end
		local list = {}
		for _, item in combined do
			table.insert(list, item)
		end
		table.sort(list, function(a, b)
			return a.value == b.value and a.userId < b.userId or a.value > b.value
		end)
		for i = 1, 8 do
			local item = list[i]
			local row = model.Board.LeaderboardUI.Rows:FindFirstChild("Row" .. i)
			if row then
				row.Text = item
						and ("#" .. i .. "  @" .. item.name .. "\n" .. (entry[2] == "Cash" and "$" or "") .. Game.number(
							item.value
						) .. (entry[2] == "Playtime" and "s" or ""))
					or "#" .. i .. "   —"
			end
		end
	end
end
task.spawn(function()
	refreshGlobal()
	while task.wait(90) do
		for _, player in Players:GetPlayers() do
			capture(player)
			write(snapshots[player])
		end
		refreshGlobal()
	end
end)
Players.PlayerRemoving:Connect(function(player)
	local data = snapshots[player]
	snapshots[player] = nil
	task.spawn(write, data)
end)
-- The Titanic Egg is a surprise: the banner never shows how long is left.
local banner = details and details:FindFirstChild("TitanicBanner")
if banner then
	banner.BannerUI.Countdown.Text = "Can appear at any moment!"
end
local elapsed = 0
RunService.Heartbeat:Connect(function(dt)
	elapsed += dt
	if elapsed < 1 then
		return
	end
	elapsed = 0
	for _, player in Players:GetPlayers() do
		capture(player)
	end
	display()
end)
