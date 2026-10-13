-- Helpers for windows imported from Figma (FigBlox) into ReplicatedStorage.UITemplates.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Ripple = require(ReplicatedStorage.Packages.Ripple)
local Theme = require(script.Parent.Theme)
local Audio = require(ReplicatedStorage:WaitForChild("Audio"))
local Figma = {}

-- Figma groups carry invisible "Split" text layers only so FigBlox keeps the art above them separate;
-- they are removed from the template on first use.
function Figma.get(name)
	local folder = ReplicatedStorage:FindFirstChild("UITemplates")
	local template = folder and folder:FindFirstChild(name)
	if template and not template:GetAttribute("SplitRemoved") then
		for _, item in template:GetDescendants() do
			if item.Name == "Split" or item.Name == "Split_Shadow" then
				item:Destroy()
			end
		end
		template:SetAttribute("SplitRemoved", true)
	end
	return template
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

-- Common scale of the right sidebars (Pets, Eggs): the old React Eggs body limits (480x460 UI units,
-- smaller on narrow/short screens), shrunk to 90% so both panels read the same size.
-- Also returns the panel top, shared too, so Pets and Eggs slide in at the same place.
function Figma.sidebarScale(width, height, panel)
	local narrow, short = width < 600, height < 520
	local w = math.min(480, width - (narrow and 56 or 84) - 32)
	local h = math.min(460, height - (short and 96 or narrow and 240 or 200))
	local s = 0.9 * math.min(w / panel.X, h / panel.Y)
	return s, short and 64 or narrow and 180 or math.max(96, (height - panel.Y * s) / 2)
end

-- FigBlox names text layers after their sample text; renames the labels (top to bottom) and shadows to `names`.
function Figma.nameTexts(parent, names)
	local labels = {}
	for _, child in parent:GetChildren() do
		if child:IsA("TextLabel") and not string.find(child.Name, "_Shadow$") then
			table.insert(labels, child)
		end
	end
	table.sort(labels, function(a, b)
		return a.Position.Y.Offset < b.Position.Y.Offset
	end)
	for i, label in labels do
		local shadow = parent:FindFirstChild(label.Name .. "_Shadow")
		label.Name = names[i] or label.Name
		if shadow then
			shadow.Name = label.Name .. "_Shadow"
		end
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
-- A tilted ancestor turns ClipsDescendants off, so Masks inside a button become CanvasGroups,
-- which clip at any rotation. A Mask always clips: Figma may export it unclipped so rotating art keeps its full image.
local function clipMasks(object)
	for _, mask in object:GetDescendants() do
		if mask.Name == "Mask" and mask.ClassName == "Frame" then
			local group = Instance.new("CanvasGroup")
			for _, property in { "Name", "Position", "Size", "AnchorPoint", "ZIndex", "LayoutOrder", "Visible" } do
				group[property] = mask[property]
			end
			group.BackgroundTransparency = 1
			for _, child in mask:GetChildren() do
				child.Parent = group
			end
			group.Parent = mask.Parent
			mask:Destroy()
		end
	end
end

-- Also for decor that rotates inside its Mask (a turning SunBurst outside any button).
Figma.clipMasks = clipMasks

function Figma.button(object, onClick, isEnabled, reduced, name)
	clipMasks(object)
	local size = object.Size
	local position = object.Position
	object.AnchorPoint = Vector2.new(0.5, 0.5)
	object.Position = position + UDim2.new(size.X.Scale / 2, size.X.Offset / 2, size.Y.Scale / 2, size.Y.Offset / 2)
	local scale = Instance.new("UIScale")
	scale.Parent = object
	local dense = size.X.Offset > 240
	local hoverScale = dense and Theme.motion.denseHoverScale or Theme.motion.hoverScale
	local tilt = dense and Theme.motion.denseTilt or Theme.motion.tilt
	local baseRotation = object.Rotation
	-- -1/1: the side the pointer entered from; the hover tilt leans that way.
	local side = 1
	local motion = Ripple.createSpring(0, {
		frequency = Theme.motion.frequency,
		dampingRatio = Theme.motion.dampingRatio,
		precision = Theme.motion.precision,
		start = true,
	})
	local function apply(t)
		scale.Scale = t < 0 and 1 + (1 - Theme.motion.pressedScale) * t or 1 + (hoverScale - 1) * t
		object.Rotation = baseRotation + math.max(t, 0) * tilt * side
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
		hit.MouseEnter:Connect(function(x)
			side = x < hit.AbsolutePosition.X + hit.AbsoluteSize.X / 2 and -1 or 1
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
		-- A short bounce, e.g. when the button's state flips.
		pulse = function()
			if not reduced() then
				motion:start()
				motion:impulse(6)
			end
		end,
		destroy = function()
			for _, connection in connections do
				connection:Disconnect()
			end
			disconnect()
			motion:destroy()
		end,
	}
end

-- Cards and rows pop in one after another (Theme.motion.reveal*). Skips objects that already
-- own a UIScale (buttons), so the hover scale is never fought over.
-- first: stagger slot of objects[1] (rows added one at a time keep their place in the cascade).
-- keepAnchor: grow from the existing AnchorPoint (objects whose position the caller keeps setting).
function Figma.reveal(objects, reduced, first, keepAnchor)
	if reduced then
		return
	end
	for i, object in objects do
		if not object:FindFirstChildOfClass("UIScale") then
			if not keepAnchor and object.AnchorPoint == Vector2.zero then
				local size = object.Size
				object.AnchorPoint = Vector2.new(0.5, 0.5)
				object.Position += UDim2.new(size.X.Scale / 2, size.X.Offset / 2, size.Y.Scale / 2, size.Y.Offset / 2)
			end
			local scale = Instance.new("UIScale")
			scale.Name = "Reveal"
			scale.Scale = Theme.motion.revealScale
			scale.Parent = object
			local motion = Ripple.createSpring(Theme.motion.revealScale, {
				frequency = Theme.motion.frequency,
				dampingRatio = Theme.motion.openDampingRatio,
				precision = Theme.motion.precision,
				start = true,
			})
			motion:onChange(function(value)
				scale.Scale = value
			end)
			motion:onComplete(function(value)
				if value > 0.999 then
					motion:destroy()
					scale:Destroy()
				end
			end)
			task.delay(((first or 1) + i - 2) * Theme.motion.revealStagger, function()
				if scale.Parent then
					motion:setGoal(1)
				else
					motion:destroy()
				end
			end)
		end
	end
end

-- Idle motion on one shared Heartbeat: "sway" rocks and bobs an item image, "spin" turns a burst,
-- "fall" drops a background picture through its clipping parent and wraps it to the top,
-- "shine" sweeps a highlight stripe across its parent every Theme.motion.shineEvery seconds.
-- phase offsets neighbours; reduced() parks the object at rest. Returns a handle shaped like Figma.button's
-- (destroy stops it, refresh does nothing), so windows keep it in their buttons list for cleanup.
-- Each item keeps its own clock that only runs while it is shown, so a paused item resumes without a jump.
local idlers = {}
local heartbeat

-- Hidden items and items inside a fading window rest: every change inside a CanvasGroup redraws it.
local function shown(object)
	local node = object.Parent
	while node and not node:IsA("LayerCollector") do
		if node:IsA("GuiObject") and not node.Visible then
			return false
		end
		if node:IsA("CanvasGroup") and node.GroupTransparency > 0.01 then
			return false
		end
		node = node.Parent
	end
	return node ~= nil
end

-- "conveyor": the tiled Studs art slides left by `offset` (0..studsPeriod); the gap it leaves on the right
-- is filled by a clipped copy shifted one tile period back, which shows the same pattern.
local function belt(frame)
	local image = frame:FindFirstChildWhichIsA("ImageLabel")
	local w, h = frame.Size.X.Offset, frame.Size.Y.Offset
	frame.ClipsDescendants = true
	image.Size = UDim2.fromOffset(w, h)
	local strip = Instance.new("Frame")
	strip.Name = "StudsWrap"
	strip.BackgroundTransparency = 1
	strip.ClipsDescendants = true
	strip.ZIndex = image.ZIndex
	strip.Parent = frame
	local copy = image:Clone()
	copy.Position = UDim2.fromOffset(Theme.motion.studsPeriod - w, 0)
	copy.Parent = strip
	return function(offset)
		image.Position = UDim2.fromOffset(-offset, 0)
		strip.Position = UDim2.fromOffset(w - offset, 0)
		strip.Size = UDim2.fromOffset(offset, h)
	end
end

function Figma.idle(object, kind, phase, reduced)
	local entry = { object = object, kind = kind, phase = phase, reduced = reduced, time = 0 }
	entry.position, entry.rotation = object.Position, object.Rotation
	if kind == "conveyor" then
		entry.belt = belt(object)
	end
	idlers[entry] = true
	if not heartbeat then
		heartbeat = RunService.Heartbeat:Connect(function(dt)
			for item in idlers do
				local o = item.object
				-- Destroy clears Parent of the whole tree: windows that are gone stop their idles here.
				if o.Parent == nil then
					idlers[item] = nil
					continue
				end
				if item.reduced() then
					if item.kind == "conveyor" then
						item.belt(0)
					else
						o.Position, o.Rotation = item.position, item.rotation
					end
					continue
				end
				if not shown(o) then
					continue
				end
				item.time += dt
				local now = item.time
				if item.kind == "conveyor" then
					item.belt(now * Theme.motion.studsSpeed % Theme.motion.studsPeriod)
				elseif item.kind == "spin" then
					o.Rotation = item.rotation + now * Theme.motion.burstSpeed % 360
				elseif item.kind == "fall" then
					local base = item.position
					local h = o.Size.Y.Offset
					local travel = o.Parent.Size.Y.Offset + h
					-- phase keeps the design spacing: each item starts the loop where it was drawn.
					local y = (base.Y.Offset + h + now * Theme.motion.fallSpeed) % travel - h
					o.Position = UDim2.new(base.X.Scale, base.X.Offset, 0, y)
					o.Rotation = item.rotation
						+ math.sin(now * Theme.motion.swaySpeed + item.phase) * Theme.motion.swayAngle * 2
				elseif item.kind == "shine" then
					local base = item.position
					local width = o.Parent.Size.X.Offset
					local t = math.clamp(((now + item.phase) % Theme.motion.shineEvery) / Theme.motion.shineTime, 0, 1)
					o.Position = base + UDim2.fromOffset((t * 2 - 1) * (width + o.Size.X.Offset), 0)
				else
					local t = now * Theme.motion.swaySpeed + item.phase
					o.Rotation = item.rotation + math.sin(t) * Theme.motion.swayAngle
					o.Position = item.position + UDim2.fromOffset(0, (math.cos(t) - 1) * 0.5 * Theme.motion.bobHeight)
				end
			end
		end)
	end
	return {
		refresh = function() end,
		destroy = function()
			idlers[entry] = nil
			if not next(idlers) and heartbeat then
				heartbeat:Disconnect()
				heartbeat = nil
			end
		end,
	}
end

-- Window headers: their Studs layer runs left like a conveyor belt (no-op for imports without a separate Studs).
function Figma.studs(root, reduced)
	for _, studs in root:GetDescendants() do
		if studs.Name == "Studs" and studs.Parent.Name == "Header" and studs:FindFirstChildWhichIsA("ImageLabel") then
			Figma.idle(studs, "conveyor", 0, reduced)
		end
	end
end

return Figma
