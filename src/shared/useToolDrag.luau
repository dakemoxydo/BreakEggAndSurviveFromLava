local React = require(game.ReplicatedStorage.Packages.React)
local UIS = game:GetService("UserInputService")

local function contains(object, point)
	return object
		and object.Parent
		and object.Visible
		and point.X >= object.AbsolutePosition.X
		and point.Y >= object.AbsolutePosition.Y
		and point.X <= object.AbsolutePosition.X + object.AbsoluteSize.X
		and point.Y <= object.AbsolutePosition.Y + object.AbsoluteSize.Y
end

-- One pointer owns a drag. Bindings move decoration without re-rendering App.
return function(p)
	local latest = React.useRef(p)
	latest.current = p
	local pending = React.useRef(nil)
	local blockedUntil = React.useRef(0)
	local tool, setTool = React.useState(nil)
	local point, move = React.useBinding(Vector2.zero)
	local target, showTarget = React.useBinding(nil)
	local function destination(at)
		for index, ref in latest.current.slotRefs.current do
			if contains(ref.current, at) then
				return index, ref.current
			end
		end
		local object = latest.current.inventoryRef.current
		if contains(object, at) then
			return 0, object
		end
	end
	local function cancel()
		if pending.current and pending.current.moved then
			blockedUntil.current = os.clock() + 0.15
		end
		pending.current = nil
		setTool(nil)
		showTarget(nil)
	end
	local function update(input)
		local drag = pending.current
		if not drag then
			return
		end
		local at = Vector2.new(input.Position.X, input.Position.Y)
		if not drag.moved and (at - drag.start).Magnitude >= 12 then
			drag.moved = true
			setTool(drag.tool)
		end
		if drag.moved then
			move(at)
			local _, object = destination(at)
			showTarget(object and { position = object.AbsolutePosition, size = object.AbsoluteSize } or nil)
		end
	end
	local start = React.useCallback(function(item, input)
		if not latest.current.enabled or pending.current or not table.find(latest.current.tools, item) then
			return
		end
		if
			input.UserInputType ~= Enum.UserInputType.MouseButton1
			and input.UserInputType ~= Enum.UserInputType.Touch
		then
			return
		end
		pending.current =
			{ tool = item, input = input, start = Vector2.new(input.Position.X, input.Position.Y), moved = false }
	end, {})
	local suppressed = React.useCallback(function()
		return os.clock() < blockedUntil.current or (pending.current ~= nil and pending.current.moved)
	end, {})
	React.useEffect(function()
		if not p.enabled or (pending.current and not table.find(p.tools, pending.current.tool)) then
			cancel()
		end
	end, { p.enabled, p.tools, p.kind })
	React.useEffect(function()
		cancel()
	end, { p.kind })
	React.useEffect(function()
		local changed = UIS.InputChanged:Connect(function(input)
			local drag = pending.current
			if
				drag
				and (
					input == drag.input
					or (
						drag.input.UserInputType == Enum.UserInputType.MouseButton1
						and input.UserInputType == Enum.UserInputType.MouseMovement
					)
				)
			then
				update(input)
			end
		end)
		local ended = UIS.InputEnded:Connect(function(input)
			local drag = pending.current
			if
				not drag
				or not (
					input == drag.input
					or (
						drag.input.UserInputType == Enum.UserInputType.MouseButton1
						and input.UserInputType == Enum.UserInputType.MouseButton1
					)
				)
			then
				return
			end
			update(input)
			if drag.moved and latest.current.enabled and table.find(latest.current.tools, drag.tool) then
				local index = destination(Vector2.new(input.Position.X, input.Position.Y))
				if index ~= nil then
					latest.current.assign(drag.tool, index)
				end
			end
			cancel()
		end)
		local lost = UIS.WindowFocusReleased:Connect(cancel)
		return function()
			changed:Disconnect()
			ended:Disconnect()
			lost:Disconnect()
			pending.current = nil
		end
	end, {})
	return React.useMemo(function()
		return { tool = tool, point = point, target = target, start = start, suppressed = suppressed }
	end, { tool, point, target, start, suppressed })
end
