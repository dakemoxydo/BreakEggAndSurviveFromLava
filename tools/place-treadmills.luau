assert(not game:GetService("RunService"):IsRunning(), "Edit required")
local lobby = workspace.Map.StartZone
assert(not lobby:FindFirstChild("Treadmills"), "Preserve existing treadmills")
local source = workspace:FindFirstChild("Blue_Treadmill_Roblox")
assert(source and source:IsA("Model"), "Imported treadmill missing")
local backups = game.ServerStorage:FindFirstChild("WorldBackups")
local copy = source:Clone()
copy.Name = "ImportedTreadmill_BeforeScale"
copy.Parent = backups
local assets = game.ServerStorage:FindFirstChild("Assets") or Instance.new("Folder", game.ServerStorage)
assets.Name = "Assets"
local environment = assets:FindFirstChild("Environment") or Instance.new("Folder", assets)
environment.Name = "Environment"
local treadmills = environment:FindFirstChild("Treadmills") or Instance.new("Folder", environment)
treadmills.Name = "Treadmills"
local template = source:Clone()
template.Name = "TreadmillLvl1"
local cf, size = template:GetBoundingBox()
template:ScaleTo(template:GetScale() * 7 / size.X)
local box, dimensions = template:GetBoundingBox()
template.WorldPivot = CFrame.new(box.Position.X, box.Position.Y - dimensions.Y / 2, box.Position.Z)
template:PivotTo(CFrame.new())
for _, p in template:GetDescendants() do
	if p:IsA("BasePart") then
		p.Anchored = true
		p.CanCollide = false
		p.CanTouch = false
		p.CanQuery = false
	end
end
template.Parent = treadmills
local stations = Instance.new("Folder")
stations.Name = "Treadmills"
local summary = {}
for _, base in lobby.PlayerBases:GetChildren() do
	local m = template:Clone()
	m.Name = "Treadmill_" .. base.Name
	m:SetAttribute("BaseIndex", base:GetAttribute("BaseIndex"))
	local baseCF = base:GetPivot()
	local pos = baseCF:PointToWorldSpace(Vector3.new(-52, 0.1, 0))
	m:PivotTo(CFrame.new(pos))
	local belt = m:FindFirstChild("Treadmill_Belt", true)
	local display = m:FindFirstChild("Treadmill_Display", true)
	assert(belt and display, "Missing Belt or Display")
	local deck = Instance.new("Part")
	deck.Name = "BeltCollision"
	deck.Anchored = true
	deck.Transparency = 1
	deck.Size = belt.Size
	deck.CFrame = belt.CFrame
	deck.CanCollide = true
	deck.CanTouch = false
	deck.CanQuery = true
	deck.Parent = m
	local top = belt.Position + Vector3.new(0, belt.Size.Y / 2, 0)
	local direction = Vector3.new(display.Position.X - top.X, 0, display.Position.Z - top.Z).Unit
	local center = Instance.new("Part")
	center.Name = "TrainingCenter"
	center.Anchored = true
	center.Transparency = 1
	center.Size = Vector3.new(belt.Size.X * 0.85, 0.2, belt.Size.Z * 0.65)
	center.CFrame = CFrame.lookAt(top, top + direction)
	center.CanCollide = false
	center.CanTouch = false
	center.CanQuery = false
	center.Parent = m
	m.Parent = stations
	table.insert(
		summary,
		{ name = m.Name, position = tostring(pos), beltTop = tostring(top), size = tostring(dimensions) }
	)
end
stations.Parent = lobby
source:Destroy()
return game:GetService("HttpService"):JSONEncode({ stations = summary, template = template:GetFullName() })
