-- Helpers for windows imported from Figma (FigBlox) into ReplicatedStorage.UITemplates.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Ripple = require(ReplicatedStorage.Packages.Ripple)
local Theme = require(script.Parent.Theme)
local Audio = require(ReplicatedStorage:WaitForChild("Audio"))
local Figma = {}

function Figma.get(name)
	local folder = ReplicatedStorage:FindFirstChild("UITemplates")
	return folder and folder:FindFirstChild(name)
end

-- FigBlox mixes tiny scale components into offsets; resolve them against the design parent size.
function Figma.offset(object, parentSize)
	local p, s = object.Position, object.Size
	object.Position = UDim2.fromOffset(p.X.Scale * parentSize.X + p.X.Offset, p.Y.Scale * parentSize.Y + p.Y.Offset)
	object.Size = UDim2.fromOffset(s.X.Scale * parentSize.X + s.X.Offset, s.Y.Scale * parentSize.Y + s.Y.Offset)
end

-- Sets a label and its FigBlox "<name>_Shadow" twin. Shadow gets the plain text.
function Figma.setText(parent, name, text, color)
	local label = parent:FindFirstChild(name)
	local shadow = parent:FindFirstChild(name .. "_Shadow")
	if label then
		label.Text = text
		if color then
			label.TextColor3 = color
		end
	end
	if shadow then
		shadow.Text = string.gsub(text, "<[^>]->", "")
	end
end

-- Replaces a clipped Frame with a ScrollingFrame; a child named ScrollBar is the bar style reference.
function Figma.scroll(frame, direction)
	local size = Vector2.new(frame.Size.X.Offset, frame.Size.Y.Offset)
	local scroll = Instance.new("ScrollingFrame")
	scroll.Name = frame.Name
	scroll.Position = frame.Position
	scroll.Size = frame.Size
	scroll.ZIndex = frame.ZIndex
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.ScrollingDirection = direction
	scroll.ElasticBehavior = Enum.ElasticBehavior.Never
	local bar = frame:FindFirstChild("ScrollBar")
	scroll.ScrollBarThickness = bar and math.max(4, math.min(bar.Size.X.Offset, bar.Size.Y.Offset)) or 6
	scroll.ScrollBarImageColor3 = bar and bar.BackgroundColor3 or Theme.colors.white
	scroll.ScrollBarImageTransparency = bar and bar.BackgroundTransparency or 0
	if bar then
		bar:Destroy()
	end
	local extent = Vector2.zero
	for _, child in frame:GetChildren() do
		if child:IsA("GuiObject") then
			Figma.offset(child, size)
			extent = extent:Max(
				Vector2.new(
					child.Position.X.Offset + child.Size.X.Offset,
					child.Position.Y.Offset + child.Size.Y.Offset
				)
			)
		end
		child.Parent = scroll
	end
	local horizontal = direction == Enum.ScrollingDirection.X
	-- Keep the left/top inset of the design on the far side too.
	scroll.CanvasSize = horizontal and UDim2.new(0, extent.X + 4, 1, 0) or UDim2.new(1, 0, 0, extent.Y + 4)
	scroll.Parent = frame.Parent
	frame:Destroy()
	return scroll
end

-- Turns a flattened Figma button into a pressable one with the hover/press spring of UI.Button.
-- isEnabled() is read on every input; reduced() disables the animation; name names the hit button (default Hitbox).
function Figma.button(object, onClick, isEnabled, reduced, name)
	local size = object.Size
	local position = object.Position
	object.AnchorPoint = Vector2.new(0.5, 0.5)
	object.Position = position + UDim2.new(size.X.Scale / 2, size.X.Offset / 2, size.Y.Scale / 2, size.Y.Offset / 2)
	local scale = Instance.new("UIScale")
	scale.Parent = object
	local hoverScale = size.X.Offset > 240 and Theme.motion.denseHoverScale or Theme.motion.hoverScale
	local motion = Ripple.createSpring(
		0,
		{ frequency = Theme.motion.frequency, dampingRatio = 1, precision = Theme.motion.precision, start = true }
	)
	local function apply(t)
		scale.Scale = t < 0 and 1 + (1 - Theme.motion.pressedScale) * t or 1 + (hoverScale - 1) * t
	end
	local disconnect = motion:onChange(apply)
	local hover, pressed = false, false
	local function refresh()
		local goal = isEnabled() and (pressed and -1 or (hover and 1 or 0)) or 0
		if reduced() then
			motion:stop()
			motion:setGoal(goal)
			motion:setPosition(goal)
			motion:setVelocity(0)
			apply(goal)
		elseif motion:getGoal() ~= goal then
			motion:start()
			motion:setGoal(goal)
		end
	end
	local function isPress(input)
		return input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch
	end
	local hit = Instance.new("TextButton")
	hit.Name = name or "Hitbox"
	hit.Text = ""
	hit.BackgroundTransparency = 1
	hit.AutoButtonColor = false
	hit.Selectable = false
	hit.Size = UDim2.fromScale(1, 1)
	hit.ZIndex = 100
	hit.Parent = object
	local connections = {
		hit.Activated:Connect(function()
			if isEnabled() then
				Audio.play("UIClick")
				onClick()
			end
		end),
		hit.MouseEnter:Connect(function()
			hover = true
			refresh()
		end),
		hit.MouseLeave:Connect(function()
			hover, pressed = false, false
			refresh()
		end),
		hit.InputBegan:Connect(function(input)
			if isPress(input) and isEnabled() then
				pressed = true
				refresh()
			end
		end),
		UserInputService.InputEnded:Connect(function(input)
			if isPress(input) and pressed then
				pressed = false
				refresh()
			end
		end),
		UserInputService.WindowFocusReleased:Connect(function()
			hover, pressed = false, false
			refresh()
		end),
	}
	return {
		hitbox = hit,
		refresh = refresh,
		destroy = function()
			for _, connection in connections do
				connection:Disconnect()
			end
			disconnect()
			motion:destroy()
		end,
	}
end

return Figma
