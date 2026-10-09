local React = require(game.ReplicatedStorage.Packages.React)
local UI = require(script.Parent.UI)
local Theme = require(script.Parent.Theme)
local Config = require(script.Parent.Config)
local e = React.createElement
local C = Theme.colors

local function GrowingEggs(p)
	local narrow = p.width < 600
	local short = p.height < 520
	local lane = narrow and 56 or 84
	local w = math.min(480, p.width - lane - 32)
	local stacked = w < 420
	local header = stacked and 146 or 100
	local h = math.min(460, p.height - (short and 96 or narrow and 240 or 200))
	h = math.max(header + 72, h)
	local top = short and 64 or narrow and 180 or math.max(96, (p.height - h) / 2)
	local actionW = stacked and w - 28 or 166
	local gold = C.gold:Lerp(C.red, 0.12)
	local cost = p.growCost or Config.GrowAllCost or 20
	local missing = math.max(0, cost - (p.cash or 0))
	local empty = #p.eggs == 0
	local rows = {
		Padding = e(
			"UIPadding",
			{
				PaddingLeft = UDim.new(0, 14),
				PaddingRight = UDim.new(0, 14),
				PaddingTop = UDim.new(0, 12),
				PaddingBottom = UDim.new(0, 16),
			}
		),
		Layout = e("UIListLayout", { Padding = UDim.new(0, 14), SortOrder = Enum.SortOrder.LayoutOrder }),
	}
	for i, egg in p.eggs do
		local rowW = w - 40
		local rowH = 96
		rows["Egg" .. i] = e(
			"Frame",
			{ Name = "GrowingEgg" .. i, BackgroundTransparency = 1, Size = UDim2.fromOffset(rowW, rowH), LayoutOrder = i },
			{
				Card = e(
					UI.Surface,
					{
						w = rowW,
						h = rowH,
						color = C.muted,
						quiet = true,
						children = {
							Icon = UI.icon(egg.icon or "egg", 12, 10, 60, 72),
							Name = UI.text(egg.name or "Egg", 84, 10, rowW - 98, 36, 22, nil, Enum.TextXAlignment.Left),
							Status = UI.text(
								egg.status or "Growing",
								84,
								52,
								rowW - 98,
								30,
								20,
								C.green,
								Enum.TextXAlignment.Left
							),
						},
					}
				),
			}
		)
	end
	return e(
		UI.Transition,
		{
			name = "RightSidebar",
			x = p.width - w - lane - 16,
			y = top,
			w = w + lane,
			h = h,
			slide = true,
			visible = p.visible,
			transitionKey = p.kind,
			reduced = p.reduced,
			onClosed = p.onClosed,
			z = 20,
			children = {
				Panel = e(
					UI.Surface,
					{
						name = "EggsSidebar",
						x = lane,
						y = 0,
						w = w,
						h = h,
						color = C.body,
						quiet = true,
						studsTransparency = 0.92,
						studsColor = C.white,
						active = true,
						children = {
							Header = e(
								UI.Surface,
								{
									name = "GrowingEggsHeader",
									w = w,
									h = header,
									color = gold,
									shine = true,
									children = {
										Title = UI.text(
											"Growing Eggs",
											16,
											stacked and 4 or 10,
											stacked and w - 32 or w - actionW - 40,
											44,
											stacked and 28 or 34,
											nil,
											Enum.TextXAlignment.Left
										),
										Grow = e(UI.Button, {
											name = "GrowAllEggs",
											x = stacked and 14 or w - actionW - 14,
											y = stacked and 54 or 10,
											w = actionW,
											h = 54,
											color = C.gold,
											halftone = true,
											disabled = p.busy or empty or missing > 0,
											hoverScale = 1.025,
											onClick = function()
												if p.onAction then
													p.onAction("GrowAllEggs", {})
												end
											end,
											children = {
												Label = UI.text(
													"Grow All",
													6,
													1,
													actionW - 12,
													30,
													stacked and 27 or 26
												),
												Price = UI.text("$" .. tostring(cost), 6, 31, actionW - 12, 20, 18),
											},
										}),
									},
								}
							),
							Condition = UI.text(
								empty and "No eggs on your base"
									or missing > 0 and "Need $" .. tostring(missing) .. " more"
									or "Hatch " .. #p.eggs .. " eggs",
								16,
								stacked and 116 or 72,
								w - 32,
								24,
								18,
								C.white,
								Enum.TextXAlignment.Left
							),
							List = e(
								"ScrollingFrame",
								{
									Name = "GrowingEggsScroll",
									BackgroundTransparency = 1,
									BorderSizePixel = 0,
									Position = UDim2.fromOffset(6, header + 6),
									Size = UDim2.fromOffset(w - 12, h - header - 18),
									CanvasSize = UDim2.fromOffset(0, #p.eggs > 0 and #p.eggs * 110 + 14 or 0),
									ScrollBarThickness = 4,
									ScrollBarImageColor3 = C.muted,
									ScrollingDirection = Enum.ScrollingDirection.Y,
									Active = p.visible,
								},
								rows
							),
						},
					}
				),
				Collapse = e(
					UI.Button,
					{
						name = "CollapseSidebar",
						buttonRef = p.closeRef,
						label = ">",
						x = 2,
						y = (h - 72) / 2,
						w = narrow and 44 or 64,
						h = 72,
						color = C.red,
						textSize = narrow and 38 or 48,
						onClick = p.onClose,
					}
				),
			},
		}
	)
end
return React.memo(GrowingEggs)
