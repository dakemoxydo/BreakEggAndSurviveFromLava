local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Tween = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local Game = require(game.ReplicatedStorage.GameConfig)
local PickaxeEffects = require(game.ReplicatedStorage.PickaxeEffects)
local Audio = require(game.ReplicatedStorage.Audio)
local GameFeel = require(game.ReplicatedStorage.GameFeel)
local Library = require(game.ReplicatedStorage.SoundLibrary)
local Assets = require(game.ReplicatedStorage.ShopUI.Assets)
local player = Players.LocalPlayer
local Effects = {}
local running = setmetatable({}, { __mode = "k" })
local watched = setmetatable({}, { __mode = "k" })
local random = Random.new()
local white = Color3.new(1, 1, 1)

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
-- Major pentatonic: every rarity step rings the next note, so a climb plays a tune.
local Notes = { 0, 2, 4, 7, 9, 12, 14 }
local function note(index)
	return 2 ^ (Notes[math.clamp(index - 1, 1, #Notes)] / 12)
end

local function ring(parent, at, scale, color, time, size)
	local p = part(parent, "HatchRing", at, Vector3.new(0.1, 2, 2) * scale, color)
	p.Shape = Enum.PartType.Cylinder
	p.CFrame = CFrame.new(at) * CFrame.Angles(0, 0, math.pi / 2)
	fade(p, time, { Size = Vector3.new(0.05, size, size) * scale, Transparency = 1 })
	return p
end

-- Rarity name over the egg; it stays until the next step pushes it away.
local function banner(parent, at, index)
	local color = tierColor(index)
	local anchor = part(parent, "HatchTierBanner", at, Vector3.one * 0.1, color)
	anchor.Transparency = 1
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromScale(6, 1.4)
	gui.LightInfluence = 0
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
	Tween:Create(uiScale, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	Tween:Create(
		gui,
		TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ StudsOffsetWorldSpace = Vector3.new(0, 0.6, 0) }
	):Play()
	return function()
		fade(gui, 0.25, { StudsOffsetWorldSpace = Vector3.new(0, 2, 0) })
		fade(uiScale, 0.25, { Scale = 0.6 })
		fade(label, 0.25, { TextTransparency = 1 })
		fade(stroke, 0.25, { Transparency = 1 })
		Debris:AddItem(anchor, 0.3)
	end
end

-- Short screen tint for the player who broke the egg.
local function screenFlash(color, strength)
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	local effect = Instance.new("ColorCorrectionEffect")
	effect.Name = "HatchFlash"
	effect.Brightness = 0.22 * strength
	effect.TintColor = white:Lerp(color, 0.3 * strength)
	effect.Parent = camera
	fade(effect, 0.5, { Brightness = 0, TintColor = white })
	Debris:AddItem(effect, 0.6)
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
	-- Wide ground shockwave on every hatch.
	ring(folder, at + Vector3.new(0, 0.08, 0), scale, color:Lerp(white, 0.4), 0.8, 16 + tier * 2)
	if tier >= 4 then
		ring(folder, at + Vector3.new(0, 0.3, 0), scale, white, 0.8, 14 + tier * 2)
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
	Audio.play("HatchShatter", center)
	Audio.play(Library.Reveal[Game.Rarities[tier].key] or "RevealCommon", center)
	if tier >= 5 then
		Audio.play("EggBreak", center, { pitch = 0.8 })
	end
	if tier >= 6 then
		Audio.play("HatchShimmer", center, { pitch = 1.1 })
	end
	PickaxeEffects.burst(
		center,
		color,
		{ Sparks = reduced and 10 or 20 + tier * 8, Dust = reduced and 0 or 6 },
		scale * (1 + tier * 0.12)
	)
	if tier >= 4 and not reduced then
		-- Confetti in the rarity colors.
		PickaxeEffects.chips(
			center,
			14 + (tier - 4) * 8,
			{ color, white, tierColor(tier - 1), color:Lerp(white, 0.5) },
			scale,
			26,
			at.Y
		)
	end
	if owner then
		GameFeel.shake(0.25 + tier * 0.06)
		if tier >= 4 then
			GameFeel.punch(5 + (tier - 4) * 2.5, 0.8)
		else
			GameFeel.punch(2, 0.4)
		end
		if not reduced then
			screenFlash(color, 0.6 + tier * 0.1)
		end
	end
	if shell then
		local mesh = shell.PrimaryPart
		if mesh and mesh:IsA("MeshPart") and not reduced then
			-- One mesh cannot shatter: swap it for voxel chunks spread through its volume.
			for _ = 1, 26 do
				local offset = Vector3.new(
					random:NextNumber(-0.35, 0.35),
					random:NextNumber(-0.4, 0.4),
					random:NextNumber(-0.35, 0.35)
				) * mesh.Size
				local size = mesh.Size.X / 6 * random:NextNumber(0.7, 1.2)
				part(shell, "ShellChunk", mesh.CFrame * offset, Vector3.one * size, mesh.Color)
			end
			mesh:Destroy()
		end
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

-- Charge phase, timed from server time. After the intro the egg beats like a
-- heart: BeatCount beats with gaps shrinking by BeatRatio between BeatFirst and
-- BeatLast of the duration. A beat either raises the glow one rarity (pop,
-- chime, ring, name) or is a failed try: the next color leaks in and fades.
-- Raises are spread over the beats up to the rolled rarity (HatchRarity); the
-- last beat is sometimes kept for a near miss one tier above. After the last
-- beat the result is held, then the shell draws in, freezes and bursts.
local Intro, SpinEnd, Lift = 0.8, 0.75, 0.9
local BeatCount, BeatRatio, BeatFirst, BeatLast = 7, 0.85, 0.2, 0.77
local BlendTime, LeakTime = 0.2, 0.5
local InhaleTime, FreezeTime = 0.55, 0.1
local RiserLength, InhaleSoundLength = 6.06, 1.34
local function beatTimes(duration)
	local list = {}
	local total = (1 - BeatRatio ^ (BeatCount - 1)) / (1 - BeatRatio)
	local sum = 0
	for i = 1, BeatCount do
		list[i] = duration * (BeatFirst + (BeatLast - BeatFirst) * sum / total)
		sum += BeatRatio ^ (i - 1)
	end
	return list
end
-- Rarity shown after each beat: `steps` raises spread over the first `slots` beats.
local function beatTiers(target, slots)
	local raises, steps = {}, target - 1
	for j = 1, steps do
		raises[slots - math.floor((steps - j) * slots / steps)] = true
	end
	local tiers, tier = {}, 1
	for i = 1, BeatCount do
		if raises[i] then
			tier += 1
		end
		tiers[i] = tier
	end
	return tiers
end
-- Scale offset after a beat: a damped bounce peaking near `peak`.
local function bounceAfter(x, peak)
	if x < 0 or x > 1.2 then
		return 0
	end
	return 1.5 * peak * math.sin(18 * x) * math.exp(-5 * x) - 0.06 * math.exp(-25 * x)
end
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
	-- Near miss: the last beat tries one tier above the result, never above Mythic.
	local tease = target < 6 and rng:NextNumber() < 0.5
	local beats = beatTimes(duration)
	local tiers = beatTiers(target, tease and BeatCount - 1 or BeatCount)
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
			p.Color = white
			p.Material = Enum.Material.Neon
			p.MaterialVariant = ""
			if p:IsA("MeshPart") then
				p.TextureID = ""
			end
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
	gui.Size = UDim2.fromScale(7, 1.8)
	gui.AlwaysOnTop = false
	gui.Adornee = anchor
	gui.Parent = anchor
	local label = Instance.new("TextLabel")
	label.Name = "Luck"
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 0.5)
	label.Position = UDim2.fromScale(0, 0.25)
	label.Font = Enum.Font.GothamBlack
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(171, 255, 72)
	label.Text = luckText(0)
	label.Parent = gui
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 3
	stroke.Color = Color3.fromRGB(20, 30, 17)
	stroke.Parent = label
	-- Sunburst behind the egg: pushed away from the camera every frame.
	local rays = Instance.new("BillboardGui")
	rays.Name = "HatchRays"
	rays.Size = UDim2.fromScale(1, 1)
	rays.LightInfluence = 0
	rays.Brightness = 1.6
	rays.Adornee = anchor
	rays.Parent = anchor
	local rayLayers = {}
	for i = 1, 2 do
		local image = Instance.new("ImageLabel")
		image.BackgroundTransparency = 1
		image.Image = Assets.sunburst.image
		image.AnchorPoint = Vector2.new(0.5, 0.5)
		image.Position = UDim2.fromScale(0.5, 0.5)
		image.Size = UDim2.fromScale(i == 1 and 1 or 0.8, i == 1 and 1 or 0.8)
		image.ImageTransparency = 1
		image.Parent = rays
		rayLayers[i] = image
	end
	local glow = Instance.new("Highlight")
	glow.Name = "HatchGlow"
	glow.Adornee = shell
	glow.FillColor = white
	glow.FillTransparency = 0.7
	glow.OutlineColor = white
	glow.OutlineTransparency = 0.3
	glow.DepthMode = Enum.HighlightDepthMode.Occluded
	glow.Parent = folder
	local motes = {}
	if not reduced then
		for _ = 1, 8 do
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
	local leakColor, leakStart, leakPeak, leakTime = white, -math.huge, 0, LeakTime
	local lastBeat, lastPeak = -math.huge, 0
	local retireBanner
	local sounds = {}
	local function paint(color)
		glow.FillColor = color:Lerp(white, 0.55)
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
		for _, image in rayLayers do
			image.ImageColor3 = color
		end
		if shown > 1 then
			label.TextColor3 = color
		end
	end
	local function currentColor(now)
		return fromColor:Lerp(toColor, smooth(math.clamp((now - blendStart) / BlendTime, 0, 1)))
	end
	-- One beat. `quiet` catches up after a late join or a frame hitch without effects.
	local function beat(i, time, quiet)
		local raise = tiers[i] > shown
		if raise then
			fromColor = quiet and tierColor(tiers[i]) or currentColor(time)
			toColor = tierColor(tiers[i])
			blendStart = quiet and -math.huge or time
			shown = tiers[i]
		end
		if quiet then
			return
		end
		local scale = shell:GetScale()
		local point = at + Vector3.new(0, 2.2 * scale, 0)
		lastBeat = time
		Audio.play("HatchHeart", anchor, { pitch = 0.85 + i * 0.05, volume = 0.6 + i * 0.07 })
		if raise then
			local color = tierColor(shown)
			lastPeak = reduced and 0 or 0.2 + shown * 0.015
			Audio.play("HatchChime", anchor, { pitch = note(shown) })
			if shown >= 4 then
				Audio.play("HatchShimmer", anchor, { pitch = 0.85 + shown * 0.05, volume = 0.4 + (shown - 4) * 0.2 })
			end
			ring(folder, at + Vector3.new(0, 0.15, 0), scale, color, 0.7, 8 + shown * 1.5)
			ring(folder, at + Vector3.new(0, 1.2 * scale, 0), scale, color:Lerp(white, 0.4), 0.45, 6 + shown)
			if retireBanner then
				retireBanner()
			end
			retireBanner = banner(folder, at + Vector3.new(0, 3.6 * scale, 0), shown)
			PickaxeEffects.burst(point, color, { Sparks = reduced and 6 or 16 + shown * 5 }, scale * (1 + shown * 0.08))
			if owner then
				GameFeel.shake(0.1 + shown * 0.035)
				if shown >= 4 then
					GameFeel.punch(1.5 + (shown - 4), 0.35)
				end
			end
		else
			-- Failed try: the next color leaks in and drains away with a falling note.
			local nearMiss = tease and i == BeatCount
			local next = math.min(shown + 1, #Game.Rarities)
			lastPeak = reduced and 0 or (nearMiss and 0.14 or 0.08)
			leakColor, leakStart = tierColor(next), time
			leakPeak = nearMiss and 0.6 or 0.3
			leakTime = nearMiss and 0.8 or LeakTime
			Audio.play("HatchTry", anchor, { pitch = 0.9 + i * 0.03 })
			local chime = Audio.play("HatchChime", anchor, { pitch = note(next), volume = nearMiss and 0.7 or 0.35 })
			if chime then
				Tween:Create(
					chime,
					TweenInfo.new(nearMiss and 0.6 or 0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
					{ PlaybackSpeed = chime.PlaybackSpeed * 0.7 }
				):Play()
			end
			PickaxeEffects.burst(point, tierColor(next), { Sparks = reduced and 2 or (nearMiss and 14 or 5) }, scale)
			if owner then
				GameFeel.shake(nearMiss and 0.12 or 0.05)
			end
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
			for _, sound in sounds do
				sound:Destroy()
			end
		end
		if explode then
			label.Text = luckText(luck)
			label.TextColor3 = tierColor(target)
			fade(label, 0.35, { TextTransparency = 1 })
			fade(stroke, 0.35, { Transparency = 1 })
			if retireBanner then
				retireBanner()
			end
			-- The rays flare out with the burst.
			fade(rays, 0.45, { Size = UDim2.fromScale(rays.Size.X.Scale * 2.5, rays.Size.Y.Scale * 2.5) })
			for _, image in rayLayers do
				fade(image, 0.45, { ImageTransparency = 1 })
			end
			for _, mote in motes do
				mote:Destroy()
			end
			for _, beam in beams do
				beam.part:Destroy()
			end
			glow:Destroy()
			Debris:AddItem(folder, 0.5)
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
	local intro = duration > Intro and Intro or 0
	local landed = workspace:GetServerTimeNow() - started >= intro
	local riserStarted, inhaleStarted = false, false
	local done = 0
	-- A late join catches up silently.
	local joined = workspace:GetServerTimeNow() - started
	while done < BeatCount and beats[done + 1] <= joined do
		done += 1
		beat(done, beats[done], true)
	end
	local spinRays = 0
	connection = RunService.RenderStepped:Connect(function(dt)
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
		-- The riser ends right on the burst.
		if not riserStarted and not inIntro then
			riserStarted = true
			if elapsed < duration - 0.6 then
				local speed = RiserLength / (duration - intro)
				local riser = Audio.play("HatchRiser", at + Vector3.new(0, 2 * baseScale, 0), { pitch = speed })
				if riser then
					riser.TimePosition = math.max(0, elapsed - intro) * speed
					table.insert(sounds, riser)
				end
			end
		end
		if not inhaleStarted and elapsed >= duration - InhaleSoundLength then
			inhaleStarted = true
			if elapsed < duration - 0.8 then
				local inhaleSound = Audio.play("HatchInhale", at + Vector3.new(0, 2 * baseScale, 0))
				if inhaleSound then
					table.insert(sounds, inhaleSound)
				end
			end
		end
		while done < BeatCount and beats[done + 1] <= elapsed do
			done += 1
			-- Only the newest beat of a hitch plays its effects.
			beat(done, beats[done], done < BeatCount and beats[done + 1] <= elapsed)
		end
		local leak = math.clamp((elapsed - leakStart) / leakTime, 0, 1)
		local leakAmount = leak > 0 and leak < 1 and math.sin(math.pi * leak) * leakPeak or 0
		paint(currentColor(elapsed):Lerp(leakColor, leakAmount))
		-- Squeeze right before the next beat, damped bounce after the last one.
		local nextBeat = beats[done + 1]
		local squeeze = (reduced or not nextBeat) and 0
			or -0.06 * smooth(math.clamp(1 - (nextBeat - elapsed) / 0.12, 0, 1))
		local pop = bounceAfter(elapsed - lastBeat, lastPeak)
		local progress = smooth(t)
		-- End: the shell draws in, shakes harder, then freezes for a moment before the burst.
		local inhale = smooth(math.clamp((elapsed - (duration - InhaleTime)) / (InhaleTime - FreezeTime), 0, 1))
		local frozen = elapsed >= duration - FreezeTime
		local scale = baseScale * (1 + (growth - 1) * progress) * (1 - 0.12 * inhale) * (1 + pop + squeeze)
		local intensity = (inIntro or frozen) and 0 or (1 + inhale)
		local vibration = reduced and 0 or (0.012 + 0.075 * t * t) * math.sin(elapsed * (18 + 22 * t)) * intensity
		local bounce = reduced and 0
			or math.abs(math.sin(elapsed * (8 + 10 * t))) * 0.08 * baseScale * t * intensity * (1 - inhale)
		shell:ScaleTo(scale)
		bounce += lift
		shell:PivotTo(
			pivot * CFrame.new(0, bounce, 0) * CFrame.Angles(0, spin, 0) * CFrame.Angles(vibration, 0, vibration * 0.7)
		)
		anchor.Position = at + Vector3.new(0, 2.3 * scale + bounce, 0)
		gui.StudsOffsetWorldSpace = Vector3.new(0, 2.4 * scale + 1, 0)
		-- The counter rolls up on every beat and holds between them.
		local counted = done == 0 and 0
			or (done - 1 + smooth(math.clamp((elapsed - beats[done]) / 0.25, 0, 1))) / BeatCount
		label.Text = luckText(luck * counted)
		label.TextSize = 36 + math.floor(8 * progress + 30 * math.max(pop, 0))
		glow.FillTransparency = 0.7 - progress * 0.35 - inhale * 0.25 - math.max(pop, 0)
		glow.OutlineTransparency = 0.3 - progress * 0.2
		local camera = workspace.CurrentCamera
		local awake = math.clamp((elapsed - intro) / 0.4, 0, 1)
		spinRays += dt * (reduced and 0 or 20 + 140 * progress * progress + 15 * shown)
		local raySize = baseScale * (3 + 3.5 * progress + 0.4 * shown) * (1 + 2 * math.max(pop, 0) + 0.5 * inhale)
		rays.Size = UDim2.fromScale(raySize, raySize)
		rays.StudsOffsetWorldSpace = camera and camera.CFrame.LookVector * (1.6 * scale) or Vector3.zero
		for i, image in rayLayers do
			image.Rotation = i == 1 and spinRays or -spinRays * 0.6
			image.ImageTransparency = 1 - awake * (i == 1 and 0.55 + 0.25 * progress or 0.3 + 0.2 * progress)
		end
		local center = at + Vector3.new(0, 2 * scale + bounce, 0)
		local visible = math.min(#beams, 1 + 2 * shown)
		for i, beam in beams do
			local p = beam.part
			if i > visible then
				p.Transparency = 1
			else
				local yaw = beam.yaw + (reduced and 0 or elapsed * (0.4 + shown * 0.15))
				local direction = Vector3.new(
					math.cos(yaw) * math.cos(beam.pitch),
					math.sin(beam.pitch),
					math.sin(yaw) * math.cos(beam.pitch)
				)
				local length = (1.2 + 3.5 * progress + shown * 0.5)
					* beam.length
					* scale
					* (1 + inhale * 0.6 + math.max(pop, 0) * 2)
				p.Size = Vector3.new(0.18 * scale, 0.18 * scale, length)
				p.CFrame =
					CFrame.lookAt(center + direction * (length / 2 + scale), center + direction * (length + scale))
				p.Transparency = 0.35 + 0.4 * (1 - progress)
			end
		end
		for i, mote in motes do
			local angle = i * math.pi / 4 + elapsed * (1.2 + progress * 2 + shown * 0.3)
			local radius = 2.1 * scale * (1 - inhale * 0.5)
			mote.Position = at
				+ Vector3.new(
					math.cos(angle) * radius,
					(1.3 + math.sin(angle * 2) * 0.8 + progress) * scale,
					math.sin(angle) * radius
				)
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
	gui.Size = UDim2.fromScale(8, 2.4)
	gui.AlwaysOnTop = false
	gui.LightInfluence = 0
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
		-- Imported templates carry reserved RBX_* attributes that scripts cannot clear.
		if not name:find("^RBX_") then
			visual:SetAttribute(name, nil)
		end
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
