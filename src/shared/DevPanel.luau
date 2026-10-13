-- Owner-only test panel. Mounted by DevPanel.client only for players the server marked DevAccess;
-- every command is re-checked by the server (src/server/DevTools.luau).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local GuiService = game:GetService("GuiService")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local React = require(ReplicatedStorage.Packages.React)
local Ripple = require(ReplicatedStorage.Packages.Ripple)
local Game = require(ReplicatedStorage:WaitForChild("GameConfig"))
local Theme = require(script.Parent.Theme)
local UI = require(script.Parent.UI)
local Kit = require(script.Parent.DevKit)
local DevPlayers = require(script.Parent.DevPlayers)
local DevCharacter = require(script.Parent.DevCharacter)
local DevData = require(script.Parent.DevData)
local e = React.createElement
local C = Theme.colors
local player = Players.LocalPlayer
local isStudio = RunService:IsStudio()

local HEADER_H = 60
local STATUS_H = 40
local RAIL_W = 210
local REFRESH = 2
local TABS = { "Players", "Economy", "Pets", "World", "Character", "Data", "Server", "UI" }
local TAB_H = 42
local WINDOWS = {
	"Shop",
	"Index",
	"Settings",
	"Rebirth",
	"Rewards",
	"Offline Cash",
	"Pickaxe Shop",
	"Trails Shop",
	"Merge Pets",
	"Satchel Shop",
}
local VIEWPORTS = {
	{ "Phone", Vector2.new(812, 375) },
	{ "Portrait", Vector2.new(375, 812) },
	{ "Tablet", Vector2.new(1024, 768) },
	{ "1600×900", Vector2.new(1600, 900) },
}

local function roster()
	local list = Players:GetPlayers()
	table.sort(list, function(a, b)
		if (a == player) ~= (b == player) then
			return a == player
		end
		return a.Name < b.Name
	end)
	return list
end

local function DevPanel(props)
	local open, setOpen = React.useState(false)
	local mounted, setMounted = React.useState(false)
	local tab, setTab = React.useState("Players")
	local status, setStatus = React.useState({ text = "Ready", ok = true })
	local busy, setBusy = React.useState(false)
	local armed, setArmed = React.useState(nil)
	local petMode, setPetMode = React.useState("Pet")
	local weight, setWeight = React.useState(1)
	local target, setTarget = React.useState(player.UserId)
	local info, setInfo = React.useState(nil)
	-- Data tab profile dump and Server tab health, fetched only while those tabs are shown.
	local fetched, setFetched = React.useState({})
	local players, setPlayers = React.useState(roster)
	local char, setChar = React.useState(function()
		return table.clone(DevCharacter.state)
	end)
	local inset, setInset = React.useState(GuiService.TopbarInset)
	local viewport, setViewport = React.useState(workspace.CurrentCamera.ViewportSize)
	local stats, setStats = React.useBinding("")
	local progress, setProgress = React.useBinding(0)
	-- nil until dragged: the panel opens centered on screen.
	local drag, setDrag = React.useBinding(nil :: Vector2?)
	local alive = React.useRef(true)
	local openRef = React.useRef(false)
	local targetRef = React.useRef(target)
	local tabRef = React.useRef(tab)
	local fetching = React.useRef(false)
	local refStore = React.useRef({}).current
	openRef.current = open
	targetRef.current = target
	tabRef.current = tab

	local spring = React.useMemo(function()
		return Ripple.createSpring(0, {
			frequency = Theme.motion.openFrequency,
			dampingRatio = 1,
			precision = Theme.motion.transitionPrecision,
			start = true,
		})
	end, {})

	-- Snapshot of the target player (stats, pets, eggs); quiet: no busy state, no status line.
	local fetch = React.useCallback(function()
		local remote = ReplicatedStorage:FindFirstChild("DevAction")
		if not remote or fetching.current then
			return
		end
		fetching.current = true
		local wanted = targetRef.current
		task.spawn(function()
			local ok, result = pcall(remote.InvokeServer, remote, "GetPlayer", { target = wanted })
			fetching.current = false
			if not alive.current or targetRef.current ~= wanted then
				return
			end
			if ok and typeof(result) == "table" and result.success then
				setInfo(result.data)
			elseif wanted ~= player.UserId then
				setTarget(player.UserId)
			end
		end)
	end, {})
	React.useEffect(function()
		setInfo(nil)
		if openRef.current then
			fetch()
		end
	end, { target })

	-- Quiet read-only request; the reply lands in fetched[key].
	local query = React.useCallback(function(name, key)
		local remote = ReplicatedStorage:FindFirstChild("DevAction")
		if not remote then
			return
		end
		task.spawn(function()
			local ok, result = pcall(remote.InvokeServer, remote, name, { target = targetRef.current })
			if alive.current and ok and typeof(result) == "table" and result.success then
				setFetched(function(old)
					local new = table.clone(old)
					new[key] = result.data
					return new
				end)
			end
		end)
	end, {})
	local reloadTab = React.useCallback(function()
		if tabRef.current == "Data" then
			query("GetProfile", "profile")
		elseif tabRef.current == "Server" then
			query("GetServer", "server")
		end
	end, {})
	React.useEffect(function()
		if open then
			reloadTab()
		end
	end, { tab, target, open } :: { any })

	React.useEffect(function()
		local change = spring:onChange(function(value)
			setProgress(value)
			if value <= Theme.motion.closedAt and not openRef.current then
				setMounted(false)
			end
		end)
		local function refreshRoster()
			setPlayers(roster())
		end
		DevCharacter.start()
		DevData.start()
		local connections = {
			DevCharacter.Changed.Event:Connect(setChar),
			GuiService:GetPropertyChangedSignal("TopbarInset"):Connect(function()
				setInset(GuiService.TopbarInset)
			end),
			workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
				setViewport(workspace.CurrentCamera.ViewportSize)
			end),
			Players.PlayerAdded:Connect(refreshRoster),
			Players.PlayerRemoving:Connect(function(left)
				task.defer(refreshRoster)
				if left.UserId == targetRef.current then
					setTarget(player.UserId)
				end
			end),
		}
		local frames, elapsed, sinceFetch = 0, 0, 0
		table.insert(
			connections,
			RunService.Heartbeat:Connect(function(dt)
				frames += 1
				elapsed += dt
				sinceFetch += dt
				if elapsed >= 0.5 then
					setStats(
						string.format(
							"%d FPS · %d ms",
							math.floor(frames / elapsed + 0.5),
							math.floor(player:GetNetworkPing() * 1000 + 0.5)
						)
					)
					frames, elapsed = 0, 0
				end
				if sinceFetch >= REFRESH and openRef.current then
					sinceFetch = 0
					fetch()
					refreshRoster()
					-- The profile dump is not polled: refreshing would drop a text selection.
					if tabRef.current == "Server" then
						reloadTab()
					end
				end
			end)
		)
		return function()
			alive.current = false
			change()
			spring:destroy()
			for _, connection in connections do
				connection:Disconnect()
			end
		end
	end, {})

	local toggle = React.useCallback(function()
		local nextOpen = not openRef.current
		openRef.current = nextOpen
		setOpen(nextOpen)
		setArmed(nil)
		if nextOpen then
			setMounted(true)
			fetch()
		end
		if player:GetAttribute("ReducedMotion") then
			spring:stop()
			spring:setGoal(nextOpen and 1 or 0)
			spring:setPosition(nextOpen and 1 or 0)
			setProgress(nextOpen and 1 or 0)
			if not nextOpen then
				setMounted(false)
			end
		else
			spring:start()
			spring:setGoal(nextOpen and 1 or 0)
		end
	end, {})
	React.useEffect(function()
		local key = UserInputService.InputBegan:Connect(function(input, processed)
			if not processed and input.KeyCode == Enum.KeyCode.F2 then
				toggle()
			end
		end)
		return function()
			key:Disconnect()
		end
	end, {})

	-- Commands act on the selected target unless the payload names one.
	-- after(data) runs once the server confirms success.
	local run = React.useCallback(function(name, payload, after)
		local remote = ReplicatedStorage:FindFirstChild("DevAction")
		if not remote then
			setStatus({ text = "DevAction remote is missing.", ok = false })
			return
		end
		payload = table.clone(payload or {})
		if payload.target == nil then
			payload.target = targetRef.current
		end
		setBusy(true)
		setArmed(nil)
		task.spawn(function()
			local ok, result = pcall(remote.InvokeServer, remote, name, payload)
			if not alive.current then
				return
			end
			setBusy(false)
			if ok and typeof(result) == "table" then
				setStatus({ text = result.message or (result.success and "Done" or "Failed"), ok = result.success })
				if result.success then
					fetch()
					reloadTab()
					if after then
						after(result.data)
					end
				end
			else
				setStatus({ text = "Request failed.", ok = false })
			end
		end)
	end, {})
	local function say(text, ok)
		setStatus({ text = text, ok = ok })
	end

	-- The toggle sits in the top bar right after Roblox's own buttons: never over the chat window below it.
	local barH = math.max(inset.Height, 44)
	local toggleH = math.min(44, barH - 8)
	local toggleButton = e(UI.Button, {
		name = "DevToggle",
		label = "DEV",
		x = inset.Min.X + 4,
		-- Roblox top bar buttons sit 12 px from the top in a 58 px bar: share their baseline.
		y = inset.Min.Y + math.max(0, barH - toggleH - 2),
		w = 64,
		h = toggleH,
		color = open and C.gold or C.purple,
		textSize = 20,
		onClick = toggle,
	})
	if not mounted then
		return e("Frame", { Name = "DevRoot", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) }, {
			Toggle = toggleButton,
		})
	end

	local panelW = math.min(900, viewport.X - 24)
	local panelH = math.clamp(viewport.Y - barH - 24, 360, 720)
	local contentW = panelW - RAIL_W - 36
	local inner = contentW - 34
	local layout = {
		cell = math.floor((inner - 24) / 4),
		third = math.floor((inner - 16) / 3),
		wide = math.floor((inner - 8) / 2),
		full = inner,
	}
	local me = target == player.UserId
	local targetPlayer = Players:GetPlayerByUserId(target)
	local targetName = targetPlayer and targetPlayer.Name or "?"
	local canEdit = isStudio or me
	local ui = Kit.make({
		layout = layout,
		busy = busy,
		canEdit = canEdit,
		armed = armed,
		setArmed = setArmed,
		run = run,
		status = say,
		refStore = refStore,
	})

	local content
	if tab == "Players" then
		content = DevPlayers({
			ui = ui,
			me = player,
			target = target,
			setTarget = function(userId)
				setTarget(userId)
				setArmed(nil)
			end,
			info = info and info.userId == target and info or nil,
			roster = players,
			canEdit = canEdit,
			run = run,
		})
	elseif tab == "Economy" then
		local function quick(list, add)
			local out = {}
			for _, value in list do
				table.insert(out, ui.edit("+" .. Game.number(value), C.green, add, { amount = value }))
			end
			return out
		end
		local cash = quick({ 1e3, 1e6, 1e9, 1e12, 1e15 }, "AddCash")
		table.insert(cash, ui.edit("Zero", C.muted, "SetCash", { amount = 0 }))
		local speed = quick({ 10, 100, 1e3, 1e6 }, "AddSpeed")
		table.insert(speed, ui.edit("Reset 16", C.muted, "SetSpeed", { amount = 16 }))
		local s = info and info.userId == target and info.stats
		content = {
			Cash = ui.section("Cash", 1, {
				Quick = ui.grid(cash, 1),
				Amount = ui.amount("cash", "Amount: 2500, 1.5M, 3T…", {
					{
						"Add",
						C.green,
						function(value)
							run("AddCash", { amount = value })
						end,
					},
					{
						"Set",
						C.gold,
						function(value)
							run("SetCash", { amount = value })
						end,
					},
				}, not canEdit, 2),
			}, nil, "list", s and ("now $" .. Game.number(s.cash)) or nil),
			Speed = ui.section("Speed", 2, {
				Quick = ui.grid(speed, 1),
				Amount = ui.amount("speed", "Speed: 500, 20K, 1M…", {
					{
						"Add",
						C.green,
						function(value)
							run("AddSpeed", { amount = value })
						end,
					},
					{
						"Set",
						C.gold,
						function(value)
							run("SetSpeed", { amount = value })
						end,
					},
				}, not canEdit, 2),
			}, nil, "list", s and ("now " .. Game.number(s.speed)) or nil),
			Progress = ui.section("Progress", 3, {
				Grid = ui.grid({
					ui.edit("+1 Rebirth", C.purple, "AddRebirth"),
					ui.edit("0 Rebirths", C.muted, "ResetRebirths"),
					ui.edit("All gear", C.blue, "UnlockGear"),
					ui.edit("Max base", C.blue, "MaxBase"),
					ui.edit("Rewards ready", C.gold, "ResetRewards"),
				}, 1),
				Offline = ui.amount("offline", "Offline cash to add", {
					{
						"Add offline",
						C.gold,
						function(value)
							run("AddOffline", { amount = value })
						end,
					},
				}, not canEdit, 2),
			}, nil, "list", s and ("rebirths " .. s.rebirths .. "  ·  offline $" .. Game.number(s.offline)) or nil),
		}
	elseif tab == "Pets" then
		local modes = {}
		for _, mode in { "Pet", "Egg" } do
			table.insert(
				modes,
				ui.button(mode, nil, function()
					setPetMode(mode)
				end, { variant = "utility", selected = petMode == mode, disabled = false })
			)
		end
		for _, value in { 1, 10, 100, 1000 } do
			table.insert(
				modes,
				ui.button(Game.number(value) .. " kg", nil, function()
					setWeight(value)
				end, { variant = "utility", selected = weight == value, disabled = false })
			)
		end
		local pets = {}
		for _, pet in Game.Pets do
			table.insert(
				pets,
				ui.button(nil, C.body, function()
					run(petMode == "Egg" and "GiveEgg" or "GivePet", { kind = pet.key, weight = weight })
				end, {
					w = layout.third,
					quiet = true,
					disabled = busy or not canEdit,
					children = {
						Icon = UI.icon(pet.icon, 8, 4, 32, 32),
						Name = UI.text(
							pet.name,
							46,
							2,
							layout.third - 58,
							36,
							18,
							Kit.rarityColor(pet.rarity),
							Enum.TextXAlignment.Left,
							nil,
							{ fit = true }
						),
					},
				})
			)
		end
		content = {
			Give = ui.section("Give as", 1, {
				Modes = ui.grid(modes, 1),
				Custom = ui.amount("weight", "Custom kg, Enter", {
					{
						"Use kg",
						C.blue,
						function(value)
							if value > 0 and value <= 1e6 then
								setWeight(value)
								say("Weight " .. Game.number(value) .. " kg", true)
							end
						end,
					},
				}, false, 2),
			}, nil, "list", "now " .. string.lower(petMode) .. ", " .. Game.number(weight) .. " kg"),
			Collection = ui.section(
				"Collection",
				2,
				ui.cells({
					ui.edit("Discover all", C.blue, "DiscoverAll"),
					ui.edit("Hatch base", C.green, "HatchBaseEggs"),
					ui.confirm("clear", "Clear all", "ClearPets", {}),
				})
			),
			Animals = ui.section(
				"Tap to give a " .. string.lower(petMode),
				3,
				ui.cells(pets),
				layout.third,
				nil,
				"to " .. targetName
			),
		}
	elseif tab == "World" then
		local d = info and info.userId == target and info.dev
		local function switch(label, on, onClick, extra)
			local p = { variant = "utility", selected = on }
			for key, value in extra or {} do
				p[key] = value
			end
			return ui.button(label .. (on and ": ON" or ": OFF"), nil, onClick, p)
		end
		local lava = {
			ui.button("Lava now", C.red, function()
				run("StartLava")
			end),
			ui.button("Stop wave", C.muted, function()
				run("StopLava")
			end),
			switch("Paused", d and d.lavaOff, function()
				run("SetLavaOff", { off = not (d and d.lavaOff) })
			end, { disabled = busy or not d }),
		}
		for _, seconds in { 10, 30, 60, 120 } do
			table.insert(
				lava,
				ui.button("Every " .. seconds .. "s", nil, function()
					run("SetLavaInterval", { seconds = seconds })
				end, { variant = "utility", selected = d and d.lavaInterval == seconds })
			)
		end
		local lavaNote = not d and ""
			or d.lava.active and "wave running"
			or d.lavaOff and "paused"
			or ("next in " .. d.lava.nextIn .. "s")
		local rarities = {
			ui.button("Normal", nil, function()
				run("SetForceRarity", {})
			end, { variant = "utility", selected = d and d.rarity == nil, disabled = busy or not canEdit }),
		}
		for _, rarity in Game.Rarities do
			if rarity.key ~= "Titanic" then
				table.insert(
					rarities,
					ui.button(rarity.key, nil, function()
						run("SetForceRarity", { rarity = rarity.key })
					end, {
						variant = "utility",
						selected = d and d.rarity == rarity.key,
						textColor = rarity.color,
						disabled = busy or not canEdit,
					})
				)
			end
		end
		local lucks = {}
		for _, value in { 1, 10, 100, 1000 } do
			table.insert(
				lucks,
				ui.button("Luck x" .. Game.number(value), nil, function()
					run("SetLuck", { value = value })
				end, {
					variant = "utility",
					selected = d and d.luck == value,
					disabled = busy or not canEdit,
				})
			)
		end
		local function broadcast(kind)
			return function(text)
				run("Broadcast", { text = text, kind = kind })
			end
		end
		content = {
			Lava = ui.section("Lava (whole server)", 1, ui.cells(lava), nil, nil, lavaNote),
			Eggs = ui.section(
				"Field eggs (whole server)",
				2,
				ui.cells({
					ui.button("Titan egg", C.purple, function()
						run("SpawnTitan")
					end),
					ui.button("Refill HP", C.green, function()
						run("RefillEggs")
					end),
				})
			),
			Cheats = ui.section(
				"Cheats",
				3,
				ui.cells({
					switch("Immune", d and d.immune, function()
						run("SetLavaImmune", { on = not (d and d.immune) })
					end, { disabled = busy or not d or not canEdit }),
					switch("One-hit", d and d.oneHit, function()
						run("SetOneHit", { on = not (d and d.oneHit) })
					end, { disabled = busy or not d or not canEdit }),
				}),
				nil,
				nil,
				"for " .. targetName
			),
			Hatch = ui.section("Hatch result", 4, {
				Rarity = ui.grid(rarities, 1),
				Luck = ui.grid(lucks, 2),
			}, nil, "list", "eggs " .. targetName .. " breaks"),
			Broadcast = ui.section("Broadcast to all players", 5, {
				Row = ui.message("broadcast", "Message (filtered by Roblox)", {
					{ "Info", C.muted, broadcast(nil) },
					{ "Danger", C.red, broadcast("danger") },
					{ "Event", C.gold, broadcast("event") },
				}, 1),
			}, nil, "list"),
			Notices = ui.section(
				"Test toasts",
				6,
				ui.cells({
					ui.button("Info", C.muted, function()
						run("Notice", {})
					end),
					ui.button("Danger", C.red, function()
						run("Notice", { kind = "danger" })
					end),
					ui.button("Event", C.gold, function()
						run("Notice", { kind = "event" })
					end),
				}),
				nil,
				nil,
				"to " .. targetName
			),
		}
	elseif tab == "Data" then
		content = DevData.profile({
			ui = ui,
			target = target,
			targetPlayer = targetPlayer,
			me = me,
			busy = busy,
			canEdit = canEdit,
			isStudio = isStudio,
			profile = fetched.profile and fetched.profile.userId == target and fetched.profile or nil,
			run = run,
			refresh = function()
				query("GetProfile", "profile")
				say("Profile reloaded", true)
			end,
			-- Show never toggles an open window shut; the panel closes so the window is visible.
			openOffline = function()
				if props.controller then
					props.controller:Fire("Show", "Offline Cash")
				end
				if openRef.current then
					toggle()
				end
			end,
		})
	elseif tab == "Server" then
		content = DevData.server({
			ui = ui,
			server = fetched.server,
			run = run,
			clearClient = function()
				table.clear(DevData.clientLog)
				setFetched(table.clone(fetched))
				say("Client log cleared", true)
			end,
		})
	elseif tab == "Character" then
		local function switch(label, on, onClick)
			return ui.button(label .. (on and ": ON" or ": OFF"), nil, onClick, {
				variant = "utility",
				selected = on,
				disabled = false,
			})
		end
		local function speeds(list, current, set)
			local out = {}
			for _, value in list do
				table.insert(
					out,
					ui.button(tostring(value), nil, function()
						set(value)
					end, { variant = "utility", selected = current == value, disabled = false })
				)
			end
			return out
		end
		local help = "WASD move · E/Space up · Q/Ctrl down · Shift ×3"
		content = {
			Movement = ui.section("Movement", 1, {
				Toggles = ui.grid({
					switch("Fly", char.fly, function()
						DevCharacter.setFly(not char.fly)
					end),
					switch("Noclip", char.noclip, function()
						DevCharacter.setNoclip(not char.noclip)
					end),
				}, 1),
				Speed = ui.grid(speeds({ 50, 100, 250, 500 }, char.flySpeed, DevCharacter.setFlySpeed), 2),
			}, nil, "list", "you only · fly speed in studs/s"),
			Camera = ui.section("Free camera", 2, {
				Toggles = ui.grid({
					switch("Freecam", char.freecam, function()
						DevCharacter.setFreecam(not char.freecam)
					end),
				}, 1),
				Speed = ui.grid(speeds({ 20, 60, 150, 400 }, char.camSpeed, DevCharacter.setCamSpeed), 2),
			}, nil, "list", "hold right mouse to look"),
			Help = e("Frame", { LayoutOrder = 3, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 24) }, {
				Text = Kit.small(help, 2, 2, layout.full, 20, Color3.fromRGB(170, 176, 182)),
			}),
		}
	else
		local windows = {}
		for _, name in WINDOWS do
			table.insert(
				windows,
				ui.button(name, C.blue, function()
					if props.controller then
						props.controller:Fire("Open", name)
						say("Opened " .. name, true)
					end
				end, { disabled = false })
			)
		end
		content = { Windows = ui.section("Open window", 1, ui.cells(windows)) }
		if isStudio and props.controller then
			local sizes = {}
			for _, item in VIEWPORTS do
				table.insert(
					sizes,
					ui.button(item[1], C.muted, function()
						props.controller:Fire("PreviewViewport", item[2])
						say("Game UI laid out for " .. item[1], true)
					end, { disabled = false })
				)
			end
			table.insert(
				sizes,
				ui.button("Real size", C.green, function()
					props.controller:Fire("PreviewViewport", workspace.CurrentCamera.ViewportSize)
					say("Game UI uses the real viewport", true)
				end, { disabled = false })
			)
			content.Viewport = ui.section("Studio: preview layout", 2, ui.cells(sizes))
		end
	end
	content.List = e("UIListLayout", { Padding = UDim.new(0, 14), SortOrder = Enum.SortOrder.LayoutOrder })
	content.Padding = e("UIPadding", {
		PaddingLeft = UDim.new(0, 12),
		PaddingRight = UDim.new(0, 12),
		PaddingTop = UDim.new(0, 8),
		PaddingBottom = UDim.new(0, 14),
	})

	-- Left rail: who the commands act on, then the tabs.
	local rail = {
		Target = e(UI.Button, {
			name = "TargetCard",
			x = 12,
			y = HEADER_H,
			w = RAIL_W,
			h = 84,
			variant = "utility",
			selected = tab == "Players",
			onClick = function()
				setTab("Players")
				setArmed(nil)
			end,
			children = {
				Avatar = Kit.avatar(target, 56, 10, 14),
				Label = Kit.small(me and "TARGET · YOU" or "TARGET", 76, 10, RAIL_W - 86, 16, C.gold),
				Name = UI.text(
					targetPlayer and targetPlayer.DisplayName or "?",
					76,
					26,
					RAIL_W - 86,
					30,
					22,
					C.white,
					Enum.TextXAlignment.Left,
					nil,
					{ fit = true }
				),
				Handle = Kit.small(
					canEdit and "@" .. targetName or "read-only (live)",
					76,
					58,
					RAIL_W - 86,
					16,
					canEdit and C.white or C.red
				),
			},
		}),
		Hint = Kit.small(
			"F2 toggles · drag the header",
			16,
			panelH - STATUS_H - 4,
			RAIL_W,
			20,
			Color3.fromRGB(170, 176, 182)
		),
	}
	for i, name in TABS do
		rail["Tab" .. name] = e(UI.Button, {
			name = "Tab" .. name,
			label = name,
			x = 12,
			y = HEADER_H + 96 + (i - 1) * (TAB_H + 6),
			w = RAIL_W,
			h = TAB_H,
			variant = "utility",
			selected = tab == name,
			textSize = 20,
			onClick = function()
				setTab(name)
				setArmed(nil)
			end,
		})
	end

	-- Opens centered on screen, below the top bar; dragging the header moves it from there.
	local defaultPos = Vector2.new(
		math.max(0, math.floor((viewport.X - panelW) / 2)),
		math.max(barH + 8, math.floor((viewport.Y - panelH) / 2))
	)
	local env = (player:GetAttribute("DataStoreEnvironment") or "?")
		.. " · "
		.. (player:GetAttribute("DataStoreMode") or "?")
	local panel = e("CanvasGroup", {
		Name = "DevPanelWindow",
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(panelW, panelH),
		Position = React.joinBindings({ drag = drag, t = progress }):map(function(v)
			local at = v.drag or defaultPos
			return UDim2.fromOffset(at.X, at.Y + math.floor((1 - v.t) * 12 + 0.5))
		end),
		GroupTransparency = progress:map(function(t)
			return 1 - math.clamp(t, 0, 1)
		end),
		ZIndex = 2,
	}, {
		Input = e(UI.InputEnabled.Provider, { value = open }, {
			Body = e(UI.Surface, { w = panelW, h = panelH, color = C.body, quiet = true, z = 1 }),
			Header = e("TextButton", {
				Name = "DragHandle",
				Text = "",
				AutoButtonColor = false,
				Selectable = false,
				BackgroundTransparency = 1,
				Size = UDim2.fromOffset(panelW - 64, HEADER_H),
				ZIndex = 5,
				[React.Event.InputBegan] = function(_, input)
					if
						input.UserInputType ~= Enum.UserInputType.MouseButton1
						and input.UserInputType ~= Enum.UserInputType.Touch
					then
						return
					end
					local start = input.Position
					local origin = drag:getValue() or defaultPos
					local moved, ended
					moved = UserInputService.InputChanged:Connect(function(change)
						if change.UserInputType == Enum.UserInputType.MouseMovement or change == input then
							local delta = change.Position - start
							local camera = workspace.CurrentCamera.ViewportSize
							setDrag(
								Vector2.new(
									math.clamp(origin.X + delta.X, 0, camera.X - panelW),
									math.clamp(origin.Y + delta.Y, 0, camera.Y - HEADER_H)
								)
							)
						end
					end)
					ended = UserInputService.InputEnded:Connect(function(done)
						if done == input or done.UserInputType == Enum.UserInputType.MouseButton1 then
							moved:Disconnect()
							ended:Disconnect()
						end
					end)
				end,
			}, {
				Title = UI.text("DEV PANEL", 18, 12, 200, 38, 28, C.white, Enum.TextXAlignment.Left),
				Env = Kit.small(env, RAIL_W + 24, 12, 260, 18, C.gold),
				Stats = e("TextLabel", {
					BackgroundTransparency = 1,
					Position = UDim2.fromOffset(RAIL_W + 24, 32),
					Size = UDim2.fromOffset(260, 18),
					Text = stats,
					Font = Enum.Font.GothamBold,
					TextSize = 15,
					TextColor3 = C.white,
					TextXAlignment = Enum.TextXAlignment.Left,
					ZIndex = 8,
				}, { Outline = e("UIStroke", { Color = C.ink, Thickness = 1.5 }) }),
			}),
			Close = e(UI.Button, {
				name = "CloseDevPanel",
				label = "X",
				x = panelW - 58,
				y = 10,
				w = 46,
				h = 42,
				color = C.red,
				textSize = 22,
				z = 6,
				onClick = toggle,
			}),
			Rail = e("Frame", {
				Name = "Rail",
				BackgroundTransparency = 1,
				Size = UDim2.fromScale(1, 1),
				ZIndex = 5,
			}, rail),
			Area = e("Frame", {
				Name = "ContentArea",
				Position = UDim2.fromOffset(RAIL_W + 24, HEADER_H),
				Size = UDim2.fromOffset(contentW, panelH - HEADER_H - STATUS_H - 8),
				BackgroundColor3 = C.ink,
				BackgroundTransparency = 0.45,
				ZIndex = 5,
			}, {
				Corner = e("UICorner", { CornerRadius = UDim.new(0, Theme.radius) }),
				Scroll = e("ScrollingFrame", {
					Name = "DevScroll",
					BackgroundTransparency = 1,
					BorderSizePixel = 0,
					Size = UDim2.fromScale(1, 1),
					CanvasSize = UDim2.new(),
					AutomaticCanvasSize = Enum.AutomaticSize.Y,
					ScrollBarThickness = 6,
					ScrollBarImageColor3 = C.white,
					ScrollingDirection = Enum.ScrollingDirection.Y,
					ZIndex = 5,
				}, content),
			}),
			Status = UI.text(
				status.text,
				RAIL_W + 28,
				panelH - STATUS_H - 4,
				contentW - 8,
				STATUS_H,
				18,
				busy and C.white or (status.ok and C.green or C.red),
				Enum.TextXAlignment.Left,
				nil,
				{ fit = true }
			),
		}),
	})

	return e("Frame", { Name = "DevRoot", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) }, {
		Toggle = toggleButton,
		Panel = panel,
	})
end

return DevPanel
