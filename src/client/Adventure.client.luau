local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local UIS = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Game = require(RS:WaitForChild("GameConfig"))
local PickaxeEffects = require(RS:WaitForChild("PickaxeEffects"))
local HatchEffects = require(RS:WaitForChild("HatchEffects"))
local BaseFence = require(RS:WaitForChild("BaseFence"))
local Audio = require(RS:WaitForChild("Audio"))
local player = Players.LocalPlayer
local action = RS:WaitForChild("GameplayAction")
local feedback = RS:WaitForChild("GameplayFeedback")
local mouse = player:GetMouse()
local last = 0
local function held()
	return player.Character and player.Character:FindFirstChildOfClass("Tool")
end
local function eggFrom(part)
	local model = part
	while model and model ~= workspace do
		if model:IsA("Model") and model:GetAttribute("BreakableEgg") then
			return model
		end
		model = model.Parent
	end
end
local function targetEgg(screenPoint)
	local tool = held()
	if not tool or not tool:GetAttribute("Pickaxe") then
		return
	end
	local root = player.Character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	local target = eggFrom(mouse.Target)
	if screenPoint then
		local camera = workspace.CurrentCamera
		if camera then
			local ray = camera:ViewportPointToRay(screenPoint.X, screenPoint.Y)
			local params = RaycastParams.new()
			params.FilterType = Enum.RaycastFilterType.Exclude
			params.FilterDescendantsInstances = { player.Character }
			local hit = workspace:Raycast(ray.Origin, ray.Direction * 500, params)
			target = hit and eggFrom(hit.Instance) or nil
		end
	end
	if
		target
		and not target:GetAttribute("Hatching")
		and (target:GetPivot().Position - root.Position).Magnitude < Game.SwingRange
	then
		return target
	end
	local folder = workspace.Map:FindFirstChild("Adventure")
	if not folder then
		return
	end
	local closest, distance = nil, Game.SwingRange
	for _, model in folder:GetChildren() do
		if model:IsA("Model") and model:GetAttribute("BreakableEgg") and not model:GetAttribute("Hatching") then
			local d = (model:GetPivot().Position - root.Position).Magnitude
			if d < distance then
				closest = model
				distance = d
			end
		end
	end
	return closest
end
local function swing(screenPoint)
	if
		player:GetAttribute("UIWindowOpen")
		or player:GetAttribute("OnTreadmill")
		or (player:GetAttribute("CarryingCount") or 0) > 0
		or not player:GetAttribute("PetDataReady")
	then
		return
	end
	local tool = held()
	if not tool then
		return
	end
	if os.clock() - last < (tool.Name == "Lava Bat" and 0.8 or Game.SwingCooldown) then
		return
	end
	if tool:GetAttribute("Pickaxe") then
		local target = targetEgg(screenPoint)
		last = os.clock()
		local character = player.Character
		local id = target and target:GetAttribute("EggId")
		PickaxeEffects.swing(character)
		task.delay(Game.SwingImpactTime, function()
			local humanoid = character:FindFirstChildOfClass("Humanoid")
			if
				player.Character == character
				and tool.Parent == character
				and humanoid
				and humanoid.Health > 0
				and not player:GetAttribute("UIWindowOpen")
				and not player:GetAttribute("OnTreadmill")
			then
				-- Play the impact now instead of waiting a round trip for EggHit.
				local root = character:FindFirstChild("HumanoidRootPart")
				if
					target
					and target.Parent
					and not target:GetAttribute("Hatching")
					and root
					and (target:GetPivot().Position - root.Position).Magnitude < Game.SwingRange
				then
					PickaxeEffects.predict(target, character)
				end
				action:FireServer("Swing", id)
			end
		end)
	elseif tool.Name == "Lava Bat" then
		last = os.clock()
		local character = player.Character
		PickaxeEffects.swing(character)
		task.delay(Game.SwingImpactTime, function()
			local humanoid = character:FindFirstChildOfClass("Humanoid")
			if
				player.Character == character
				and tool.Parent == character
				and humanoid
				and humanoid.Health > 0
				and not player:GetAttribute("UIWindowOpen")
				and not player:GetAttribute("OnTreadmill")
			then
				action:FireServer("Bat")
			end
		end)
	end
end
UIS.InputBegan:Connect(function(input, processed)
	if processed then
		return
	end
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		swing()
	end
end)
UIS.TouchTapInWorld:Connect(function(at, processed)
	if not processed then
		swing(at)
	end
end)
local highlight = Instance.new("Highlight")
highlight.Name = "TargetEgg"
highlight.FillTransparency = 1
highlight.OutlineColor = Color3.fromRGB(255, 237, 105)
highlight.DepthMode = Enum.HighlightDepthMode.Occluded
highlight.Enabled = false
highlight.Parent = workspace
local accumulator = 0
RunService.RenderStepped:Connect(function(dt)
	accumulator += dt
	if accumulator < 0.1 then
		return
	end
	accumulator = 0
	local target
	if not player:GetAttribute("UIWindowOpen") then
		target = targetEgg()
	end
	highlight.Adornee = target
	highlight.Enabled = target ~= nil
	if player:GetAttribute("AutoSwing") then
		swing()
	end
end)
feedback.OnClientEvent:Connect(function(name, at, extra)
	if name == "Open" then
		local bootstrap = player.PlayerScripts:FindFirstChild("ShopUIBootstrap")
		local controller = bootstrap and bootstrap:FindFirstChild("UIController")
		if controller then
			controller:Fire("Open", at)
		end
	elseif name == "ToolSwing" then
		if typeof(extra) == "Instance" and extra:IsA("Model") and extra ~= player.Character then
			PickaxeEffects.swing(extra, true)
		end
	elseif name == "EggHit" then
		if type(extra) == "table" then
			if extra.character and extra.character ~= player.Character then
				PickaxeEffects.swing(extra.character, true)
			end
			PickaxeEffects.hit(at, extra)
		end
	elseif name == "Hatch" then
		if type(extra) == "table" then
			HatchEffects.begin(extra.model)
		end
	end
end)
task.spawn(function()
	local folder = workspace:WaitForChild("Map"):WaitForChild("Adventure")
	HatchEffects.watch(folder)
	PickaxeEffects.watchEggs(folder)
end)
local function ownMarker()
	local bases = workspace.Map.StartZone.PlayerBases
	for _, base in bases:GetChildren() do
		local contents = base:FindFirstChild("PetContents")
		local marker = contents and contents:FindFirstChild("BaseMarker")
		if marker then
			local gui = marker:FindFirstChild("BaseMarkerUI")
			if gui and base:GetAttribute("OwnerUserId") == player.UserId then
				gui.OwnerTitle.Text = "Your Base"
				local icon = require(RS.ShopUI.Assets).home
				gui.OwnerHead.Image = icon.image
				gui.OwnerHead.ImageRectOffset = icon.offset
				gui.OwnerHead.ImageRectSize = icon.rect
			end
		end
	end
end
player:GetAttributeChangedSignal("BaseName"):Connect(function()
	task.delay(1, ownMarker)
end)
task.delay(3, ownMarker)
-- Rising lava is drawn locally from the server's wave start (LavaWaveAt), so it moves smoothly;
-- the server applies the same GameConfig.lavaHeight for burns.
task.spawn(function()
	local biomes = workspace:WaitForChild("Map"):WaitForChild("Biomes")
	local north, south =
		biomes:WaitForChild("Forest"):WaitForChild("Floor"), biomes:WaitForChild("Snow"):WaitForChild("Floor")
	local far = south.Position.Z - south.Size.Z / 2
	local depth = Game.SafeZ - far
	local w = Game.LavaWave
	local low, high = Game.FieldFloorY + w.low, Game.FieldFloorY + w.high
	local function slab(name, height, color, transparency, material)
		local part = Instance.new("Part")
		part.Name = name
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.CastShadow = false
		part.Material = material
		part.Color = color
		part.Transparency = transparency
		part.Size = Vector3.new(north.Size.X, height, depth)
		return part
	end
	-- Cartoon look: flat, almost opaque orange body with a lighter top band and ball bubbles.
	local body = slab("RisingLava", high - low + 4, Color3.fromRGB(245, 96, 28), 0.12, Enum.Material.SmoothPlastic)
	local surface = slab("LavaSurface", 0.4, Color3.fromRGB(255, 160, 50), 0.05, Enum.Material.SmoothPlastic)
	local embers = Instance.new("ParticleEmitter")
	embers.Name = "Embers"
	embers.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	embers.Color = ColorSequence.new(Color3.fromRGB(255, 220, 90))
	embers.LightEmission = 0.5
	embers.Lifetime = NumberRange.new(1, 2)
	embers.Speed = NumberRange.new(3, 6)
	embers.EmissionDirection = Enum.NormalId.Top
	embers.SpreadAngle = Vector2.new(15, 15)
	embers.Size = NumberSequence.new(0.5, 0)
	embers.Parent = surface
	local bubbles = {}
	for i = 1, 14 do
		local ball = Instance.new("Part")
		ball.Name = "LavaBubble"
		ball.Shape = Enum.PartType.Ball
		ball.Anchored = true
		ball.CanCollide = false
		ball.CanQuery = false
		ball.CanTouch = false
		ball.CastShadow = false
		ball.Material = Enum.Material.SmoothPlastic
		ball.Color = Color3.fromRGB(255, 186, 70)
		ball.Parent = surface
		bubbles[i] = { part = ball, offset = i / 14, speed = 0.5 + (i % 4) * 0.12, size = 1.2 + (i % 3) * 0.6 }
	end
	local minX, maxX = north.Position.X - north.Size.X / 2, north.Position.X + north.Size.X / 2
	local function spot()
		local focus = workspace.CurrentCamera.Focus.Position
		return math.clamp(focus.X + math.random(-35, 35), minX + 2, maxX - 2),
			math.clamp(focus.Z + math.random(-35, 35), far + 2, Game.SafeZ - 2)
	end
	local tint = Instance.new("ColorCorrectionEffect")
	tint.Name = "LavaTint"
	tint.Enabled = false
	tint.Parent = game:GetService("Lighting")
	local glow = Color3.fromRGB(255, 210, 180)
	RunService.Heartbeat:Connect(function()
		local started = workspace:GetAttribute("LavaWaveAt")
		local elapsed = started and workspace:GetServerTimeNow() - started
		local y = elapsed and Game.lavaHeight(elapsed)
		if not y then
			surface.Parent, tint.Enabled = nil, false
			body.Parent = nil
			return
		end
		-- Fade in/out over the first and last second; strength follows the height.
		local fade = math.clamp(math.min(elapsed, w.rise + w.hold + w.fall - elapsed), 0, 1)
		local strength = math.clamp((y - low) / (high - low), 0, 1)
		local top = y + math.sin(os.clock() * 2) * 0.08 -- visual only; burns use y
		local x, z = north.Position.X, Game.SafeZ - depth / 2
		body.Position = Vector3.new(x, top - 0.4 - body.Size.Y / 2, z)
		surface.Position = Vector3.new(x, top - 0.2, z)
		body.Transparency = 1 - 0.88 * fade
		surface.Transparency = 1 - 0.95 * fade
		embers.Rate = 6 + 14 * strength
		-- Each bubble swells out of the surface and pops, then reappears near the camera.
		for _, b in bubbles do
			local phase = (os.clock() * b.speed + b.offset) % 1
			if phase < (b.last or 1) then
				b.x, b.z = spot()
			end
			b.last = phase
			local d = b.size * math.sin(phase * math.pi) * fade
			b.part.Size = Vector3.one * math.max(d, 0.05)
			b.part.Transparency = d < 0.1 and 1 or 0
			b.part.Position = Vector3.new(b.x, top - d * 0.2, b.z)
		end
		tint.TintColor = Color3.new(1, 1, 1):Lerp(glow, strength * fade * 0.3)
		tint.Enabled = true
		body.Parent, surface.Parent = workspace, workspace
	end)
end)
-- Tick for the last five seconds before a lava wave while in the field.
player:GetAttributeChangedSignal("EventRemaining"):Connect(function()
	local left = player:GetAttribute("EventRemaining") or 0
	if player:GetAttribute("InField") and left > 0 and left <= 5 then
		Audio.play("HatchHeart", nil, { pitch = 1 + (5 - left) * 0.08 })
	end
end)
BaseFence.watch(workspace:WaitForChild("Map"):WaitForChild("StartZone"):WaitForChild("PlayerBases"))
-- Standing in a shop stand's TouchZone opens its window; stepping out closes it.
task.spawn(function()
	local shops = workspace:WaitForChild("Map"):WaitForChild("StartZone"):WaitForChild("Shops")
	local zones = {}
	for _, stand in { { "BlueShopStand", "Pickaxe Shop" }, { "GreenShopStand", "Trails Shop" } } do
		local part = shops:WaitForChild(stand[1]):WaitForChild("TouchZone"):WaitForChild("TouchPart")
		table.insert(zones, { part = part, screen = stand[2], inside = false })
	end
	local controller = player.PlayerScripts:WaitForChild("ShopUIBootstrap"):WaitForChild("UIController")
	while true do
		task.wait(0.2)
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		for _, zone in zones do
			local inside = false
			if root then
				local offset = zone.part.CFrame:PointToObjectSpace(root.Position):Abs()
				inside = offset.X <= zone.part.Size.X / 2
					and offset.Y <= zone.part.Size.Y / 2 + 3
					and offset.Z <= zone.part.Size.Z / 2
			end
			if inside ~= zone.inside then
				zone.inside = inside
				controller:Fire(inside and "Show" or "Hide", zone.screen)
			end
		end
	end
end)
