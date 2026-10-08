assert(not game:GetService("RunService"):IsRunning(), "Edit required")
local folder = workspace:FindFirstChild("Map")
assert(not folder or folder:IsA("Folder"), "Workspace.Map must be Folder")
local root = workspace:FindFirstChild("ReferenceMap") or (folder and folder:FindFirstChild("ReferenceMap"))
assert(root, "ReferenceMap missing")
assert(not root:GetAttribute("ZFightingFixed"), "Already fixed")
local backups = game.ServerStorage:FindFirstChild("WorldBackups")
if not backups then
	backups = Instance.new("Folder")
	backups.Name = "WorldBackups"
	backups.Parent = game.ServerStorage
end
local copy = root:Clone()
copy.Name = "ReferenceMap_BeforeZFix_" .. os.date("!%Y%m%d_%H%M%S")
copy.Parent = backups
local removed = 0
local changed = 0
for _, base in root.StartZone.PlayerBases:GetChildren() do
	local seen = {}
	for _, p in base:GetChildren() do
		if p:IsA("BasePart") then
			if p.Name == "FencePost" or p.Name == "PostCap" then
				local key = p.Name .. tostring(p.CFrame) .. tostring(p.Size)
				if seen[key] then
					p:Destroy()
					removed += 1
				else
					seen[key] = true
				end
			elseif p.Name == "FenceRail" and p.Size.X > p.Size.Z then
				p.Size -= Vector3.new(0.6, 0, 0)
				changed += 1
			elseif p.Name == "FenceFooting" and p.Size.X > p.Size.Z then
				p.Size = Vector3.new(p.Size.X - 5, p.Size.Y, p.Size.Z)
				changed += 1
			end
		end
	end
end
for _, p in root:GetDescendants() do
	if p:IsA("BasePart") then
		if p.Name == "PerimeterWall" then
			p.Size = Vector3.new(p.Size.X, p.Size.Y, 420)
			changed += 1
		elseif p.Name == "GrassWallCap" then
			p.Size = Vector3.new(p.Size.X, p.Size.Y, 419.5)
			p.Position = Vector3.new(p.Position.X, p.Position.Y, 169.75)
			changed += 1
		elseif p.Name == "WallCap" and p.Parent.Name == "Snow" then
			p.Size = Vector3.new(p.Size.X, p.Size.Y, 179.5)
			p.Position = Vector3.new(p.Position.X, p.Position.Y, -489.75)
			changed += 1
		elseif p.Name == "Root" and p.Parent.Name == "BlockTree" then
			local s = p.Size.Y / 2
			p.Size -= Vector3.new(0, 0.1 * s, 0)
			p.Position += Vector3.new(0, 0.05 * s, 0)
			changed += 1
		elseif p.Parent.Name == "Cactus" and p.Name == "Arm" then
			p.Size = Vector3.new(p.Size.X, p.Size.Y, 2.8)
			changed += 1
		elseif p.Parent.Name == "Cactus" and p.Name == "Tip" then
			p.Size = Vector3.new(p.Size.X, p.Size.Y, 2.6)
			changed += 1
		end
	end
end
if not folder then
	folder = Instance.new("Folder")
	folder.Name = "Map"
	folder.Parent = workspace
end
root.Parent = folder
root:SetAttribute("ZFightingFixed", true)
return { path = root:GetFullName(), removedDuplicates = removed, adjustedParts = changed, backup = copy:GetFullName() }
