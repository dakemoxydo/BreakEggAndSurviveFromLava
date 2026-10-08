assert(not game:GetService("RunService"):IsRunning(), "Edit required")
local map = workspace:FindFirstChild("Map")
assert(map and map:IsA("Folder"), "Workspace.Map folder required")
local backups = game.ServerStorage:FindFirstChild("WorldBackups") or Instance.new("Folder", game.ServerStorage)
backups.Name = "WorldBackups"
local copy = map:Clone()
copy.Name = "Map_BeforeOrganization_" .. os.date("!%Y%m%d_%H%M%S")
copy.Parent = backups
local before = {}
for _, p in map:GetDescendants() do
	if p:IsA("BasePart") then
		before[p] = { cf = p.CFrame, size = p.Size, collide = p.CanCollide, touch = p.CanTouch, query = p.CanQuery }
	end
end
local names = {
	Biomes = true,
	Forest = true,
	Desert = true,
	Snow = true,
	StartZone = true,
	PlayerBases = true,
	LobbyDecoration = true,
	BoundaryWalls = true,
	ReferenceMap = true,
}
local targets = {}
for _, v in map:GetDescendants() do
	if v:IsA("Model") and names[v.Name] then
		table.insert(targets, v)
	end
end
local count = 0
for _, old in targets do
	local f = Instance.new("Folder")
	f.Name = old.Name
	for k, v in old:GetAttributes() do
		f:SetAttribute(k, v)
	end
	for _, tag in old:GetTags() do
		f:AddTag(tag)
	end
	f.Parent = old.Parent
	for _, child in old:GetChildren() do
		child.Parent = f
	end
	for _, v in game:GetDescendants() do
		if v:IsA("ObjectValue") and v.Value == old then
			v.Value = f
		end
	end
	old:Destroy()
	count += 1
end
local biomes = map:FindFirstChild("Biomes", true)
assert(biomes, "Biomes missing")
local start = biomes:FindFirstChild("StartZone") or map:FindFirstChild("StartZone", true)
if start and start.Parent == biomes then
	assert(not map:FindFirstChild("StartZone"), "Duplicate StartZone")
	start.Parent = map
end
local function folder(parent, name)
	local f = parent:FindFirstChild(name)
	if not f then
		f = Instance.new("Folder")
		f.Name = name
		f.Parent = parent
	end
	return f
end
for _, zone in biomes:GetChildren() do
	if zone:IsA("Folder") and (zone.Name == "Forest" or zone.Name == "Desert" or zone.Name == "Snow") then
		local environment = folder(zone, "Environment")
		local boundaries = folder(zone, "BoundaryWalls")
		for _, v in zone:GetChildren() do
			if v:IsA("Model") then
				v.Parent = environment
			elseif v:IsA("BasePart") and (v.Name == "SideWall" or v.Name == "WallCap") then
				v.Parent = boundaries
			end
		end
	end
end
local endBoundary = folder(biomes, "EndBoundary")
for _, v in biomes:GetChildren() do
	if v:IsA("BasePart") and (v.Name == "EndWall" or v.Name == "EndWallCap") then
		v.Parent = endBoundary
	end
end
if start then
	local shops = folder(start, "Shops")
	for _, v in start:GetChildren() do
		if v:IsA("Model") and (v.Name == "BlueShopStand" or v.Name == "GreenShopStand") then
			v.Parent = shops
		end
	end
end
local locked = 0
for p, state in before do
	assert(
		p.Parent
			and p.CFrame == state.cf
			and p.Size == state.size
			and p.CanCollide == state.collide
			and p.CanTouch == state.touch
			and p.CanQuery == state.query,
		"Geometry changed: " .. p.Name
	)
	local isStructure = p.Name == "Floor"
		or p.Name == "GrassFloor"
		or (p.Parent and (p.Parent.Name == "BoundaryWalls" or p.Parent.Name == "EndBoundary"))
	p.Locked = isStructure
	if isStructure then
		locked += 1
	end
end
local base = workspace:FindFirstChild("Baseplate")
if base and base:IsA("BasePart") then
	base:SetAttribute("LockedBeforeMapOrganization", base.Locked)
	base.Locked = true
end
local hierarchy = {}
for _, v in map:GetDescendants() do
	if v:IsA("Folder") then
		table.insert(hierarchy, v:GetFullName())
	end
end
return game:GetService("HttpService"):JSONEncode({
	convertedModels = count,
	lockedMapParts = locked,
	folders = hierarchy,
	backup = copy:GetFullName(),
	geometryPreserved = true,
})
