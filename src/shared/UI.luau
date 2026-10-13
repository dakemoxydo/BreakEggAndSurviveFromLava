local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.React)
local Ripple = require(ReplicatedStorage.Packages.Ripple)
local UserInputService = game:GetService("UserInputService")
local TextService = game:GetService("TextService")
local Theme = require(script.Parent.Theme)
local Assets = require(script.Parent.Assets)
local IndexSurface = require(script.Parent.IndexSurface)
local Audio = require(ReplicatedStorage:WaitForChild("Audio"))
local e = React.createElement
local UI = {}
UI.InputEnabled = React.createContext(true)
UI.ReducedMotion = React.createContext(false)
local function corner(radius)
	return e("UICorner", { CornerRadius = UDim.new(0, radius) })
end
-- opts.fit picks one TextSize that fits (long words shrink instead of breaking);
-- computed in design units, not TextScaled, so hover scale cannot re-fit it per frame.
-- opts.rich enables <font> color runs.
local function fitSize(text, size, w, h)
	local plain = string.gsub(text, "<[^>]->", "")
	for s = size, 10, -1 do
		local fits = TextService:GetTextSize(plain, s, Enum.Font.GothamBlack, Vector2.new(w, 1e4)).Y <= h
		for word in string.gmatch(plain, "%S+") do
			if TextService:GetTextSize(word, s, Enum.Font.GothamBlack, Vector2.new(1e4, 1e4)).X > w then
				fits = false
				break
			end
		end
		if fits then
			return s
		end
	end
	return 10
end
function UI.text(text, x, y, w, h, size, color, align, outline, opts)
	opts = opts or {}
	if opts.fit then
		size = fitSize(text, size, w, h)
	end
	return e("TextLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(x, y),
		Size = UDim2.fromOffset(w, h),
		Text = text,
		Font = Enum.Font.GothamBlack,
		TextSize = size,
		TextColor3 = color or Theme.colors.white,
		TextXAlignment = align or Enum.TextXAlignment.Center,
		TextWrapped = true,
		RichText = opts.rich or false,
		ZIndex = 8,
	}, {
		Outline = e("UIStroke", {
			Color = Theme.colors.ink,
			Thickness = outline or Theme.outline,
			StrokeSizingMode = Enum.StrokeSizingMode.FixedSize,
			LineJoinMode = Enum.LineJoinMode.Round,
		}),
	})
end
function UI.hex(color)
	return "#" .. color:ToHex()
end
function UI.icon(key, x, y, w, h, color)
	local a = Assets[key]
	if not a then
		return nil
	end
	local properties = {
		Name = key,
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(x, y),
		Size = UDim2.fromOffset(w, h),
		Image = a.image,
		ImageRectOffset = a.offset or Vector2.zero,
		ImageRectSize = a.rect or Vector2.zero,
		ImageColor3 = color or Color3.new(1, 1, 1),
		ScaleType = Enum.ScaleType.Fit,
		ZIndex = 7,
	}
	if a.outlineExtension then
		local children = {}
		for i = 1, 8 do
			local angle = i * math.pi / 4
			local layer = table.clone(properties)
			layer.Position =
				UDim2.fromOffset(math.cos(angle) * a.outlineExtension, math.sin(angle) * a.outlineExtension)
			layer.Size = UDim2.fromScale(1, 1)
			layer.ImageColor3 = Theme.colors.ink
			layer.ZIndex = 1
			children["Contour" .. i] = e("ImageLabel", layer)
		end
		properties.Position = UDim2.fromOffset(0, 0)
		properties.Size = UDim2.fromScale(1, 1)
		properties.ZIndex = 2
		children.Image = e("ImageLabel", properties)
		return e("Frame", {
			Name = key,
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(x, y),
			Size = UDim2.fromOffset(w, h),
			ZIndex = 7,
		}, children)
	end
	return e("ImageLabel", properties)
end
function UI.Surface(p)
	if p.variant == "utility" then
		return e("Frame", {
			Name = p.name,
			BackgroundColor3 = p.selected and Theme.colors.muted or Theme.colors.ink,
			BackgroundTransparency = p.selected and 0.15 or 0.35,
			BorderSizePixel = 0,
			Position = p.position or UDim2.fromOffset(p.x or 0, p.y or 0),
			Size = p.size or UDim2.fromOffset(p.w, p.h),
			ZIndex = p.z or 1,
		}, {
			Corner = corner(Theme.radius),
			Selected = p.selected and e("UIStroke", {
				Name = "SelectedOutline",
				Color = Theme.colors.white,
				Thickness = 2,
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
				StrokeSizingMode = Enum.StrokeSizingMode.FixedSize,
			}) or nil,
			Content = e(
				"Frame",
				{ Name = "Content", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 6 },
				p.children
			),
		})
	end
	return e(IndexSurface, p)
end
function UI.Button(p)
	local inputEnabled = React.useContext(UI.InputEnabled)
	local reduced = React.useContext(UI.ReducedMotion)
	local binding, update = React.useBinding(0)
	local states = React.useRef({ hover = false, pressed = false })
	local hoverScale = p.hoverScale or (p.w > 240 and Theme.motion.denseHoverScale or Theme.motion.hoverScale)
	local tilt = p.w > 240 and Theme.motion.denseTilt or Theme.motion.tilt
	-- -1/1: the side the pointer entered from; the hover tilt leans that way.
	local side = React.useRef(1)
	local motion = React.useMemo(function()
		return Ripple.createSpring(0, {
			frequency = Theme.motion.frequency,
			dampingRatio = Theme.motion.dampingRatio,
			precision = Theme.motion.precision,
			start = true,
		})
	end, {})
	-- Scale one centered visual subtree. Keep layout, child geometry and stroke
	-- thickness in design units; Roblox applies the shared scale exactly once.
	local scaleBinding = React.useMemo(function()
		return binding:map(function(t)
			return t < 0 and 1 + (1 - Theme.motion.pressedScale) * t or 1 + (hoverScale - 1) * t
		end)
	end, { binding, hoverScale })
	local rotationBinding = React.useMemo(function()
		return binding:map(function(t)
			return math.max(t, 0) * tilt * side.current
		end)
	end, { binding, tilt })
	React.useEffect(function()
		local disconnect = motion:onChange(update)
		return function()
			disconnect()
			motion:destroy()
		end
	end, { motion })
	local function state(key, value)
		if states.current[key] == value then
			return
		end
		states.current[key] = value
		local s = states.current
		local goal = (p.disabled or not inputEnabled) and 0 or (s.pressed and -1 or (s.hover and 1 or 0))
		if reduced then
			motion:stop()
			motion:setGoal(goal)
			motion:setPosition(goal)
			motion:setVelocity(0)
			update(goal)
		elseif motion:getGoal() ~= goal then
			motion:start()
			motion:setGoal(goal)
		end
	end
	React.useEffect(function()
		if p.disabled or not inputEnabled then
			states.current = { hover = false, pressed = false }
			motion:stop()
			motion:setGoal(0)
			motion:setPosition(0)
			motion:setVelocity(0)
			update(0)
		end
	end, { p.disabled, inputEnabled })
	React.useEffect(function()
		if reduced then
			local goal = motion:getGoal()
			motion:stop()
			motion:setPosition(goal)
			motion:setVelocity(0)
			update(goal)
		end
	end, { reduced })
	local function press(input, value)
		if
			input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			state("pressed", value)
		end
	end
	React.useEffect(function()
		local ended = UserInputService.InputEnded:Connect(function(input)
			press(input, false)
		end)
		local lost = UserInputService.WindowFocusReleased:Connect(function()
			state("pressed", false)
			state("hover", false)
		end)
		return function()
			ended:Disconnect()
			lost:Disconnect()
		end
	end, { p.disabled, inputEnabled, reduced })
	local contents = React.useMemo(function()
		local children = table.clone(p.children or {})
		if p.label then
			local inset = math.min(10, p.w * 0.15)
			children.Label = UI.text(
				p.label,
				p.icon and 62 or inset,
				p.h < 40 and 1 or 3,
				p.w - (p.icon and 74 or inset * 2),
				p.h - (p.h < 40 and 2 or 10),
				p.textSize or 30,
				p.textColor,
				nil,
				(p.variant == "index" or p.variant == "shop") and Theme.index.outline or nil
			)
		end
		if p.icon then
			local iconSize = math.min(48, p.w - 16, p.h - 14)
			children.Icon =
				UI.icon(p.icon, p.label and 8 or (p.w - iconSize) / 2, (p.h - iconSize) / 2, iconSize, iconSize)
		end
		return children
	end, { p.children, p.label, p.icon, p.w, p.h, p.textSize, p.textColor, p.variant })
	return e("TextButton", {
		Name = p.name or p.label,
		ref = p.buttonRef,
		Position = p.position or UDim2.fromOffset(p.x or 0, p.y or 0),
		Size = UDim2.fromOffset(p.w, p.h),
		Text = "",
		BackgroundTransparency = 1,
		AutoButtonColor = false,
		Selectable = false,
		Active = inputEnabled and not p.disabled,
		ZIndex = p.z or 1,
		[React.Event.Activated] = function()
			if inputEnabled and not p.disabled and p.onClick then
				Audio.play("UIClick")
				p.onClick()
			end
		end,
		[React.Event.MouseEnter] = function(rbx, x)
			side.current = x < rbx.AbsolutePosition.X + rbx.AbsoluteSize.X / 2 and -1 or 1
			state("hover", true)
		end,
		[React.Event.MouseLeave] = function()
			state("pressed", false)
			state("hover", false)
		end,
		[React.Event.InputBegan] = function(_, input)
			if inputEnabled and not p.disabled then
				press(input, true)
				if p.onInput then
					p.onInput(input)
				end
			end
		end,
		[React.Event.InputEnded] = function(_, input)
			press(input, false)
		end,
	}, {
		Visual = e("Frame", {
			Name = "Visual",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(p.w, p.h),
			Rotation = rotationBinding,
			BackgroundTransparency = 1,
		}, {
			Scale = e("UIScale", { Scale = scaleBinding }),
			Surface = e(UI.Surface, {
				w = p.w,
				h = p.h,
				variant = p.variant,
				motion = binding,
				color = p.disabled and (p.disabledColor or Theme.colors.muted) or p.color,
				selected = p.selected,
				quiet = p.quiet,
				halftone = p.halftone,
				children = contents,
			}),
		}),
	})
end
function UI.Transition(p)
	local inputEnabled = React.useContext(UI.InputEnabled)
	local progress, update = React.useBinding(0)
	local dimProgress, updateDim = React.useBinding(0)
	local latest = React.useRef(p)
	latest.current = p
	-- onClosed fires once per close: early (closedAt) or on completion, whichever comes first.
	local notified = React.useRef(false)
	local function finish()
		if not notified.current and not latest.current.visible and latest.current.onClosed then
			notified.current = true
			latest.current.onClosed()
		end
	end
	local motion, dim = table.unpack(React.useMemo(function()
		local function spring()
			return Ripple.createSpring(0, {
				frequency = Theme.motion.transitionFrequency,
				dampingRatio = 1,
				precision = Theme.motion.transitionPrecision,
				start = true,
			})
		end
		return { spring(), spring() }
	end, {}))
	React.useEffect(function()
		local change = motion:onChange(function(value)
			update(value)
			-- The window is already invisible here; the rest of the spring tail would only delay the HUD.
			if value <= Theme.motion.closedAt then
				finish()
			end
		end)
		local complete = motion:onComplete(function(value)
			if value == 0 then
				finish()
			end
		end)
		local changeDim = dim:onChange(updateDim)
		return function()
			change()
			complete()
			changeDim()
			motion:destroy()
			dim:destroy()
		end
	end, { motion })
	React.useEffect(function()
		motion:setPosition(0)
		motion:setVelocity(0)
		update(0)
	end, { p.transitionKey })
	React.useEffect(function()
		local goal = p.visible and 1 or 0
		if p.visible then
			notified.current = false
		end
		if p.reduced then
			for _, spring in { motion, dim } do
				spring:stop()
				spring:setGoal(goal)
				spring:setPosition(goal)
				spring:setVelocity(0)
			end
			update(goal)
			updateDim(goal)
			if goal == 0 then
				task.defer(finish)
			end
		else
			-- Opening is a little slower and overshoots; closing settles without bounce.
			-- The backdrop follows visibility only, so switching windows does not flash it.
			local options = goal == 1
					and { frequency = Theme.motion.openFrequency, dampingRatio = Theme.motion.openDampingRatio }
				or { frequency = Theme.motion.transitionFrequency, dampingRatio = 1 }
			motion:start()
			motion:setGoal(goal, options)
			dim:start()
			dim:setGoal(goal, { frequency = options.frequency, dampingRatio = 1 })
		end
	end, { p.visible, p.transitionKey, p.reduced })
	local backdrop = p.backdrop
	return e("Frame", {
		Name = p.name or "Transition",
		Position = UDim2.fromOffset(p.x, p.y),
		Size = UDim2.fromOffset(p.w, p.h),
		BackgroundTransparency = 1,
		ZIndex = p.z or 2,
	}, {
		-- Full-screen dimmer behind the window; fades with it and blocks clicks to the scene.
		Backdrop = backdrop and e("TextButton", {
			Name = backdrop.name,
			Position = UDim2.fromOffset(-p.x, -p.y),
			Size = UDim2.fromOffset(backdrop.w, backdrop.h),
			BackgroundColor3 = backdrop.color,
			BackgroundTransparency = dimProgress:map(function(t)
				return 1 - (1 - backdrop.transparency) * math.clamp(t, 0, 1)
			end),
			Text = "",
			AutoButtonColor = false,
			Selectable = false,
			ZIndex = 0,
		}),
		Group = e("CanvasGroup", {
			Name = "AnimatedGroup",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Size = UDim2.fromOffset(p.w + 32, p.h + 32),
			BackgroundTransparency = 1,
			Position = progress:map(function(t)
				return UDim2.fromOffset(
					p.w / 2 + (p.slide and (1 - t) * (p.w + 32) or 0),
					p.h / 2 + (p.slide and 0 or (1 - t) * 10)
				)
			end),
			GroupTransparency = progress:map(function(t)
				return 1 - math.clamp(t, 0, 1)
			end),
		}, {
			-- Modal windows grow in from openScale; slide-in panels keep their size.
			Scale = not p.slide and e("UIScale", {
				Scale = progress:map(function(t)
					return Theme.motion.openScale + (1 - Theme.motion.openScale) * t
				end),
			}) or nil,
			Content = e("Frame", {
				Name = "Content",
				Position = UDim2.fromOffset(16, 16),
				Size = UDim2.fromOffset(p.w, p.h),
				BackgroundTransparency = 1,
			}, {
				Input = e(UI.InputEnabled.Provider, { value = p.visible and inputEnabled }, p.children),
			}),
		}),
	})
end
function UI.progress(label, value, total, x, y, w, h, color, variant)
	local ratio = total > 0 and math.clamp(value / total, 0, 1) or 0
	if variant == "index" then
		return e(UI.Surface, {
			variant = "index",
			x = x,
			y = y,
			w = w,
			h = h,
			color = Theme.colors.body,
			quiet = true,
			children = {
				Fill = ratio > 0 and e("Frame", {
					Name = "ProgressFill",
					Position = UDim2.fromOffset(7, 7),
					Size = UDim2.fromOffset((w - 14) * ratio, h - 18),
					BackgroundColor3 = color,
					BorderSizePixel = 0,
					ZIndex = 5,
				}, {
					Corner = corner(4),
					Gradient = e("UIGradient", {
						Rotation = 90,
						Color = ColorSequence.new(
							color:Lerp(Theme.colors.white, 0.15),
							color:Lerp(Theme.colors.ink, 0.12)
						),
					}),
					Studs = e("ImageLabel", {
						BackgroundTransparency = 1,
						Size = UDim2.fromScale(1, 1),
						Image = Theme.studs,
						ScaleType = Enum.ScaleType.Tile,
						TileSize = UDim2.fromScale(40 / (w - 14), 40 / (h - 18)),
						ImageColor3 = Theme.colors.ink,
						ImageTransparency = 0.88,
						ZIndex = 5,
					}, { Corner = corner(4) }),
				}) or nil,
				Label = UI.text(
					label .. " " .. value .. "/" .. total,
					12,
					4,
					w - 24,
					h - 10,
					24,
					nil,
					nil,
					Theme.index.outline
				),
			},
		})
	end
	return e(UI.Surface, {
		x = x,
		y = y,
		w = w,
		h = h,
		color = Theme.colors.muted,
		quiet = true,
		children = {
			Fill = e("Frame", {
				Position = UDim2.fromOffset(3, 3),
				Size = UDim2.new(ratio, -6, 1, -11),
				BackgroundColor3 = color,
				BorderSizePixel = 0,
				ZIndex = 5,
			}, { Corner = corner(3) }),
			Label = UI.text(label .. " " .. value .. "/" .. total, 12, 4, w - 24, h - 10, 30),
		},
	})
end
UI.Button = React.memo(UI.Button)
UI.Surface = React.memo(UI.Surface)
return UI
