-- Local-only dev tools for the owner's own character and screen: fly, noclip, free camera.
-- Nothing here is saved or sent to the server; the character's physics replicate as usual.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local player = Players.LocalPlayer
local DevCharacter = {}
DevCharacter.Changed = Instance.new("BindableEvent")
DevCharacter.state = { fly = false, noclip = false, freecam = false, flySpeed = 100, camSpeed = 60 }
local state = DevCharacter.state
local flyParts, collided, camLook = nil, {}, nil

local function humanoidOf(character)
	return character and character:FindFirstChildOfClass("Humanoid")
end
local function key(code)
	return UserInputService:IsKeyDown(code) and 1 or 0
end
-- Camera-relative WASD + E/Space up, Q/Ctrl down; nil when nothing is held.
local function input(camera)
	local cf = camera.CFrame
	local move = cf.LookVector * (key(Enum.KeyCode.W) - key(Enum.KeyCode.S))
		+ cf.RightVector * (key(Enum.KeyCode.D) - key(Enum.KeyCode.A))
		+ Vector3.yAxis
			* (math.max(key(Enum.KeyCode.E), key(Enum.KeyCode.Space)) - math.max(
				key(Enum.KeyCode.Q),
				key(Enum.KeyCode.LeftControl)
			))
	if move.Magnitude < 0.01 then
		return nil
	end
	return move.Unit * (UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) and 3 or 1)
end
local function emit()
	DevCharacter.Changed:Fire(table.clone(state))
end

local function stopFly()
	if flyParts then
		for _, part in flyParts.instances do
			part:Destroy()
		end
		if flyParts.humanoid.Parent then
			flyParts.humanoid.PlatformStand = false
		end
		flyParts = nil
	end
end
local function startFly(character)
	stopFly()
	local humanoid = humanoidOf(character)
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not humanoid or not root then
		return
	end
	local attachment = Instance.new("Attachment")
	attachment.Name = "DevFly"
	attachment.Parent = root
	local velocity = Instance.new("LinearVelocity")
	velocity.Name = "DevFlyVelocity"
	velocity.Attachment0 = attachment
	velocity.MaxForce = math.huge
	velocity.VectorVelocity = Vector3.zero
	velocity.Parent = root
	local align = Instance.new("AlignOrientation")
	align.Name = "DevFlyAlign"
	align.Mode = Enum.OrientationAlignmentMode.OneAttachment
	align.Attachment0 = attachment
	align.MaxTorque = math.huge
	align.Responsiveness = 40
	align.CFrame = root.CFrame.Rotation
	align.Parent = root
	humanoid.PlatformStand = true
	flyParts = { instances = { velocity, align, attachment }, velocity = velocity, align = align, humanoid = humanoid }
end
function DevCharacter.setFly(on)
	state.fly = on
	if on then
		startFly(player.Character)
	else
		stopFly()
	end
	emit()
end
function DevCharacter.setFlySpeed(value)
	state.flySpeed = value
	emit()
end

local function restoreCollisions()
	for part in collided do
		if part.Parent then
			part.CanCollide = true
		end
	end
	table.clear(collided)
end
function DevCharacter.setNoclip(on)
	state.noclip = on
	if not on then
		restoreCollisions()
	end
	emit()
end

local function controls()
	local module = player:FindFirstChild("PlayerScripts") and player.PlayerScripts:FindFirstChild("PlayerModule")
	local ok, result = pcall(function()
		return require(module):GetControls()
	end)
	return ok and result or nil
end
function DevCharacter.setFreecam(on)
	local camera = workspace.CurrentCamera
	state.freecam = on
	local c = controls()
	if on then
		local _, yaw = camera.CFrame:ToOrientation()
		local pitch = math.asin(math.clamp(camera.CFrame.LookVector.Y, -1, 1))
		camLook = { position = camera.CFrame.Position, yaw = yaw, pitch = pitch }
		camera.CameraType = Enum.CameraType.Scriptable
		if c then
			c:Disable()
		end
	else
		camLook = nil
		UserInputService.MouseBehavior = Enum.MouseBehavior.Default
		camera.CameraType = Enum.CameraType.Custom
		camera.CameraSubject = humanoidOf(player.Character)
		if c then
			c:Enable()
		end
	end
	emit()
end
function DevCharacter.setCamSpeed(value)
	state.camSpeed = value
	emit()
end

local started = false
function DevCharacter.start()
	if started then
		return
	end
	started = true
	player.CharacterAdded:Connect(function(character)
		table.clear(collided)
		if state.fly then
			character:WaitForChild("HumanoidRootPart", 10)
			startFly(character)
		end
	end)
	RunService.Stepped:Connect(function()
		local character = player.Character
		if state.noclip and character then
			for _, part in character:GetDescendants() do
				if part:IsA("BasePart") and part.CanCollide then
					part.CanCollide = false
					collided[part] = true
				end
			end
		end
	end)
	RunService.RenderStepped:Connect(function(dt)
		local camera = workspace.CurrentCamera
		if flyParts then
			local move = input(camera)
			flyParts.velocity.VectorVelocity = move and move * state.flySpeed or Vector3.zero
			local look = camera.CFrame.LookVector * Vector3.new(1, 0, 1)
			if look.Magnitude > 0.01 then
				flyParts.align.CFrame = CFrame.lookAt(Vector3.zero, look)
			end
		end
		if camLook then
			-- Hold the right mouse button to look around.
			if UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2) then
				UserInputService.MouseBehavior = Enum.MouseBehavior.LockCurrentPosition
				local delta = UserInputService:GetMouseDelta()
				camLook.yaw -= delta.X * 0.004
				camLook.pitch = math.clamp(camLook.pitch - delta.Y * 0.004, -1.5, 1.5)
			else
				UserInputService.MouseBehavior = Enum.MouseBehavior.Default
			end
			local rotation = CFrame.fromOrientation(camLook.pitch, camLook.yaw, 0)
			camera.CameraType = Enum.CameraType.Scriptable
			camera.CFrame = CFrame.new(camLook.position) * rotation
			local move = input(camera)
			if move then
				camLook.position += move * state.camSpeed * dt
			end
		end
	end)
end

return DevCharacter
