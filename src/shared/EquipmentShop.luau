local React = require(game.ReplicatedStorage.Packages.React)
local Game = require(game.ReplicatedStorage.GameConfig)
local UI = require(script.Parent.UI)
local Theme = require(script.Parent.Theme)
local e = React.createElement
local C = Theme.colors
local function EquipmentShop(p)
	local pickaxes = p.kind == "Pickaxe Shop"
	local list = pickaxes and Game.Pickaxes or Game.Trails
	local owned = p.owned or {}
	local cash = p.cash or 0
	local compactCard = p.height - p.headerH < 330
	-- One horizontal row: cards fill the scroll height (minus padding and the scrollbar), so it never scrolls vertically.
	local scrollH = p.height - p.headerH - 56
	local height = compactCard and 172 or scrollH - 32
	local cw = compactCard and 360 or p.compact and math.max(220, math.min(320, p.width - 60)) or 270
	local gap = 18
	local scrollRef = React.useRef(nil)
	-- Opening the shop shows the item in use.
	React.useEffect(function()
		if scrollRef.current and p.equipped then
			scrollRef.current.CanvasPosition = Vector2.new((p.equipped - 1) * (cw + gap) * (p.scale or 1), 0)
		end
	end, { p.kind })
	local cards = {
		Layout = e("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, gap),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		Padding = e("UIPadding", {
			PaddingLeft = UDim.new(0, 12),
			PaddingRight = UDim.new(0, 12),
			PaddingTop = UDim.new(0, 8),
			PaddingBottom = UDim.new(0, 16),
		}),
	}
	for i, item in list do
		local have = table.find(owned, i) ~= nil
		local equipped = p.equipped == i
		local missing = math.max(0, item.cost - cash)
		local color = pickaxes
				and ((i < 3 and C.white) or i < 5 and C.green or i < 8 and C.blue or i < 11 and C.purple or C.red)
			or item.color
		local imageY = compactCard and 42 or (pickaxes and 92 or 64)
		local imageH = compactCard and 112 or height - imageY - 112
		local image = UI.icon(
			(pickaxes and "pickaxe" or "trail") .. item.key,
			compactCard and 12 or 20,
			imageY,
			compactCard and 100 or cw - 40,
			imageH
		)
		cards["Item" .. i] = e(
			"Frame",
			{ Name = "ShopItem" .. i, BackgroundTransparency = 1, Size = UDim2.fromOffset(cw, height), LayoutOrder = i },
			{
				Card = e(UI.Surface, {
					w = cw,
					h = height,
					color = color,
					selected = equipped,
					children = {
						Title = UI.text(
							item.name,
							12,
							8,
							cw - 24,
							compactCard and 32 or 48,
							compactCard and 23 or 36,
							nil,
							nil,
							nil,
							{ fit = true }
						),
						Rarity = pickaxes and UI.text(
							item.rarity,
							compactCard and 124 or 12,
							compactCard and 43 or 58,
							compactCard and cw - 136 or cw - 24,
							28,
							compactCard and 20 or 24
						) or nil,
						Image = image,
						-- Stat band overlaps the illustration like the reference: green value, white unit.
						Stat = e(UI.Surface, {
							x = compactCard and 124 or 12,
							y = compactCard and 71 or height - 140,
							w = compactCard and cw - 136 or cw - 24,
							h = compactCard and 28 or 46,
							variant = "utility",
							z = 9,
							children = {
								Value = UI.text(
									'<font color="'
										.. UI.hex(C.green)
										.. '">'
										.. (pickaxes and Game.number(item.power) or "x" .. Game.number(item.multiplier))
										.. "</font> "
										.. (pickaxes and "Power" or "Speed"),
									6,
									1,
									compactCard and cw - 148 or cw - 36,
									compactCard and 24 or 40,
									compactCard and 20 or 32,
									nil,
									nil,
									nil,
									{ rich = true, fit = true }
								),
							},
						}),
						Condition = UI.text(
							equipped and "In use"
								or have and "Owned"
								or missing > 0 and "Need $" .. Game.number(missing) .. " more"
								or "Ready to buy",
							compactCard and 124 or 12,
							compactCard and 99 or height - 91,
							compactCard and cw - 136 or cw - 24,
							24,
							18,
							equipped and C.white or missing > 0 and not have and C.gold or C.white
						),
						Action = e(UI.Button, {
							name = "BuyEquipment" .. i,
							x = compactCard and 124 or 12,
							y = compactCard and 123 or height - 62,
							w = compactCard and cw - 136 or cw - 24,
							h = compactCard and 44 or 48,
							color = C.green,
							label = equipped and "Equipped" or have and "Equip" or "Buy $" .. Game.number(item.cost),
							textSize = 25,
							disabled = p.busy or equipped or (not have and missing > 0),
							onClick = function()
								p.onAction(pickaxes and "BuyPickaxe" or "BuyTrail", { index = i })
							end,
						}),
					},
				}),
			}
		)
	end
	return e("Frame", {
		Name = "EquipmentShop",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(12, p.headerH + 10),
		Size = UDim2.fromOffset(p.width - 24, p.height - p.headerH - 22),
	}, {
		Balance = UI.text(
			"Balance: $" .. Game.number(cash),
			12,
			0,
			p.width - 48,
			28,
			22,
			C.green,
			Enum.TextXAlignment.Left
		),
		Scroll = e("ScrollingFrame", {
			Name = "EquipmentScroll",
			ref = scrollRef,
			Position = UDim2.fromOffset(0, 34),
			Size = UDim2.new(1, 0, 1, -34),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			CanvasSize = UDim2.new(0, 24 + #list * cw + (#list - 1) * gap, 1, 0),
			ScrollingDirection = Enum.ScrollingDirection.X,
			ScrollBarThickness = 6,
			ScrollBarImageColor3 = C.white,
			Active = true,
		}, cards),
	})
end
return EquipmentShop
