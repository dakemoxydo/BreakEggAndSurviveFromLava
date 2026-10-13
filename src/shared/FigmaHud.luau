-- Wide-screen HUD from the Figma import (ReplicatedStorage.UITemplates.Hud, frame "Hud V2").
-- Groups keep their Figma size ratio and stick to their screen edge instead of the 16:9 frame.
local React = require(game.ReplicatedStorage.Packages.React)
local UI = require(script.Parent.UI)
local Figma = require(script.Parent.FigmaTemplate)
local e = React.createElement
local DESIGN = Vector2.new(1920, 1080)
-- Figma button frame -> { hit button name, prop callback, onOpen screen }.
local BUTTONS = {
	{ "LeftSideButtons", "ShopBtn", "OpenShop", "Shop" },
	{ "LeftSideButtons", "Index", "OpenIndex", "Index" },
	{ "LeftSideButtons", "Settings", "OpenSettings", "Settings" },
	{ "LeftSideButtons", "Rewards", "OpenRewards", "Rewards" },
	{ "LeftSideButtons", "Rebirth", "OpenRebirth", "Rebirth" },
	{ "RightSideButtins", "PetsBtn", "OpenPets", "Pets" },
	{ "RightSideButtins", "EggsBtn", "Eggs", "Eggs" },
	{ "Counters", "PlussSpeedBtn", "GetSpeed" },
	{ "Counters", "PlussMoneyBtn", "GetCash" },
}

local function build(latest)
	local source = Figma.get("Hud")["Hud V2"]
	-- The root works in Figma pixels: one UIScale fits the design, groups keep their design offsets.
	local root = Instance.new("Frame")
	root.Name = "FigmaHud"
	root.BackgroundTransparency = 1
	local scale = Instance.new("UIScale")
	scale.Parent = root
	local groups = {}
	for _, name in { "LeftSideButtons", "RightSideButtins", "Counters" } do
		local group = source[name]:Clone()
		local p, s = group.Position, group.Size
		local position = Vector2.new(p.X.Scale * DESIGN.X + p.X.Offset, p.Y.Scale * DESIGN.Y + p.Y.Offset)
		local size = Vector2.new(s.X.Scale * DESIGN.X + s.X.Offset, s.Y.Scale * DESIGN.Y + s.Y.Offset)
		group.Size = UDim2.fromOffset(size.X, size.Y)
		groups[name] = { object = group, position = position, size = size }
		group.Parent = root
	end
	-- The "+" buttons start inside the centered value text box (x 80..304); move them past its right edge.
	for _, name in { "PlussSpeedBtn", "PlussMoneyBtn" } do
		local plus = groups.Counters.object[name]
		plus.Position = UDim2.new(0, 312, plus.Position.Y.Scale, plus.Position.Y.Offset)
	end
	-- Both counter texts are named after the Figma sample; the upper pair is Speed, the lower Cash.
	for _, label in groups.Counters.object:GetChildren() do
		if label:IsA("TextLabel") then
			local y = label.Position.Y.Scale * groups.Counters.size.Y + label.Position.Y.Offset
			local base = y < 0.3 * groups.Counters.size.Y and "SpeedValue" or "CashValue"
			label.Name = string.find(label.Name, "_Shadow$") and base .. "_Shadow" or base
		end
	end
	local function reduced()
		return latest.current.reduced
	end
	local function always()
		return true
	end
	local buttons = {}
	for _, spec in BUTTONS do
		local group, frame, name, screen = table.unpack(spec)
		table.insert(
			buttons,
			Figma.button(groups[group].object[frame], function()
				if screen then
					latest.current.onOpen(screen)
				elseif name == "GetSpeed" then
					latest.current.onSpeedPlus()
				else
					latest.current.onCashPlus()
				end
			end, always, reduced, name)
		)
	end
	-- Mask decor of every HUD button:
	-- sunbursts turn, Shop's cash/energy pictures fall, Shine stripes sweep in turn.
	local i = 0
	for _, group in groups do
		for _, mask in group.object:GetDescendants() do
			if mask.Name == "Mask" then
				if mask:IsA("Frame") then
					mask.ClipsDescendants = true
				end
				i += 1
				for _, item in mask:GetChildren() do
					local kind = item.Name == "SunBurst" and "spin"
						or (string.find(item.Name, "^Cash%d") or string.find(item.Name, "^Energy%d")) and "fall"
						or string.find(item.Name, "^Shine%d") and "shine"
					if kind then
						table.insert(buttons, Figma.idle(item, kind, i * 0.55, reduced))
					end
				end
			end
		end
	end
	return { root = root, scale = scale, groups = groups, buttons = buttons }
end

local function update(view, p)
	local s = math.min(p.width / DESIGN.X, p.height / DESIGN.Y)
	view.scale.Scale = s
	view.root.Size = UDim2.fromOffset(p.width / s, p.height / s)
	-- Side columns are centered vertically; the left one together with the row App puts under it
	-- (p.leftReserve, App units).
	local rootH = p.height / s
	for name, g in view.groups do
		local o = g.object
		if name == "RightSideButtins" then
			o.AnchorPoint = Vector2.new(1, 0)
			o.Position = UDim2.new(1, -(DESIGN.X - g.position.X - g.size.X), 0, (rootH - g.size.Y) / 2)
		elseif name == "Counters" then
			o.AnchorPoint = Vector2.new(0, 1)
			o.Position = UDim2.new(0, g.position.X, 1, -(DESIGN.Y - g.position.Y - g.size.Y))
		else
			o.Position = UDim2.fromOffset(g.position.X, (rootH - g.size.Y - (p.leftReserve or 0) / s) / 2)
		end
	end
	-- Groups pop back in when they reappear (sidebar or inventory closed), growing from their screen edge.
	for name, shown in { RightSideButtins = p.showSides, Counters = p.showResources } do
		local object = view.groups[name].object
		if shown and not object.Visible then
			Figma.reveal({ object }, p.reduced, 1, true)
		end
		object.Visible = shown
	end
	local counters = view.groups.Counters.object
	Figma.setText(counters, "SpeedValue", p.speed)
	Figma.setText(counters, "CashValue", p.cash)
end

local function FigmaHud(p)
	local reduced = React.useContext(UI.ReducedMotion)
	local host = React.useRef(nil)
	local view = React.useRef(nil)
	local latest = React.useRef(nil)
	local props = table.clone(p)
	props.reduced = reduced or p.reduced
	latest.current = props
	React.useEffect(function()
		-- A template that no longer matches the code must not take the whole React tree down.
		local ok, built = pcall(build, latest)
		if not ok then
			warn("Figma template Hud: " .. tostring(built))
			return
		end
		view.current = built
		update(built, latest.current)
		local groups = built.groups
		Figma.reveal(
			{ groups.LeftSideButtons.object, groups.RightSideButtins.object, groups.Counters.object },
			latest.current.reduced,
			1,
			true
		)
		built.root.Parent = host.current
		return function()
			for _, button in built.buttons do
				button.destroy()
			end
			built.root:Destroy()
			view.current = nil
		end
	end, {})
	React.useEffect(function()
		if view.current then
			update(view.current, latest.current)
		end
	end)
	return e("Frame", {
		Name = "FigmaHudHost",
		ref = host,
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(p.width, p.height),
	})
end

return FigmaHud
