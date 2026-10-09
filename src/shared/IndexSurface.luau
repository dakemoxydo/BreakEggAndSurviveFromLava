local React = require(game.ReplicatedStorage.Packages.React)
local Theme = require(script.Parent.Theme)
local Assets = require(script.Parent.Assets)
local e = React.createElement
local function corner(radius)
	return e("UICorner", { CornerRadius = UDim.new(0, radius) })
end

-- Contour, inner lip and bevel are inset geometry; shadows never add a second stroke.
return function(p)
	local color = p.color or Theme.colors.body
	local style = Theme.index
	local radius = style.radius
	local contour = style.outline
	local bevel = style.bevel
	local offset = UDim2.fromOffset(0, 0)
	local faceW = math.max(1, p.w - 2 * contour - 4)
	local faceH = math.max(1, p.h - 2 * contour - bevel - 4)
	local decoration = {
		Corner = corner(radius - contour - 2),
		Gradient = e(
			"UIGradient",
			{
				Rotation = 90,
				Color = p.motion and p.motion:map(function(t)
					local tint = color:Lerp(Theme.colors.ink, 0.1 * math.clamp(t, 0, 1))
					return ColorSequence.new(
						tint:Lerp(Theme.colors.white, p.quiet and 0.035 or 0.12),
						tint:Lerp(Theme.colors.ink, 0.08)
					)
				end) or ColorSequence.new(
					color:Lerp(Theme.colors.white, p.quiet and 0.035 or 0.12),
					color:Lerp(Theme.colors.ink, 0.08)
				),
			}
		),
		Studs = e(
			"ImageLabel",
			{
				Name = "Studs",
				BackgroundTransparency = 1,
				Size = UDim2.fromScale(1, 1),
				Image = Theme.studs,
				ScaleType = Enum.ScaleType.Tile,
				TileSize = UDim2.fromScale(40 / faceW, 40 / faceH),
				ImageColor3 = p.studsColor or Theme.colors.ink,
				ImageTransparency = p.studsTransparency or (p.quiet and 0.94 or 0.84),
				ZIndex = 4,
			},
			{ Corner = corner(radius - contour - 2) }
		),
	}
	if p.shine then
		decoration.Shine = e(
			"Frame",
			{
				BackgroundColor3 = Theme.colors.white,
				BackgroundTransparency = 0.88,
				BorderSizePixel = 0,
				Size = UDim2.fromScale(1, 1),
				ZIndex = 3,
			},
			{
				Corner = corner(radius - contour - 2),
				Fade = e(
					"UIGradient",
					{
						Rotation = 28,
						Transparency = NumberSequence.new({
							NumberSequenceKeypoint.new(0, 1),
							NumberSequenceKeypoint.new(0.4, 1),
							NumberSequenceKeypoint.new(0.41, 0.2),
							NumberSequenceKeypoint.new(0.57, 0.2),
							NumberSequenceKeypoint.new(0.58, 1),
							NumberSequenceKeypoint.new(1, 1),
						}),
					}
				),
			}
		)
	end
	if p.burst then
		local diameter = math.min(p.w - 48, p.h - 140)
		decoration.Burst = e(
			"ImageLabel",
			{
				Name = "PetSunburst",
				BackgroundTransparency = 1,
				AnchorPoint = Vector2.new(0.5, 0),
				Position = UDim2.new(0.5, 0, 0, 12),
				Size = UDim2.fromOffset(diameter, diameter),
				Image = Assets.sunburst.image,
				ImageTransparency = 0.88,
				ImageColor3 = Theme.colors.white,
				ZIndex = 4,
			}
		)
	end
	if p.halftone then
		local diameter = p.variant == "shop" and math.min(p.w * 0.38, 100) or math.min(p.w * 0.8, 180)
		for i, position in { UDim2.fromScale(0, 1), UDim2.fromScale(1, 0) } do
			decoration["Halftone" .. i] = e(
				"ImageLabel",
				{
					BackgroundTransparency = 1,
					AnchorPoint = Vector2.new(0.5, 0.5),
					Position = position,
					Size = UDim2.fromOffset(diameter, diameter),
					Image = Assets.indexHalftone.image,
					ImageColor3 = Theme.colors.ink,
					ImageTransparency = p.variant == "shop" and 0.91 or 0.85,
					ZIndex = 5,
				}
			)
		end
	end
	return e(
		"Frame",
		{
			Name = p.name,
			BackgroundTransparency = 1,
			Position = p.position or UDim2.fromOffset(p.x or 0, p.y or 0),
			Size = p.size or UDim2.fromOffset(p.w, p.h),
			Active = p.active or false,
			ZIndex = p.z or 1,
		},
		{
			Shadow = e(
				"Frame",
				{
					Name = "VolumeShadow",
					Position = UDim2.fromOffset(0, style.shadow),
					Size = UDim2.fromScale(1, 1),
					BackgroundColor3 = Color3.new(0, 0, 0),
					BorderSizePixel = 0,
					ZIndex = 1,
				},
				{ Corner = corner(radius) }
			),
			Contour = e(
				"Frame",
				{
					Name = "Contour",
					Position = offset,
					Size = UDim2.fromScale(1, 1),
					BackgroundColor3 = Theme.colors.ink,
					BorderSizePixel = 0,
					ZIndex = 2,
				},
				{
					Corner = corner(radius),
					Body = e(
						"Frame",
						{
							Name = "Bevel",
							Position = UDim2.fromOffset(contour, contour),
							Size = UDim2.new(1, -2 * contour, 1, -2 * contour),
							BackgroundColor3 = color:Lerp(Theme.colors.ink, 0.55),
							BorderSizePixel = 0,
							ZIndex = 2,
						},
						{
							Corner = corner(radius - contour),
							Lip = e(
								"Frame",
								{
									Name = "InnerStroke",
									Position = UDim2.fromOffset(1, 1),
									Size = UDim2.new(1, -2, 1, -bevel - 2),
									BackgroundColor3 = color:Lerp(Theme.colors.white, p.quiet and 0.12 or 0.22),
									BorderSizePixel = 0,
									ZIndex = 3,
								},
								{
									Corner = corner(radius - contour - 1),
									Face = e(
										"Frame",
										{
											Name = "Face",
											Position = UDim2.fromOffset(1, 1),
											Size = UDim2.new(1, -2, 1, -2),
											BackgroundColor3 = Theme.colors.white,
											BorderSizePixel = 0,
											ClipsDescendants = true,
											ZIndex = 3,
										},
										decoration
									),
								}
							),
						}
					),
				}
			),
			Content = e(
				"Frame",
				{ Name = "Content", Position = offset, BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 6 },
				p.children
			),
		}
	)
end
