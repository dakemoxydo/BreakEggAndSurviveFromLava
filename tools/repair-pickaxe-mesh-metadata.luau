-- Restore intrinsic mesh dimensions without changing the intended Part.Size.
local storage = game.ServerStorage.Assets.Items.Pickaxes.Templates
local runtime = game.ReplicatedStorage.PickaxeModels
local repaired = {}
for _, template in runtime:GetChildren() do
	local source = storage:FindFirstChild(template.Name)
	assert(source and source:IsA("MeshPart") and source.MeshSize.X > 0, "Missing imported geometry")
	local size, cframe, pivot = template.Size, template.CFrame, template.PivotOffset
	template:ApplyMesh(source)
	template.Size, template.CFrame, template.PivotOffset = size, cframe, pivot
	table.insert(repaired, {key=template.Name, meshSize={template.MeshSize.X,template.MeshSize.Y,template.MeshSize.Z}})
end
return game:GetService("HttpService"):JSONEncode(repaired)
