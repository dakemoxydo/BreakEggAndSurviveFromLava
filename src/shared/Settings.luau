local React = require(game.ReplicatedStorage.Packages.React)
local UIS = game:GetService("UserInputService")
local UI = require(script.Parent.UI)
local C = require(script.Parent.Theme).colors
local e = React.createElement

local function Volume(p)
	local ref = React.useRef(nil)
	local drag = React.useRef(nil)
	local latest = React.useRef(p)
	local inputEnabled = React.useContext(UI.InputEnabled)
	latest.current = { onAction = p.onAction, setting = p.setting, value = p.value, enabled = p.enabled ~= false
		and inputEnabled }
	local value = math.clamp(p.value, 0, 1)
	local current = React.useRef(value)
	local preview, update = React.useBinding(value)
	local function show(nextValue)
		current.current = math.clamp(nextValue, 0, 1)
		update(current.current)
	end
	local function releaseScroll()
		local pending = drag.current
		if pending and pending.scroll and pending.scroll.Parent then
			pending.scroll.ScrollingEnabled = pending.scrollingEnabled
		end
		drag.current = nil
	end
	local function atPointer(x)
		local object = ref.current
		if not object then
			return
		end
		-- Map the pointer to the handle's center travel, including the UI scale.
		local scale = object.AbsoluteSize.X / p.w
		show((x - object.AbsolutePosition.X - 26 * scale) / math.max(1, object.AbsoluteSize.X - 52 * scale))
	end
	local function setVolume(nextValue)
		show(nextValue)
		latest.current.onAction("SetSetting", { setting = latest.current.setting, value = current.current })
	end
	React.useEffect(function()
		if not latest.current.enabled then
			if drag.current then
				releaseScroll()
				show(latest.current.value)
			end
		elseif not drag.current then
			show(latest.current.value)
		end
	end, { p.value, p.enabled, inputEnabled })
	React.useEffect(function()
		local changed = UIS.InputChanged:Connect(function(input)
			local pending = drag.current
			if not pending or not latest.current.enabled then
				return
			end
			if
				(
					pending.input.UserInputType == Enum.UserInputType.MouseButton1
					and input.UserInputType == Enum.UserInputType.MouseMovement
				) or input == pending.input
			then
				atPointer(input.Position.X)
			end
		end)
		local ended = UIS.InputEnded:Connect(function(input)
			local pending = drag.current
			if
				not pending
				or not (
					input == pending.input
					or (
						pending.input.UserInputType == Enum.UserInputType.MouseButton1
						and input.UserInputType == Enum.UserInputType.MouseButton1
					)
				)
			then
				return
			end
			atPointer(input.Position.X)
			local nextValue = current.current
			releaseScroll()
			if latest.current.enabled then
				setVolume(nextValue)
			else
				show(latest.current.value)
			end
		end)
		local lost = UIS.WindowFocusReleased:Connect(function()
			releaseScroll()
			show(latest.current.value)
		end)
		return function()
			changed:Disconnect()
			ended:Disconnect()
			lost:Disconnect()
			releaseScroll()
		end
	end, { p.w })
	return e(React.Fragment, nil, {
		Percent = UI.text(
			preview:map(function(v)
				return math.floor(v * 100) .. "%"
			end),
			p.percentX,
			10,
			62,
			32,
			22,
			C.gold
		),
		Slider = e(UI.Button, {
			name = p.setting,
			x = p.x,
			y = p.y,
			w = p.w,
			h = 48,
			variant = "utility",
			buttonRef = ref,
			disabled = p.enabled == false,
			onInput = function(input)
				if
					input.UserInputType == Enum.UserInputType.MouseButton1
					or input.UserInputType == Enum.UserInputType.Touch
				then
					if drag.current or not ref.current then
						return
					end
					local scroll = ref.current:FindFirstAncestorWhichIsA("ScrollingFrame")
					drag.current = { input = input, scroll = scroll, scrollingEnabled = scroll
						and scroll.ScrollingEnabled }
					if scroll then
						scroll.ScrollingEnabled = false
					end
					atPointer(input.Position.X)
				elseif input.KeyCode == Enum.KeyCode.Left or input.KeyCode == Enum.KeyCode.DPadLeft then
					setVolume(current.current - 0.1)
				elseif input.KeyCode == Enum.KeyCode.Right or input.KeyCode == Enum.KeyCode.DPadRight then
					setVolume(current.current + 0.1)
				end
			end,
			children = {
				Track = e(UI.Surface, { x = 12, y = 18, w = p.w - 24, h = 12, variant = "utility" }),
				Fill = e(
					"Frame",
					{
						Name = "VolumeFill",
						Position = UDim2.fromOffset(12, 18),
						Size = preview:map(function(v)
							return UDim2.fromOffset(math.max(4, (p.w - 24) * v), 12)
						end),
						BackgroundColor3 = C.gold,
						BorderSizePixel = 0,
						ZIndex = 7,
					},
					{ Corner = e("UICorner", { CornerRadius = UDim.new(0, 4) }) }
				),
				Handle = e(
					UI.Surface,
					{
						position = preview:map(function(v)
							return UDim2.fromOffset(12 + (p.w - 52) * v, 10)
						end),
						w = 28,
						h = 28,
						color = C.gold,
						z = 10,
					}
				),
			},
		}),
	})
end

local function Settings(p)
	local narrow = p.width < 520
	local rowW = p.width - 48
	local rows = {
		Padding = e(
			"UIPadding",
			{
				PaddingLeft = UDim.new(0, 20),
				PaddingRight = UDim.new(0, 20),
				PaddingTop = UDim.new(0, 12),
				PaddingBottom = UDim.new(0, 20),
			}
		),
		Layout = e("UIListLayout", { Padding = UDim.new(0, 20), SortOrder = Enum.SortOrder.LayoutOrder }),
	}
	for i, item in { { "Music", "Background music", "MusicVolume" }, { "SFX", "Sound effects", "SFXVolume" } } do
		local value = p.data[item[3]] or 1
		rows[item[3]] = e(
			"Frame",
			{
				Name = item[3] .. "Row",
				BackgroundTransparency = 1,
				Size = UDim2.fromOffset(rowW, narrow and 148 or 100),
				LayoutOrder = i,
			},
			{
				Card = e(
					UI.Surface,
					{
						w = rowW,
						h = narrow and 148 or 100,
						color = C.muted,
						quiet = true,
						children = {
							Name = UI.text(
								item[1],
								16,
								8,
								narrow and rowW - 90 or rowW * 0.43,
								42,
								30,
								nil,
								Enum.TextXAlignment.Left
							),
							Description = UI.text(
								item[2],
								16,
								52,
								narrow and rowW - 32 or rowW * 0.43,
								30,
								20,
								nil,
								Enum.TextXAlignment.Left
							),
							Slider = e(
								Volume,
								{
									setting = item[3],
									value = value,
									percentX = rowW - 78,
									x = narrow and 16 or rowW * 0.48,
									y = narrow and 88 or 44,
									w = narrow and rowW - 32 or rowW * 0.48 - 16,
									onAction = p.onAction,
									enabled = p.enabled,
								}
							),
						},
					}
				),
			}
		)
	end
	for i, item in
		{
			{ "Other players' pets", "ViewOthersPets" },
			{ "My pets", "ViewMyPets" },
			{ "My eggs", "ViewMyEggs" },
			{ "Reduced motion", "ReducedMotion" },
		}
	do
		local enabled = item[2] == "ReducedMotion" and p.data.ReducedMotion == true
			or item[2] ~= "ReducedMotion" and p.data[item[2]] ~= false
		rows[item[2]] = e(
			"Frame",
			{
				Name = item[2] .. "Row",
				BackgroundTransparency = 1,
				Size = UDim2.fromOffset(rowW, narrow and 124 or 84),
				LayoutOrder = i + 2,
			},
			{
				Card = e(
					UI.Surface,
					{
						w = rowW,
						h = narrow and 124 or 84,
						color = C.muted,
						quiet = true,
						children = {
							Name = UI.text(
								item[1],
								16,
								8,
								narrow and rowW - 32 or rowW - 166,
								52,
								narrow and 24 or 30,
								nil,
								Enum.TextXAlignment.Left
							),
							Toggle = e(UI.Button, {
								name = item[2],
								label = enabled and "ON" or "OFF",
								x = rowW - 136,
								y = narrow and 64 or 18,
								w = 120,
								h = 48,
								color = enabled and C.green or C.red,
								textSize = 24,
								selected = enabled,
								disabled = p.enabled == false,
								onClick = function()
									p.onAction("SetSetting", { setting = item[2], value = not enabled })
								end,
							}),
						},
					}
				),
			}
		)
	end
	return e(
		"ScrollingFrame",
		{
			Name = "SettingsScroll",
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Position = UDim2.fromOffset(4, p.headerH + 12),
			Size = UDim2.fromOffset(p.width - 8, p.height - p.headerH - 32),
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			CanvasSize = UDim2.fromOffset(0, 0),
			ScrollBarThickness = 5,
			ScrollBarImageColor3 = C.white,
			ScrollingDirection = Enum.ScrollingDirection.Y,
			Active = true,
		},
		rows
	)
end
return React.memo(Settings)
