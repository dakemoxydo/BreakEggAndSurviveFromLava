-- Pets sidebar from the Figma import (ReplicatedStorage.UITemplates.Pets, frame "Pets Window").
-- The collapse tab sits left of the panel, Equip Best below it; InventoryPet1 is the row template.
local React = require(game.ReplicatedStorage.Packages.React)
local Game = require(game.ReplicatedStorage.GameConfig)
local UI = require(script.Parent.UI)
local Theme = require(script.Parent.Theme)
local Config = require(script.Parent.Config)
local Assets = require(script.Parent.Assets)
local Figma = require(script.Parent.FigmaTemplate)
local e = React.createElement
local ROW_STEP = 126
local NEED_COLOR = Color3.new(1, 1, 1)
-- Fallback icon box for imports where the row art still holds the placeholder paw (no separate Icon layer).
local ICON = { x = 14, y = 14, size = 84 }

local function offsetOf(object)
	return Vector2.new(object.Position.X.Offset, object.Position.Y.Offset)
end

-- Properties that differ between the Equip and Unequip button art; the layers are the same.
local PAINT = {
	Frame = { "BackgroundColor3" },
	ImageLabel = { "Image", "ImageColor3" },
	UIGradient = { "Color" },
	UIStroke = { "Color" },
}

-- Copies the art of one template button state onto a button, layer by layer (matched by name and class).
local function paint(target, source)
	for _, from in source:GetChildren() do
		local to = target:FindFirstChild(from.Name)
		if to and to.ClassName == from.ClassName then
			for _, key in PAINT[from.ClassName] or {} do
				to[key] = from[key]
			end
			paint(to, from)
		end
	end
end

-- Bounding box of the template parts, in Figma units.
local function bounds(source)
	local min, max = Vector2.new(math.huge, math.huge), Vector2.new(-math.huge, -math.huge)
	for _, name in { "PetsFrame", "CollapseSidebar", "EquipBestPets" } do
		local o = source[name]
		local at = offsetOf(o)
		min = min:Min(at)
		max = max:Max(at + Vector2.new(o.Size.X.Offset, o.Size.Y.Offset))
	end
	return min, max
end

local function build(latest)
	local source = Figma.get("Pets")["Pets Window"]
	local origin, corner = bounds(source)
	local root = Instance.new("Frame")
	root.Name = "PetsWindow"
	root.BackgroundTransparency = 1
	root.Size = UDim2.fromOffset(corner.X - origin.X, corner.Y - origin.Y)
	local scale = Instance.new("UIScale")
	scale.Parent = root
	local parts = {}
	for _, name in { "PetsFrame", "CollapseSidebar", "EquipBestPets" } do
		local part = source[name]:Clone()
		local at = offsetOf(part) - origin
		part.Position = UDim2.fromOffset(at.X, at.Y)
		part.Parent = root
		parts[name] = part
	end
	local panel = parts.PetsFrame
	local main, header = panel.MainFrame, panel.Header
	Figma.nameTexts(main, { "Condition" })
	Figma.nameTexts(header, { "Title" })
	Figma.nameTexts(header.AddPetSlot, { "Label" })
	Figma.nameTexts(parts.EquipBestPets, { "Label" })
	Figma.nameTexts(parts.CollapseSidebar, { "Label" })
	local scroll = Figma.scroll(main.PetsInventoryScroll, Enum.ScrollingDirection.Y)
	local row = scroll.InventoryPet1
	local rowAt = offsetOf(row)
	-- Both button arts come from the template rows: red Unequip (row 1) and green Equip (row 3).
	local unequipArt = row:FindFirstChild("PetAction1"):Clone()
	local equipRow = scroll:FindFirstChild("InventoryPet3")
	local equipArt = equipRow and equipRow:FindFirstChild("PetAction3"):Clone() or unequipArt
	row.Parent = nil
	for _, child in scroll:GetChildren() do
		if string.find(child.Name, "^InventoryPet") then
			child:Destroy()
		end
	end
	Figma.nameTexts(row, { "Name", "Income" })
	local action = row.PetAction1
	action.Name = "PetActionFrame"
	Figma.nameTexts(action, { "Label" })
	-- The template's Icon layer (placeholder paw) shows the pet's image; older imports get a box on top.
	local slot = row:FindFirstChild("Icon")
	local image = slot and slot:FindFirstChildWhichIsA("ImageLabel")
	if image then
		image.Name = "PetImage"
	else
		image = Instance.new("ImageLabel")
		image.Name = "Icon"
		image.BackgroundTransparency = 1
		image.Position = UDim2.fromOffset(ICON.x, ICON.y)
		image.Size = UDim2.fromOffset(ICON.size, ICON.size)
		image.ZIndex = 9
		image.Parent = row
	end
	image.ScaleType = Enum.ScaleType.Fit
	local function reduced()
		return latest.current.reduced
	end
	Figma.studs(root, reduced)
	local function ready()
		return latest.current.inputEnabled and not latest.current.busy
	end
	local buttons = {
		Figma.button(parts.CollapseSidebar, function()
			latest.current.onClose()
		end, function()
			return latest.current.inputEnabled
		end, reduced, "CollapseSidebar"),
		Figma.button(header.AddPetSlot, function()
			latest.current.onAction("AddPetSlot", {})
		end, function()
			local p = latest.current
			return ready() and not p.maximum and p.missing == 0
		end, reduced, "AddPetSlot"),
		Figma.button(parts.EquipBestPets, function()
			latest.current.onAction("EquipBestPets", {})
		end, ready, reduced, "EquipBestPets"),
	}
	return {
		root = root,
		scale = scale,
		main = main,
		header = header,
		scroll = scroll,
		row = row,
		rowAt = rowAt,
		art = { equip = equipArt, unequip = unequipArt },
		rows = {},
		buttons = buttons,
		ready = ready,
		reduced = reduced,
		latest = latest,
	}
end

local function addRow(view, i)
	local row = view.row:Clone()
	row.Name = "InventoryPet" .. i
	row.Position = UDim2.fromOffset(view.rowAt.X, view.rowAt.Y + (i - 1) * ROW_STEP)
	row.Parent = view.scroll
	Figma.reveal({ row }, view.reduced(), i)
	local state = { row = row, action = row.PetActionFrame }
	state.button = Figma.button(state.action, function()
		local pet = state.pet
		view.latest.current.onAction(pet.equipped and "UnequipPet" or "EquipPet", { pet = pet.id or pet.name })
	end, view.ready, view.reduced, "PetAction" .. i)
	state.idle = Figma.idle(row.Icon, "sway", i * 0.9, view.reduced)
	return state
end

local function update(view, p)
	view.scale.Scale = p.scale
	view.scroll.Active = p.inputEnabled
	Figma.setText(view.header, "Title", string.upper(p.equipped .. "/" .. p.capacity .. " Active"))
	Figma.setText(
		view.header.AddPetSlot,
		"Label",
		p.maximum and "MAX SLOTS" or "+1 SLOT [$" .. Game.number(p.slotCost) .. "]"
	)
	Figma.setText(
		view.main,
		"Condition",
		p.maximum and "Maximum capacity reached"
			or p.missing > 0 and "Need $" .. Game.number(p.missing) .. " more"
			or "Balance: $" .. Game.number(p.cash),
		p.missing > 0 and not p.maximum and NEED_COLOR or Theme.colors.green
	)
	for i, pet in p.pets do
		local state = view.rows[i]
		if not state then
			state = addRow(view, i)
			view.rows[i] = state
		end
		state.pet = pet
		Figma.setText(state.row, "Name", pet.name, Theme.colors[Config.RarityColor[pet.rarity] or "white"])
		Figma.setText(state.row, "Income", "($" .. Game.number(pet.income) .. "/s)")
		Figma.setText(state.action, "Label", pet.equipped and "UNEQUIP" or "EQUIP")
		paint(state.action, pet.equipped and view.art.unequip or view.art.equip)
		local asset = Assets[pet.icon]
		local icon = state.row.Icon:FindFirstChild("PetImage") or state.row.Icon
		icon.Image = asset and asset.image or ""
		icon.ImageRectOffset = asset and asset.offset or Vector2.zero
		icon.ImageRectSize = asset and asset.rect or Vector2.zero
		state.button.refresh()
	end
	for i = #p.pets + 1, #view.rows do
		view.rows[i].button.destroy()
		view.rows[i].idle.destroy()
		view.rows[i].row:Destroy()
		view.rows[i] = nil
	end
	local bottom = #p.pets > 0 and view.rowAt.Y + (#p.pets - 1) * ROW_STEP + view.row.Size.Y.Offset + 4 or 0
	view.scroll.CanvasSize = UDim2.new(1, 0, 0, bottom)
	for _, button in view.buttons do
		button.refresh()
	end
end

-- Template size in Figma units: whole window (tab, panel, Equip Best) and the panel alone.
local function designSize()
	local source = Figma.get("Pets")["Pets Window"]
	local origin, corner = bounds(source)
	local panel = source.PetsFrame
	return corner - origin, Vector2.new(panel.Size.X.Offset, panel.Size.Y.Offset)
end

local function PetsWindow(p)
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
			warn("Figma template Pets: " .. tostring(built))
			return
		end
		view.current = built
		update(built, latest.current)
		built.root.Parent = host.current
		return function()
			for _, button in built.buttons do
				button.destroy()
			end
			for _, state in built.rows do
				state.button.destroy()
				state.idle.destroy()
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
		Name = "PetsSidebar",
		ref = host,
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
	})
end

return { Component = PetsWindow, designSize = designSize }
