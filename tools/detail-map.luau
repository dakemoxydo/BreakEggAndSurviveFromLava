-- Additive Edit-only dressing. Existing geometry and gameplay markers stay intact.
assert(not game:GetService("RunService"):IsRunning(), "Run in Edit mode")
local map = workspace:WaitForChild("Map")
assert(not map:FindFirstChild("LandscapeDetails"), "LandscapeDetails already installed")
local storage = game:GetService("ServerStorage")
local backups = storage:FindFirstChild("WorldBackups") or Instance.new("Folder")
backups.Name = "WorldBackups"
backups.Parent = storage
local backup = map:Clone()
backup.Name = "MapBeforeLandscapeDetails_20261008"
backup.Parent = backups

local root = Instance.new("Folder")
root.Name = "LandscapeDetails"
root:SetAttribute("Version", 1)
root.Parent = map
local C = Color3.fromRGB
local function folder(name)
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = root
	return f
end
local function part(parent, name, size, position, color, yaw)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = CFrame.new(position) * CFrame.Angles(0, math.rad(yaw or 0), 0)
	p.Color = color
	p.Material = Enum.Material.Plastic
	p.MaterialVariant = "ReferenceHDStuds"
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end
local function plate(parent, floor, x, z, w, d, h, color)
	local top = floor.Position.Y + floor.Size.Y / 2
	return part(parent, "TerrainPlate", Vector3.new(w, h, d), Vector3.new(x, top + h / 2, z), color)
end
local function cloneAt(parent, source, x, y, z, scale, yaw, color)
	local m = source:Clone()
	m.Name = source.Name .. "Detail"
	m:ScaleTo(m:GetScale() * scale)
	m:PivotTo(CFrame.new(x, y, z) * CFrame.Angles(0, math.rad(yaw), 0))
	local cf, size = m:GetBoundingBox()
	-- Place the actual lower bound on the support, regardless of inherited pivot.
	m:PivotTo(m:GetPivot() + Vector3.new(0, y - (cf.Position.Y - size.Y / 2), 0))
	for _, p in m:GetDescendants() do
		if p:IsA("BasePart") then
			p.Anchored = true
			p.CanCollide = false
			p.CanTouch = false
			p.CanQuery = false
			if color then
				p.Color = color
			end
		end
	end
	m.Parent = parent
	return m
end
local function shrub(parent, x, y, z, scale, color, yaw)
	local m = Instance.new("Model")
	m.Name = "BlockShrub"
	part(m, "Leaves", Vector3.new(5, 2.8, 4) * scale, Vector3.new(x, y + 1.4 * scale, z), color, yaw)
	part(
		m,
		"LeavesSide",
		Vector3.new(3.2, 2, 3) * scale,
		Vector3.new(x + 2 * scale, y + scale, z + 1.1 * scale),
		color:Lerp(C(150, 218, 94), 0.12),
		yaw
	)
	part(
		m,
		"LeavesTop",
		Vector3.new(3, 1.2, 2.8) * scale,
		Vector3.new(x - 0.5 * scale, y + 3 * scale, z - 0.3 * scale),
		color,
		yaw
	)
	m.WorldPivot = CFrame.new(x, y, z)
	m.Parent = parent
end
local function flowers(parent, x, y, z, color)
	for i = 1, 3 do
		local dx = (i - 2) * 1.2
		local dz = i % 2 * 0.9
		part(parent, "FlowerStem", Vector3.new(0.22, 1.1, 0.22), Vector3.new(x + dx, y + 0.55, z + dz), C(60, 144, 45))
		local bloom = part(
			parent,
			"BlockBloom",
			Vector3.new(0.85, 0.4, 0.85),
			Vector3.new(x + dx, y + 1.25, z + dz),
			color,
			i * 17
		)
		bloom.MaterialVariant = ""
	end
end

local palettes = {
	Forest = { plate = C(129, 220, 14), edge = C(124, 212, 8), leaf = C(54, 153, 40), rock = C(89, 104, 137) },
	Desert = { plate = C(244, 205, 122), edge = C(233, 191, 105), leaf = C(67, 163, 64), rock = C(175, 123, 88) },
	Snow = { plate = C(239, 249, 255), edge = C(209, 233, 244), leaf = C(89, 161, 169), rock = C(120, 156, 184) },
}
for index, name in { "Forest", "Desert", "Snow" } do
	local zone = map.Biomes[name]
	local floor = zone.Floor
	local f = folder(name)
	local palette = palettes[name]
	local cz = floor.Position.Z
	local top = floor.Position.Y + floor.Size.Y / 2
	local rock = assert(zone.Environment:FindFirstChild("RockCluster"))
	local tree = zone.Environment:FindFirstChild(name == "Desert" and "Cactus" or "BlockTree")
	-- Low, single-layer patches fall between the fixed egg rows.
	for i, data in { { -34, 52, 30, 14 }, { 38, 12, 34, 14 }, { -32, -28, 38, 12 }, { 32, -68, 28, 14 } } do
		plate(f, floor, data[1], cz + data[2], data[3], data[4], 0.22 + (i % 2) * 0.08, palette.plate)
	end
	for i, data in { { -100, 59, 32, 34 }, { 99, 21, 34, 38 }, { -98, -21, 36, 32 }, { 98, -64, 36, 30 } } do
		local x, z = data[1], cz + data[2]
		plate(f, floor, x, z, data[3], data[4], 0.45, palette.edge)
		cloneAt(f, rock, x + (x < 0 and 5 or -5), top + 0.45, z - 5, 0.7 + i * 0.07, i * 23, palette.rock)
		shrub(f, x + (x < 0 and 10 or -10), top + 0.45, z + 5, 0.85 + (i % 2) * 0.25, palette.leaf, i * 13)
		if name == "Forest" then
			flowers(f, x + (x < 0 and 4 or -4), top + 0.45, z + 10, C(255, 223, 96))
		end
		if name == "Desert" then
			cloneAt(f, tree, x + (x < 0 and -4 or 4), top + 0.45, z + 7, 0.48, i * 37)
		elseif name == "Snow" then
			part(
				f,
				"IceSliver",
				Vector3.new(2, 3 + i * 0.5, 2),
				Vector3.new(x - 7, top + 0.45 + (3 + i * 0.5) / 2, z + 7),
				C(130, 218, 243),
				i * 15
			)
		end
	end
	-- Asymmetric wall-foot outcrops, backed by the original continuous wall.
	for i, data in
		{ { -114, 40, 12, 14, 16 }, { 113, -3, 14, 20, 20 }, { -114, -62, 12, 10, 20 }, { 114, 65, 12, 9, 14 } }
	do
		local x, z = data[1], cz + data[2]
		local h = data[4]
		part(f, "WallOutcrop", Vector3.new(data[3], h, data[5]), Vector3.new(x, top + h / 2, z), palette.rock)
		part(
			f,
			"OutcropCap",
			Vector3.new(data[3] + 0.3, 0.7, data[5] + 0.3),
			Vector3.new(x, top + h + 0.35, z),
			palette.edge
		)
		shrub(f, x, top + h + 0.7, z, 0.85, palette.leaf, i * 19)
	end
	-- Crown decoration rests on the wall caps; alternating open wall sections remain.
	for i, data in { { -123, 66 }, { 123, 35 }, { -123, -20 }, { 123, -61 } } do
		local x, z = data[1], cz + data[2]
		cloneAt(f, rock, x, 34, z, 0.5, i * 29, palette.rock)
		if i % 2 == index % 2 then
			cloneAt(f, tree, x, 34, z + 9, name == "Desert" and 0.6 or 0.42, i * 41)
		else
			shrub(f, x, 34, z + 6, 0.75, palette.leaf, i * 11)
		end
	end
end

local lobby = folder("Lobby")
local floor = map.StartZone.GrassFloor
local rock = map.StartZone.LobbyDecoration:FindFirstChild("RockCluster")
local tree = map.StartZone.LobbyDecoration:FindFirstChild("BlockTree")
for i, data in
	{
		{ -75, 20, 40, 24 },
		{ 72, 18, 44, 24 },
		{ -34, 67, 38, 18 },
		{ 36, 57, 36, 18 },
		{ -153, 57, 26, 22 },
		{
			158,
			56,
			28,
			22,
		},
	}
do
	plate(lobby, floor, data[1], data[2], data[3], data[4], 0.24, C(132, 223, 12))
end
for i, data in { { -176, 68 }, { 183, 73 }, { -165, 2 }, { 175, 32 }, { -110, 49 }, { 113, 53 } } do
	local x, z = data[1], data[2]
	cloneAt(lobby, rock, x, 0.1, z, 0.55 + i * 0.03, i * 31)
	shrub(lobby, x + 4, 0.1, z + 2, 0.9, C(60, 160, 43), i * 19)
	flowers(lobby, x - 3, 0.1, z + 4, i % 2 == 0 and C(255, 215, 98) or C(255, 165, 205))
end
for i, data in { { -171, -43 }, { 171, -43 }, { -213, 65 }, { 213, 45 }, { -150, 203 }, { 90, 203 } } do
	cloneAt(lobby, rock, data[1], 34, data[2], 0.6, i * 17)
	if i % 2 == 0 then
		cloneAt(lobby, tree, data[1], 34, data[2], 0.38, i * 27)
	else
		shrub(lobby, data[1], 34, data[2], 0.9, C(60, 160, 43), i * 16)
	end
end
local count = 0
for _, p in root:GetDescendants() do
	if p:IsA("BasePart") then
		count += 1
	end
end
return { addedParts = count, backup = backup:GetFullName(), details = root:GetFullName() }
