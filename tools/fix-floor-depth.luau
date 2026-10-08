assert(not game:GetService("RunService"):IsRunning(), "Studio Edit required")
local root = workspace.Map.ReferenceMap
local base = workspace:FindFirstChild("Baseplate")
assert(base and base:IsA("BasePart"), "Baseplate missing")
local floors = { root.StartZone.GrassFloor, root.Biomes.Forest.Floor, root.Biomes.Desert.Floor, root.Biomes.Snow.Floor }
local lowest = math.huge
for _, p in floors do
	lowest = math.min(lowest, p.Position.Y - p.Size.Y / 2)
end
local targetTop = lowest - 6
local currentTop = base.Position.Y + base.Size.Y / 2
assert(currentTop > targetTop, "Baseplate already safely below floors; inspect other cause")
local backups = game.ServerStorage:FindFirstChild("WorldBackups") or Instance.new("Folder", game.ServerStorage)
backups.Name = "WorldBackups"
local copy = base:Clone()
copy.Name = "Baseplate_BeforeFloorFix_" .. os.date("!%Y%m%d_%H%M%S")
copy.Parent = backups
base.CFrame = base.CFrame + Vector3.new(0, targetTop - currentTop, 0)
local textures = 0
for _, p in floors do
	local seen = {}
	for _, t in p:GetChildren() do
		if t:IsA("Texture") or t:IsA("Decal") then
			local key = t.ClassName .. tostring(t.Face) .. t.Texture
			if seen[key] then
				t:Destroy()
			else
				seen[key] = true
				textures += 1
			end
		end
	end
end
root:SetAttribute("BaseplateFloorSeparation", true)
return {
	baseplateTop = base.Position.Y + base.Size.Y / 2,
	clearanceBelowFloorBottom = 6,
	floorTextures = textures,
	backup = copy:GetFullName(),
}
