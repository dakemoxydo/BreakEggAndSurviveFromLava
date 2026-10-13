-- Builds parkour levels in the Forest, Desert and Snow field zones (Edit, via MCP execute_luau).
-- Re-runnable: removes its own Parkour/EggSpots folders first. The floor stays as the safe ground;
-- the original Environment of each zone is backed up once to ServerStorage.WorldBackups.
-- Heights are studs above the floor top. Lava rises to GameConfig.LavaWave.high (10): tops >= 12 are refuges.
-- Jumps: gaps 1.5-3 studs with rises <= 4 (checked in Play at WalkSpeed 16, JumpPower 50).
local map = workspace.Map
local backups = game.ServerStorage:FindFirstChild("WorldBackups") or Instance.new("Folder")
backups.Name = "WorldBackups"
backups.Parent = game.ServerStorage
local studs = map.StartZone.PlayerBases.Base01.FencePost:FindFirstChild("Studs")

local CAP = 0.6
local function rgb(r, g, b)
	return Color3.fromRGB(r, g, b)
end
local Palettes = {
	Forest = { body = rgb(139, 94, 60), cap = rgb(122, 214, 62), dark = rgb(104, 70, 45), accent = rgb(232, 64, 56) },
	Desert = {
		body = rgb(214, 158, 92),
		cap = rgb(248, 218, 146),
		dark = rgb(178, 124, 70),
		accent = rgb(255, 196, 40),
	},
	Snow = {
		body = rgb(116, 148, 196),
		cap = rgb(242, 249, 255),
		dark = rgb(88, 114, 160),
		accent = rgb(150, 228, 255),
	},
}
-- Shared zone-local layout: x across (-120..120), z toward the Safe Zone (-90..90). Desert mirrors X, Snow mirrors Z.
-- Pyramid tiers: { top height, width, depth }. Rings between tiers are 8 studs: room for an egg.
local Pyramids = {
	{ at = Vector2.new(-70, 30), tiers = { { 4, 60, 56 }, { 8, 44, 40 }, { 12, 28, 24 }, { 16, 14, 12 } } },
	{ at = Vector2.new(68, -40), tiers = { { 4, 52, 48 }, { 8, 36, 32 }, { 12, 20, 16 } } },
}
-- Routes to the Rare islands: { x, z, width, depth, top height }.
local Floating = {
	{ -56, 28, 9, 9, 20 },
	{ -45, 22, 9, 9, 24 },
	{ -34, 16, 9, 9, 28 },
	{ -18, 10, 20, 20, 30 },
	{ 66, -24.5, 9, 9, 16 },
	{ 72, -13.5, 9, 9, 20 },
	{ 78, -2.5, 9, 9, 24 },
	{ 80, 13.5, 20, 20, 28 },
}
-- Ramps from the floor onto the first tier: { x, z, climb direction x, climb direction z }.
local Ramps = {
	{ -34, 30, -1, 0 },
	{ 68, -10, 0, -1 },
}
-- Floor prop groups along the walls: { x, z, yaw }.
local Groups = { { 106, -82, 20 }, { -108, 70, -35 }, { 104, 34, 70 }, { -62, -84, 140 }, { 8, 80, -10 } }
local Props = { Forest = "BlockTree", Desert = "Cactus", Snow = "BlockTree" }
-- Egg spots: { x, z, height, rarity }. 13 Common, 1 Uncommon, 2 Rare per zone.
local Spots = {
	{ -30, 72, 0, 1 },
	{ 32, 72, 0, 1 },
	{ 22, 34, 0, 1 },
	{ -96, -34, 0, 1 },
	{ -40, -74, 0, 1 },
	{ -96, 30, 4, 1 },
	{ -70, 6, 4, 1 },
	{ -88, 30, 8, 1 },
	{ -70, 46, 8, 1 },
	{ 46, -40, 4, 1 },
	{ 68, -60, 4, 1 },
	{ 54, -40, 8, 1 },
	{ 68, -52, 8, 1 },
	{ -70, 30, 16, 2 },
	{ -18, 10, 30, 3 },
	{ 80, 13.5, 28, 3 },
}

local function texture(part)
	if not studs then
		return
	end
	for _, face in Enum.NormalId:GetEnumItems() do
		local t = studs:Clone()
		t.Face = face
		t.Parent = part
	end
end
local function block(parent, name, size, cf, color, class)
	local part = Instance.new(class or "Part")
	part.Name = name
	part.Size = size
	part.CFrame = cf
	part.Color = color
	part.Material = Enum.Material.Plastic
	part.MaterialVariant = "ReferenceHDStuds"
	part.Anchored = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	texture(part)
	part.Parent = parent
	return part
end
-- Smooth shapes (cylinders, balls, ice) without the studs map.
local function smooth(parent, name, shape, size, cf, color, material)
	local part = Instance.new("Part")
	part.Name = name
	part.Shape = shape
	part.Size = size
	part.CFrame = cf
	part.Color = color
	part.Material = material or Enum.Material.SmoothPlastic
	part.Anchored = true
	part.Parent = parent
	return part
end

local report = {}
for _, biome in { "Forest", "Desert", "Snow" } do
	local zone = map.Biomes[biome]
	local floor = zone.Floor
	local ground = floor.Position.Y + floor.Size.Y / 2
	local center = floor.Position
	local sx = biome == "Desert" and -1 or 1
	local sz = biome == "Snow" and -1 or 1
	local function world(x, z, y)
		return Vector3.new(center.X + x * sx, ground + (y or 0), center.Z + z * sz)
	end
	local palette = Palettes[biome]
	for _, name in { "Parkour", "EggSpots" } do
		local old = zone:FindFirstChild(name)
		if old then
			old:Destroy()
		end
	end
	local env = zone:FindFirstChild("Environment")
	local backupName = "FieldEnvironmentBeforeParkour_" .. biome
	if env and not backups:FindFirstChild(backupName) then
		local copy = env:Clone()
		copy.Name = backupName
		copy.Parent = backups
	end
	local template = backups[backupName]:FindFirstChild(Props[biome])
	local rock = backups[backupName]:FindFirstChild("RockCluster")
	local parkour = Instance.new("Folder")
	parkour.Name = "Parkour"
	local footprints = {}
	local function clear(x, z, w, d)
		table.insert(footprints, { x = x * sx, z = z * sz, w = w + 4, d = d + 4 })
	end
	-- Body + slightly wider cap; the cap's top is exactly `top`.
	-- opts: bottom (default 0, floor), shade (0..1 toward dark, strata), body/cap colors.
	local function solid(name, w, d, top, x, z, opts)
		opts = opts or {}
		local bottomY = opts.bottom or 0
		local bodyH = top - CAP - bottomY
		local bodyColor = opts.body
			or (bottomY > 0 and palette.dark or palette.body:Lerp(palette.dark, opts.shade or 0))
		local body =
			block(parkour, name, Vector3.new(w, bodyH, d), CFrame.new(world(x, z, bottomY + bodyH / 2)), bodyColor)
		block(
			parkour,
			name .. "Cap",
			Vector3.new(w + 0.8, CAP, d + 0.8),
			CFrame.new(world(x, z, top - CAP / 2)),
			opts.cap or palette.cap
		)
		clear(x, z, w, d)
		return body
	end
	local function post(name, x, z, w, top, bottomY, color)
		local part = block(
			parkour,
			name,
			Vector3.new(w, top - bottomY, w),
			CFrame.new(world(x, z, (top + bottomY) / 2)),
			color or palette.body
		)
		clear(x, z, w, w)
		return part
	end
	local function disc(name, x, z, diameter, top, thickness, color)
		local cf = CFrame.new(world(x, z, top - thickness / 2)) * CFrame.Angles(0, 0, math.rad(90))
		clear(x, z, diameter, diameter)
		return smooth(parkour, name, Enum.PartType.Cylinder, Vector3.new(thickness, diameter, diameter), cf, color)
	end
	local function ball(name, x, z, y, diameter, color, collide)
		local part =
			smooth(parkour, name, Enum.PartType.Ball, Vector3.one * diameter, CFrame.new(world(x, z, y)), color)
		part.CanCollide = collide ~= false
		clear(x, z, diameter, diameter)
		return part
	end
	local function truss(name, x, z, bottomY, top)
		local part = Instance.new("TrussPart")
		part.Name = name
		part.Size = Vector3.new(2, top - bottomY, 2)
		part.CFrame = CFrame.new(world(x, z, (top + bottomY) / 2))
		part.Color = palette.dark
		part.Anchored = true
		part.Parent = parkour
		return part
	end
	-- Narrow plank between two walkable points (x, top, z), slope up to ~30 degrees.
	local function plank(name, from, to, width, color)
		local a, b = world(from.X, from.Z, from.Y), world(to.X, to.Z, to.Y)
		local cf = CFrame.lookAt((a + b) / 2, b) * CFrame.new(0, -0.4, 0)
		return block(parkour, name, Vector3.new(width, 0.8, (b - a).Magnitude + 1), cf, color or palette.dark)
	end
	local function prop(name, model, x, z, y, scale, yaw)
		if not model then
			return
		end
		local item = model:Clone()
		item.Name = name
		item:ScaleTo(item:GetScale() * scale)
		item:PivotTo(CFrame.new(item:GetPivot().Position) * CFrame.Angles(0, math.rad(yaw or 0), 0))
		local cf, size = item:GetBoundingBox()
		item:PivotTo(item:GetPivot() + (world(x, z, y) - (cf.Position - Vector3.new(0, size.Y / 2, 0))))
		item.Parent = parkour
	end

	for i, pyramid in Pyramids do
		for t, tier in pyramid.tiers do
			solid(
				"Pyramid" .. i .. "Tier" .. t,
				tier[2],
				tier[3],
				tier[1],
				pyramid.at.X,
				pyramid.at.Y,
				{ shade = (t % 2) * 0.35 }
			)
		end
	end
	for i, f in Floating do
		local x, z, w, d, top = f[1], f[2], f[3], f[4], f[5]
		solid("Floating" .. i, w, d, top, x, z, { bottom = top - 3 })
		if w > 10 then
			-- Tapering rock under the big platforms so they read as floating islands.
			block(
				parkour,
				"Floating" .. i .. "Root",
				Vector3.new(w * 0.6, 4, d * 0.6),
				CFrame.new(world(x, z, top - 5)),
				palette.dark
			)
			block(
				parkour,
				"Floating" .. i .. "Tip",
				Vector3.new(w * 0.3, 3, d * 0.3),
				CFrame.new(world(x, z, top - 8.5)),
				palette.dark
			)
		end
	end
	for i, r in Ramps do
		local x, z, dx, dz = r[1], r[2], r[3] * sx, r[4] * sz
		-- A wedge's high end faces its local -Z; turn that toward the climb direction.
		local cf = CFrame.new(world(x, z, 2)) * CFrame.Angles(0, math.atan2(-dx, -dz), 0)
		block(parkour, "Ramp" .. i, Vector3.new(8, 4, 12), cf, palette.cap, "WedgePart")
	end

	-- Landmark at (-30, -20) with its own route to Rare #1, plus two smaller set pieces per biome.
	if biome == "Forest" then
		-- Giant tree: leaf pads spiral up to a deck at 24 (truss = shortcut), a plank leads to Rare #1.
		post("TreeTrunk", -30, -20, 8, 34, 0, rgb(120, 78, 46))
		for i, a in { 0, 45, 90, 135, 180, 225, 270 } do
			local r = math.rad(a)
			solid(
				"LeafPad" .. i,
				7,
				7,
				3 * i,
				-30 + 15 * math.cos(r),
				-20 + 15 * math.sin(r),
				{ bottom = math.max(0, 3 * i - 1.6), body = rgb(58, 150, 48), cap = rgb(84, 196, 64) }
			)
		end
		solid("TreeDeck", 20, 20, 24, -30, -20, { bottom = 22.4, cap = rgb(176, 122, 72) })
		truss("TreeTruss", -35.5, -31, 0, 24)
		local leaves = { rgb(66, 168, 56), rgb(88, 194, 66), rgb(118, 218, 80) }
		solid("CanopyLow", 30, 30, 38, -30, -20, { bottom = 34, body = leaves[1], cap = leaves[2] })
		solid("CanopyMid", 20, 20, 42, -30, -20, { bottom = 38, body = leaves[2], cap = leaves[3] })
		solid("CanopyTop", 10, 10, 45, -30, -20, { bottom = 42, body = leaves[3], cap = leaves[3] })
		plank("TreeBridge", Vector3.new(-21, 24, -10), Vector3.new(-19, 30, 2), 2.5)
		-- Mushroom grove (refuge on the tallest cap).
		for i, m in { { 66, 52, 10, 4 }, { 76, 58, 9, 8 }, { 84, 50, 8, 12 } } do
			local x, z, d, top = m[1], m[2], m[3], m[4]
			post("MushroomStem" .. i, x, z, d * 0.3, top - 1.2, 0, rgb(250, 238, 214))
			disc("MushroomCap" .. i, x, z, d, top, 1.6, palette.accent)
			for k = 0, 2 do
				local r = math.rad(k * 120 + i * 40)
				ball(
					"MushroomDot" .. i .. k,
					x + d * 0.28 * math.cos(r),
					z + d * 0.28 * math.sin(r),
					top,
					1.4,
					rgb(255, 255, 255),
					false
				)
			end
		end
		solid("MushroomPebble", 4, 4, 2, 58, 48, { shade = 0.4 })
		-- Stump hops up to a lookout stump (refuge at 12).
		for i, s in { { -92, -62, 7, 3 }, { -84, -56, 7, 6 }, { -76, -50, 7, 9 }, { -68, -56, 8, 12 } } do
			disc("Stump" .. i, s[1], s[2], s[3], s[4], s[4], rgb(132, 88, 52))
			disc("StumpRing" .. i, s[1], s[2], s[3] - 1.2, s[4] + 0.05, 0.1, rgb(214, 170, 112)).CanCollide = false
		end
	elseif biome == "Desert" then
		-- Sun temple: stepped base, four columns, a roof refuge with an obelisk; broken columns climb to it.
		solid("TempleBase", 28, 28, 4, -30, -20, { shade = 0.3 })
		solid("TempleFloor", 20, 20, 8, -30, -20)
		for i, c in { { -39, -29 }, { -21, -29 }, { -39, -11 }, { -21, -11 } } do
			post("TempleColumn" .. i, c[1], c[2], 3, 24, 8, rgb(236, 196, 128))
		end
		solid("TempleRoof", 22, 22, 26, -30, -20, { bottom = 24 })
		post("Obelisk", -30, -20, 4, 36, 26, rgb(222, 176, 104))
		block(parkour, "ObeliskTip", Vector3.new(3, 2, 3), CFrame.new(world(-30, -20, 37)), palette.accent)
		for i, p in { { -12, -30, 8 }, { -12, -22, 12 }, { -12, -14, 16 }, { -12, -6, 20 }, { -20, -4, 24 } } do
			solid("BrokenColumn" .. i, 5, 5, p[3], p[1], p[2], { shade = (i % 2) * 0.3 })
		end
		solid("RoofStep", 5, 5, 28, -28, -5, { bottom = 26 })
		-- Arch gate with column stubs up to the lintel (refuge at 16).
		post("ArchLeft", 64, 55, 4, 14, 0, rgb(236, 196, 128))
		post("ArchRight", 86, 55, 4, 14, 0, rgb(236, 196, 128))
		solid("ArchLintel", 26, 5, 16, 75, 55, { bottom = 14, body = rgb(222, 176, 104) })
		for i, s in { { 68, 63, 4 }, { 74, 63, 8 }, { 80, 63, 12 } } do
			solid("ArchStub" .. i, 5, 5, s[3], s[1], s[2], { shade = 0.3 })
		end
		-- Dunes and a cactus group.
		for i, d in { { -88, -58, 0 }, { -76, -60, 180 } } do
			block(
				parkour,
				"Dune" .. i,
				Vector3.new(14, 4, 12),
				CFrame.new(world(d[1], d[2], 2)) * CFrame.Angles(0, math.rad(d[3]), 0),
				palette.cap,
				"WedgePart"
			)
			clear(d[1], d[2], 14, 12)
		end
		prop("DuneCactus1", template, -82, -48, 0, 0.9, 30)
		prop("DuneCactus2", template, -94, -50, 0, 0.6, 110)
		prop("DuneRock", rock, -70, -66, 0, 0.8, 200)
	else
		-- Ice tower: narrow 2-stud ledges, crystal crown, ice stones to Rare #1.
		for i, t in { { 24, 4 }, { 20, 8 }, { 16, 12 }, { 12, 16 }, { 8, 20 } } do
			solid("IceTower" .. i, t[1], t[1], t[2], -30, -20, { shade = (i % 2) * 0.3 })
		end
		for i, c in { { -30, -20, 3, 32 }, { -27.5, -18, 2, 27 }, { -32.5, -22.5, 2, 26 }, { -28, -23, 1.6, 25 } } do
			local crystal = smooth(
				parkour,
				"Crystal" .. i,
				Enum.PartType.Block,
				Vector3.new(c[3], c[4] - 20, c[3]),
				CFrame.new(world(c[1], c[2], (c[4] + 20) / 2))
					* CFrame.Angles(0, math.rad(i * 25), math.rad((i - 2) * 6)),
				palette.accent,
				Enum.Material.Ice
			)
			crystal.Transparency = 0.15
			crystal.CanCollide = i == 1
		end
		solid("IceStone1", 5, 5, 24, -26, -10, { bottom = 22 })
		solid("IceStone2", 5, 5, 28, -22, -3, { bottom = 26 })
		-- Frozen pond with iceberg hops (refuge at 12).
		smooth(
			parkour,
			"FrozenPond",
			Enum.PartType.Block,
			Vector3.new(34, 0.2, 24),
			CFrame.new(world(75, 55, 0.1)),
			rgb(178, 226, 255),
			Enum.Material.Ice
		).CanCollide =
			false
		for i, b in { { 66, 52, 4 }, { 74, 58, 8 }, { 82, 52, 12 }, { 89, 61, 6 } } do
			solid("Iceberg" .. i, 6, 6, b[3], b[1], b[2], { body = palette.accent:Lerp(palette.body, 0.4) })
		end
		-- Snowmen and pines.
		for i, s in { { -88, -58, 1 }, { -76, -62, 0.8 } } do
			local k = s[3]
			ball("SnowmanBase" .. i, s[1], s[2], 3 * k, 6 * k, palette.cap)
			ball("SnowmanBody" .. i, s[1], s[2], 7.4 * k, 4.4 * k, palette.cap)
			ball("SnowmanHead" .. i, s[1], s[2], 10.6 * k, 3 * k, palette.cap)
			block(
				parkour,
				"SnowmanNose" .. i,
				Vector3.new(0.5, 0.5, 1.6) * k,
				CFrame.new(world(s[1], s[2] + 1.8 * k, 10.6 * k)),
				rgb(255, 140, 40)
			).CanCollide =
				false
		end
		prop("Pine1", template, -94, -46, 0, 0.6, 15)
		prop("Pine2", template, -68, -48, 0, 0.45, 75)
	end
	clear(-30, -20, 36, 36)
	for i, g in Groups do
		prop("Group" .. i .. "Big", template, g[1], g[2], 0, 0.8, g[3])
		prop("Group" .. i .. "Rock", rock, g[1] + 7, g[2] - 5, 0, 0.6, g[3] + 90)
		clear(g[1], g[2], 20, 20)
	end
	parkour.Parent = zone

	local spots = Instance.new("Folder")
	spots.Name = "EggSpots"
	for i, s in Spots do
		local spot = Instance.new("Part")
		spot.Name = string.format("Spot%02d", i)
		spot.Size = Vector3.one
		spot.Transparency = 1
		spot.Anchored = true
		spot.CanCollide = false
		spot.CanQuery = false
		spot.CanTouch = false
		spot.Position = world(s[1], s[2], s[3])
		spot:SetAttribute("Rarity", s[4])
		spot.Parent = spots
		clear(s[1], s[2], 10, 10)
	end
	spots.Parent = zone
	-- Keep only old decorations clear of the new levels, groups, egg spots and the Titanic Egg spot.
	local removed = 0
	if env then
		table.insert(footprints, { x = 0, z = -192 - center.Z, w = 40, d = 40 })
		for _, model in env:GetChildren() do
			local cf, size = model:GetBoundingBox()
			local mx, mz = cf.Position.X - center.X, cf.Position.Z - center.Z
			for _, f in footprints do
				if math.abs(mx - f.x) < (size.X + f.w) / 2 and math.abs(mz - f.z) < (size.Z + f.d) / 2 then
					model:Destroy()
					removed += 1
					break
				end
			end
		end
	end
	table.insert(
		report,
		biome
			.. ": parts "
			.. #parkour:GetDescendants()
			.. ", spots "
			.. #spots:GetChildren()
			.. ", decor removed "
			.. removed
	)
	task.wait()
end
return table.concat(report, "\n")
