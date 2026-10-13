-- Settings window from the Figma import (ReplicatedStorage.UITemplates.Settings, frame "Settings Window").
-- Volume rows: Track, VolumeFill and Knob move with the value when the import keeps them apart;
-- a flattened "Slider" image stays static (the value still changes). Toggles swap the ON/OFF art of the template.
local React = require(game.ReplicatedStorage.Packages.React)
local UIS = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local UI = require(script.Parent.UI)
local Figma = require(script.Parent.FigmaTemplate)
local e = React.createElement
local KNOB_TWEEN = TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local VOLUMES = { MusicVolumeRow = "MusicVolume", SFXVolumeRow = "SFXVolume" }
local TOGGLES = {
	ViewOthersPetsRow = "ViewOthersPets",
	ViewMyPetsRow = "ViewMyPets",
	ViewMyEggsRow = "ViewMyEggs",
	ReducedMotionRow = "ReducedMotion",
}

local function offsetOf(object)
	return Vector2.new(object.Position.X.Offset, object.Position.Y.Offset)
end

local function sizeOf(object)
	return Vector2.new(object.Size.X.Offset, object.Size.Y.Offset)
end

local function isOn(data, setting)
	if setting == "ReducedMotion" then
		return data.ReducedMotion == true
	end
	return data[setting] ~= false
end

local function build(latest)
	local source = Figma.get("Settings")["Settings Window"]
	local frame = source.SettingsFrame:Clone()
	local exit = source.ExitBtn:Clone()
	local origin = offsetOf(source.SettingsFrame)
	local root = Instance.new("Frame")
	root.Name = "SettingsWindow"
	root.BackgroundTransparency = 1
	root.AnchorPoint = Vector2.new(0.5, 0.5)
	root.Position = UDim2.fromScale(0.5, 0.5)
	root.Size = source.SettingsFrame.Size
	local scale = Instance.new("UIScale")
	scale.Parent = root
	frame.Position = UDim2.fromOffset(0, 0)
	frame.Parent = root
	local exitAt = offsetOf(exit) - origin
	exit.Position = UDim2.fromOffset(exitAt.X, exitAt.Y)
	exit.ZIndex = 10
	exit.Parent = root
	local list = frame.MainFrame.SettingsScroll
	local function reduced()
		return latest.current.reduced
	end
	Figma.studs(root, reduced)
	local function ready()
		return latest.current.inputEnabled and latest.current.enabled
	end
	local buttons = {
		Figma.button(exit, function()
			latest.current.onClose()
		end, function()
			return latest.current.inputEnabled
		end, reduced, "CloseWindow"),
	}
	local art = {}
	local toggles = {}
	for rowName, setting in TOGGLES do
		local row = list:FindFirstChild(rowName)
		if row then
			Figma.nameTexts(row, { "Title", "State" })
			local toggle = row.Toggle
			-- A separate Knob slides between its ON and OFF spots. Layered Track and Knob are swapped whole
			-- for the other state's copies; a flattened toggle swaps its image.
			local knob = toggle:FindFirstChild("Knob")
			local track = toggle:FindFirstChild("Track")
			local image = not track and (knob or toggle):FindFirstChildWhichIsA("ImageLabel")
			local state = row:FindFirstChild("State")
			local look = { image = image and image.Image, x = knob and knob.Position.X.Offset }
			art[state and state.Text == "ON" and "on" or "off"] = look
			local button = Figma.button(toggle, function()
				latest.current.onAction(
					"SetSetting",
					{ setting = setting, value = not isOn(latest.current.data, setting) }
				)
			end, ready, reduced, setting)
			-- Cloned after Figma.button so the copies keep the clipping Masks it set up.
			look.track = track and track:Clone()
			look.knob = track and knob and knob:Clone()
			table.insert(buttons, button)
			toggles[setting] = { row = row, image = image, track = track, knob = knob, button = button }
		end
	end
	local volumes = {}
	local connections = {}
	for rowName, setting in VOLUMES do
		local row = list:FindFirstChild(rowName)
		if row then
			Figma.nameTexts(row, { "Title", "Percent", "Description" })
			local track, fill, knob =
				row:FindFirstChild("Track"), row:FindFirstChild("VolumeFill"), row:FindFirstChild("Knob")
			local volume = { row = row, setting = setting }
			local area
			if track and fill and knob then
				-- The fill is cropped, not stretched: its art keeps the design width.
				for _, child in fill:GetChildren() do
					if child:IsA("GuiObject") then
						Figma.offset(child, sizeOf(fill))
					end
				end
				fill.ClipsDescendants = true
				volume.track, volume.fill, volume.knob = track, fill, knob
				volume.trackAt, volume.trackSize = offsetOf(track), sizeOf(track)
				area = {
					at = Vector2.new(volume.trackAt.X, offsetOf(knob).Y),
					size = Vector2.new(volume.trackSize.X, knob.Size.Y.Offset),
				}
			else
				local slider = row.Slider
				area = { at = offsetOf(slider), size = sizeOf(slider) }
			end
			local hit = Instance.new("TextButton")
			hit.Name = setting
			hit.Text = ""
			hit.BackgroundTransparency = 1
			hit.AutoButtonColor = false
			hit.Position = UDim2.fromOffset(area.at.X, area.at.Y)
			hit.Size = UDim2.fromOffset(area.size.X, area.size.Y)
			hit.ZIndex = 100
			hit.Parent = row
			volume.hit = hit
			local function atPointer(x)
				volume.preview = math.clamp((x - hit.AbsolutePosition.X) / math.max(1, hit.AbsoluteSize.X), 0, 1)
				latest.current.refresh()
			end
			local function finish(commit)
				local value = volume.preview
				volume.drag, volume.preview = nil, nil
				if commit and value and ready() then
					latest.current.onAction("SetSetting", { setting = setting, value = value })
				end
				latest.current.refresh()
			end
			table.insert(
				connections,
				hit.InputBegan:Connect(function(input)
					local press = input.UserInputType == Enum.UserInputType.MouseButton1
						or input.UserInputType == Enum.UserInputType.Touch
					if press and ready() and not volume.drag then
						volume.drag = input
						atPointer(input.Position.X)
					end
				end)
			)
			table.insert(
				connections,
				UIS.InputChanged:Connect(function(input)
					local drag = volume.drag
					if
						drag
						and (
							input == drag
							or drag.UserInputType == Enum.UserInputType.MouseButton1
								and input.UserInputType == Enum.UserInputType.MouseMovement
						)
					then
						atPointer(input.Position.X)
					end
				end)
			)
			table.insert(
				connections,
				UIS.InputEnded:Connect(function(input)
					local drag = volume.drag
					if drag and (input == drag or input.UserInputType == drag.UserInputType) then
						atPointer(input.Position.X)
						finish(true)
					end
				end)
			)
			table.insert(
				connections,
				UIS.WindowFocusReleased:Connect(function()
					if volume.drag then
						finish(false)
					end
				end)
			)
			volumes[setting] = volume
		end
	end
	-- Rows are drawn at different values; every row crops the widest (full) fill art of the template.
	local full
	for _, volume in volumes do
		if volume.fill and (not full or volume.fill.Size.X.Offset > full.Size.X.Offset) then
			full = volume.fill
		end
	end
	for _, volume in volumes do
		if full and volume.fill and volume.fill ~= full then
			volume.fill:ClearAllChildren()
			for _, child in full:GetChildren() do
				child:Clone().Parent = volume.fill
			end
		end
	end
	local rows = {}
	for _, row in list:GetChildren() do
		if row:IsA("GuiObject") then
			table.insert(rows, row)
		end
	end
	table.sort(rows, function(a, b)
		return a.Position.Y.Offset < b.Position.Y.Offset
	end)
	Figma.reveal(rows, reduced())
	return {
		root = root,
		scale = scale,
		buttons = buttons,
		connections = connections,
		toggles = toggles,
		volumes = volumes,
		art = art,
	}
end

local function update(view, p)
	view.scale.Scale = math.min(p.width / view.root.Size.X.Offset, p.height / view.root.Size.Y.Offset)
	for setting, toggle in view.toggles do
		local on = isOn(p.data, setting)
		if toggle.on ~= nil and toggle.on ~= on then
			toggle.button.pulse()
		end
		local look = view.art[on and "on" or "off"]
		if look then
			if toggle.image and look.image then
				toggle.image.Image = look.image
			elseif toggle.on ~= on then
				for _, part in { "track", "knob" } do
					if toggle[part] and look[part] then
						local copy = look[part]:Clone()
						copy.Position = toggle[part].Position
						copy.Parent = toggle[part].Parent
						toggle[part]:Destroy()
						toggle[part] = copy
					end
				end
			end
			if toggle.knob and look.x then
				local goal = UDim2.new(0, look.x, toggle.knob.Position.Y.Scale, toggle.knob.Position.Y.Offset)
				if toggle.on == nil or p.reduced then
					toggle.knob.Position = goal
				else
					TweenService:Create(toggle.knob, KNOB_TWEEN, { Position = goal }):Play()
				end
			end
		end
		toggle.on = on
		Figma.setText(toggle.row, "State", on and "ON" or "OFF")
	end
	for setting, volume in view.volumes do
		if volume.drag and not (p.inputEnabled and p.enabled) then
			volume.drag, volume.preview = nil, nil
		end
		local value = volume.preview or math.clamp(p.data[setting] or 1, 0, 1)
		Figma.setText(volume.row, "Percent", math.floor(value * 100 + 0.5) .. "%")
		if volume.track then
			local w = volume.trackSize.X
			local knobW = volume.knob.Size.X.Offset
			local x =
				math.clamp(volume.trackAt.X + w * value - knobW / 2, volume.trackAt.X, volume.trackAt.X + w - knobW)
			volume.knob.Position = UDim2.new(0, x, volume.knob.Position.Y.Scale, volume.knob.Position.Y.Offset)
			volume.fill.Size = UDim2.fromOffset(math.max(0, x + knobW / 2 - volume.trackAt.X), volume.trackSize.Y)
		end
	end
	for _, button in view.buttons do
		button.refresh()
	end
end

local function SettingsWindow(p)
	local inputEnabled = React.useContext(UI.InputEnabled)
	local reduced = React.useContext(UI.ReducedMotion)
	local host = React.useRef(nil)
	local view = React.useRef(nil)
	local latest = React.useRef(nil)
	local props = table.clone(p)
	props.inputEnabled = inputEnabled
	props.reduced = reduced or p.reduced
	props.refresh = function()
		if view.current then
			update(view.current, latest.current)
		end
	end
	latest.current = props
	React.useEffect(function()
		-- A template that no longer matches the code must not take the whole React tree down.
		local ok, built = pcall(build, latest)
		if not ok then
			warn("Figma template Settings: " .. tostring(built))
			return
		end
		view.current = built
		update(built, latest.current)
		built.root.Parent = host.current
		return function()
			for _, button in built.buttons do
				button.destroy()
			end
			for _, connection in built.connections do
				connection:Disconnect()
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
		Name = "Settings",
		ref = host,
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(p.width, p.height),
	})
end

return SettingsWindow
