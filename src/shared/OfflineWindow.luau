-- Offline Cash window from the Figma import (ReplicatedStorage.UITemplates.OfflineCash, frame "OfflineFrame").
local React = require(game.ReplicatedStorage.Packages.React)
local UI = require(script.Parent.UI)
local Figma = require(script.Parent.FigmaTemplate)
local e = React.createElement
-- The import has no close button of its own; Trails Shop's ExitBtn is the same design, at the header's right end.
local EXIT_POSITION = UDim2.fromOffset(922, 9)

local function build(latest)
	local source = Figma.get("OfflineCash")["Offline Cash Window"].OfflineFrame
	local root = source:Clone()
	root.Name = "OfflineWindow"
	root.AnchorPoint = Vector2.new(0.5, 0.5)
	root.Position = UDim2.fromScale(0.5, 0.5)
	root.Size = UDim2.fromOffset(source.Size.X.Offset, source.Size.Y.Offset)
	local scale = root:FindFirstChildOfClass("UIScale") or Instance.new("UIScale")
	scale.Parent = root
	local reward = root.OfflineReward
	Figma.nameTexts(reward, { "Earned", "Amount" })
	Figma.nameTexts(reward.ClaimOffline, { "Label" })
	Figma.nameTexts(reward.DoubleOffline, { "Label", "Status" })
	local exit = Figma.get("TrailsShop")["Trails Shop Window"].ExitBtn:Clone()
	exit.Position = EXIT_POSITION
	exit.ZIndex = 10
	exit.Parent = root
	local function reduced()
		return latest.current.reduced
	end
	Figma.studs(root, reduced)
	local buttons = {
		Figma.button(exit, function()
			latest.current.onClose()
		end, function()
			return latest.current.inputEnabled
		end, reduced, "CloseWindow"),
		Figma.button(reward.ClaimOffline, function()
			latest.current.onClaim()
		end, function()
			return latest.current.inputEnabled and not latest.current.busy
		end, reduced, "ClaimOffline"),
	}
	table.insert(buttons, Figma.idle(reward.Cash, "sway", 0, reduced))
	table.insert(buttons, Figma.idle(reward.Burst, "spin", 0, reduced))
	return {
		root = root,
		scale = scale,
		reward = reward,
		claim = reward.ClaimOffline,
		-- Keeps the RichText size tag of the design around the amount.
		amountFormat = string.gsub(reward.Amount.Text, ">[^<]*<", ">%%s<", 1),
		buttons = buttons,
	}
end

local function update(view, p)
	view.scale.Scale = math.min(p.width / view.root.Size.X.Offset, p.height / view.root.Size.Y.Offset)
	local amount = "$" .. p.amount
	Figma.setText(
		view.reward,
		"Amount",
		string.find(view.amountFormat, "%%s") and string.format(view.amountFormat, amount) or amount
	)
	Figma.setText(view.claim, "Label", p.busy and "CLAIMING..." or "CLAIM")
	for _, button in view.buttons do
		button.refresh()
	end
end

local function OfflineWindow(p)
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
			warn("Figma template OfflineCash: " .. tostring(built))
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
		Name = "Offline Cash",
		ref = host,
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(p.width, p.height),
	})
end

return OfflineWindow
