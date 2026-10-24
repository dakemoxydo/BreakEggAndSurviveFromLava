local RS = game:GetService("ReplicatedStorage")
local React = require(RS.Packages.React)
local UI = require(script.Parent.UI)
local Config = require(script.Parent.Config)
local Figma = require(script.Parent.FigmaTemplate)
local Theme = require(script.Parent.Theme)
local Visuals = require(RS:WaitForChild("PetVisuals"))
local e = React.createElement
local DESIGN = Vector2.new(1240, 666)

local function preview(parent, pet)
	local old = parent:FindFirstChild("PetPreview")
	if old then
		old:Destroy()
	end
	local icon = parent:FindFirstChild("Icon")
	if icon then
		icon.Visible = false
	end
	local viewport = Instance.new("ViewportFrame")
	viewport.Name = "PetPreview"
	viewport.BackgroundTransparency = 1
	viewport.Position = icon and icon.Position or UDim2.fromOffset(8, 8)
	viewport.Size = icon and icon.Size or UDim2.new(1, -16, 1, -16)
	viewport.ZIndex = icon and icon.ZIndex or 8
	viewport.Ambient = Color3.fromRGB(200, 200, 210)
	viewport.LightDirection = Vector3.new(-1, -2, -3)
	local world = Instance.new("WorldModel")
	world.Parent = viewport
	local model = Visuals.pet(pet.key)
	model.Parent = world
	model:PivotTo(CFrame.Angles(0, math.rad(-24), 0))
	local cf, size = model:GetBoundingBox()
	local extent = math.max(size.X, size.Y, size.Z)
	local camera = Instance.new("Camera")
	camera.FieldOfView = 34
	camera.CFrame = CFrame.lookAt(cf.Position + Vector3.new(extent * 0.65, extent * 0.35, -extent * 2.15), cf.Position)
	camera.Parent = viewport
	viewport.CurrentCamera = camera
	viewport.Parent = parent
end

local function progress(bar, value, total)
	Figma.nameTexts(bar, { "Count" })
	Figma.setText(bar, "Count", value .. "/" .. total)
	local fill = bar.Fill
	local clip = Instance.new("Frame")
	clip.Name = "ProgressClip"
	clip.BackgroundTransparency = 1
	clip.Position = fill.Position
	clip.Size = UDim2.fromOffset(fill.Size.X.Offset * value / math.max(1, total), fill.Size.Y.Offset)
	clip.ClipsDescendants = true
	clip.ZIndex = fill.ZIndex
	fill.Position = UDim2.fromOffset(0, 0)
	fill.Parent = clip
	clip.Parent = bar
end

local function build(latest)
	local p = latest.current
	local source = Figma.get("Index")["Index Window"]
	local root = source.IndexFrame:Clone()
	root.AnchorPoint = Vector2.new(0.5, 0.5)
	root.Position = UDim2.fromScale(0.5, 0.5)
	local scale = root:FindFirstChildOfClass("UIScale") or Instance.new("UIScale")
	scale.Parent = root
	local exit = source.ExitBtn:Clone()
	exit.Position = UDim2.fromOffset(1161, 6)
	exit.ZIndex = 10
	exit.Parent = root
	local function enabled()
		return latest.current.inputEnabled and latest.current.enabled
	end
	local function reduced()
		return latest.current.reduced
	end
	local buttons = { Figma.button(exit, function()
		latest.current.onClose()
	end, enabled, reduced, "CloseWindow") }
	local main = root.MainFrame
	local collection = main.IndexCollection
	local template = collection:Clone()
	local scroll = Instance.new("ScrollingFrame")
	scroll.Name = "IndexScroll"
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.Position = collection.Position
	scroll.Size = collection.Size
	scroll.ScrollBarThickness = 6
	scroll.ScrollingDirection = Enum.ScrollingDirection.Y
	scroll.ZIndex = collection.ZIndex
	scroll.Parent = main
	collection:Destroy()
	local discoveries = {}
	for _, name in p.discovered do
		discoveries[name] = true
	end
	local groups = { Forest = {}, Desert = {}, Snow = {}, Titanic = {} }
	local total, forest = 0, 0
	for _, pet in Config.Pets do
		table.insert(groups[pet.biome], pet)
		if discoveries[pet.name] then
			total += 1
		end
	end
	for section, biome in { "Forest", "Desert", "Snow", "Titanic" } do
		local row = template:Clone()
		row.Name = biome .. "Section"
		row.Position = UDim2.fromOffset(0, (section - 1) * 446)
		local context = row.ForestContext
		Figma.nameTexts(context, { "Title", "Count" })
		Figma.setText(context, "Title", string.upper(biome))
		-- Only Forest has an illustration in this design.
		context["Icon Egg"].Visible = biome == "Forest"
		local grid = row.PetGrid
		for _, child in grid:GetChildren() do
			child:Destroy()
		end
		local owned = 0
		for i, pet in groups[biome] do
			local unlocked = discoveries[pet.name] == true
			if unlocked then
				owned += 1
			end
			local style = not unlocked and 2 or pet.rarity == "Uncommon" and 3 or pet.rarity == "Mythic" and 7 or 1
			local card = template.PetGrid["PetSlot" .. style]:Clone()
			card.Name = "Pet_" .. pet.key
			card.Position = UDim2.fromOffset(((i - 1) % 4) * 156, math.floor((i - 1) / 4) * 156)
			Figma.nameTexts(card, { "Name" })
			Figma.setText(card, "Name", unlocked and pet.name or "???")
			card.Name_Shadow.TextScaled = true
			card:FindFirstChild("Name").TextScaled = true
			if unlocked then
				if pet.rarity ~= "Common" and pet.rarity ~= "Uncommon" and pet.rarity ~= "Mythic" then
					card.Top.BackgroundColor3 = Theme.colors[pet.color]
				end
				preview(card, pet)
			end
			card.Parent = grid
			table.insert(
				buttons,
				Figma.button(card, function()
					latest.current.onSelect(pet.key)
				end, enabled, reduced, "Select_" .. pet.key)
			)
		end
		Figma.setText(context, "Count", owned .. "/" .. #groups[biome])
		progress(row.ForestProgress, owned, #groups[biome])
		row.Parent = scroll
		if biome == "Forest" then
			forest = owned
		end
	end
	template:Destroy()
	scroll.CanvasSize = UDim2.fromOffset(0, 4 * 446 - 16)
	local bar = main.Total.TotalBar
	progress(bar, total, #Config.Pets)
	Figma.setText(bar, "Count", "UNLOCKED: " .. total .. "/" .. #Config.Pets)
	Figma.nameTexts(main.IndexDetail, { "Name", "Rarity", "Income" })
	Figma.nameTexts(main.IndexRewards.ClaimCollectionReward, { "Label" })
	local ready = forest == #groups.Forest
	table.insert(
		buttons,
		Figma.button(main.IndexRewards.ClaimCollectionReward, function()
			latest.current.onAction("ClaimCollectionReward", {})
		end, function()
			return enabled() and ready and not latest.current.claimed
		end, reduced, "ClaimCollectionReward")
	)
	Figma.studs(root, reduced)
	return { root = root, scale = scale, scroll = scroll, buttons = buttons, discoveries = discoveries, ready = ready }
end

local function update(view, p)
	view.scale.Scale = math.min(p.width / DESIGN.X, p.height / DESIGN.Y)
	view.scroll.Active = p.inputEnabled
	local pet = Config.Pets[1]
	for _, candidate in Config.Pets do
		if candidate.key == p.selection then
			pet = candidate
			break
		end
	end
	local detail = view.root.MainFrame.IndexDetail
	local owned = view.discoveries[pet.name]
	Figma.setText(detail, "Name", owned and pet.name or "???")
	Figma.setText(detail, "Rarity", owned and pet.rarity or "Not discovered")
	Figma.setText(detail, "Income", owned and "$" .. p.formatNumber(pet.income) .. "/s" or "Hatch eggs to discover")
	for _, name in { "Name", "Rarity", "Income" } do
		detail:FindFirstChild(name).TextScaled = true
		detail:FindFirstChild(name .. "_Shadow").TextScaled = true
	end
	if view.selected ~= pet.key then
		local old = detail.Preview:FindFirstChild("PetPreview")
		if old then
			old:Destroy()
		end
		detail.Preview.Icon.Visible = not owned
		if owned then
			preview(detail.Preview, pet)
		end
		view.selected = pet.key
	end
	Figma.setText(
		view.root.MainFrame.IndexRewards.ClaimCollectionReward,
		"Label",
		p.claimed and "CLAIMED" or view.ready and "CLAIM REWARD" or "FIND ALL FOREST PETS"
	)
	local button = view.root.MainFrame.IndexRewards.ClaimCollectionReward
	button.Label.TextScaled = true
	button.Label_Shadow.TextScaled = true
	for _, handle in view.buttons do
		handle.refresh()
	end
end

local function IndexWindow(p)
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
		local ok, built = pcall(build, latest)
		if not ok then
			warn("Figma template Index: " .. tostring(built))
			return
		end
		view.current = built
		built.root.Parent = host.current
		update(built, latest.current)
		return function()
			for _, button in built.buttons do
				button.destroy()
			end
			built.root:Destroy()
			view.current = nil
		end
	end, { p.discoveryKey })
	React.useEffect(function()
		if view.current then
			update(view.current, latest.current)
		end
	end)
	return e(
		"Frame",
		{ Name = "Index", ref = host, BackgroundTransparency = 1, Size = UDim2.fromOffset(p.width, p.height) }
	)
end

return IndexWindow
