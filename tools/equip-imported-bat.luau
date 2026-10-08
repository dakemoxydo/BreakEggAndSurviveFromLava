assert(not game:GetService("RunService"):IsRunning(), "Edit required")
local source = workspace:FindFirstChild("Scene")
assert(source and source:IsA("Model"), "Imported Scene missing")
local grip = source:FindFirstChild("02 Dark wrapped grip refined", true)
assert(grip and grip:IsA("MeshPart"), "Bat grip missing")
assert(not game.StarterPack:FindFirstChild("Lava Bat"), "Bat already exists")
local assets = game.ServerStorage:FindFirstChild("Assets") or Instance.new("Folder", game.ServerStorage)
assets.Name = "Assets"
local items = assets:FindFirstChild("Items") or Instance.new("Folder", assets)
items.Name = "Items"
local weapons = items:FindFirstChild("Bats") or Instance.new("Folder", items)
weapons.Name = "Bats"
local visual = source:Clone()
visual.Name = "WoodenBatVisual"
local _, size = visual:GetBoundingBox()
visual:ScaleTo(visual:GetScale() * 4.5 / size.X)
local clonedGrip = visual:FindFirstChild("02 Dark wrapped grip refined", true)
local transform = CFrame.Angles(0, 0, -math.pi / 2) * CFrame.new(-clonedGrip.Position)
local tool = Instance.new("Tool")
tool.Name = "Lava Bat"
tool.ToolTip = "Бита"
tool.RequiresHandle = true
tool.CanBeDropped = false
tool.Grip = CFrame.identity
local handle = Instance.new("Part")
handle.Name = "Handle"
handle.Size = Vector3.new(0.3, 1, 0.3)
handle.CFrame = CFrame.identity
handle.Transparency = 1
handle.Parent = tool
local count = 0
for _, p in visual:GetDescendants() do
	if p:IsA("BasePart") then
		p.CFrame = transform * p.CFrame
		p.PivotOffset = CFrame.identity
		p.Anchored = false
		p.Massless = true
		p.CanCollide = false
		p.CanTouch = false
		p.CanQuery = false
		p.Parent = tool
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = handle
		weld.Part1 = p
		weld.Parent = p
		count += 1
	end
end
handle.Anchored = false
handle.Massless = true
handle.CanCollide = false
handle.CanTouch = false
handle.CanQuery = false
visual:Destroy()
assert(count == 3, "Unexpected imported bat geometry")
source.Name = "WoodenBatSource"
source.Parent = weapons
tool.Parent = game.StarterPack
return { tool = tool:GetFullName(), visualParts = count, source = source:GetFullName(), length = 4.5 }
