local React = require(game.ReplicatedStorage.Packages.React)
local Visuals = require(game.ReplicatedStorage:WaitForChild("PetVisuals"))
local e = React.createElement
local function ModelPreview(props)
	local ref = React.useRef(nil)
	React.useEffect(function()
		local viewport = ref.current
		if not viewport then
			return
		end
		local world = Instance.new("WorldModel")
		world.Parent = viewport
		local model = props.pickaxe and Visuals.pickaxe(props.pickaxe) or Visuals.pet(props.kind, props.weight)
		if props.locked then
			for _, p in model:GetDescendants() do
				if p:IsA("BasePart") then
					p.Color = Color3.fromRGB(20, 23, 28)
				elseif p:IsA("Texture") then
					p.Transparency = 1
				end
			end
		end
		model.Parent = world
		model:PivotTo(CFrame.Angles(0, math.rad(-24), 0))
		local cf, size = model:GetBoundingBox()
		local center = cf.Position
		local extent = math.max(size.X, size.Y, size.Z)
		local camera = Instance.new("Camera")
		camera.FieldOfView = 34
		camera.CFrame = CFrame.lookAt(center + Vector3.new(extent * 0.65, extent * 0.35, -extent * 2.15), center)
		camera.Parent = viewport
		viewport.CurrentCamera = camera
		return function()
			viewport.CurrentCamera = nil
			world:Destroy()
			camera:Destroy()
		end
	end, { props.kind, props.pickaxe, props.weight, props.locked })
	return e(
		"ViewportFrame",
		{
			Name = props.name or "ItemPreview",
			ref = ref,
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(props.x or 0, props.y or 0),
			Size = UDim2.fromOffset(props.w, props.h),
			Ambient = Color3.fromRGB(200, 200, 210),
			LightColor = Color3.new(1, 1, 1),
			LightDirection = Vector3.new(-1, -2, -3),
			ZIndex = 7,
		}
	)
end
return React.memo(ModelPreview)
