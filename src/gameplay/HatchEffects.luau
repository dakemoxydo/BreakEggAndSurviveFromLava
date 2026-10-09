local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Tween = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local Game = require(game.ReplicatedStorage.GameConfig)
local PickaxeEffects = require(game.ReplicatedStorage.PickaxeEffects)
local Audio = require(game.ReplicatedStorage.Audio)
local GameFeel = require(game.ReplicatedStorage.GameFeel)
local Library = require(game.ReplicatedStorage.SoundLibrary)
local player = Players.LocalPlayer
local Effects = {}
local running = setmetatable({}, { __mode = "k" })
local watched = setmetatable({}, { __mode = "k" })
local random = Random.new()

local function part(parent, name, at, size, color)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Position = at
	p.Color = color
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.CastShadow = false
	p.Material = Enum.Material.Neon
	p.Parent = parent
	return p
end
local function fade(object, time, properties)
	Tween:Create(object, TweenInfo.new(time, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), properties):Play()
end
local function smooth(t)
	return t * t * (3 - 2 * t)
end
local function luckText(value)
	return string.format("x%.2f Luck", value)
end
local function seed(text)
	local value = 0
	for i = 1, #text do
		value = (value * 31 + string.byte(text, i)) % 2147483647
	end
	return value
end
local function tierColor(index)
	local item = Game.Rarities[math.clamp(index, 1, #Game.Rarities)]
	return item.color
end

local function ring(parent, at, scale, color, time, size)
	local p = part(parent, "HatchRing", at, Vector3.new(0.1, 2, 2) * scale, color)
	p.Shape = Enum.PartType.Cylinder
	p.CFrame = CFrame.new(at) * CFrame.Angles(0, 0, math.pi / 2)
	fade(p, time, { Size = Vector3.new(0.05, size, size) * scale, Transparency = 1 })
	return p
end

-- Rarity name that pops over the egg on every step of the ladder.
local function banner(parent, at, index)
	local color = tierColor(index)
	local anchor = part(parent, "HatchTierBanner", at, Vector3.one * 0.1, color)
	anchor.Transparency = 1
	Debris:AddItem(anchor, 1.1)
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(260, 60)
	gui.LightInfluence = 0
	gui.MaxDistance = 180
	gui.Parent = anchor
	local uiScale = Instance.new("UIScale")
	uiScale.Scale = 0.3
	uiScale.Parent = gui
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.GothamBlack
	label.TextScaled = true
	label.TextColor3 = color
	label.Text = string.upper(Game.Rarities[index].key) .. "!"
	label.Parent = gui
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 3
	stroke.Parent = label
	Tween:Create(uiScale, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	Tween:Create(
		gui,
		TweenInfo.new(1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ StudsOffsetWorldSpace = Vector3.new(0, 1.5, 0) }
	):Play()
	local fadeInfo = TweenInfo.new(0.35, Enum.EasingStyle.Linear, Enum.EasingDirection.Out, 0, false, 0.6)
	Tween:Create(label, fadeInfo, { TextTransparency = 1 }):Play()
	Tween:Create(stroke, fadeInfo, { Transparency = 1 }):Play()
end

local function burst(shell, at, scale, tier, reduced, owner)
	local color = tierColor(tier)
	local center = at + Vector3.new(0, 2 * scale, 0)
	local folder = Instance.new("Folder")
	folder.Name = "HatchBurst"
	folder.Parent = workspace
	Debris:AddItem(folder, 1.6)
	local flash = part(folder, "HatchFlash", center, Vector3.one * scale, color)
	flash.Shape = Enum.PartType.Ball
	fade(flash, 0.4, { Size = Vector3.one * (5 + tier * 0.6) * scale, Transparency = 1 })
	ring(folder, at + Vector3.new(0, 0.12, 0), scale, color, 0.55, 9 + tier)
	if tier >= 4 then
		ring(folder, at + Vector3.new(0, 0.3, 0), scale, Color3.new(1, 1, 1), 0.8, 14 + tier * 2)
	end
	if tier >= 5 then
		-- Column of light for Legendary and above.
		local pillar =
			part(folder, "HatchPillar", at + Vector3.new(0, 30, 0), Vector3.new(60, 2.5 * scale, 2.5 * scale), color)
		pillar.Shape = Enum.PartType.Cylinder
		pillar.CFrame = CFrame.new(at + Vector3.new(0, 30, 0)) * CFrame.Angles(0, 0, math.pi / 2)
		pillar.Transparency = 0.2
		fade(pillar, 1.4, { Size = Vector3.new(60, 7 * scale, 7 * scale), Transparency = 1 })
	end
	Audio.play("HatchPop", center)
	Audio.play(Library.Reveal[Game.Rarities[tier].key] or "RevealCommon", center)
	if tier >= 5 then
		Audio.play("EggBreak", center, { pitch = 0.8 })
	end
	PickaxeEffects.burst(
		center,
		color,
		{ Sparks = reduced and 10 or 20 + tier * 8, Dust = reduced and 0 or 6 },
		scale * (1 + tier * 0.12)
	)
	if owner then
		GameFeel.shake(0.25 + tier * 0.06)
		if tier >= 4 then
			GameFeel.punch(5 + (tier - 4) * 2.5, 0.8)
		end
	end
	if shell then
		for _, p in shell:GetChildren() do
			if p:IsA("BasePart") then
				if reduced then
					p.Transparency = 1
				else
					p.Parent = folder
					local delta = p.Position - center
					local direction = delta.Magnitude > 0.01 and delta.Unit or Vector3.new(0, 1, 0)
					p.Transparency = 0
					PickaxeEffects.fling(
						p,
						(direction * random:NextNumber(14, 22) + Vector3.new(0, random:NextNumber(10, 18), 0))
							* scale ^ 0.5,
						at.Y,
						random:NextNumber(0.8, 1.2)
					)
				end
			end
		end
		Debris:AddItem(shell, 0.5)
	end
end

-- Charge phase. The glow starts white and climbs the rarity ladder up to the
-- rolled rarity (HatchRarity): steps are evenly spaced between 20% and 80% of
-- the growth. Each color blends in over BlendTime; once it has arrived the
-- step is marked by a ring, sparks, a pop and the rarity name. Sometimes the
-- color drifts toward one tier higher and back right before the burst, then
-- everything holds still for a beat. Timing comes from server time.
local BlendTime = 0.4
-- Opening beat before the charge: one full spin while lifting off the ground,
-- then a drop back onto it. The ladder and growth use the time after it.
local Intro, SpinEnd, Lift = 1, 0.75, 0.9
function Effects.begin(model)
	if
		not model
		or not model:IsA("Model")
		or not model.PrimaryPart
		or running[model]
		or not model:GetAttribute("Hatching")
	then
		return
	end
	local started = model:GetAttribute("HatchStarted")
	if type(started) ~= "number" then
		return
	end
	local duration = model:GetAttribute("HatchDuration") or Game.FieldHatchDuration
	if workspace:GetServerTimeNow() - started >= duration then
		return
	end
	PickaxeEffects.stopEggRecoil(model)
	local reduced = player:GetAttribute("ReducedMotion")
	local baseScale = model:GetScale()
	local pivot = model:GetPivot()
	local at = pivot.Position
	local growth = model:GetAttribute("HatchGrowth") or Game.FieldHatchGrowth
	local luck = model:GetAttribute("HatchLuck") or 1
	local target = Game.RarityIndex[model:GetAttribute("HatchRarity")] or 1
	local owner = model:GetAttribute("HatchedBy") == player.UserId
	local rng = Random.new(seed(tostring(model:GetAttribute("EggId") or "")))
	-- Near miss: one tier above the result flashes briefly, never above Mythic.
	local tease = target < 6 and rng:NextNumber() < 0.5
	local steps = {}
	for k = 2, target do
		steps[k] = 0.2 + 0.6 * (k - 1) / math.max(target - 1, 1)
	end
	local shell = model:Clone()
	shell.Name = "HatchingEggVisual"
	for name in shell:GetAttributes() do
		shell:SetAttribute(name, nil)
	end
	for _, child in shell:GetChildren() do
		if child.Name == "NestTwig" or not child:IsA("BasePart") then
			child:Destroy()
		end
	end
	-- Hide the real egg locally with Transparency: LocalTransparencyModifier did
	-- not hide it, so it stayed static under the spinning shell.
	local originals = {}
	for _, p in model:GetChildren() do
		if p:IsA("BasePart") and p.Name ~= "NestTwig" then
			originals[p] = p.Transparency
			p.Transparency = 1
		end
	end
	shell.Parent = workspace
	local cracks = {}
	for _, p in shell:GetDescendants() do
		if p:IsA("BasePart") and p.Name == "EggCrack" then
			p.Material = Enum.Material.Neon
			table.insert(cracks, p)
		elseif p:IsA("BasePart") then
			p.Color = Color3.new(1, 1, 1)
			p.Material = Enum.Material.Neon
			p.MaterialVariant = ""
		elseif p:IsA("Texture") or p:IsA("Decal") then
			p.Transparency = 1
		end
	end
	local folder = Instance.new("Folder")
	folder.Name = "HatchCharge"
	folder.Parent = workspace
	local anchor = part(folder, "HatchLuckAnchor", at, Vector3.one * 0.1, tierColor(1))
	anchor.Transparency = 1
	local gui = Instance.new("BillboardGui")
	gui.Name = "HatchLuckCounter"
	gui.Size = UDim2.fromOffset(310, 80)
	gui.MaxDistance = 180
	gui.AlwaysOnTop = false
	gui.Adornee = anchor
	gui.Parent = anchor
	local label = Instance.new("TextLabel")
	label.Name = "Luck"
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.GothamBlack
	label.TextSize = 36
	label.TextColor3 = Color3.fromRGB(171, 255, 72)
	label.Text = luckText(0)
	label.Parent = gui
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 3
	stroke.Color = Color3.fromRGB(20, 30, 17)
	stroke.Parent = label
	local glow = Instance.new("Highlight")
	glow.Name = "HatchGlow"
	glow.Adornee = shell
	glow.FillColor = Color3.new(1, 1, 1)
	glow.FillTransparency = 0.7
	glow.OutlineColor = Color3.new(1, 1, 1)
	glow.OutlineTransparency = 0.3
	glow.DepthMode = Enum.HighlightDepthMode.Occluded
	glow.Parent = folder
	local motes = {}
	if not reduced then
		for i = 1, 8 do
			table.insert(motes, part(folder, "HatchMote", at, Vector3.one * 0.12 * baseScale, tierColor(1)))
		end
	end
	-- Light shafts leaking out of the shell; more appear with every tier.
	local beams = {}
	for i = 1, 3 + 2 * #Game.Rarities do
		local beam = part(folder, "HatchBeam", at, Vector3.new(0.2, 0.2, 1) * baseScale, tierColor(1))
		beam.Transparency = 1
		beams[i] = {
			part = beam,
			yaw = rng:NextNumber(0, math.pi * 2),
			pitch = rng:NextNumber(-0.5, 0.9),
			length = rng:NextNumber(0.7, 1.2),
		}
	end
	local shown = 1
	local fromColor, toColor, blendStart = tierColor(1), tierColor(1), -math.huge
	local pulseAt, pending = -math.huge, nil
	local function paint(color)
		glow.FillColor = color:Lerp(Color3.new(1, 1, 1), 0.55)
		glow.OutlineColor = color
		for _, crack in cracks do
			crack.Color = color
		end
		for _, mote in motes do
			mote.Color = color
		end
		for _, beam in beams do
			beam.part.Color = color
		end
		if shown > 1 then
			label.TextColor3 = color
		end
	end
	local function setTier(index, quiet, now)
		local color = tierColor(index)
		-- Steps blend from the current color; a late join or step down is instant.
		fromColor = quiet and color or fromColor:Lerp(toColor, math.clamp((now - blendStart) / BlendTime, 0, 1))
		toColor = color
		blendStart = quiet and -math.huge or now
		-- The highlight waits until the new color has fully arrived.
		pending = not quiet and { index = index, at = now + BlendTime } or nil
	end
	local function highlight(index, now)
		local color = tierColor(index)
		Audio.play("HatchTierUp", anchor, { pitch = 0.85 + index * 0.12 })
		pulseAt = now
		local scale = shell:GetScale()
		local center = at + Vector3.new(0, 2.2 * scale, 0)
		ring(folder, at + Vector3.new(0, 1.2 * scale, 0), scale, color, 0.5, 7 + index)
		banner(folder, at + Vector3.new(0, 3.6 * scale, 0), index)
		PickaxeEffects.burst(center, color, { Sparks = reduced and 6 or 14 + index * 3 }, scale)
		if owner then
			GameFeel.shake(0.08 + index * 0.03)
		end
	end
	local connection, destroying, finished
	local sourceGone = false
	local function cleanup(explode)
		if finished then
			return
		end
		finished = true
		if connection then
			connection:Disconnect()
		end
		if destroying then
			destroying:Disconnect()
		end
		running[model] = nil
		if not explode then
			for p, value in originals do
				if p.Parent then
					p.Transparency = value
				end
			end
		end
		if explode then
			label.Text = luckText(luck)
			label.TextColor3 = tierColor(target)
			fade(label, 0.35, { TextTransparency = 1 })
			fade(stroke, 0.35, { Transparency = 1 })
			for _, mote in motes do
				mote:Destroy()
			end
			for _, beam in beams do
				beam.part:Destroy()
			end
			glow:Destroy()
			Debris:AddItem(folder, 0.4)
			burst(shell, at, baseScale, target, reduced, owner)
		else
			folder:Destroy()
			shell:Destroy()
		end
	end
	running[model] = cleanup
	destroying = model.Destroying:Connect(function()
		sourceGone = true
		if workspace:GetServerTimeNow() - started < duration - 0.12 then
			cleanup(false)
		end
	end)
	local lastTick, teased = -1, false
	local intro = duration > Intro and Intro or 0
	local landed = workspace:GetServerTimeNow() - started >= intro
	connection = RunService.RenderStepped:Connect(function()
		local elapsed = workspace:GetServerTimeNow() - started
		-- `t` is the charge progress after the intro.
		local t = math.clamp((elapsed - intro) / (duration - intro), 0, 1)
		if not sourceGone and not model.Parent then
			cleanup(false)
			return
		end
		if elapsed >= duration then
			cleanup(true)
			return
		end
		local inIntro = elapsed < intro
		local spin, lift = 0, 0
		if inIntro and not reduced then
			local x = elapsed / intro
			spin = math.pi * 2 * smooth(math.clamp(x / SpinEnd, 0, 1))
			lift = Lift
				* baseScale
				* (x < SpinEnd and smooth(math.clamp(x / 0.4, 0, 1)) or 1 - ((x - SpinEnd) / (1 - SpinEnd)) ^ 2)
		end
		if not inIntro and not landed then
			landed = true
			Audio.play("EggHit", at, { pitch = 0.7 })
			PickaxeEffects.burst(
				at + Vector3.new(0, 0.3, 0),
				Color3.fromRGB(200, 190, 170),
				{ Sparks = 0, Dust = reduced and 0 or 8 },
				baseScale
			)
			if owner then
				GameFeel.shake(0.12)
			end
		end
		local tier = 1
		for k = 2, target do
			if t >= steps[k] then
				tier = k
			end
		end
		local display = tier
		if display ~= shown then
			local jump = display < shown or display - shown > 1
			shown = display
			setTier(display, jump, elapsed)
		end
		if pending and elapsed >= pending.at then
			highlight(pending.index, elapsed)
			pending = nil
		end
		local color = fromColor:Lerp(toColor, smooth(math.clamp((elapsed - blendStart) / BlendTime, 0, 1)))
		-- Near miss: the color drifts partway toward the next tier and back, no flicker.
		local teaseAmount = tease and t >= 0.83 and t < 0.9 and math.sin(math.pi * (t - 0.83) / 0.07) * 0.6 or 0
		if teaseAmount > 0 and not teased then
			teased = true
			Audio.play("HatchTease", anchor, { pitch = 0.85 + (target + 1) * 0.12 })
		end
		paint(teaseAmount > 0 and color:Lerp(tierColor(target + 1), teaseAmount) or color)
		-- Short pop of the shell on every rarity step.
		local pulse = reduced and 0 or math.max(0, 1 - (elapsed - pulseAt) / 0.35) ^ 2
		local progress = smooth(t)
		-- Last tenth: everything holds still and the shell draws in before bursting.
		local inhale = t >= 0.9 and smooth((t - 0.9) / 0.1) or 0
		local scale = baseScale * (1 + (growth - 1) * progress) * (1 - 0.1 * inhale) * (1 + 0.14 * pulse)
		local intensity = inIntro and 0 or (1 - inhale)
		local vibration = reduced and 0 or (0.012 + 0.075 * t * t) * math.sin(elapsed * (18 + 22 * t)) * intensity
		local bounce = reduced and 0 or math.abs(math.sin(elapsed * (8 + 10 * t))) * 0.08 * baseScale * t * intensity
		shell:ScaleTo(scale)
		bounce += lift
		shell:PivotTo(
			pivot * CFrame.new(0, bounce, 0) * CFrame.Angles(0, spin, 0) * CFrame.Angles(vibration, 0, vibration * 0.7)
		)
		anchor.Position = at + Vector3.new(0, 2.3 * scale + bounce, 0)
		gui.StudsOffsetWorldSpace = Vector3.new(0, 2.4 * scale + 1, 0)
		label.Text = luckText(luck * progress)
		label.TextSize = 36 + math.floor(8 * progress)
		glow.FillTransparency = 0.7 - progress * 0.35 - inhale * 0.25
		glow.OutlineTransparency = 0.3 - progress * 0.2
		local center = at + Vector3.new(0, 2 * scale + bounce, 0)
		local visible = math.min(#beams, 1 + 2 * display)
		for i, beam in beams do
			local p = beam.part
			if i > visible then
				p.Transparency = 1
			else
				local yaw = beam.yaw + (reduced and 0 or elapsed * (0.4 + display * 0.15))
				local direction = Vector3.new(
					math.cos(yaw) * math.cos(beam.pitch),
					math.sin(beam.pitch),
					math.sin(yaw) * math.cos(beam.pitch)
				)
				local length = (1.2 + 3.5 * progress + display * 0.5) * beam.length * scale * (1 + inhale * 0.6)
				p.Size = Vector3.new(0.18 * scale, 0.18 * scale, length)
				p.CFrame =
					CFrame.lookAt(center + direction * (length / 2 + scale), center + direction * (length + scale))
				p.Transparency = 0.35 + 0.4 * (1 - progress)
			end
		end
		for i, mote in motes do
			local angle = i * math.pi / 4 + elapsed * (1.2 + progress * 2 + display * 0.3)
			local radius = 2.1 * scale * (1 - inhale * 0.5)
			mote.Position = at
				+ Vector3.new(
					math.cos(angle) * radius,
					(1.3 + math.sin(angle * 2) * 0.8 + progress) * scale,
					math.sin(angle) * radius
				)
		end
		local tick = math.floor(progress * 6)
		if tick ~= lastTick and inhale == 0 and not inIntro then
			lastTick = tick
			Audio.play("HatchCharge", anchor, { pitch = 1 + progress })
		end
	end)
end

-- Rarity title over a freshly hatched animal, visible to everyone nearby.
local function title(model, tier, scale)
	local camera = workspace.CurrentCamera
	local _, size = model:GetBoundingBox()
	local at = model:GetPivot().Position + Vector3.new(0, size.Y + 1.5, 0)
	if camera and (camera.CFrame.Position - at).Magnitude > 150 then
		return
	end
	local color = tierColor(tier)
	local anchor = part(workspace, "HatchTitle", at, Vector3.one * 0.1, color)
	anchor.Transparency = 1
	Debris:AddItem(anchor, 2.8)
	local gui = Instance.new("BillboardGui")
	gui.Name = "HatchRarity"
	gui.Size = UDim2.fromOffset(360, 110)
	gui.AlwaysOnTop = false
	gui.LightInfluence = 0
	gui.MaxDistance = 150
	gui.Parent = anchor
	local uiScale = Instance.new("UIScale")
	uiScale.Scale = 0.2
	uiScale.Parent = gui
	local rarity = Instance.new("TextLabel")
	rarity.BackgroundTransparency = 1
	rarity.Size = UDim2.fromScale(1, 0.58)
	rarity.Font = Enum.Font.GothamBlack
	rarity.TextScaled = true
	rarity.TextColor3 = color
	rarity.Text = string.upper(Game.Rarities[tier].key) .. (tier >= 5 and "!" or "")
	rarity.Parent = gui
	local rarityStroke = Instance.new("UIStroke")
	rarityStroke.Thickness = 4
	rarityStroke.Parent = rarity
	local name = Instance.new("TextLabel")
	name.BackgroundTransparency = 1
	name.Size = UDim2.fromScale(1, 0.4)
	name.Position = UDim2.fromScale(0, 0.6)
	name.Font = Enum.Font.GothamBlack
	name.TextScaled = true
	name.TextColor3 = Color3.new(1, 1, 1)
	name.Text = model.Name
	name.Parent = gui
	local nameStroke = Instance.new("UIStroke")
	nameStroke.Thickness = 3
	nameStroke.Parent = name
	Tween:Create(
		uiScale,
		TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{ Scale = 1 + (tier >= 5 and 0.2 or 0) }
	):Play()
	Tween:Create(
		gui,
		TweenInfo.new(2.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ StudsOffsetWorldSpace = Vector3.new(0, 1.6 * scale, 0) }
	):Play()
	local fadeInfo = TweenInfo.new(0.4, Enum.EasingStyle.Linear, Enum.EasingDirection.Out, 0, false, 2)
	for _, item in { rarity, name } do
		Tween:Create(item, fadeInfo, { TextTransparency = 1 }):Play()
	end
	for _, item in { rarityStroke, nameStroke } do
		Tween:Create(item, fadeInfo, { Transparency = 1 }):Play()
	end
	if tier >= 3 then
		local attachment = Instance.new("Attachment")
		attachment.Parent = anchor
		local sparkle = Instance.new("ParticleEmitter")
		sparkle.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		sparkle.Color = ColorSequence.new(color, Color3.new(1, 1, 1))
		sparkle.LightEmission = 1
		sparkle.LightInfluence = 0
		sparkle.Size =
			NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5 * scale), NumberSequenceKeypoint.new(1, 0) })
		sparkle.Lifetime = NumberRange.new(0.6, 1)
		sparkle.Speed = NumberRange.new(2, 5)
		sparkle.SpreadAngle = Vector2.new(180, 180)
		sparkle.Acceleration = Vector3.new(0, -4, 0)
		sparkle.Rate = 12 * tier
		sparkle.Parent = attachment
		task.delay(1.3, function()
			if sparkle.Parent then
				sparkle.Enabled = false
			end
		end)
	end
end

local function reveal(model)
	if running[model] then
		return
	end
	local count = 0
	for _, child in model:GetChildren() do
		if child:IsA("BasePart") then
			count += 1
		end
	end
	if count < (model:GetAttribute("HatchRevealPartCount") or math.huge) then
		return
	end
	local started = model:GetAttribute("HatchRevealStarted")
	if type(started) ~= "number" then
		return
	end
	local duration = model:GetAttribute("HatchRevealDuration") or Game.FieldRevealDuration
	if workspace:GetServerTimeNow() - started >= duration then
		return
	end
	local scale = model:GetScale()
	local pivot = model:GetPivot()
	local reduced = player:GetAttribute("ReducedMotion")
	local tier = Game.RarityIndex[model:GetAttribute("HatchRarity")] or 1
	title(model, tier, scale)
	local visual = model:Clone()
	visual.Name = "HatchingPetVisual"
	for name in visual:GetAttributes() do
		visual:SetAttribute(name, nil)
	end
	for _, child in visual:GetDescendants() do
		if child:IsA("BillboardGui") or child:IsA("ProximityPrompt") then
			child:Destroy()
		end
	end
	local originals = {}
	for _, child in model:GetChildren() do
		if child:IsA("BasePart") then
			originals[child] = child.Transparency
			child.Transparency = 1
		end
	end
	visual.Parent = workspace
	local connection, finished
	local function stop()
		if finished then
			return
		end
		finished = true
		if connection then
			connection:Disconnect()
		end
		for child, value in originals do
			if child.Parent then
				child.Transparency = value
			end
		end
		visual:Destroy()
		running[model] = nil
	end
	running[model] = stop
	connection = RunService.RenderStepped:Connect(function()
		if not model.Parent then
			stop()
			return
		end
		local t = math.clamp((workspace:GetServerTimeNow() - started) / duration, 0, 1)
		if t >= 1 then
			stop()
			return
		end
		local factor
		if reduced then
			factor = 0.8 + 0.2 * smooth(t)
		elseif t < 0.58 then
			local x = t / 0.58
			factor = 0.16 + 0.96 * (1 - (1 - x) ^ 3)
		else
			factor = 1.12 - 0.12 * smooth((t - 0.58) / 0.42)
		end
		visual:ScaleTo(scale * factor)
		local jump = reduced and 0 or math.sin(t * math.pi) * 0.9 * scale
		local turn = reduced and 0
			or math.sin(t * math.pi) * math.rad(22) + (tier >= 4 and (1 - (1 - t) ^ 2) * math.pi * 2 or 0)
		visual:PivotTo(pivot * CFrame.new(0, jump, 0) * CFrame.Angles(0, turn, 0))
	end)
end

local function watch(model)
	if not model:IsA("Model") or watched[model] then
		return
	end
	local connections = {}
	watched[model] = connections
	local function update()
		if not model.PrimaryPart then
			return
		end
		if model:GetAttribute("Hatching") then
			Effects.begin(model)
		end
		if model:GetAttribute("HatchRevealStarted") then
			reveal(model)
		end
	end
	table.insert(connections, model.AttributeChanged:Connect(update))
	table.insert(
		connections,
		model.ChildAdded:Connect(function()
			if model.PrimaryPart then
				update()
			end
		end)
	)
	table.insert(connections, model:GetPropertyChangedSignal("PrimaryPart"):Connect(update))
	table.insert(
		connections,
		model.Destroying:Connect(function()
			for _, c in connections do
				c:Disconnect()
			end
			watched[model] = nil
		end)
	)
	if model.PrimaryPart then
		update()
	end
end
function Effects.watch(folder)
	folder.ChildAdded:Connect(watch)
	for _, model in folder:GetChildren() do
		watch(model)
	end
end
return Effects
