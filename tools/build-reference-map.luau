-- Run once in Studio Edit using the command bar or Studio MCP.
-- Only creates Workspace.ReferenceMap. UI and existing spawn are preserved.
local RunService = game:GetService("RunService")
assert(not RunService:IsRunning(), "Build requires Studio Edit; do not stop another agent's Play session.")
assert(not workspace:FindFirstChild("ReferenceMap"), "ReferenceMap already exists; preserve manual changes.")
assert(
	not (workspace:FindFirstChild("Map") and workspace.Map:FindFirstChild("ReferenceMap")),
	"Workspace.Map.ReferenceMap already exists; preserve manual changes."
)
local root = Instance.new("Model")
root.Name = "ReferenceMap"
root:SetAttribute("BuilderVersion", 1)
local textureSource = workspace:FindFirstChild("Baseplate")
textureSource = textureSource and textureSource:FindFirstChildWhichIsA("Texture")
local textureId = textureSource and textureSource.Texture or "rbxassetid://6372755229"
local tileU = textureSource and textureSource.StudsPerTileU or 8
local tileV = textureSource and textureSource.StudsPerTileV or 8
local C = {
	grass = Color3.fromRGB(132, 232, 48),
	leaf = Color3.fromRGB(67, 166, 37),
	wall = Color3.fromRGB(184, 99, 101),
	wood = Color3.fromRGB(113, 65, 36),
	foundation = Color3.fromRGB(163, 97, 50),
	stone = Color3.fromRGB(89, 104, 137),
	sand = Color3.fromRGB(246, 213, 135),
	snow = Color3.fromRGB(225, 243, 255),
}
local function model(name, parent)
	local m = Instance.new("Model")
	m.Name = name
	m.Parent = parent or root
	return m
end
local function part(parent, name, size, position, color, collide, faces)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Position = position
	p.Anchored = true
	p.Material = Enum.Material.Plastic
	p.Color = color
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.CanCollide = collide ~= false
	p.CanTouch = false
	p.CanQuery = p.CanCollide
	p.Parent = parent
	for _, face in faces or { Enum.NormalId.Top } do
		local t = Instance.new("Texture")
		t.Name = "Studs"
		t.Texture = textureId
		t.Face = face
		t.StudsPerTileU = tileU
		t.StudsPerTileV = tileV
		t.Transparency = textureSource and textureSource.Transparency or 0.15
		t.Parent = p
	end
	return p
end
local allFaces = Enum.NormalId:GetEnumItems()
local function block(parent, name, size, pos, color, collide)
	return part(parent, name, size, pos, color, collide, allFaces)
end
local function tree(parent, x, z, scale, snowy)
	local m = model("BlockTree", parent)
	block(m, "Trunk", Vector3.new(3, 13, 3) * scale, Vector3.new(x, 6.5 * scale, z), C.wall, true)
	block(m, "Root", Vector3.new(7, 2, 5) * scale, Vector3.new(x, scale, z), C.wall, false)
	local leaf = snowy and Color3.fromRGB(103, 170, 182) or C.leaf
	block(m, "Crown", Vector3.new(14, 11, 13) * scale, Vector3.new(x, 16 * scale, z), leaf, false)
	block(
		m,
		"CrownSide",
		Vector3.new(10, 8, 11) * scale,
		Vector3.new(x + 6 * scale, 14 * scale, z + 2 * scale),
		leaf,
		false
	)
	block(
		m,
		"CrownTop",
		Vector3.new(10, 4, 9) * scale,
		Vector3.new(x - 1 * scale, 23 * scale, z - 1 * scale),
		snowy and C.snow or leaf,
		false
	)
	m.WorldPivot = CFrame.new(x, 0, z)
end
local function rock(parent, x, z, s)
	local m = model("RockCluster", parent)
	block(m, "Rock", Vector3.new(8, 3, 6) * s, Vector3.new(x, 1.5 * s, z), C.stone, true)
	block(m, "UpperRock", Vector3.new(5, 2, 4) * s, Vector3.new(x - 1 * s, 4 * s, z), C.stone, true)
	m.WorldPivot = CFrame.new(x, 0, z)
end
local lobby = model("StartZone")
part(lobby, "GrassFloor", Vector3.new(240, 2, 420), Vector3.new(0, -0.9, 170), C.grass)
-- Raised outer walls, green top strips, unobstructed exit toward the biomes.
for _, x in { -123, 123 } do
	block(lobby, "PerimeterWall", Vector3.new(6, 34, 426), Vector3.new(x, 16, 170), C.wall, true)
	part(lobby, "GrassWallCap", Vector3.new(7, 1, 426), Vector3.new(x, 33.5, 170), C.leaf, false)
end
block(lobby, "BackWall", Vector3.new(240, 34, 6), Vector3.new(0, 16, 383), C.wall, true)
part(lobby, "BackWallCap", Vector3.new(240, 1, 7), Vector3.new(0, 33.5, 383), C.leaf, false)
local bases = model("PlayerBases", lobby)
local function pen(index, z)
	local m = model(string.format("Base%02d", index), bases)
	m:SetAttribute("BaseIndex", index)
	m:SetAttribute("EntranceWidth", 18.6)
	local x = 66
	local w = 80
	local d = 52
	local function rail(a, b)
		local mid = (a + b) / 2
		local length = (b - a).Magnitude
		local alongX = math.abs(a.X - b.X) > 1
		part(
			m,
			"FenceFooting",
			alongX and Vector3.new(length + 2, 0.5, 3) or Vector3.new(3, 0.5, length + 2),
			mid + Vector3.new(0, 0.35, 0),
			C.foundation,
			false
		)
		for _, h in { 2, 4 } do
			block(
				m,
				"FenceRail",
				alongX and Vector3.new(length, 0.65, 0.6) or Vector3.new(0.6, 0.65, length),
				mid + Vector3.new(0, h, 0),
				C.wood,
				true
			)
		end
		local count = math.ceil(length / 20)
		for j = 0, count do
			local p = a:Lerp(b, j / count)
			block(m, "FencePost", Vector3.new(1, 5, 1), p + Vector3.new(0, 2.5, 0), C.wood, true)
			block(m, "PostCap", Vector3.new(1.4, 0.45, 1.4), p + Vector3.new(0, 5.1, 0), C.foundation, false)
		end
	end
	-- Entrance faces the common promenade; 20 studs clear.
	rail(Vector3.new(x - w / 2, 0, z - d / 2), Vector3.new(x + w / 2, 0, z - d / 2))
	rail(Vector3.new(x + w / 2, 0, z - d / 2), Vector3.new(x + w / 2, 0, z + d / 2))
	rail(Vector3.new(x - w / 2, 0, z + d / 2), Vector3.new(x + w / 2, 0, z + d / 2))
	rail(Vector3.new(x - w / 2, 0, z - d / 2), Vector3.new(x - w / 2, 0, z - 10))
	rail(Vector3.new(x - w / 2, 0, z + 10), Vector3.new(x - w / 2, 0, z + d / 2))
	local marker = part(m, "BaseAnchor", Vector3.new(1, 1, 1), Vector3.new(x, 0.5, z), C.grass, false, {})
	marker.Transparency = 1
	m.WorldPivot = CFrame.new(x, 0, z)
end
for i = 1, 6 do
	pen(i, -15 + i * 60)
end
-- A bright boundary line and broad, open approach match the reference.
local line = part(
	lobby,
	"SafeZoneBoundary",
	Vector3.new(240, 0.16, 0.7),
	Vector3.new(0, 0.2, -30),
	Color3.fromRGB(255, 42, 43),
	false,
	{}
)
line.Material = Enum.Material.Neon
local decor = model("LobbyDecoration", lobby)
for _, p in { { -99, 30, 1.2 }, { -103, 135, 0.95 }, { -96, 265, 1.1 }, { -100, 350, 0.85 } } do
	tree(decor, p[1], p[2], p[3])
	rock(decor, p[1] + 12, p[2] + 9, 0.8)
end
local function stall(name, x, z, accent)
	local m = model(name, lobby)
	block(m, "Deck", Vector3.new(15, 1, 10), Vector3.new(x, 0.6, z), C.foundation, true)
	for _, dx in { -6, 6 } do
		for _, dz in { -3, 3 } do
			block(m, "Post", Vector3.new(0.8, 9, 0.8), Vector3.new(x + dx, 5, z + dz), C.wood, true)
		end
	end
	block(m, "Counter", Vector3.new(14, 1.1, 3), Vector3.new(x, 4, z - 3), C.foundation, true)
	for i = 1, 6 do
		local roof = part(
			m,
			"StripedAwning",
			Vector3.new(2.7, 0.6, 12),
			Vector3.new(x - 9.45 + i * 2.7, 10, z),
			i % 2 == 0 and Color3.new(1, 1, 1) or accent,
			true
		)
		roof.CFrame = roof.CFrame * CFrame.Angles(math.rad(9), 0, 0)
	end
	m.WorldPivot = CFrame.new(x, 0, z)
end
stall("BlueShopStand", -84, 4, Color3.fromRGB(41, 191, 255))
stall("GreenShopStand", 84, -15, Color3.fromRGB(52, 237, 82))
local biomes = model("Biomes")
for index, spec in { { "Forest", C.grass, -130 }, { "Desert", C.sand, -310 }, { "Snow", C.snow, -490 } } do
	local name, color, z = spec[1], spec[2], spec[3]
	local zone = model(name, biomes)
	part(zone, "Floor", Vector3.new(240, 2, 180), Vector3.new(0, -0.9, z), color)
	local wallColor = index == 2 and Color3.fromRGB(194, 160, 108)
		or (index == 3 and Color3.fromRGB(142, 190, 215) or C.wall)
	for _, x in { -123, 123 } do
		block(zone, "SideWall", Vector3.new(6, 34, 180), Vector3.new(x, 16, z), wallColor, true)
		part(zone, "WallCap", Vector3.new(7, 1, 180), Vector3.new(x, 33.5, z), color, false)
	end
	for j = 1, 5 do
		for _, side in { -1, 1 } do
			local x = side * (82 + (j % 2) * 14)
			local zz = z - 77 + j * 27
			if index ~= 2 then
				tree(zone, x, zz, 0.85 + (j % 3) * 0.16, index == 3)
			else
				local cactus = model("Cactus", zone)
				block(cactus, "Stem", Vector3.new(3, 15, 3), Vector3.new(x, 7.5, zz), Color3.fromRGB(27, 181, 74), true)
				block(
					cactus,
					"Arm",
					Vector3.new(8, 2.5, 3),
					Vector3.new(x + 2, 8, zz),
					Color3.fromRGB(27, 181, 74),
					false
				)
				block(
					cactus,
					"Tip",
					Vector3.new(2.5, 7, 3),
					Vector3.new(x + 5, 11, zz),
					Color3.fromRGB(27, 181, 74),
					false
				)
				cactus.WorldPivot = CFrame.new(x, 0, zz)
				local dead = model("DeadTree", zone)
				block(dead, "Trunk", Vector3.new(3, 19, 3), Vector3.new(x - side * 17, 9.5, zz - 9), C.stone, true)
				for _, sign in { -1, 1 } do
					local b = block(
						dead,
						"Branch",
						Vector3.new(2, 12, 2),
						Vector3.new(x - side * 17 + sign * 4, 17, zz - 9),
						C.stone,
						false
					)
					b.CFrame = b.CFrame * CFrame.Angles(0, 0, math.rad(-sign * 30))
				end
				dead.WorldPivot = CFrame.new(x - side * 17, 0, zz - 9)
			end
			rock(zone, x - side * 12, zz + 10, 0.75 + (j % 2) * 0.4)
		end
	end
	zone.WorldPivot = CFrame.new(0, 0, z)
end
block(biomes, "EndWall", Vector3.new(240, 34, 6), Vector3.new(0, 16, -583), Color3.fromRGB(142, 190, 215), true)
part(biomes, "EndWallCap", Vector3.new(240, 1, 7), Vector3.new(0, 33.5, -583), C.snow, false)
-- Pivots describe placement points without moving completed geometry.
bases.WorldPivot = CFrame.new(66, 0, 205)
lobby.WorldPivot = CFrame.new(0, 0, 170)
decor.WorldPivot = CFrame.new(-99, 0, 190)
biomes.WorldPivot = CFrame.new(0, 0, -310)
root.WorldPivot = CFrame.new(0, 0, 0)
root.Parent = workspace
return "Built ReferenceMap: 6 player pens, start zone, forest/desert/snow. No UI, eggs, bosses or gameplay scripts."
