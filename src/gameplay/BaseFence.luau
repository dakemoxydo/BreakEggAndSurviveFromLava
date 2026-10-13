-- Client-side fence look per pen level. Only colors, materials and decor change:
-- geometry, collisions and the base floor stay exactly as authored on the map.
local Players = game:GetService("Players")
local Tween = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local Audio = require(game.ReplicatedStorage.Audio)
local player = Players.LocalPlayer

local function rgb(r, g, b)
	return Color3.fromRGB(r, g, b)
end
-- Index = pen level (1..#GameConfig.PenCosts + 1). Level 1 matches the map's wooden fence.
local Styles = {
	{ post = rgb(113, 65, 36), rail = rgb(113, 65, 36), cap = rgb(163, 97, 50) },
	{ post = rgb(245, 245, 238), rail = rgb(232, 232, 224), cap = rgb(226, 64, 64) },
	{ post = rgb(52, 120, 224), rail = rgb(120, 184, 255), cap = rgb(255, 214, 64), capScale = 1.15 },
	{ post = rgb(118, 124, 138), rail = rgb(160, 166, 178), cap = rgb(84, 88, 100), capScale = 1.2 },
	{ post = rgb(38, 158, 88), rail = rgb(110, 214, 120), cap = rgb(255, 196, 40), capScale = 1.25 },
	{ post = rgb(240, 180, 40), rail = rgb(255, 228, 120), cap = rgb(255, 250, 220), capScale = 1.3, glow = true },
	{
		post = rgb(118, 58, 200),
		rail = rgb(180, 120, 255),
		cap = rgb(232, 170, 255),
		capScale = 1.3,
		glow = true,
		light = true,
	},
	{
		post = rgb(140, 28, 28),
		rail = rgb(60, 22, 22),
		cap = rgb(255, 120, 30),
		capScale = 1.35,
		glow = true,
		light = true,
	},
	{
		post = rgb(40, 220, 255),
		rail = rgb(255, 110, 220),
		cap = rgb(255, 255, 140),
		capScale = 1.4,
		glow = true,
		light = true,
		sparkle = true,
	},
}
local SPARKLES = "rbxasset://textures/particles/sparkles_main.dds"
local WAVE = 0.9 -- seconds for the rebuild wave to go once around the pen

local Fence = {}
local originals = {} -- part -> authored CFrame, Size, Material, MaterialVariant
local runs = {} -- base -> { gen, tweens }

local function original(part)
	local o = originals[part]
	if not o then
		o = { cf = part.CFrame, size = part.Size, material = part.Material, variant = part.MaterialVariant }
		originals[part] = o
	end
	return o
end

local function fenceParts(base)
	local list = {}
	for _, part in base:GetChildren() do
		if part:IsA("BasePart") and (part.Name:match("^Fence") or part.Name == "PostCap") then
			original(part)
			table.insert(list, part)
		end
	end
	return list
end

local function decor(part, class, name, enabled, build)
	local item = part:FindFirstChild(name)
	if enabled and not item then
		item = Instance.new(class)
		item.Name = name
		build(item)
		item.Parent = part
	elseif not enabled and item then
		item:Destroy()
	end
	return item
end

local function paint(part, style)
	local o = original(part)
	if part.Name == "FencePost" then
		part.Color = style.post
	elseif part.Name == "FenceRail" then
		part.Color = style.rail
	elseif part.Name == "FenceFooting" then
		part.Color = style.cap
	elseif part.Name == "PostCap" then
		part.Color = style.cap
		part.Size = o.size * (style.capScale or 1)
		part.Material = style.glow and Enum.Material.Neon or o.material
		part.MaterialVariant = style.glow and "" or o.variant
		local light = decor(part, "PointLight", "FenceGlow", style.light, function(glow)
			glow.Range = 9
			glow.Brightness = 1.5
		end)
		if light then
			light.Color = style.cap
		end
		local sparkle = decor(part, "ParticleEmitter", "FenceSparkle", style.sparkle, function(emitter)
			emitter.Texture = SPARKLES
			emitter.Rate = 1.5
			emitter.Lifetime = NumberRange.new(0.8, 1.4)
			emitter.Speed = NumberRange.new(0.5, 1.5)
			emitter.SpreadAngle = Vector2.new(180, 180)
			emitter.LightEmission = 1
			emitter.Size = NumberSequence.new(0.35, 0)
		end)
		if sparkle then
			sparkle.Color = ColorSequence.new(style.cap, Color3.new(1, 1, 1))
		end
	end
end

local function burst(at, color)
	local point = Instance.new("Attachment")
	point.Position = at -- Terrain sits at the origin
	point.Parent = workspace.Terrain
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = SPARKLES
	emitter.Enabled = false
	emitter.Color = ColorSequence.new(color, Color3.new(1, 1, 1))
	emitter.LightEmission = 1
	emitter.Lifetime = NumberRange.new(0.5, 0.9)
	emitter.Speed = NumberRange.new(6, 12)
	emitter.SpreadAngle = Vector2.new(60, 60)
	emitter.Acceleration = Vector3.new(0, -20, 0)
	emitter.Size = NumberSequence.new(0.6, 0)
	emitter.EmissionDirection = Enum.NormalId.Top
	emitter.Parent = point
	emitter:Emit(12)
	Debris:AddItem(point, 1.2)
end

-- Applies the style for `level`; `animated` plays the rebuild wave (upgrade seen live).
function Fence.apply(base, level, animated)
	local style = Styles[math.clamp(level or 1, 1, #Styles)]
	local run = runs[base] or { gen = 0, tweens = {} }
	runs[base] = run
	run.gen += 1
	for _, t in run.tweens do
		t:Cancel()
	end
	table.clear(run.tweens)
	local parts = fenceParts(base)
	local anchor = base:FindFirstChild("BaseAnchor")
	if not animated or not anchor or player:GetAttribute("ReducedMotion") then
		for _, part in parts do
			part.CFrame = originals[part].cf
			paint(part, style)
		end
		return
	end
	local gen, center = run.gen, anchor.Position
	Audio.play("RevealRare", anchor)
	for _, part in parts do
		local o = originals[part]
		part.CFrame = o.cf
		local rel = o.cf.Position - center
		local delay = (math.atan2(rel.X, rel.Z) + math.pi) / (2 * math.pi) * WAVE
		task.delay(delay, function()
			if run.gen ~= gen then
				return
			end
			if part.Name == "FenceFooting" then
				paint(part, style)
				return
			end
			-- Sink below the floor, swap the look, pop back up with overshoot.
			local depth = o.cf.Y + o.size.Y / 2 + 0.3
			local down = Tween:Create(
				part,
				TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
				{ CFrame = o.cf - Vector3.new(0, depth, 0) }
			)
			table.insert(run.tweens, down)
			down.Completed:Connect(function(state)
				if state ~= Enum.PlaybackState.Completed or run.gen ~= gen then
					return
				end
				paint(part, style)
				local up = Tween:Create(
					part,
					TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
					{ CFrame = o.cf }
				)
				table.insert(run.tweens, up)
				up:Play()
				if part.Name == "FencePost" then
					burst(o.cf.Position + Vector3.new(0, o.size.Y / 2 + 0.5, 0), style.cap)
				end
			end)
			down:Play()
		end)
	end
end

-- Keeps every base's fence in sync with its PenLevel attribute.
function Fence.watch(bases)
	local function track(base)
		local shown = base:GetAttribute("PenLevel")
		Fence.apply(base, shown, false)
		base:GetAttributeChangedSignal("PenLevel"):Connect(function()
			local level = base:GetAttribute("PenLevel")
			-- Only a live upgrade animates; joining, base reassignment and release apply instantly.
			Fence.apply(base, level, shown ~= nil and level ~= nil and level > shown)
			shown = level
		end)
	end
	for _, base in bases:GetChildren() do
		track(base)
	end
	bases.ChildAdded:Connect(track)
end

return Fence
