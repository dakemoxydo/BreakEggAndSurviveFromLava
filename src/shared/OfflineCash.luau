local React = require(game.ReplicatedStorage.Packages.React)
local UI = require(script.Parent.UI)
local Theme = require(script.Parent.Theme)
local e = React.createElement
local C = Theme.colors

-- The reward illustration and its amount form one composition, as in the reference.
local function OfflineCash(p)
	local w = p.width
	local h = p.height - p.headerH
	local narrow = w < 600
	local low = h < 330
	local margin = narrow and 18 or 28
	local gap = narrow and 14 or 24
	local buttonH = low and 58 or narrow and 72 or 100
	local buttonY = h - buttonH - margin
	local heroTop = low and 40 or narrow and 68 or 92
	local heroH = math.max(56, buttonY - heroTop - 12)
	local cashW = math.min(w - margin * 2, heroH * 1.48)
	local cashH = math.min(heroH, cashW / 1.3)
	local cashY = heroTop + (heroH - cashH) / 2
	local amountSize = math.min(narrow and 72 or 144, cashW * 0.29, (w - 48) / (#p.amount + 1) * 1.35)
	local claimW = (w - margin * 2 - gap) * 0.58
	local doubleW = w - margin * 2 - gap - claimW
	local burstSize = math.min(heroH, w - margin * 2)
	local burst =
		UI.icon("sunburst", (w - burstSize) / 2, heroTop + (heroH - burstSize) / 2, burstSize, burstSize, C.gold)
	if burst then
		local props = table.clone(burst.props)
		props.ImageTransparency = 0.76
		burst = e("ImageLabel", props)
	end
	local doubleContents = {
		Label = UI.text(
			"2x Cash",
			8,
			low and 4 or 10,
			doubleW - 16,
			low and 25 or 38,
			low and 23 or narrow and 25 or 38,
			C.white
		),
		Status = UI.text(
			"Unavailable",
			8,
			low and 31 or narrow and 45 or 58,
			doubleW - 16,
			24,
			narrow and 16 or 20,
			C.white
		),
	}
	return e(
		"Frame",
		{
			Name = "OfflineReward",
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(0, p.headerH),
			Size = UDim2.fromOffset(w, h),
		},
		{
			Glow = e(
				"Frame",
				{
					Name = "RewardGlow",
					Position = UDim2.fromOffset(8, 8),
					Size = UDim2.fromOffset(w - 16, buttonY - 4),
					BackgroundColor3 = C.green,
					BackgroundTransparency = 0.95,
					BorderSizePixel = 0,
					ZIndex = 1,
				},
				{
					Corner = e("UICorner", { CornerRadius = UDim.new(0, 8) }),
					Fade = e(
						"UIGradient",
						{
							Rotation = 90,
							Transparency = NumberSequence.new({
								NumberSequenceKeypoint.new(0, 1),
								NumberSequenceKeypoint.new(0.65, 0.2),
								NumberSequenceKeypoint.new(1, 1),
							}),
						}
					),
				}
			),
			Earned = UI.text(
				"You earned:",
				margin,
				low and 8 or 20,
				w - margin * 2,
				low and 32 or narrow and 40 or 60,
				low and 28 or narrow and 34 or 60
			),
			Burst = burst,
			Cash = UI.icon("cash", (w - cashW) / 2, cashY, cashW, cashH),
			Amount = UI.text(
				"$" .. p.amount,
				margin,
				cashY + cashH * 0.36,
				w - margin * 2,
				math.max(54, amountSize * 1.35),
				amountSize,
				C.green
			),
			Claim = e(
				UI.Button,
				{
					name = "ClaimOffline",
					label = p.busy and "Claiming..." or "Claim",
					x = margin,
					y = buttonY,
					w = claimW,
					h = buttonH,
					color = C.green,
					textSize = low and 32 or narrow and 38 or 64,
					halftone = true,
					hoverScale = 1.025,
					disabled = p.busy,
					onClick = p.onClaim,
				}
			),
			Double = e(
				UI.Button,
				{
					name = "DoubleOffline",
					x = margin + claimW + gap,
					y = buttonY,
					w = doubleW,
					h = buttonH,
					color = C.purple,
					halftone = true,
					hoverScale = 1.025,
					disabled = true,
					disabledColor = C.purple:Lerp(C.body, 0.18),
					children = doubleContents,
				}
			),
			DoubleBadge = not low and e(
				"Frame",
				{
					Name = "DoubleBadge",
					BackgroundTransparency = 1,
					Position = UDim2.fromOffset(w - margin - (narrow and 60 or 84), buttonY - 25),
					Size = UDim2.fromOffset(narrow and 70 or 92, 48),
					Rotation = 15,
					ZIndex = 10,
				},
				{
					Text = UI.text("2x", 0, 0, narrow and 70 or 92, 48, narrow and 34 or 44, C.purple),
				}
			) or nil,
		}
	)
end
return React.memo(OfflineCash)
