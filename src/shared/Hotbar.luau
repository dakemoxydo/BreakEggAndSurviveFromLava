local RS = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local React = require(RS.Packages.React)
local Ripple = require(RS.Packages.Ripple)
local UI = require(script.Parent.UI)
local Theme = require(script.Parent.Theme)
local e = React.createElement
local player = Players.LocalPlayer
local Hotbar = {}
function Hotbar.layout(width, height, slots, open)
	local narrow = width < 600
	local columns = narrow and not (height < 520 and width >= 480) and 5 or 10
	local available = (narrow or height < 520) and width - 32 or math.min(820, width * 0.5)
	local gap, h = 8, height < 520 and 64 or 92
	local cell = math.min(108, (available - (columns - 1) * gap) / columns)
	local occupied = {}
	for i = 1, 10 do
		if slots[i] then
			table.insert(occupied, i)
		end
	end
	local rows = math.ceil((open and 10 or #occupied) / columns)
	return {
		columns = columns,
		gap = gap,
		cell = cell,
		h = h,
		occupied = occupied,
		fullW = columns * (cell + gap) - gap,
		fullH = math.ceil(10 / columns) * (h + 12) - 12,
		closedW = math.max(0, math.min(columns, #occupied) * (cell + gap) - gap),
		top = height - 20 - (rows > 0 and rows * (h + 12) - 12 or 0),
	}
end
function Hotbar.icon(tool, x, y, w, h)
	local key = tool:GetAttribute("UIIcon")
		or ({ ["Secret Pickaxe"] = "pickaxe", ["Lava Bat"] = "lavaBat" })[tool.Name]
		or (
			tool:GetAttribute("PlacementKind") == "Egg" and "egg"
			or tool:GetAttribute("PlacementKind") == "Pet" and "chicken"
		)
	if key then
		return UI.icon(key, x, y, w, h)
	end
	if tool.TextureId ~= "" then
		return e("ImageLabel", {
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(x, y),
			Size = UDim2.fromOffset(w, h),
			Image = tool.TextureId,
			ScaleType = Enum.ScaleType.Fit,
			ZIndex = 7,
		})
	end
	return nil
end
function Hotbar.Bar(p)
	local ownRefs = React.useRef({})
	local refs = p.slotRefs or ownRefs
	local binding, update = React.useBinding(0)
	local motion = React.useMemo(function()
		return Ripple.createSpring(0, {
			frequency = Theme.motion.transitionFrequency,
			dampingRatio = 1,
			precision = Theme.motion.transitionPrecision,
			start = true,
		})
	end, {})
	React.useEffect(function()
		local disconnect = motion:onChange(update)
		return function()
			disconnect()
			motion:destroy()
		end
	end, { motion })
	React.useEffect(function()
		local goal = p.open and 1 or 0
		if p.reduced then
			motion:stop()
			motion:setGoal(goal)
			motion:setPosition(goal)
			motion:setVelocity(0)
			update(goal)
		else
			motion:start()
			motion:setGoal(goal)
		end
	end, { p.open, p.reduced })
	local layout = Hotbar.layout(p.width, p.height, p.slots, p.open)
	local columns, gap, cell, h = layout.columns, layout.gap, layout.cell, layout.h
	local fullW, fullH, closedW = layout.fullW, layout.fullH, layout.closedW
	local closed = layout.occupied
	local content = {}
	for i = 1, 10 do
		local tool = p.slots[i]
		local rank = table.find(closed, i)
		if p.open or tool then
			if not refs.current[i] then
				refs.current[i] = React.createRef()
			end
			local col = (i - 1) % columns
			local row = math.floor((i - 1) / columns)
			local closedCol = rank and (rank - 1) % columns or col
			local closedRow = rank and math.floor((rank - 1) / columns) or row
			local selected = tool and tool.Parent == player.Character
			local children = { Number = UI.text(tostring(i % 10), 5, 2, 28, 30, 25, nil, Enum.TextXAlignment.Left) }
			if tool then
				local small = cell < 90 or p.height < 520
				children.Image = Hotbar.icon(
					tool,
					cell < 64 and 6 or 10,
					cell < 64 and 26 or 6,
					cell - (cell < 64 and 12 or 20),
					cell < 64 and 30 or p.height < 520 and 28 or small and 38 or 60
				)
				local label = small and tool.Name == "Secret Pickaxe" and "Pickaxe" or tool.Name
				if cell >= 64 then
					children.Label = UI.text(
						label,
						small and 2 or 5,
						p.height < 520 and 36 or small and 46 or 70,
						cell - (small and 4 or 10),
						p.height < 520 and 26 or small and 40 or 36,
						small and 16 or 18,
						nil,
						nil,
						nil,
						{ fit = true }
					)
				end
			end
			content["Slot" .. i] = e(UI.Button, {
				name = "HotbarSlot" .. i,
				buttonRef = refs.current[i],
				w = cell,
				h = h,
				variant = "utility",
				selected = selected,
				hoverScale = 1.025,
				position = binding:map(function(t)
					local cx = (p.width - closedW) / 2 + closedCol * (cell + gap)
					local ox = (p.width - fullW) / 2 + col * (cell + gap)
					local cy = p.height - 20 - h - closedRow * (h + 12)
					local oy = p.height - 20 - fullH + row * (h + 12)
					if not tool then
						return UDim2.fromOffset(ox, oy)
					end
					return UDim2.fromOffset(cx + (ox - cx) * t, cy + (oy - cy) * t)
				end),
				onClick = function()
					if p.drag and p.drag.suppressed() then
						return
					end
					if p.open and p.selectedTool then
						p.assign(p.selectedTool, i)
						p.onAssigned()
					else
						p.equip(tool)
					end
				end,
				onInput = function(input)
					if p.open and tool and p.drag then
						p.drag.start(tool, input)
					end
				end,
				children = children,
			})
		end
	end
	return e(
		"Frame",
		{ Name = "CustomHotbar", BackgroundTransparency = 1, Size = UDim2.fromOffset(p.width, p.height), ZIndex = 35 },
		content
	)
end
Hotbar.Bar = React.memo(Hotbar.Bar)
return Hotbar
