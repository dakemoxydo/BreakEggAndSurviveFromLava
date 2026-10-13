-- Data and Server tabs of the dev panel: the target's saved profile, offline simulation, server health and logs.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LogService = game:GetService("LogService")
local Stats = game:GetService("Stats")
local React = require(ReplicatedStorage.Packages.React)
local Game = require(ReplicatedStorage:WaitForChild("GameConfig"))
local Theme = require(script.Parent.Theme)
local Kit = require(script.Parent.DevKit)
local e = React.createElement
local C = Theme.colors
local GREY = Color3.fromRGB(170, 176, 182)
local LOG_SIZE = 40
local LOG_SHOWN = 20
-- Long profiles are cut so the text box stays responsive.
local JSON_LIMIT = 15000
local DevData = {}
DevData.clientLog = {}

local function ago(at)
	if not at or at <= 0 then
		return "never"
	end
	local seconds = math.max(0, os.time() - at)
	return seconds < 120 and seconds .. "s ago" or math.floor(seconds / 60) .. "m ago"
end
local function duration(seconds)
	local h = math.floor(seconds / 3600)
	return h > 0 and string.format("%dh %02dm", h, math.floor(seconds % 3600 / 60))
		or string.format("%dm %02ds", math.floor(seconds / 60), math.floor(seconds % 60))
end

-- Collects this client's warnings and errors; idempotent.
local started = false
function DevData.start()
	if started then
		return
	end
	started = true
	LogService.MessageOut:Connect(function(message, kind)
		if kind == Enum.MessageType.MessageWarning or kind == Enum.MessageType.MessageError then
			table.insert(DevData.clientLog, {
				at = os.time(),
				error = kind == Enum.MessageType.MessageError,
				text = string.sub(message, 1, 300),
			})
			if #DevData.clientLog > LOG_SIZE then
				table.remove(DevData.clientLog, 1)
			end
		end
	end)
end

-- Wrapped text block on a dark plate; grows with its text.
local function textBlock(name, order, text, color, mono)
	return e("Frame", {
		Name = name,
		LayoutOrder = order,
		BackgroundColor3 = C.ink,
		BackgroundTransparency = 0.25,
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		ZIndex = 6,
	}, {
		Corner = e("UICorner", { CornerRadius = UDim.new(0, Theme.radius) }),
		Padding = e("UIPadding", {
			PaddingLeft = UDim.new(0, 10),
			PaddingRight = UDim.new(0, 10),
			PaddingTop = UDim.new(0, 8),
			PaddingBottom = UDim.new(0, 8),
		}),
		-- Read-only TextBox: the text can be selected and copied.
		Text = e("TextBox", {
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			Text = text,
			Font = mono and Enum.Font.Code or Enum.Font.GothamMedium,
			TextSize = mono and 15 or 16,
			TextColor3 = color or C.white,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top,
			TextWrapped = true,
			MultiLine = true,
			ClearTextOnFocus = false,
			TextEditable = false,
			ZIndex = 7,
		}),
	})
end

-- Newest first; a list of { at, error, text }.
local function logBlock(list)
	local rows = {
		Layout = e("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }),
	}
	local shown = 0
	for i = #list, 1, -1 do
		shown += 1
		if shown > LOG_SHOWN then
			break
		end
		local item = list[i]
		rows["Line" .. shown] = textBlock(
			"Line" .. shown,
			shown,
			os.date("%H:%M:%S", item.at) .. "  " .. item.text,
			item.error and Color3.fromRGB(255, 120, 120) or C.gold
		)
	end
	if shown == 0 then
		rows.Empty = textBlock("Empty", 1, "No warnings or errors.", GREY)
	end
	return e("Frame", {
		LayoutOrder = 1,
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
	}, rows)
end

-- p: ui, target, targetPlayer, me, canEdit, isStudio, profile (GetProfile data or nil), run, refresh, openOffline
function DevData.profile(p)
	local ui, layout = p.ui, p.ui.layout
	local data = p.profile
	local name = p.targetPlayer and p.targetPlayer.Name or "?"
	local content = {}
	content.Save = ui.section("Saved profile", 1, {
		Tiles = Kit.tiles({
			{ "Store", data and data.store or "…" },
			{ "Mode", data and data.mode or "…", data and data.mode == "Mock" and C.gold or nil },
			{ "Last save", ago(p.targetPlayer and p.targetPlayer:GetAttribute("LastDataSaveAt")), C.green },
			{ "Size", data and (Game.number(data.bytes) .. " B · " .. data.keys .. " keys") or "…" },
		}, 1, layout.cell),
		Buttons = ui.grid({
			ui.edit("Save now", C.green, "SaveNow", {}),
			ui.button("Reload", C.blue, p.refresh, { disabled = false }),
		}, 2),
	}, nil, "list", "autosave every 60 s")

	local offline = {}
	for _, hours in { 1, 8, 24, 48 } do
		table.insert(
			offline,
			ui.button("Away " .. hours .. "h", C.gold, function()
				p.run("SimulateOffline", { hours = hours }, p.me and p.openOffline or nil)
			end, { disabled = p.busy or not p.canEdit })
		)
	end
	content.Offline = ui.section(
		"Offline income",
		2,
		ui.cells(offline),
		nil,
		nil,
		p.me and "adds the reward, opens Offline Cash" or "adds to " .. name .. "'s Offline Cash"
	)

	if p.isStudio then
		content.Reset = ui.section(
			"Studio only",
			3,
			ui.cells({ ui.confirm("reset" .. p.target, "Reset profile", "ResetProfile", {}) }),
			layout.wide,
			nil,
			"fresh template, kicks " .. (p.me and "you" or name)
		)
	end

	local text = data and data.text or "Loading…"
	if #text > JSON_LIMIT then
		text = string.sub(text, 1, JSON_LIMIT) .. "\n… cut at " .. Game.number(JSON_LIMIT) .. " characters"
	end
	content.Json = ui.section(
		"Profile data",
		4,
		{ Text = textBlock("Json", 1, text, nil, true) },
		nil,
		"list",
		data and ("schema v" .. tostring(data.version) .. " · as it will be saved") or nil
	)
	return content
end

-- p: ui, server (GetServer data or nil), run, clearClient
function DevData.server(p)
	local ui, layout = p.ui, p.ui.layout
	local s = p.server
	local function value(format, field)
		return s and string.format(format, s[field]) or "…"
	end
	local content = {}
	content.Health = ui.section("Server", 1, {
		Tiles = Kit.tiles({
			{ "Server FPS", value("%.0f", "fps"), s and s.fps < 40 and C.red or C.green },
			{ "Physics FPS", value("%.0f", "physics") },
			{ "Server memory", value("%.0f MB", "memory") },
			{ "Client memory", string.format("%.0f MB", Stats:GetTotalMemoryUsageMb()) },
			{ "Players", s and (s.players .. " / " .. s.maxPlayers) or "…" },
			{ "Uptime", s and duration(s.uptime) or "…" },
			{ "Workspace", s and Game.number(s.instances) .. " inst" or "…" },
			{ "Place ver.", value("%d", "version") },
		}, 1, layout.cell),
	}, nil, "list", s and (s.store .. " · " .. s.mode) or nil)
	content.ServerLog = ui.section("Server warnings and errors", 2, {
		Clear = ui.grid({
			ui.button("Clear", C.muted, function()
				p.run("ClearServerLog")
			end),
		}, 0),
		Rows = logBlock(s and s.log or {}),
	}, nil, "list", "newest first · last " .. LOG_SHOWN)
	content.ClientLog = ui.section("Your client warnings and errors", 3, {
		Clear = ui.grid({
			ui.button("Clear", C.muted, p.clearClient, { disabled = false }),
		}, 0),
		Rows = logBlock(DevData.clientLog),
	}, nil, "list", "since the panel loaded")
	content.Job = e("Frame", { LayoutOrder = 4, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 24) }, {
		Text = Kit.small("JobId " .. (s and s.jobId ~= "" and s.jobId or "studio"), 2, 2, layout.full, 20, GREY),
	})
	return content
end

return DevData
