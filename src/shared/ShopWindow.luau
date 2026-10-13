-- Shop window from the Figma import (ReplicatedStorage.UITemplates.Shop, frame "Shop Window").
-- Pack cards are named by Config.Offers keys; prices, amounts and art come from the template.
local React = require(game.ReplicatedStorage.Packages.React)
local UI = require(script.Parent.UI)
local Config = require(script.Parent.Config)
local Figma = require(script.Parent.FigmaTemplate)
local e = React.createElement
local DESIGN = Vector2.new(975, 675)
-- ExitBtn is a sibling of ShopFrame in the import; this is its spot relative to ShopFrame.
local EXIT_POSITION = UDim2.fromOffset(896, 8)
-- Fixed cards without a pack grid. A nil key has no offer yet and reports "not available".
local FIXED = {
	{ "BundleFrame", "Starter Pack", nil },
	{ "2X Frame", "2X Speed", nil },
	{ "2X Frame", "2X Cash", "cash2" },
}
local SECTIONS = { ["Speed Packs"] = "SpeedPacksTitle", ["Cash Packs"] = "CashPacksTitle" }

local function offerByKey(key)
	for _, offer in Config.Offers do
		if offer.key == key then
			return offer
		end
	end
	return nil
end

local function build(latest)
	local window = Figma.get("Shop")["Shop Window"]
	local frame = window.ShopFrame:Clone()
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Position = UDim2.fromScale(0.5, 0.5)
	frame.Size = UDim2.fromOffset(DESIGN.X, DESIGN.Y)
	-- The import carries FigBlox's own UIScale; two UIScales on one object conflict, so reuse it.
	local scale = frame:FindFirstChildOfClass("UIScale") or Instance.new("UIScale")
	scale.Parent = frame
	local exit = window.ExitBtn:Clone()
	exit.Position = EXIT_POSITION
	exit.ZIndex = 10
	exit.Parent = frame
	local scroll = Figma.scroll(frame.MainFrame, Enum.ScrollingDirection.Y)
	scroll.Active = true
	local function enabled()
		return latest.current.inputEnabled
	end
	local function reduced()
		return latest.current.reduced
	end
	Figma.studs(frame, reduced)
	local buttons = {
		Figma.button(exit, function()
			latest.current.onClose()
		end, enabled, reduced, "CloseWindow"),
	}
	local function buy(object, key)
		if not object then
			return
		end
		table.insert(
			buttons,
			Figma.button(object, function()
				latest.current.onPurchase(offerByKey(key) or {})
			end, enabled, reduced, "Buy_" .. (key or object.Parent.Name))
		)
	end
	local cards = {}
	-- FindFirstChild: FigBlox may flatten a layer into the card image; a missing button is skipped, not fatal.
	for _, spec in FIXED do
		local group = scroll:FindFirstChild(spec[1])
		local card = group and group:FindFirstChild(spec[2])
		if card then
			table.insert(cards, card)
		end
		buy(card and card:FindFirstChild("BuyBtn"), spec[3])
	end
	for _, section in { "SpeedPacks", "CashPacks" } do
		local grid = scroll:FindFirstChild(section)
		for _, card in grid and grid:GetChildren() or {} do
			table.insert(cards, card)
			buy(card:FindFirstChild("Buy_" .. card.Name), card.Name)
			-- Gift buttons are design only: gifting is not implemented.
			local gift = card:FindFirstChild("Gift_" .. card.Name)
			if gift then
				table.insert(
					buttons,
					Figma.button(gift, function()
						latest.current.onGift()
					end, enabled, reduced)
				)
			end
		end
	end
	-- Pop in top to bottom, left to right; item icons (separate "Icon" layers) sway out of phase.
	-- Design position inside the scroll (the window is not on screen yet, so no AbsolutePosition).
	local function top(card)
		local at = Vector2.zero
		local object = card
		while object and object ~= scroll do
			at += Vector2.new(object.Position.X.Offset, object.Position.Y.Offset)
			object = object.Parent
		end
		return at.Y * 10000 + at.X
	end
	for i = #cards, 1, -1 do
		if not cards[i]:IsA("GuiObject") then
			table.remove(cards, i)
		end
	end
	for i, card in cards do
		local icon = card:FindFirstChild("Icon")
		if icon then
			table.insert(buttons, Figma.idle(icon, "sway", i * 0.9, reduced))
		end
	end
	table.sort(cards, function(a, b)
		return top(a) < top(b)
	end)
	Figma.reveal(cards, reduced())
	return { root = frame, scale = scale, scroll = scroll, buttons = buttons }
end

local function jump(view, category)
	local title = SECTIONS[category] and view.scroll:FindFirstChild(SECTIONS[category])
	view.scroll.CanvasPosition = Vector2.new(0, title and title.Position.Y.Offset - 8 or 0)
end

local function ShopWindow(p)
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
			warn("Figma template Shop: " .. tostring(built))
			return
		end
		view.current = built
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
			view.current.scale.Scale = math.min(p.width / DESIGN.X, p.height / DESIGN.Y)
			view.current.scroll.Active = inputEnabled
		end
	end)
	React.useEffect(function()
		if view.current then
			jump(view.current, p.category)
		end
	end, { p.category })
	return e("Frame", {
		Name = "Shop",
		ref = host,
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(p.width, p.height),
	})
end

return ShopWindow
