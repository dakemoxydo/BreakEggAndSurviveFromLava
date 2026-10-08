assert(not game:GetService("RunService"):IsRunning(), "Edit required")
local root = workspace.Map.ReferenceMap
assert(not root:GetAttribute("LobbyJunctionAligned"), "Already aligned; inspect manual changes")
local lobby = root.StartZone
local floor = lobby.GrassFloor
local forest = root.Biomes.Forest.Floor
assert(math.abs(floor.CFrame.RightVector.Z) > 0.99, "Expected manually rotated lobby")
local backups = game.ServerStorage:FindFirstChild("WorldBackups") or Instance.new("Folder", game.ServerStorage)
backups.Name = "WorldBackups"
local backup = root:Clone()
backup.Name = "ReferenceMap_BeforeJunction_" .. os.date("!%Y%m%d_%H%M%S")
backup.Parent = backups
local front = forest.Position.Z + forest.Size.Z / 2
local depth = floor.Size.X
local width = floor.Size.Z
local target = Vector3.new(forest.Position.X, floor.Position.Y, front + depth / 2)
local delta = target - floor.Position
local oldPivot = lobby:GetPivot()
lobby:PivotTo(oldPivot + delta)
local template = lobby:FindFirstChild("PerimeterWall")
local capTemplate = lobby:FindFirstChild("BackWallCap")
local walls = Instance.new("Model")
walls.Name = "BoundaryWalls"
local function make(source, name, size, pos)
	local p = source:Clone()
	p.Name = name
	p.Size = size
	p.CFrame = CFrame.new(pos)
	p.Parent = walls
	return p
end
local x = target.X
local back = front + depth
local centerZ = (front + back) / 2
local half = width / 2
local mouth = forest.Size.X / 2
for _, side in { -1, 1 } do
	make(template, "SideWall", Vector3.new(6, 34, depth), Vector3.new(x + side * (half + 3), 16, centerZ))
	make(capTemplate, "SideWallCap", Vector3.new(7, 1, depth - 1), Vector3.new(x + side * (half + 3), 33.5, centerZ))
	local inner = x + side * (mouth + 6)
	local outer = x + side * (half + 6)
	make(
		template,
		"EntranceWing",
		Vector3.new(math.abs(outer - inner), 34, 6),
		Vector3.new((inner + outer) / 2, 16, front - 3)
	)
	local ci = x + side * (mouth + 6.5)
	local co = x + side * (half + 6.5)
	make(
		capTemplate,
		"EntranceWingCap",
		Vector3.new(math.abs(co - ci), 1, 7),
		Vector3.new((ci + co) / 2, 33.5, front - 3)
	)
end
make(template, "RearWall", Vector3.new(width + 12, 34, 6), Vector3.new(x, 16, back + 3))
make(capTemplate, "RearWallCap", Vector3.new(width + 13, 1, 7), Vector3.new(x, 33.5, back + 3))
local remove = {}
for _, p in lobby:GetChildren() do
	if
		p:IsA("BasePart")
		and (p.Name == "PerimeterWall" or p.Name == "GrassWallCap" or p.Name == "BackWall" or p.Name == "BackWallCap")
	then
		table.insert(remove, p)
	end
end
for _, p in remove do
	p:Destroy()
end
walls.WorldPivot = CFrame.new(x, 0, centerZ)
walls.Parent = lobby
local line = lobby.SafeZoneBoundary
line.Size = Vector3.new(forest.Size.X, 0.16, 0.7)
line.CFrame = CFrame.new(x, 0.2, front + 0.5)
lobby.WorldPivot = CFrame.new(target.X, 0, target.Z) * oldPivot.Rotation
root:SetAttribute("LobbyJunctionAligned", true)
return {
	delta = tostring(delta),
	floor = tostring(floor.CFrame),
	junctionZ = front,
	openingWidth = forest.Size.X,
	backup = backup:GetFullName(),
}
