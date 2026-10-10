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
	{ "RightSideButtins", "PetsBtn", "OpenPets", "Pets" },
	{ "RightSideButtins", "EggsBtn", "Eggs", "Eggs" },
	{ "Counters", "PlussSpeedBtn", "GetSpeed" },
	{ "Counters", "PlussMoneyBtn", "GetCash" },
}

local function build(latest)
	local source = Figma.get("Hud")["Hud V2"]
	local root = Instance.new("Frame")
	root.Name = "FigmaHud"
	root.BackgroundTransparency = 1
	root.Size = UDim2.fromScale(1, 1)
	local groups = {}
	for _, name in { "LeftSideButtons", "RightSideButtins", "Counters" } do
		local group = source[name]:Clone()
		local p, s = group.Position, group.Size
		groups[name] = {
			object = group,
			position = Vector2.new(p.X.Scale * DESIGN.X, p.Y.Scale * DESIGN.Y),
			size = Vector2.new(s.X.Scale * DESIGN.X, s.Y.Scale * DESIGN.Y),
			yScale = p.Y.Scale,
		}
		group.Parent = root
	end
	-- Both counter texts are named after the Figma sample; the upper pair is Speed, the lower Cash.
	for _, label in groups.Counters.object:GetChildren() do
		if label:IsA("TextLabel") then
			local base = label.Position.Y.Scale < 0.3 and "SpeedValue" or "CashValue"
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
	return { root = root, groups = groups, buttons = buttons }
end

local function update(view, p)
	local s = math.min(p.width / DESIGN.X, p.height / DESIGN.Y)
	for name, g in view.groups do
		local o = g.object
		o.Size = UDim2.fromOffset(g.size.X * s, g.size.Y * s)
		if name == "RightSideButtins" then
			o.AnchorPoint = Vector2.new(1, 0)
			o.Position = UDim2.new(1, -(DESIGN.X - g.position.X - g.size.X) * s, g.yScale, 0)
		elseif name == "Counters" then
			o.AnchorPoint = Vector2.new(0, 1)
			o.Position = UDim2.new(0, g.position.X * s, 1, -(DESIGN.Y - g.position.Y - g.size.Y) * s)
		else
			o.Position = UDim2.new(0, g.position.X * s, g.yScale, 0)
		end
	end
	view.groups.RightSideButtins.object.Visible = p.showSides
	view.groups.Counters.object.Visible = p.showResources
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
		local built = build(latest)
		view.current = built
		update(built, latest.current)
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
