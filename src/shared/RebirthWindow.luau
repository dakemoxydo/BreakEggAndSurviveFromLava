-- Rebirth window body: current -> next bonuses, Cash progress to the price and a two-tap confirm.
-- The server applies the rebirth (UIAction "Rebirth"); this screen only shows and requests it.
local React = require(game.ReplicatedStorage.Packages.React)
local Game = require(game.ReplicatedStorage.GameConfig)
local UI = require(script.Parent.UI)
local Theme = require(script.Parent.Theme)
local e = React.createElement
local C = Theme.colors
local CONFIRM_SECONDS = 3

local function multiplier(value)
	return "x" .. (string.format("%.1f", value):gsub("%.0$", ""))
end

local function bonusCard(name, x, y, w, h, title, now, after, color, compact)
	return e(UI.Surface, {
		name = name,
		x = x,
		y = y,
		w = w,
		h = h,
		color = color,
		children = {
			Title = UI.text(title, 12, 8, w - 24, compact and 30 or 36, compact and 24 or 30),
			Values = UI.text(
				now .. "  >  " .. after,
				12,
				compact and 38 or 48,
				w - 24,
				h - (compact and 50 or 64),
				compact and 36 or 52,
				C.gold
			),
		},
	})
end

local function RebirthWindow(p)
	local confirming, setConfirming = React.useState(false)
	local rebirths = p.data.Rebirths or 0
	local cash = p.data.Cash or 0
	local cost = Game.rebirthCost(rebirths)
	local maxed = cost > Game.MaxCash
	local ready = not maxed and cash >= cost
	-- A pending confirmation expires, and closing or losing the price cancels it.
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

	local compact = p.width < 580
	local pad = compact and 16 or 28
	local inner = p.width - pad * 2
	local y = compact and 10 or 16
	local body = {}
	body.Count = UI.text(
		"Rebirths: " .. rebirths,
		pad,
		y,
		inner,
		compact and 30 or 36,
		compact and 24 or 30,
		nil,
		Enum.TextXAlignment.Left
	)
	y += compact and 38 or 48
	local cardH = compact and 104 or 136
	if compact then
		body.Income = bonusCard(
			"IncomeBonus",
			pad,
			y,
			inner,
			cardH,
			"Income",
			multiplier(Game.rebirthIncome(rebirths)),
			multiplier(Game.rebirthIncome(rebirths + 1)),
			C.green,
			true
		)
		body.Luck = bonusCard(
			"LuckBonus",
			pad,
			y + cardH + 12,
			inner,
			cardH,
			"Egg Luck",
			multiplier(Game.rebirthLuck(rebirths)),
			multiplier(Game.rebirthLuck(rebirths + 1)),
			C.blue,
			true
		)
		y += cardH * 2 + 24
	else
		local half = (inner - 20) / 2
		body.Income = bonusCard(
			"IncomeBonus",
			pad,
			y,
			half,
			cardH,
			"Income",
			multiplier(Game.rebirthIncome(rebirths)),
			multiplier(Game.rebirthIncome(rebirths + 1)),
			C.green,
			false
		)
		body.Luck = bonusCard(
			"LuckBonus",
			pad + half + 20,
			y,
			half,
			cardH,
			"Egg Luck",
			multiplier(Game.rebirthLuck(rebirths)),
			multiplier(Game.rebirthLuck(rebirths + 1)),
			C.blue,
			false
		)
		y += cardH + 20
	end
	local barH = compact and 44 or 52
	local ratio = maxed and 1 or math.clamp(cash / cost, 0, 1)
	body.Progress = e(UI.Surface, {
		name = "RebirthProgress",
		x = pad,
		y = y,
		w = inner,
		h = barH,
		color = C.muted,
		quiet = true,
		children = {
			Fill = ratio > 0 and e("Frame", {
				Name = "Fill",
				Position = UDim2.fromOffset(3, 3),
				Size = UDim2.new(ratio, -6, 1, -11),
				BackgroundColor3 = ready and C.green or C.gold,
				BorderSizePixel = 0,
				ZIndex = 5,
			}, { Corner = e("UICorner", { CornerRadius = UDim.new(0, 3) }) }) or nil,
			Label = UI.text(
				maxed and "MAX" or "$" .. Game.number(math.min(cash, cost)) .. " / $" .. Game.number(cost),
				12,
				2,
				inner - 24,
				barH - 10,
				compact and 24 or 28
			),
		},
	})
	y += barH + 12
	body.Note = UI.text(
		"Resets your Cash and Speed. Pets, pickaxes, trails and upgrades stay.",
		pad,
		y,
		inner,
		compact and 52 or 40,
		compact and 19 or 22,
		C.white:Lerp(C.muted, 0.25)
	)
	y += compact and 60 or 50
	local buttonH = compact and 58 or 66
	body.Rebirth = e(UI.Button, {
		name = "RebirthButton",
		x = pad,
		y = y,
		w = inner,
		h = buttonH,
		color = confirming and C.red or C.gold,
		label = maxed and "MAX REBIRTH"
			or not ready and "Need $" .. Game.number(cost - cash) .. " more"
			or confirming and "TAP AGAIN TO REBIRTH"
			or "REBIRTH  ·  $" .. Game.number(cost),
		disabled = p.busy or not p.enabled or not ready,
		textSize = compact and 24 or 32,
		onClick = function()
			if not confirming then
				setConfirming(true)
				return
			end
			setConfirming(false)
			p.onAction("Rebirth", {})
		end,
	})
	y += buttonH + pad
	local available = math.max(1, p.height - p.headerH)
	return e("ScrollingFrame", {
		Name = "RebirthBody",
		Position = UDim2.fromOffset(0, p.headerH),
		Size = UDim2.fromOffset(p.width, available),
		CanvasSize = UDim2.fromOffset(0, y),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = y > available and 5 or 0,
		Active = true,
	}, body)
end

return RebirthWindow
