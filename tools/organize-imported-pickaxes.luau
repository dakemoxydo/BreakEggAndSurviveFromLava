-- Move the checked full import into storage and prepare canonical templates.
local Http = game:GetService("HttpService")
local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local pack = workspace:FindFirstChild("Pickaxes_Pack")
assert(pack and pack:IsA("Model"), "Workspace.Pickaxes_Pack missing")
local config = require(ReplicatedStorage.GameConfig)
local function folder(parent, name)
	local existing = parent:FindFirstChild(name)
	assert(not existing or existing:IsA("Folder"), "Folder name occupied: " .. name)
	if existing then return existing end
	local result = Instance.new("Folder")
	result.Name = name
	result.Parent = parent
	return result
end
local assets = folder(ServerStorage, "Assets")
local pickaxes = folder(folder(assets, "Items"), "Pickaxes")
local imports = folder(pickaxes, "SourceImports")
local archive = folder(pickaxes, "Archive")
assert(not imports:FindFirstChild("Pickaxes_Pack_v03"), "Full pack already organized")
assert(not archive:FindFirstChild("BeforeFullPack_v03"), "Backup already exists")
local staged = Instance.new("Folder")
staged.Name = "Templates"
for index, info in config.Pickaxes do
	local source = pack:FindFirstChild(info.key .. "Pickaxe")
	assert(source and source:IsA("MeshPart"), "Missing imported key: " .. info.key)
	assert(source.MeshId ~= "" and source.TextureID ~= "", "Missing mesh or texture: " .. info.key)
	local grip = source.CFrame:PointToObjectSpace(source:GetPivot().Position)
	assert(math.abs(grip.X) < .001 and math.abs(grip.Z) < .001, "Unexpected grip axis")
	local template = source:Clone()
	template.Name = info.key
	template.Color = Color3.new(1, 1, 1)
	template.Material = Enum.Material.Plastic
	template.CFrame = CFrame.new(0, -grip.Y, 0)
	template.PivotOffset = CFrame.new(0, grip.Y, 0)
	template.Anchored = true
	template.CanCollide = false
	template.CanTouch = false
	template.CanQuery = false
	template.Massless = true
	template.Transparency = 0
	template:SetAttribute("AssetKey", info.key)
	template:SetAttribute("Tier", index)
	template:SetAttribute("SourcePackVersion", "v03")
	template:SetAttribute("SourceMeshName", source.Name)
	local head = Instance.new("Attachment")
	head.Name = "PickaxeHead"
	head.Position = Vector3.new(0, 2.75 + grip.Y, 0)
	head.Parent = template
	template.Parent = staged
end
assert(#staged:GetChildren() == 18 and #pack:GetChildren() == 18, "Expected exactly 18 meshes")
local backup = Instance.new("Folder")
backup.Name = "BeforeFullPack_v03"
local runtime = ReplicatedStorage:FindFirstChild("PickaxeModels")
if runtime then local copy = runtime:Clone(); copy.Name = "RuntimeTemplates"; copy.Parent = backup end
local previous = pickaxes:FindFirstChild("Templates")
if previous then previous.Name = "StorageTemplates"; previous.Parent = backup end
backup.Parent = archive
staged.Parent = pickaxes
pack.Name = "Pickaxes_Pack_v03"
pack:SetAttribute("SourcePackVersion", "v03")
pack.Parent = imports
for _, mesh in pack:GetChildren() do
	mesh.Anchored = true
	mesh.CanCollide = false
	mesh.CanTouch = false
	mesh.CanQuery = false
	mesh.Color = Color3.new(1, 1, 1)
end
return Http:JSONEncode({source=pack:GetFullName(),templates=staged:GetFullName(),count=#staged:GetChildren(),backup=backup:GetFullName()})
