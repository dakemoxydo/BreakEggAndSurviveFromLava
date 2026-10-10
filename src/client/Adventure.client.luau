local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local UIS = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Game = require(RS:WaitForChild("GameConfig"))
local PickaxeEffects = require(RS:WaitForChild("PickaxeEffects"))
local HatchEffects = require(RS:WaitForChild("HatchEffects"))
local player = Players.LocalPlayer
local action = RS:WaitForChild("GameplayAction")
local feedback = RS:WaitForChild("GameplayFeedback")
local mouse = player:GetMouse()
local last = 0
local function held()
	return player.Character and player.Character:FindFirstChildOfClass("Tool")
end
local function eggFrom(part)
	local model = part
	while model and model ~= workspace do
		if model:IsA("Model") and model:GetAttribute("BreakableEgg") then
			return model
		end
		model = model.Parent
	end
end
local function targetEgg(screenPoint)
	local tool = held()
	if not tool or not tool:GetAttribute("Pickaxe") then
		return
	end
	local root = player.Character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	local target = eggFrom(mouse.Target)
	if screenPoint then
		local camera = workspace.CurrentCamera
		if camera then
			local ray = camera:ViewportPointToRay(screenPoint.X, screenPoint.Y)
			local params = RaycastParams.new()
			params.FilterType = Enum.RaycastFilterType.Exclude
			params.FilterDescendantsInstances = { player.Character }
			local hit = workspace:Raycast(ray.Origin, ray.Direction * 500, params)
			target = hit and eggFrom(hit.Instance) or nil
		end
	end
	if
		target
		and not target:GetAttribute("Hatching")
		and (target:GetPivot().Position - root.Position).Magnitude < Game.SwingRange
	then
		return target
	end
	local folder = workspace.Map:FindFirstChild("Adventure")
	if not folder then
		return
	end
	local closest, distance = nil, Game.SwingRange
	for _, model in folder:GetChildren() do
		if model:IsA("Model") and model:GetAttribute("BreakableEgg") and not model:GetAttribute("Hatching") then
			local d = (model:GetPivot().Position - root.Position).Magnitude
			if d < distance then
				closest = model
				distance = d
			end
		end
	end
	return closest
end
local function swing(screenPoint)
	if
		player:GetAttribute("UIWindowOpen")
		or player:GetAttribute("OnTreadmill")
		or (player:GetAttribute("CarryingCount") or 0) > 0
		or not player:GetAttribute("PetDataReady")
	then
		return
	end
	local tool = held()
	if not tool then
		return
	end
	if os.clock() - last < (tool.Name == "Lava Bat" and 0.8 or Game.SwingCooldown) then
		return
	end
	if tool:GetAttribute("Pickaxe") then
		local target = targetEgg(screenPoint)
		last = os.clock()
		local character = player.Character
		local id = target and target:GetAttribute("EggId")
		PickaxeEffects.swing(character)
		task.delay(Game.SwingImpactTime, function()
			local humanoid = character:FindFirstChildOfClass("Humanoid")
			if
				player.Character == character
				and tool.Parent == character
				and humanoid
				and humanoid.Health > 0
				and not player:GetAttribute("UIWindowOpen")
				and not player:GetAttribute("OnTreadmill")
			then
				-- Play the impact now instead of waiting a round trip for EggHit.
				local root = character:FindFirstChild("HumanoidRootPart")
				if
					target
					and target.Parent
					and not target:GetAttribute("Hatching")
					and root
					and (target:GetPivot().Position - root.Position).Magnitude < Game.SwingRange
				then
					PickaxeEffects.predict(target, character)
				end
				action:FireServer("Swing", id)
			end
		end)
	elseif tool.Name == "Lava Bat" then
		last = os.clock()
		local character = player.Character
		PickaxeEffects.swing(character)
		task.delay(Game.SwingImpactTime, function()
			local humanoid = character:FindFirstChildOfClass("Humanoid")
			if
				player.Character == character
				and tool.Parent == character
				and humanoid
				and humanoid.Health > 0
				and not player:GetAttribute("UIWindowOpen")
				and not player:GetAttribute("OnTreadmill")
			then
				action:FireServer("Bat")
			end
		end)
	end
end
UIS.InputBegan:Connect(function(input, processed)
	if processed then
		return
	end
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		swing()
	end
end)
UIS.TouchTapInWorld:Connect(function(at, processed)
	if not processed then
		swing(at)
	end
end)
local highlight = Instance.new("Highlight")
highlight.Name = "TargetEgg"
highlight.FillTransparency = 1
highlight.OutlineColor = Color3.fromRGB(255, 237, 105)
highlight.DepthMode = Enum.HighlightDepthMode.Occluded
highlight.Enabled = false
highlight.Parent = workspace
local accumulator = 0
RunService.RenderStepped:Connect(function(dt)
	accumulator += dt
	if accumulator < 0.1 then
		return
	end
	accumulator = 0
	local target
	if not player:GetAttribute("UIWindowOpen") then
		target = targetEgg()
	end
	highlight.Adornee = target
	highlight.Enabled = target ~= nil
	if player:GetAttribute("AutoSwing") then
		swing()
	end
end)
feedback.OnClientEvent:Connect(function(name, at, extra)
	if name == "Open" then
		local bootstrap = player.PlayerScripts:FindFirstChild("ShopUIBootstrap")
		local controller = bootstrap and bootstrap:FindFirstChild("UIController")
		if controller then
			controller:Fire("Open", at)
		end
	elseif name == "ToolSwing" then
		if typeof(extra) == "Instance" and extra:IsA("Model") and extra ~= player.Character then
			PickaxeEffects.swing(extra, true)
		end
	elseif name == "EggHit" then
		if type(extra) == "table" then
			if extra.character and extra.character ~= player.Character then
				PickaxeEffects.swing(extra.character, true)
			end
			PickaxeEffects.hit(at, extra)
		end
	elseif name == "Hatch" then
		if type(extra) == "table" then
			HatchEffects.begin(extra.model)
		end
	end
end)
task.spawn(function()
	local folder = workspace:WaitForChild("Map"):WaitForChild("Adventure")
	HatchEffects.watch(folder)
	PickaxeEffects.watchEggs(folder)
end)
local function ownMarker()
	local bases = workspace.Map.StartZone.PlayerBases
	for _, base in bases:GetChildren() do
		local contents = base:FindFirstChild("PetContents")
		local marker = contents and contents:FindFirstChild("BaseMarker")
		if marker then
			local gui = marker:FindFirstChild("BaseMarkerUI")
			if gui and base:GetAttribute("OwnerUserId") == player.UserId then
				gui.OwnerTitle.Text = "Your Base"
				local icon = require(RS.ShopUI.Assets).home
				gui.OwnerHead.Image = icon.image
				gui.OwnerHead.ImageRectOffset = icon.offset
				gui.OwnerHead.ImageRectSize = icon.rect
			end
		end
	end
end
player:GetAttributeChangedSignal("BaseName"):Connect(function()
	task.delay(1, ownMarker)
end)
task.delay(3, ownMarker)
