-- Rewards window from the Figma import (ReplicatedStorage.UITemplates.Rewards, frame "Rewards Window").
-- Daily Reward opens once per Game.RewardDay. The Day row scrolls sideways through every Game.StreakRewards
-- day; each card is a copy of the template card drawn for its reward kind. Timers follow the server clock.
local React = require(game.ReplicatedStorage.Packages.React)
local TweenService = game:GetService("TweenService")
local Game = require(game.ReplicatedStorage.GameConfig)
local UI = require(script.Parent.UI)
local Theme = require(script.Parent.Theme)
local Figma = require(script.Parent.FigmaTemplate)
local e = React.createElement
local DESIGN = Vector2.new(1920, 1080)
-- Template card per reward kind.
local TEMPLATE = { Speed = "Day1", Cash = "Day2", Egg = "Day3", Chest = "Day4" }
local SCROLL_TWEEN = TweenInfo.new(0.45, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
local SHADE = 0.45
local OPEN_SETTLE = 0.5

local function offsetOf(object)
	return Vector2.new(object.Position.X.Offset, object.Position.Y.Offset)
end

local function sizeOf(object)
	return Vector2.new(object.Size.X.Offset, object.Size.Y.Offset)
end

local function clock(seconds)
	seconds = math.max(0, math.ceil(seconds))
	return string.format("%02d:%02d:%02d", seconds // 3600, seconds // 60 % 60, seconds % 60)
end

-- Button labels change length (CLAIM, CLAIMED, 23:59:59): they shrink to fit, never above the design size.
local function fit(parent, name)
	for _, label in { parent:FindFirstChild(name), parent:FindFirstChild(name .. "_Shadow") } do
		local limit = Instance.new("UITextSizeConstraint")
		limit.MaxTextSize = label.TextSize
		limit.Parent = label
		label.TextScaled = true
	end
end

-- A dark cover over `parent` with the rounding of its Top layer; hidden until update shows it.
local function shade(parent, name)
	local cover = Instance.new("Frame")
	cover.Name = name
	cover.BackgroundColor3 = Color3.new(0, 0, 0)
	cover.BackgroundTransparency = 1 - SHADE
	cover.BorderSizePixel = 0
	cover.Size = UDim2.fromScale(1, 1)
	cover.ZIndex = 20
	cover.Visible = false
	local corner = parent.Top:FindFirstChildOfClass("UICorner")
	if corner then
		corner:Clone().Parent = cover
	end
	cover.Parent = parent
	return cover
end

local function build(latest)
	local source = Figma.get("Rewards")["Rewards Window"]
	local frame = source.RewardsFrame:Clone()
	Figma.offset(frame, DESIGN)
	local origin, size = offsetOf(frame), sizeOf(frame)
	local root = Instance.new("Frame")
	root.Name = "RewardsWindow"
	root.BackgroundTransparency = 1
	root.AnchorPoint = Vector2.new(0.5, 0.5)
	root.Position = UDim2.fromScale(0.5, 0.5)
	root.Size = UDim2.fromOffset(size.X, size.Y)
	local scale = Instance.new("UIScale")
	scale.Parent = root
	frame.Position = UDim2.fromOffset(0, 0)
	frame.Parent = root
	local exit = source.ExitBtn:Clone()
	Figma.offset(exit, DESIGN)
	local exitAt = offsetOf(exit) - origin
	exit.Position = UDim2.fromOffset(exitAt.X, exitAt.Y)
	exit.ZIndex = 10
	exit.Parent = root
	local function reduced()
		return latest.current.reduced
	end
	local function ready()
		return latest.current.inputEnabled and latest.current.enabled
	end
	local view = { root = root, scale = scale }
	view.buttons = {
		Figma.button(exit, function()
			latest.current.onClose()
		end, function()
			return latest.current.inputEnabled
		end, reduced, "CloseWindow"),
	}
	local main = frame.MainFrame
	-- Daily Reward: its SunBurst turns, so the card Mask clips as a CanvasGroup.
	local daily = main.DailyFrame.DailyReward
	Figma.clipMasks(daily)
	Figma.nameTexts(daily, { "Title" })
	Figma.nameTexts(daily.ClaimBtn, { "Label" })
	fit(daily.ClaimBtn, "Label")
	view.daily = daily
	view.dailyButton = Figma.button(daily.ClaimBtn, function()
		latest.current.onAction("ClaimDailyReward", {}, function()
			view.dailyButton.pulse()
		end)
	end, function()
		return ready() and view.dailyOpen
	end, reduced, "ClaimDaily")
	table.insert(view.buttons, view.dailyButton)
	-- Day row: the template lays the four cards out with a grid; the code places all days the same way.
	local days = main.DaysFrame
	Figma.offset(days, sizeOf(main))
	local grid = days:FindFirstChildOfClass("UIGridLayout")
	local padding = days:FindFirstChildOfClass("UIPadding")
	local cell, gap = Vector2.new(grid.CellSize.X.Offset, grid.CellSize.Y.Offset), grid.CellPadding.X.Offset
	local left, top, right = padding.PaddingLeft.Offset, padding.PaddingTop.Offset, padding.PaddingRight.Offset
	local templates = {}
	for kind, name in TEMPLATE do
		templates[kind] = days[name]
	end
	local scroll = Instance.new("ScrollingFrame")
	scroll.Name = "DaysFrame"
	scroll.AnchorPoint = days.AnchorPoint
	scroll.Position = days.Position
	scroll.Size = days.Size
	scroll.ZIndex = days.ZIndex
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.ScrollingDirection = Enum.ScrollingDirection.X
	scroll.ElasticBehavior = Enum.ElasticBehavior.Never
	scroll.ScrollBarThickness = 6
	scroll.ScrollBarImageColor3 = Theme.colors.white
	local count = #Game.StreakRewards
	scroll.CanvasSize = UDim2.new(0, left + count * cell.X + (count - 1) * gap + right, 1, 0)
	scroll.Parent = main
	view.scroll, view.step, view.left, view.cell, view.width = scroll, cell.X + gap, left, cell, scroll.Size.X.Offset
	view.cards = {}
	local reveal = { daily }
	for i, reward in Game.StreakRewards do
		local card = templates[reward.kind]:Clone()
		card.Name = "Day" .. i
		card.Position = UDim2.fromOffset(left + (i - 1) * view.step, top)
		card.Size = UDim2.fromOffset(cell.X, cell.Y)
		Figma.nameTexts(card, { "Title" })
		Figma.setText(card, "Title", "DAY " .. i)
		Figma.nameTexts(card.ClaimBtn, { "Label" })
		fit(card.ClaimBtn, "Label")
		-- Claimed days sit under a shade; a day not open yet shades only its button.
		local state = { card = card, shade = shade(card, "Claimed"), locked = shade(card.ClaimBtn, "Locked") }
		card.Parent = scroll
		state.button = Figma.button(card.ClaimBtn, function()
			latest.current.onAction("ClaimStreakReward", { day = i }, function()
				state.button.pulse()
			end)
		end, function()
			return ready() and state.open
		end, reduced, "ClaimDay" .. i)
		table.insert(view.buttons, state.button)
		view.cards[i] = state
		table.insert(reveal, card)
	end
	days:Destroy()
	-- Idle decor like the HUD: card Shine stripes sweep in turn, the Daily SunBurst turns, item icons sway.
	-- Button Masks stay still: they are CanvasGroups, which redraw on every change inside.
	local phase = 0
	for _, mask in frame:GetDescendants() do
		if mask.Name == "Mask" and not mask:FindFirstAncestor("ClaimBtn") then
			if mask:IsA("Frame") then
				mask.ClipsDescendants = true
			end
			for _, item in mask:GetChildren() do
				local kind = item.Name == "SunBurst" and "spin" or string.find(item.Name, "^Shine%d") and "shine"
				if kind then
					phase += 1
					table.insert(view.buttons, Figma.idle(item, kind, phase * 0.55, reduced))
				end
			end
		end
	end
	for i, card in reveal do
		local icon = card:FindFirstChild("Icon")
		if icon then
			table.insert(view.buttons, Figma.idle(icon, "sway", i * 0.9, reduced))
		end
	end
	Figma.studs(root, reduced)
	Figma.reveal(reveal, reduced())
	return view
end

-- Brings the next day to claim into the middle of the row. CanvasPosition is in screen pixels, so the
-- design target is scaled by the row's current on-screen size.
local function jump(view, smooth)
	local target = view.left + view.claimed * view.step - (view.width - view.cell.X) / 2
	local position = Vector2.new(math.max(0, target) * view.scroll.AbsoluteSize.X / view.width, 0)
	if smooth then
		TweenService:Create(view.scroll, SCROLL_TWEEN, { CanvasPosition = position }):Play()
	else
		view.scroll.CanvasPosition = position
	end
end

local function update(view, p)
	view.scale.Scale = math.min(p.width / view.root.Size.X.Offset, p.height / view.root.Size.Y.Offset)
	view.scroll.Active = p.inputEnabled
	local now = workspace:GetServerTimeNow()
	local data = p.data
	local dailyLeft = data.DailyRewardAt + Game.RewardDay - now
	view.dailyOpen = dailyLeft <= 0
	Figma.setText(view.daily.ClaimBtn, "Label", view.dailyOpen and "CLAIM!" or clock(dailyLeft))
	local claimed, open = Game.rewardStreak(data.RewardStreak, data.RewardStreakAt, now)
	local wait = data.RewardStreakAt + Game.RewardDay - now
	for i, state in view.cards do
		local was = state.open
		state.open = i == claimed + 1 and open
		Figma.setText(state.card.ClaimBtn, "Label", i <= claimed and "CLAIMED" or state.open and "CLAIM" or clock(wait))
		state.shade.Visible = i <= claimed
		state.locked.Visible = i > claimed and not state.open
		-- Later days hide their button until their turn.
		state.card.ClaimBtn.Visible = i <= claimed + 1
		if state.open and was == false then
			state.button.pulse()
		end
	end
	if view.claimed ~= claimed then
		local first = view.claimed == nil
		view.claimed = claimed
		if first then
			-- The window is still growing in (or not laid out yet): scroll once it has settled.
			task.delay(OPEN_SETTLE, function()
				if view.scroll.Parent then
					jump(view, not p.reduced)
				end
			end)
		else
			jump(view, not p.reduced)
		end
	end
	for _, button in view.buttons do
		button.refresh()
	end
end

local function RewardsWindow(p)
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
			warn("Figma template Rewards: " .. tostring(built))
			return
		end
		view.current = built
		built.root.Parent = host.current
		update(built, latest.current)
		-- Countdowns tick once a second while the window is open.
		local alive = true
		task.spawn(function()
			while alive do
				task.wait(1)
				if alive then
					update(built, latest.current)
				end
			end
		end)
		return function()
			alive = false
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
		Name = "Rewards",
		ref = host,
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(p.width, p.height),
	})
end

return RewardsWindow
