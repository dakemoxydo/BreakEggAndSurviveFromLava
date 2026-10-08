assert(not game:GetService("RunService"):IsRunning(), "Edit required")
local pack = game:GetService("StarterPack")
assert(not pack:FindFirstChild("Secret Pickaxe"), "Pickaxe already exists")
local tool = Instance.new("Tool")
tool.Name = "Secret Pickaxe"
tool.ToolTip = "Кирка"
tool.CanBeDropped = false
tool.RequiresHandle = true
tool.Grip = CFrame.new(0, -1, 0)
tool:SetAttribute("TemporaryModel", true)
local function part(name, size, cf, color, material)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material
	p.Anchored = false
	p.Massless = true
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = tool
	return p
end
local handle =
	part("Handle", Vector3.new(0.32, 3.6, 0.32), CFrame.new(), Color3.fromRGB(134, 80, 42), Enum.Material.Wood)
local metal = Color3.fromRGB(154, 178, 195)
part("Head", Vector3.new(2.8, 0.45, 0.5), CFrame.new(0, 1.65, 0), metal, Enum.Material.Metal)
for _, side in { -1, 1 } do
	part(
		"PickTip",
		Vector3.new(1.2, 0.3, 0.35),
		CFrame.new(side * 1.8, 1.45, 0) * CFrame.Angles(0, 0, math.rad(-side * 24)),
		metal,
		Enum.Material.Metal
	)
end
part(
	"HeadSocket",
	Vector3.new(0.55, 0.65, 0.6),
	CFrame.new(0, 1.5, 0),
	Color3.fromRGB(76, 95, 110),
	Enum.Material.Metal
)
part(
	"GripBand",
	Vector3.new(0.4, 0.85, 0.4),
	CFrame.new(0, -1.15, 0),
	Color3.fromRGB(58, 40, 30),
	Enum.Material.Plastic
)
for _, p in tool:GetChildren() do
	if p:IsA("BasePart") and p ~= handle then
		local w = Instance.new("WeldConstraint")
		w.Part0 = handle
		w.Part1 = p
		w.Parent = p
	end
end
tool.Parent = pack
return { path = tool:GetFullName(), parts = 6, welds = 5, availableOnSpawn = true }
