local React = require(game.ReplicatedStorage.Packages.React)
local TextService = game:GetService("TextService")
local Ripple = require(game.ReplicatedStorage.Packages.Ripple)
local Game = require(game.ReplicatedStorage.GameConfig)
local UI = require(script.Parent.UI)
local Figma = require(script.Parent.FigmaTemplate)
local Theme = require(script.Parent.Theme)
local e = React.createElement
local CONFIRM_SECONDS = 3

local function multiplier(value)
	return "x" .. (string.format("%.1f", value):gsub("%.0$", ""))
end

-- Dynamic numbers shrink within the imported text boxes, never above the design size.
local function fit(fits, parent, name)
	local labels = { parent:FindFirstChild(name), parent:FindFirstChild(name .. "_Shadow") }
	for _, label in labels do
		label.TextScaled = false
		label.TextWrapped = false
	end
	table.insert(fits, { labels = labels, maxSize = labels[1].TextSize })
end

local function fitText(item)
	local label = item.labels[1]
	if item.text == label.Text then
		return
	end
	local params = Instance.new("GetTextBoundsParams")
	params.Font = label.FontFace
	params.Text = string.gsub(label.Text, "<[^>]->", "")
	params.Size = item.maxSize
	params.Width = 1000000
	local ok, bounds = pcall(TextService.GetTextBoundsAsync, TextService, params)
	params:Destroy()
	if not ok then
		return
	end
	local ratio =
		math.min(1, (label.Size.X.Offset - 6) / math.max(1, bounds.X), label.Size.Y.Offset / math.max(1, bounds.Y))
	local size = math.max(1, math.floor(item.maxSize * ratio))
	for _, text in item.labels do
		text.TextSize = size
	end
	item.text = label.Text
end

local function build(latest)
	local root = Figma.get("Rebirth").RebirthFrame:Clone()
	root.Name = "RebirthWindow"
	root.AnchorPoint = Vector2.new(0.5, 0.5)
	root.Position = UDim2.fromScale(0.5, 0.5)
	local scale = root:FindFirstChildOfClass("UIScale") or Instance.new("UIScale")
	scale.Parent = root
	local main = root.MainFrame
	main.ConfirmAction.Visible = false
	local fits = {}
	fit(fits, main, "Count")
	fit(fits, main, "ResetNote")
	fit(fits, main, "KeepNote")
	fit(fits, main.IncomeBonus, "Values")
	fit(fits, main.LuckBonus, "Values")
	fit(fits, main.RebirthProgress, "Label")
	fit(fits, main.RebirthAction, "Label")
	fit(fits, main.ConfirmAction, "Label")
	local function enabled()
		return latest.current.inputEnabled and latest.current.enabled and not latest.current.busy
	end
	local function ready()
		local p = latest.current
		local cost = Game.rebirthCost(p.data.Rebirths or 0)
		return enabled() and cost <= Game.MaxCash and (p.data.Cash or 0) >= cost
	end
	local function reduced()
		return latest.current.reduced
	end
	local function rebirth()
		local p = latest.current
		if not p.confirming then
			p.setConfirming(true)
			return
		end
		p.setConfirming(false)
		p.onAction("Rebirth", {})
	end
	local actionButton = Figma.button(main.RebirthAction, rebirth, ready, reduced, "RebirthButton")
	local confirmButton = Figma.button(main.ConfirmAction, rebirth, ready, reduced, "ConfirmRebirthButton")
	local buttons = {
		Figma.button(root.ExitBtn, function()
			latest.current.onClose()
		end, enabled, reduced, "CloseWindow"),
		actionButton,
		confirmButton,
	}
	Figma.clipMasks(root)
	table.insert(buttons, Figma.idle(root.Header.Studs, "conveyor", 0, reduced))
	for i, card in { main.IncomeBonus, main.LuckBonus } do
		table.insert(buttons, Figma.idle(card.Icon, "sway", (i - 1) * 0.8, reduced))
		for _, stripe in card.Artwork.Mask:GetChildren() do
			if string.match(stripe.Name, "^Shine%d+$") then
				table.insert(buttons, Figma.idle(stripe, "shine", (i - 1) * 0.3, reduced))
			end
		end
	end
	Figma.reveal({ main.IncomeBonus, main.LuckBonus, main.RebirthProgress }, reduced())
	local veil = Instance.new("Frame")
	veil.Name = "DisabledVeil"
	veil.BackgroundColor3 = Color3.new(0, 0, 0)
	veil.BackgroundTransparency = 0.45
	veil.BorderSizePixel = 0
	veil.Size = UDim2.fromScale(1, 1)
	veil.ZIndex = main.RebirthAction.Label.ZIndex - 1
	veil.Parent = main.RebirthAction
	local fill = main.RebirthProgress.Fill
	local fillSize = fill.Size
	local function applyProgress(value)
		value = math.clamp(value, 0, 1)
		fill.Size = UDim2.fromOffset(fillSize.X.Offset * value, fillSize.Y.Offset)
		fill.Visible = value > 0
	end
	local p = latest.current
	local cost = Game.rebirthCost(p.data.Rebirths or 0)
	local ratio = cost > Game.MaxCash and 1 or math.clamp((p.data.Cash or 0) / cost, 0, 1)
	local progress = Ripple.createSpring(ratio, {
		frequency = Theme.motion.frequency,
		dampingRatio = Theme.motion.dampingRatio,
		precision = 0.0001,
		start = false,
	})
	local disconnectProgress = progress:onChange(applyProgress)
	applyProgress(ratio)
	return {
		root = root,
		main = main,
		fits = fits,
		scale = scale,
		buttons = buttons,
		actionButton = actionButton,
		confirmButton = confirmButton,
		veil = veil,
		progress = progress,
		applyProgress = applyProgress,
		disconnectProgress = disconnectProgress,
	}
end

local function update(view, p)
	local root = view.root
	local main = view.main
	view.scale.Scale = math.min(p.width / root.Size.X.Offset, p.height / root.Size.Y.Offset)
	local count = p.data.Rebirths or 0
	local cash = p.data.Cash or 0
	local cost = Game.rebirthCost(count)
	local maxed = cost > Game.MaxCash
	local ready = not maxed and cash >= cost
	Figma.setText(main, "Count", "Rebirths: " .. count)
	Figma.setText(
		main.IncomeBonus,
		"Values",
		multiplier(Game.rebirthIncome(count)) .. "  >  " .. multiplier(Game.rebirthIncome(count + 1))
	)
	Figma.setText(
		main.LuckBonus,
		"Values",
		multiplier(Game.rebirthLuck(count)) .. "  >  " .. multiplier(Game.rebirthLuck(count + 1))
	)
	local ratio = maxed and 1 or math.clamp(cash / cost, 0, 1)
	if p.reduced then
		view.progress:stop()
		view.progress:setGoal(ratio)
		view.progress:setPosition(ratio)
		view.progress:setVelocity(0)
		view.applyProgress(ratio)
	elseif view.progress:getGoal() ~= ratio then
		view.progress:start()
		view.progress:setGoal(ratio)
	end
	Figma.setText(
		main.RebirthProgress,
		"Label",
		maxed and "MAX" or "$" .. Game.number(math.min(cash, cost)) .. " / $" .. Game.number(cost)
	)
	local confirming = p.confirming and ready and p.enabled
	main.RebirthAction.Visible = not confirming
	main.ConfirmAction.Visible = confirming
	view.veil.Visible = not ready or p.busy
	if view.confirming ~= confirming then
		if confirming then
			view.confirmButton.pulse()
		end
		view.confirming = confirming
	end
	Figma.setText(
		main.RebirthAction,
		"Label",
		maxed and "MAX REBIRTH"
			or not ready and "Need $" .. Game.number(cost - cash) .. " more"
			or p.busy and "REBIRTHING..."
			or "REBIRTH  ·  $" .. Game.number(cost)
	)
	for _, button in view.buttons do
		button.refresh()
	end
	for _, item in view.fits do
		fitText(item)
	end
end

local function FigmaRebirthWindow(p)
	local confirming, setConfirming = React.useState(false)
	local inputEnabled = React.useContext(UI.InputEnabled)
	local reduced = React.useContext(UI.ReducedMotion)
	local host = React.useRef(nil)
	local view = React.useRef(nil)
	local latest = React.useRef(nil)
	local props = table.clone(p)
	props.inputEnabled = inputEnabled
	props.reduced = reduced or p.reduced
	props.confirming = confirming
	props.setConfirming = setConfirming
	latest.current = props
	local cost = Game.rebirthCost(p.data.Rebirths or 0)
	local ready = cost <= Game.MaxCash and (p.data.Cash or 0) >= cost
	React.useEffect(function()
		if not confirming then
			return
		end
		local thread = task.delay(CONFIRM_SECONDS, function()
			setConfirming(false)
		end)
		return function()
			task.cancel(thread)
		end
	end, { confirming })
	React.useEffect(function()
		if not p.enabled or not ready then
			setConfirming(false)
		end
	end, { p.enabled, ready })
	React.useEffect(function()
		local ok, built = pcall(build, latest)
		if not ok then
			warn("Figma template Rebirth: " .. tostring(built))
			return
		end
		view.current = built
		update(built, latest.current)
		built.root.Parent = host.current
		return function()
			for _, button in built.buttons do
				button.destroy()
			end
			built.disconnectProgress()
			built.progress:destroy()
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
		Name = "Rebirth",
		ref = host,
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(p.width, p.height),
	})
end

return FigmaRebirthWindow
