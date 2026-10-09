local React = require(game.ReplicatedStorage.Packages.React)
local Game = require(game.ReplicatedStorage.GameConfig)
local UI = require(script.Parent.UI)
local Theme = require(script.Parent.Theme)
local Preview = require(script.Parent.ModelPreview)
local e = React.createElement
local C = Theme.colors
local function AdventurePanels(p)
	local confirmation, setConfirmation = React.useState(nil)
	React.useEffect(function()
		if p.enabled == false then
			setConfirmation(nil)
		end
	end, { p.enabled, p.kind })
	local body = {}
	local compact = p.width < 580
	local available = math.max(1, p.height - p.headerH)
	local low = available < 330
	if p.kind == "Satchel Shop" then
		local level = p.data.SatchelLevel or 1
		local cost = 1000 * 25 ^ (level - 1)
		local missing = math.max(0, cost - (p.data.Cash or 0))
		body.Title = UI.text("Carry more animals per run!", 20, 12, p.width - 40, 48, compact and 24 or 34, C.gold)
		body.Amount = UI.text("Your satchel: " .. level .. " Animals", 20, 68, p.width - 40, 50, compact and 28 or 40)
		body.Description = UI.text(
			"Bring stolen animals back to the Safe Zone.\nGuardians and lava make you lose your cargo.",
			24,
			126,
			p.width - 48,
			94,
			compact and 21 or 26
		)
		body.Buy = e(UI.Button, {
			name = "UpgradeSatchel",
			x = 24,
			y = 234,
			w = p.width - 48,
			h = 58,
			color = C.green,
			label = level >= 8 and "MAX LEVEL" or "+1 Animal  ·  $" .. Game.number(cost),
			disabled = p.busy or level >= 8 or missing > 0,
			textSize = compact and 23 or 30,
			onClick = function()
				p.onAction("UpgradeSatchel", {})
			end,
		})
		body.Condition = UI.text(
			level >= 8 and "Maximum capacity reached"
				or missing > 0 and "Need $" .. Game.number(missing) .. " more"
				or "Balance: $" .. Game.number(p.data.Cash or 0),
			24,
			304,
			p.width - 48,
			32,
			20,
			C.gold
		)
		return e(
			"ScrollingFrame",
			{
				Position = UDim2.fromOffset(0, p.headerH),
				Size = UDim2.fromOffset(p.width, available),
				CanvasSize = UDim2.fromOffset(0, 356),
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				ScrollBarThickness = 5,
				Active = true,
			},
			body
		)
	else
		if confirmation then
			local current = {}
			for _, pet in p.pets do
				current[pet.id] = pet
			end
			local valid = true
			local onBase = 0
			for _, pet in confirmation.pets do
				local live = current[pet.id]
				if not live or live.kind ~= pet.kind or live.equipped ~= pet.equipped then
					valid = false
				end
				if pet.equipped then
					onBase += 1
				end
			end
			local rows = {
				Layout = e("UIListLayout", { Padding = UDim.new(0, 12), SortOrder = Enum.SortOrder.LayoutOrder }),
				Padding = e(
					"UIPadding",
					{ PaddingLeft = UDim.new(0, 12), PaddingTop = UDim.new(0, 8), PaddingBottom = UDim.new(0, 12) }
				),
			}
			rows.Explanation = e(
				"Frame",
				{ BackgroundTransparency = 1, Size = UDim2.fromOffset(p.width - 48, low and 64 or 82), LayoutOrder = 0 },
				{
					Text = UI.text(
						valid and "Replace these 3 animals with one egg?"
							or "These animals changed. Cancel and choose again.",
						0,
						0,
						p.width - 48,
						low and 30 or 40,
						compact and 22 or 25,
						C.gold
					),
					Consequence = UI.text(
						onBase > 0 and onBase .. " on your base will stop earning."
							or "The original animals will be consumed.",
						0,
						low and 34 or 44,
						p.width - 48,
						low and 26 or 34,
						20
					),
				}
			)
			for i, pet in confirmation.pets do
				rows["Pet" .. i] = e(
					"Frame",
					{
						Name = "MergeInput" .. i,
						BackgroundTransparency = 1,
						Size = UDim2.fromOffset(p.width - 48, low and 64 or 84),
						LayoutOrder = i,
					},
					{
						Card = e(
							UI.Surface,
							{
								w = p.width - 48,
								h = low and 64 or 84,
								variant = "utility",
								children = {
									Image = e(
										Preview,
										{ kind = pet.kind, weight = pet.weight, x = 8, y = 8, w = low and 48 or 60, h = low
												and 48
											or 60 }
									),
									Name = UI.text(
										pet.name,
										80,
										4,
										p.width - 140,
										low and 28 or 36,
										22,
										nil,
										Enum.TextXAlignment.Left
									),
									Identity = UI.text(
										"#"
											.. string.sub(pet.id, -8)
											.. " · "
											.. (pet.equipped and "On base" or "Backpack"),
										80,
										low and 34 or 42,
										p.width - 140,
										low and 24 or 34,
										18,
										nil,
										Enum.TextXAlignment.Left
									),
								},
							}
						),
					}
				)
			end
			body.Preview = e(
				"ScrollingFrame",
				{
					Name = "MergeConfirmation",
					Position = UDim2.fromOffset(12, 4),
					Size = UDim2.fromOffset(p.width - 24, math.max(1, available - 84)),
					BackgroundTransparency = 1,
					BorderSizePixel = 0,
					CanvasSize = UDim2.fromOffset(0, 0),
					AutomaticCanvasSize = Enum.AutomaticSize.Y,
					ScrollBarThickness = 5,
					Active = true,
				},
				rows
			)
			local buttonW = (p.width - 56) / 2
			body.Cancel = e(UI.Button, {
				name = "CancelMerge",
				label = "Cancel",
				x = 20,
				y = available - 64,
				w = buttonW,
				h = 48,
				color = C.red,
				textSize = 24,
				disabled = p.busy,
				onClick = function()
					setConfirmation(nil)
				end,
			})
			body.Confirm = e(UI.Button, {
				name = "ConfirmMerge",
				label = "Confirm Merge",
				x = 36 + buttonW,
				y = available - 64,
				w = buttonW,
				h = 48,
				color = C.green,
				textSize = compact and 21 or 25,
				disabled = p.busy or not valid,
				onClick = function()
					local ids = {}
					for _, pet in confirmation.pets do
						table.insert(ids, pet.id)
					end
					p.onAction("MergePets", { kind = confirmation.kind, pets = ids }, function()
						setConfirmation(nil)
					end)
				end,
			})
			return e(
				"Frame",
				{
					Position = UDim2.fromOffset(0, p.headerH),
					Size = UDim2.fromOffset(p.width, available),
					BackgroundTransparency = 1,
				},
				body
			)
		end
		local hintH = low and 44 or 95
		local listY = low and 64 or 125
		body.Hint = UI.text(
			low and "Merge 3 matching animals into an egg."
				or "Merge 3 matching animals into a heavier egg.\nPlace the egg on your base to hatch it.",
			16,
			low and 8 or 14,
			p.width - 32,
			hintH,
			low and 22 or 27
		)
		local counts = {}
		for _, pet in p.pets do
			local item = counts[pet.kind]
			if not item then
				item = { kind = pet.kind, name = pet.name, count = 0, pets = {} }
				counts[pet.kind] = item
			end
			item.count += 1
			if #item.pets < 3 then
				table.insert(item.pets, pet)
			end
		end
		local rows = {
			Layout = e("UIListLayout", { Padding = UDim.new(0, 18), SortOrder = Enum.SortOrder.LayoutOrder }),
			Padding = e(
				"UIPadding",
				{ PaddingTop = UDim.new(0, 8), PaddingBottom = UDim.new(0, 12), PaddingLeft = UDim.new(0, 4) }
			),
		}
		local i = 0
		for _, pet in Game.Pets do
			local item = counts[pet.key]
			if item then
				i += 1
				rows[pet.key] = e(
					"Frame",
					{
						Name = "Merge" .. pet.key,
						Size = UDim2.fromOffset(p.width - 52, compact and 158 or 110),
						BackgroundTransparency = 1,
						LayoutOrder = i,
					},
					{
						Surface = e(
							UI.Surface,
							{
								w = p.width - 52,
								h = compact and 158 or 110,
								color = C.muted,
								quiet = true,
								children = {
									Image = e(
										Preview,
										{ kind = pet.key, x = 6, y = 6, w = compact and 72 or 90, h = compact and 72
											or 90 }
									),
									Title = UI.text(
										pet.name,
										compact and 84 or 106,
										8,
										compact and p.width - 142 or p.width - 370,
										46,
										compact and 21 or 26,
										nil,
										Enum.TextXAlignment.Left
									),
									Count = UI.text(
										item.count .. " / 3 Animals",
										compact and 84 or 106,
										54,
										compact and p.width - 142 or p.width - 370,
										36,
										20,
										item.count >= 3 and C.green or C.white,
										Enum.TextXAlignment.Left
									),
									Merge = e(UI.Button, {
										name = "Merge" .. pet.key,
										label = "Merge 3",
										x = compact and 12 or p.width - 242,
										y = compact and 97 or 26,
										w = compact and p.width - 76 or 180,
										h = 48,
										color = C.green,
										textSize = 25,
										disabled = p.busy or item.count < 3,
										onClick = function()
											setConfirmation({ kind = pet.key, pets = table.clone(item.pets) })
										end,
									}),
								},
							}
						),
					}
				)
			end
		end
		if i == 0 then
			rows.Empty =
				UI.text("Steal animals from the field to start your collection.", 16, 16, p.width - 76, 100, 26)
		end
		body.List = e(
			"ScrollingFrame",
			{
				Name = "MergeList",
				Position = UDim2.fromOffset(22, listY),
				Size = UDim2.fromOffset(p.width - 44, math.max(1, available - listY - 16)),
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				CanvasSize = UDim2.fromOffset(0, 0),
				AutomaticCanvasSize = Enum.AutomaticSize.Y,
				ScrollBarThickness = 5,
				Active = true,
			},
			rows
		)
	end
	return e(
		"Frame",
		{
			Position = UDim2.fromOffset(0, p.headerH),
			Size = UDim2.fromOffset(p.width, p.height - p.headerH),
			BackgroundTransparency = 1,
		},
		body
	)
end
return AdventurePanels
