-- Growing Eggs sidebar from the Figma import (ReplicatedStorage.UITemplates.Eggs, frame "Eggs Window").
-- The collapse tab sits left of the panel; GrowingEgg1 is the row template, cloned per growing egg.
local React = require(game.ReplicatedStorage.Packages.React)
local UI = require(script.Parent.UI)
local Figma = require(script.Parent.FigmaTemplate)
local Assets = require(script.Parent.Assets)
local e = React.createElement
local ROW_STEP = 126

local function offsetOf(object)
	return Vector2.new(object.Position.X.Offset, object.Position.Y.Offset)
end

local function build(latest)
	local source = Figma.get("Eggs")["Eggs Window"]
	local panelAt, tabAt = offsetOf(source.EggsFrame), offsetOf(source.CollapseSidebar)
	local origin = panelAt:Min(tabAt)
	local panel = source.EggsFrame:Clone()
	local tab = source.CollapseSidebar:Clone()
	local root = Instance.new("Frame")
	root.Name = "EggsWindow"
	root.BackgroundTransparency = 1
	local size = Vector2.new(panelAt.X - origin.X + panel.Size.X.Offset, panel.Size.Y.Offset)
	root.Size = UDim2.fromOffset(size.X, size.Y)
	local scale = Instance.new("UIScale")
	scale.Parent = root
	panel.Position = UDim2.fromOffset(panelAt.X - origin.X, panelAt.Y - origin.Y)
	panel.Parent = root
	tab.Position = UDim2.fromOffset(tabAt.X - origin.X, tabAt.Y - origin.Y)
	tab.Parent = root
	local main = panel.MainFrame
	local scroll = Figma.scroll(main.GrowingEggsScroll, Enum.ScrollingDirection.Y)
	local row = scroll.GrowingEgg1
	local rowAt = offsetOf(row)
	row.Parent = nil
	-- The row template leaves the left gap for egg art; fill it with the egg icon.
	if not row:FindFirstChild("Icon") then
		local icon = Instance.new("ImageLabel")
		icon.Name = "Icon"
		icon.BackgroundTransparency = 1
		icon.Position = UDim2.fromOffset(14, 14)
		icon.Size = UDim2.fromOffset(84, 84)
		icon.Image = Assets.egg.image
		icon.ScaleType = Enum.ScaleType.Fit
		icon.ZIndex = 9
		icon.Parent = row
	end
	for _, child in scroll:GetChildren() do
		if string.find(child.Name, "^GrowingEgg") then
			child:Destroy()
		end
	end
	local function reduced()
		return latest.current.reduced
	end
	Figma.studs(root, reduced)
	local grow = panel.Header.GrowAllEggs
	-- The template has no disabled look: a dark veil over Grow All shows it cannot be pressed.
	local veil = Instance.new("Frame")
	veil.Name = "DisabledVeil"
	veil.BackgroundColor3 = Color3.new(0, 0, 0)
	veil.BackgroundTransparency = 0.45
	veil.BorderSizePixel = 0
	veil.Size = UDim2.fromScale(1, 1)
	veil.ZIndex = 99
	local corner = grow:FindFirstChildWhichIsA("UICorner", true)
	if corner then
		corner:Clone().Parent = veil
	end
	veil.Parent = grow
	local buttons = {
		Figma.button(tab, function()
			latest.current.onClose()
		end, function()
			return latest.current.inputEnabled
		end, reduced, "CollapseSidebar"),
		Figma.button(grow, function()
			latest.current.onAction("GrowAllEggs", {})
		end, function()
			local p = latest.current
			return p.inputEnabled and not p.busy and not p.empty and p.missing == 0
		end, reduced, "GrowAllEggs"),
	}
	return {
		root = root,
		scale = scale,
		main = main,
		grow = grow,
		veil = veil,
		scroll = scroll,
		row = row,
		rowAt = rowAt,
		rows = {},
		idles = {},
		reduced = reduced,
		buttons = buttons,
	}
end

local function update(view, p)
	view.scale.Scale = p.scale
	view.scroll.Active = p.inputEnabled
	Figma.setText(view.grow, "Price", "$" .. tostring(p.cost))
	view.veil.Visible = p.busy or p.empty or p.missing > 0
	Figma.setText(
		view.main,
		"Condition",
		p.empty and "No eggs on your base"
			or p.missing > 0 and "Need $" .. tostring(p.missing) .. " more"
			or "Hatch " .. #p.eggs .. " eggs"
	)
	for i, egg in p.eggs do
		local row = view.rows[i]
		if not row then
			row = view.row:Clone()
			row.Name = "GrowingEgg" .. i
			row.Position = UDim2.fromOffset(view.rowAt.X, view.rowAt.Y + (i - 1) * ROW_STEP)
			row.Parent = view.scroll
			Figma.reveal({ row }, p.reduced, i)
			local icon = row:FindFirstChild("Icon")
			view.idles[i] = icon and Figma.idle(icon, "sway", i * 0.9, view.reduced)
			view.rows[i] = row
		end
		Figma.setText(row, "Name", egg.name or "Egg")
		Figma.setText(row, "Status", egg.status or "Growing")
	end
	for i = #p.eggs + 1, #view.rows do
		if view.idles[i] then
			view.idles[i].destroy()
			view.idles[i] = nil
		end
		view.rows[i]:Destroy()
		view.rows[i] = nil
	end
	local bottom = #p.eggs > 0 and view.rowAt.Y + (#p.eggs - 1) * ROW_STEP + view.row.Size.Y.Offset + 4 or 0
	view.scroll.CanvasSize = UDim2.new(1, 0, 0, bottom)
	for _, button in view.buttons do
		button.refresh()
	end
end

-- Design size of the template (panel plus collapse tab) and of the panel alone, for placement before cloning.
local function designSize()
	local source = Figma.get("Eggs")["Eggs Window"]
	local panel, tab = source.EggsFrame, source.CollapseSidebar
	local panelSize = Vector2.new(panel.Size.X.Offset, panel.Size.Y.Offset)
	return Vector2.new(panel.Position.X.Offset - tab.Position.X.Offset + panelSize.X, panelSize.Y), panelSize
end

local function EggsWindow(p)
	local inputEnabled = React.useContext(UI.InputEnabled)
	local reduced = React.useContext(UI.ReducedMotion)
	local host = React.useRef(nil)
	local view = React.useRef(nil)
	local latest = React.useRef(nil)
	local props = table.clone(p)
	props.inputEnabled = inputEnabled
	props.reduced = reduced or p.reduced
	latest.current = props
	React.useEffect(function()
		-- A template that no longer matches the code must not take the whole React tree down.
		local ok, built = pcall(build, latest)
		if not ok then
			warn("Figma template Eggs: " .. tostring(built))
			return
		end
		view.current = built
		update(built, latest.current)
		built.root.Parent = host.current
		return function()
			for _, button in built.buttons do
				button.destroy()
			end
			for _, idle in built.idles do
				idle.destroy()
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
		Name = "EggsSidebar",
		ref = host,
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
	})
end

return { Component = EggsWindow, designSize = designSize }
