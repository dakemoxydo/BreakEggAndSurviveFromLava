local React = require(game.ReplicatedStorage.Packages.React)
local UI = require(script.Parent.UI)
local Hotbar = require(script.Parent.Hotbar)
local Preview = require(script.Parent.ModelPreview)
local Theme = require(script.Parent.Theme)
local e = React.createElement
return function(p)
	local drag = p.drag
	if not drag.tool then
		return nil
	end
	local function localPoint(at)
		local root = p.rootRef.current
		return (at - (root and root.AbsolutePosition or Vector2.zero)) / p.scale
	end
	local tool = drag.tool
	local kind = tool:GetAttribute("PetKind")
	return e("Frame", {
		Name = "ToolDragPreview",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Active = false,
		ZIndex = 80,
	}, {
		Target = e("Frame", {
			Name = "ToolDropTarget",
			BackgroundTransparency = 0.88,
			BackgroundColor3 = Theme.colors.white,
			BorderSizePixel = 0,
			Active = false,
			Visible = drag.target:map(function(t)
				return t ~= nil
			end),
			Position = drag.target:map(function(t)
				local at = localPoint(t and t.position or Vector2.zero)
				return UDim2.fromOffset(at.X, at.Y)
			end),
			Size = drag.target:map(function(t)
				local size = t and t.size / p.scale or Vector2.zero
				return UDim2.fromOffset(size.X, size.Y)
			end),
		}, {
			Corner = e("UICorner", { CornerRadius = UDim.new(0, Theme.radius) }),
			Outline = e("UIStroke", { Color = Theme.colors.white, Thickness = 2 }),
		}),
		Ghost = e("Frame", {
			Name = "DraggedTool",
			BackgroundTransparency = 1,
			Size = UDim2.fromOffset(148, 106),
			ZIndex = 2,
			Active = false,
			Position = drag.point:map(function(at)
				local pos = localPoint(at)
				return UDim2.fromOffset(
					math.clamp(pos.X + 12, 8, math.max(8, p.width - 156)),
					math.clamp(pos.Y + 12, 8, math.max(8, p.height - 114))
				)
			end),
		}, {
			Body = e(UI.Surface, {
				w = 148,
				h = 106,
				variant = "utility",
				children = {
					Icon = kind and e(Preview, {
						kind = kind,
						weight = tool:GetAttribute("PetWeight") or 1,
						x = 44,
						y = 4,
						w = 60,
						h = 54,
					}) or Hotbar.icon(tool, 44, 4, 60, 54),
					Name = UI.text(tool.Name, 6, 60, 136, 40, 18),
				},
			}),
		}),
	})
end
