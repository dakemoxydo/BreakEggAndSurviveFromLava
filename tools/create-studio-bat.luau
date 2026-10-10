-- Edit-only: native geometry, preserving the existing Tool and hand frame.
assert(not game:GetService("RunService"):IsRunning(), "Run in Edit")
local tool = game.StarterPack:FindFirstChild("Lava Bat")
assert(tool and tool:IsA("Tool"), "Missing Lava Bat")
local handle = assert(tool:FindFirstChild("Handle"))
local grip = tool.Grip
local origin = handle.CFrame
for _, child in tool:GetChildren() do
	if child:IsA("MeshPart") or child.Name == "StudioBatVisual" then
		child:Destroy()
	end
end
for _, child in handle:GetChildren() do
	if child:IsA("WeldConstraint") and (not child.Part1 or not child.Part1.Parent) then
		child:Destroy()
	end
end
local model = Instance.new("Model")
model.Name = "StudioBatVisual"
local function cylinder(name, y, length, diameter, color, material)
	local part = Instance.new("Part")
	part.Name = name
	part.Shape = Enum.PartType.Cylinder
	part.Size = Vector3.new(length, diameter, diameter)
	part.CFrame = origin * CFrame.new(0, y, 0) * CFrame.Angles(0, 0, math.pi / 2)
	part.Color = color
	part.Material = material
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Massless = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.Parent = model
	local weld = Instance.new("WeldConstraint")
	weld.Part0, weld.Part1 = handle, part
	weld.Parent = part
	return part
end
local wood = Color3.fromRGB(220, 135, 57)
local dark = Color3.fromRGB(59, 35, 29)
cylinder("Pommel", -0.71315, 0.46355, 0.48756, wood, Enum.Material.Wood)
cylinder("WrappedGrip", 0, 0.96276, 0.26355, dark, Enum.Material.SmoothPlastic)
-- Small overlapping sections create a taper with a rounded, readable head.
for index = 1, 8 do
	local y = 0.46355 + (index - 0.5) * 3.09152 / 8
	local diameter = 0.30 + 0.43134 * math.min(index / 5, 1)
	cylinder("Barrel" .. index, y, 3.09152 / 8 + 0.025, diameter, wood, Enum.Material.Wood)
end
for index = 1, 5 do
	cylinder("GripBand" .. index, -0.38 + (index - 1) * 0.19, 0.045, 0.282, Color3.fromRGB(95, 57, 40), Enum.Material.SmoothPlastic)
end
model.PrimaryPart = model.WrappedGrip
model.Parent = tool
assert(tool.Grip == grip and handle.CFrame == origin, "Hand frame changed")
local folder = game.ServerStorage.Assets.Items.Bats
local old = folder:FindFirstChild("WoodenBatSource")
if old then old:Destroy() end
local source = model:Clone()
source.Name = "WoodenBatSource"
for _, child in source:GetDescendants() do
	if child:IsA("WeldConstraint") then child:Destroy()
	elseif child:IsA("BasePart") then child.Anchored = true end
end
source.Parent = folder
local _, size = model:GetBoundingBox()
return {parts = #model:GetChildren(), bounds = tostring(size), gripPreserved = true, meshParts = 0}
