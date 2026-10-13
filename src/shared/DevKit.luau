-- Building blocks of the dev panel: sections, grids, rows, number inputs. Styling follows UI.luau utility surfaces.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.React)
local Theme = require(script.Parent.Theme)
local Config = require(script.Parent.Config)
local UI = require(script.Parent.UI)
local e = React.createElement
local C = Theme.colors
local Kit = {}
Kit.CELL_H = 40
Kit.ROW_H = 52

local SUFFIX = { [""] = 1, k = 1e3, m = 1e6, b = 1e9, t = 1e12, qa = 1e15, qi = 1e18 }
-- "2.5M", "1,000", "3qa" -> number; nil when the text is not a number.
function Kit.parse(text)
	local clean = string.lower(string.gsub(text or "", "[%s,_]", ""))
	local digits, suffix = string.match(clean, "^(%-?[%d%.]+)(%a*)$")
	local value = digits and tonumber(digits)
	local scale = suffix and SUFFIX[suffix]
	if not value or not scale or value ~= value then
		return nil
	end
	return value * scale
end
function Kit.rarityColor(rarity)
	return C[Config.RarityColor[rarity] or "gold"]
end
function Kit.avatar(userId, size, x, y)
	return e("ImageLabel", {
		Name = "Avatar",
		Position = UDim2.fromOffset(x, y),
		Size = UDim2.fromOffset(size, size),
		BackgroundColor3 = C.muted,
		Image = userId > 0 and string.format("rbxthumb://type=AvatarHeadShot&id=%d&w=150&h=150", userId) or "",
		ZIndex = 7,
	}, {
		Corner = e("UICorner", { CornerRadius = UDim.new(0.5, 0) }),
		Outline = e("UIStroke", { Color = C.ink, Thickness = 2 }),
	})
end
function Kit.small(text, x, y, w, h, color, align)
	return e("TextLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(x, y),
		Size = UDim2.fromOffset(w, h),
		Text = text,
		Font = Enum.Font.GothamBold,
		TextSize = 15,
		TextColor3 = color or C.white,
		TextXAlignment = align or Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		ZIndex = 8,
	}, { Outline = e("UIStroke", { Color = C.ink, Thickness = 1.5 }) })
end

Kit.TILE_H = 58
-- Grid of label-over-value tiles; list items are { label, value, color? }.
function Kit.tiles(list, order, w)
	local children = {
		Layout = e("UIGridLayout", {
			CellSize = UDim2.fromOffset(w, Kit.TILE_H),
			CellPadding = UDim2.fromOffset(8, 8),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	}
	for i, tile in list do
		children["Tile" .. i] = e("Frame", { LayoutOrder = i, BackgroundTransparency = 1 }, {
			Surface = e(UI.Surface, {
				variant = "utility",
				w = w,
				h = Kit.TILE_H,
				children = {
					Label = Kit.small(tile[1], 10, 6, w - 20, 16, C.gold),
					Value = UI.text(
						tile[2],
						10,
						24,
						w - 20,
						28,
						20,
						tile[3] or C.white,
						Enum.TextXAlignment.Left,
						nil,
						{ fit = true }
					),
				},
			}),
		})
	end
	return e("Frame", {
		LayoutOrder = order,
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
	}, children)
end

-- Text field: Enter (or a sibling button reading ref.current.Text) submits.
function Kit.Input(p)
	return e("Frame", {
		Name = p.name or "Input",
		BackgroundColor3 = C.ink,
		BackgroundTransparency = 0.2,
		Position = UDim2.fromOffset(p.x or 0, p.y or 0),
		Size = UDim2.fromOffset(p.w, p.h or Kit.CELL_H),
		ZIndex = 7,
	}, {
		Corner = e("UICorner", { CornerRadius = UDim.new(0, Theme.radius) }),
		Outline = e("UIStroke", {
			Color = C.white,
			Transparency = 0.6,
			Thickness = 2,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		}),
		Box = e("TextBox", {
			ref = p.boxRef,
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(10, 0),
			Size = UDim2.new(1, -20, 1, 0),
			Text = "",
			PlaceholderText = p.placeholder or "",
			PlaceholderColor3 = Color3.fromRGB(150, 155, 160),
			Font = Enum.Font.GothamBold,
			TextSize = 17,
			TextColor3 = C.white,
			TextXAlignment = Enum.TextXAlignment.Left,
			ClearTextOnFocus = false,
			TextEditable = p.editable ~= false,
			ZIndex = 8,
			[React.Event.FocusLost] = function(box, enter)
				if enter and p.onSubmit then
					p.onSubmit(box.Text, box)
				end
			end,
		}),
	})
end

-- Panel-bound helpers: one object per render, closing over busy/armed/run.
-- opts: layout {cell, wide, full}, busy, canEdit, armed, setArmed, run, status, refStore (table kept across renders)
function Kit.make(opts)
	local ui = { layout = opts.layout }
	local function ref(key)
		local r = opts.refStore[key]
		if not r then
			r = React.createRef()
			opts.refStore[key] = r
		end
		return r
	end
	-- extra overrides any default; pass disabled = false for local-only buttons.
	function ui.button(label, color, onClick, extra)
		local p = {
			label = label,
			w = opts.layout.cell,
			h = Kit.CELL_H,
			color = color,
			textSize = 17,
			disabled = opts.busy,
			onClick = onClick,
		}
		for key, value in extra or {} do
			p[key] = value
		end
		return e(UI.Button, p)
	end
	-- Server command that changes saved data: disabled when the target is read-only.
	function ui.edit(label, color, name, payload, extra)
		local p = table.clone(extra or {})
		if p.disabled == nil then
			p.disabled = opts.busy or not opts.canEdit
		end
		return ui.button(label, color, function()
			opts.run(name, payload)
		end, p)
	end
	-- Destructive commands need a second tap.
	function ui.confirm(key, label, name, payload, extra)
		local armed = opts.armed == key
		local p = table.clone(extra or {})
		if p.disabled == nil then
			p.disabled = opts.busy or (p.editsData ~= false and not opts.canEdit)
		end
		local sure = p.sure or "Sure?"
		p.editsData = nil
		p.sure = nil
		return ui.button(armed and sure or label, armed and C.gold or C.red, function()
			if armed then
				opts.run(name, payload)
			else
				opts.setArmed(key)
			end
		end, p)
	end
	function ui.cells(list)
		local out = {}
		for i, item in list do
			out["Cell" .. i] = e("Frame", { LayoutOrder = i, BackgroundTransparency = 1 }, { Item = item })
		end
		return out
	end
	-- Auto-height grid block for mixing with rows inside a "list" section.
	function ui.grid(list, order, cellW)
		local children = ui.cells(list)
		children.Layout = e("UIGridLayout", {
			CellSize = UDim2.fromOffset(cellW or opts.layout.cell, Kit.CELL_H),
			CellPadding = UDim2.fromOffset(8, 8),
			SortOrder = Enum.SortOrder.LayoutOrder,
		})
		return e("Frame", {
			LayoutOrder = order or 0,
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
		}, children)
	end
	-- kind "grid" (cellW wide cells) or "list" (full-width rows stacked).
	function ui.section(title, order, children, cellW, kind, note)
		children = table.clone(children)
		if kind == "list" then
			children.Layout = e("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder })
		else
			children.Layout = e("UIGridLayout", {
				CellSize = UDim2.fromOffset(cellW or opts.layout.cell, Kit.CELL_H),
				CellPadding = UDim2.fromOffset(8, 8),
				SortOrder = Enum.SortOrder.LayoutOrder,
			})
		end
		return e("Frame", {
			Name = title,
			LayoutOrder = order,
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
		}, {
			List = e("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }),
			Title = e("Frame", { LayoutOrder = 0, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 26) }, {
				Text = UI.text(title, 2, 0, opts.layout.full - 200, 26, 20, C.gold, Enum.TextXAlignment.Left),
				Note = note and Kit.small(note, opts.layout.full - 300, 4, 296, 20, C.white, Enum.TextXAlignment.Right)
					or nil,
			}),
			Cells = e("Frame", {
				LayoutOrder = 1,
				BackgroundTransparency = 1,
				Size = UDim2.fromScale(1, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
			}, children),
		})
	end
	-- Text field with buttons: each action is { label, color, fn(text) }; Enter runs the first one.
	function ui.message(key, placeholder, actions, order)
		local buttonW = 96
		local inputW = opts.layout.full - #actions * (buttonW + 8)
		local children = {
			Input = e(Kit.Input, {
				boxRef = ref(key),
				w = inputW,
				placeholder = placeholder,
				onSubmit = function(text)
					if text ~= "" then
						actions[1][3](text)
					end
				end,
			}),
		}
		for i, action in actions do
			children["Action" .. i] = ui.button(action[1], action[2], function()
				local box = ref(key).current
				if box and box.Text ~= "" then
					action[3](box.Text)
				else
					opts.status("Type a message first.", false)
				end
			end, { x = inputW + 8 + (i - 1) * (buttonW + 8), w = buttonW })
		end
		return e("Frame", {
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, Kit.CELL_H),
			LayoutOrder = order or 99,
		}, children)
	end
	-- Number field with buttons: each action is { label, color, fn(value) }.
	function ui.amount(key, placeholder, actions, disabled, order)
		local children = {
			Input = e(Kit.Input, {
				boxRef = ref(key),
				w = opts.layout.cell * 2 + 8,
				placeholder = placeholder,
				onSubmit = function(text)
					local value = Kit.parse(text)
					if value and not disabled then
						actions[1][3](value)
					end
				end,
			}),
		}
		for i, action in actions do
			children["Action" .. i] = ui.button(action[1], action[2], function()
				local box = ref(key).current
				local value = box and Kit.parse(box.Text)
				if value then
					action[3](value)
				else
					opts.status("Type a number like 2500, 1.5M or 3T.", false)
				end
			end, {
				x = (opts.layout.cell + 8) * (i + 1),
				disabled = opts.busy or disabled,
			})
		end
		return e("Frame", {
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, Kit.CELL_H),
			LayoutOrder = order or 99,
		}, children)
	end
	return ui
end

return Kit
