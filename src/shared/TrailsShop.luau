-- Trails Shop window from the Figma import (ReplicatedStorage.UITemplates.TrailsShop).
-- The template holds one card per GameConfig.Trails entry with its own artwork and color.
local React = require(game.ReplicatedStorage.Packages.React)
local Game = require(game.ReplicatedStorage.GameConfig)
local UI = require(script.Parent.UI)
local Figma = require(script.Parent.FigmaTemplate)
local e = React.createElement
local DESIGN = Vector2.new(1301, 720)
local NEED_COLOR = Color3.fromHex("FEE545")
local WHITE = Color3.new(1, 1, 1)
local VALUE_GREEN = "rgb(66,254,0)"

local function build(latest)
	local template = Figma.get("TrailsShop")
	local source = template:FindFirstChild("Trails Shop Window")
	local frame = source.TrailsShopFrame:Clone()
	local exit = source.ExitBtn:Clone()
	local origin = Vector2.new(source.TrailsShopFrame.Position.X.Offset, source.TrailsShopFrame.Position.Y.Offset)
	local root = Instance.new("Frame")
	root.Name = "TrailsShopWindow"
	root.BackgroundTransparency = 1
	root.AnchorPoint = Vector2.new(0.5, 0.5)
	root.Position = UDim2.fromScale(0.5, 0.5)
	root.Size = UDim2.fromOffset(DESIGN.X, DESIGN.Y)
	local scale = Instance.new("UIScale")
	scale.Parent = root
	frame.Position = UDim2.fromOffset(0, 0)
	frame.Parent = root
	exit.Position = UDim2.fromOffset(exit.Position.X.Offset - origin.X, exit.Position.Y.Offset - origin.Y)
	exit.Parent = root
	local shop = frame.EquipmentShop
	local scroll = Figma.scroll(shop.EquipmentScroll, Enum.ScrollingDirection.X)
	scroll.Active = true
	local function enabled()
		return latest.current.inputEnabled and not latest.current.busy
	end
	local function reduced()
		return latest.current.reduced
	end
	Figma.studs(root, reduced)
	local buttons = {
		Figma.button(exit, function()
			latest.current.onClose()
		end, function()
			return latest.current.inputEnabled
		end, reduced),
	}
	local cards = {}
	-- shortcut: cards come only from the template; a new GameConfig trail needs a re-export from Figma.
	for i in Game.Trails do
		local card = scroll:FindFirstChild("ShopItem" .. i)
		if card then
			local action = card:FindFirstChild("BuyEquipment" .. i)
			local state = { card = card, action = action }
			state.button = Figma.button(action, function()
				latest.current.onAction("BuyTrail", { index = i })
			end, function()
				return enabled() and state.clickable
			end, reduced)
			table.insert(buttons, state.button)
			cards[i] = state
		end
	end
	local shown = {}
	for i, state in cards do
		shown[i] = state.card
		local image = state.card:FindFirstChild("Image")
		if image then
			table.insert(buttons, Figma.idle(image, "sway", i * 0.9, reduced))
		end
	end
	Figma.reveal(shown, reduced())
	return { root = root, scale = scale, shop = shop, scroll = scroll, cards = cards, buttons = buttons }
end

local function update(view, p)
	view.scale.Scale = math.min(p.width / DESIGN.X, p.height / DESIGN.Y)
	view.scroll.Active = p.inputEnabled
	local cash = p.cash or 0
	Figma.setText(view.shop, "Balance", "Balance: $" .. Game.number(cash))
	for i, state in view.cards do
		local item = Game.Trails[i]
		local have = table.find(p.owned, i) ~= nil
		local equipped = p.equipped == i
		local missing = math.max(0, item.cost - cash)
		state.clickable = not equipped and (have or missing == 0)
		Figma.setText(state.card, "Title", string.upper(item.name))
		Figma.setText(
			state.card.Stat,
			"Value",
			'<font color="'
				.. VALUE_GREEN
				.. '">x'
				.. Game.number(item.multiplier)
				.. '</font><font color="rgb(255,255,255)"> Speed</font>'
		)
		Figma.setText(
			state.card,
			"Condition",
			equipped and "In use"
				or have and "Owned"
				or missing > 0 and "Need $" .. Game.number(missing) .. " more"
				or "Ready to buy",
			missing > 0 and not have and not equipped and NEED_COLOR or WHITE
		)
		Figma.setText(
			state.action,
			"Label",
			equipped and "EQUIPPED" or have and "EQUIP" or "BUY $" .. Game.number(item.cost)
		)
		state.button.refresh()
	end
end

local function TrailsShop(p)
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
			warn("Figma template TrailsShop: " .. tostring(built))
			return
		end
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
		Name = "Trails Shop",
		ref = host,
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(p.width, p.height),
	})
end

return TrailsShop
