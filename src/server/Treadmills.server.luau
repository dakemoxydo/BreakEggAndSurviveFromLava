local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Config = require(ReplicatedStorage:WaitForChild("TrainingConfig"))
local Game = require(ReplicatedStorage:WaitForChild("GameConfig"))

local exit = Instance.new("RemoteEvent")
exit.Name = "ExitTreadmill"
assert(not ReplicatedStorage:FindFirstChild(exit.Name), "Duplicate treadmill controller")
exit.Parent = ReplicatedStorage

local active = {}
local occupied = {}
local cooldown = {}

local function standingHeight(character, humanoid, root)
	local height = humanoid.HipHeight + root.Size.Y / 2
	if humanoid.RigType == Enum.HumanoidRigType.R6 then
		local leg = character:FindFirstChild("Left Leg")
		height += leg and leg.Size.Y or 2
	end
	return height
end

local function speedValue(player, fallback)
	local speed = player:GetAttribute("Speed")
	if typeof(speed) ~= "number" or speed ~= speed or speed == math.huge or speed < 0 then
		speed = fallback
	end
	return math.min(speed, Game.MaxSpeed)
end

local function detach(player, jump)
	local session = active[player]
	if not session then
		return
	end
	active[player] = nil
	occupied[session.station] = nil
	cooldown[player] = os.clock() + Config.ReentryCooldown
	if session.track then
		session.track:Stop(0.15)
		session.track:Destroy()
	end
	if session.died then
		session.died:Disconnect()
	end
	local root, humanoid = session.root, session.humanoid
	if root.Parent then
		root.Anchored = session.anchored
		if jump and humanoid.Health > 0 then
			root.CFrame = session.exitCFrame
			root.AssemblyLinearVelocity = Vector3.new(0, 24, 0)
		end
	end
	if humanoid.Parent then
		humanoid.WalkSpeed = Game.walkSpeed(
			speedValue(player, session.walkSpeed) * (player:GetAttribute("Multiplier") or 1),
			player:GetAttribute("SlowMode")
		)
		humanoid.AutoRotate = session.autoRotate
	end
	player:SetAttribute("OnTreadmill", false)
end

local function attach(player, character, humanoid, root, station, center)
	if station:GetAttribute("OwnerUserId") and station:GetAttribute("OwnerUserId") ~= player.UserId then
		return
	end
	if active[player] or occupied[station] or (cooldown[player] or 0) > os.clock() then
		return
	end
	if humanoid.Health <= 0 or humanoid.Sit or root.Anchored then
		return
	end
	if player:GetAttribute("PetDataReady") ~= true then
		return
	end
	local standHeight = standingHeight(character, humanoid, root)
	local speed = speedValue(player, humanoid.WalkSpeed)
	player:SetAttribute("Speed", speed)
	local session = {
		station = station,
		center = center,
		character = character,
		humanoid = humanoid,
		root = root,
		elapsed = 0,
		walkSpeed = humanoid.WalkSpeed,
		autoRotate = humanoid.AutoRotate,
		anchored = root.Anchored,
		exitCFrame = center.CFrame * CFrame.new(0, standHeight + 1, center.Size.Z / 2 + 3),
	}
	active[player] = session
	occupied[station] = player
	humanoid.WalkSpeed = 0
	humanoid.AutoRotate = false
	root.AssemblyLinearVelocity = Vector3.zero
	root.AssemblyAngularVelocity = Vector3.zero
	root.CFrame = center.CFrame * CFrame.new(0, standHeight, 0)
	root.Anchored = true
	player:SetAttribute("OnTreadmill", true)
	local animate = character:FindFirstChild("Animate")
	local run = animate and animate:FindFirstChild("run")
	local animation = run and run:FindFirstChildWhichIsA("Animation", true)
	local animator = humanoid:FindFirstChildOfClass("Animator")
	if animation and animator then
		local ok, track = pcall(function()
			return animator:LoadAnimation(animation)
		end)
		if ok then
			session.track = track
			track.Priority = Enum.AnimationPriority.Action
			track.Looped = true
			track:Play(0.15)
			track:AdjustSpeed(1)
		end
	end
	session.died = humanoid.Died:Connect(function()
		detach(player, false)
	end)
end

exit.OnServerEvent:Connect(function(player)
	if active[player] then
		detach(player, true)
	end
end)
Players.PlayerRemoving:Connect(function(player)
	detach(player, false)
	cooldown[player] = nil
end)

local function connectPlayer(player)
	local function characterAdded(character)
		detach(player, false)
		local humanoid = character:WaitForChild("Humanoid", 10)
		if humanoid and player.Character == character then
			local speed = speedValue(player, humanoid.WalkSpeed)
			player:SetAttribute("Speed", speed)
			humanoid.WalkSpeed =
				Game.walkSpeed(speed * (player:GetAttribute("Multiplier") or 1), player:GetAttribute("SlowMode"))
		end
	end
	player.CharacterAdded:Connect(characterAdded)
	if player.Character then
		task.spawn(characterAdded, player.Character)
	end
end
Players.PlayerAdded:Connect(connectPlayer)
for _, player in Players:GetPlayers() do
	connectPlayer(player)
end

local scanElapsed = 0
RunService.Heartbeat:Connect(function(dt)
	for player, session in active do
		if
			player.Character ~= session.character
			or player:GetAttribute("PetDataReady") ~= true
			or not session.root.Parent
			or session.humanoid.Health <= 0
			or not session.station:IsDescendantOf(workspace)
		then
			detach(player, false)
		else
			session.elapsed += dt
			local seconds = math.floor(session.elapsed)
			if seconds > 0 then
				session.elapsed -= seconds
				player:SetAttribute(
					"Speed",
					math.min(
						Game.MaxSpeed,
						speedValue(player, session.walkSpeed)
							+ seconds
								* (session.station:GetAttribute("TrainingGain") or Config.SpeedPerSecond)
								* (player:GetAttribute("Multiplier") or 1)
					)
				)
			end
		end
	end
	scanElapsed += dt
	if scanElapsed < Config.ScanInterval then
		return
	end
	scanElapsed = 0
	local map = workspace:FindFirstChild("Map")
	local lobby = map and map:FindFirstChild("StartZone")
	local stations = lobby and lobby:FindFirstChild("Treadmills")
	if not stations then
		return
	end
	for _, player in Players:GetPlayers() do
		if active[player] or (cooldown[player] or 0) > os.clock() then
			continue
		end
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if not humanoid or not root then
			continue
		end
		for _, station in stations:GetChildren() do
			local center = station:FindFirstChild("TrainingCenter")
			if occupied[station] or not center or not center:IsA("BasePart") then
				continue
			end
			local point = center.CFrame:PointToObjectSpace(root.Position)
			if
				math.abs(point.X) <= center.Size.X / 2
				and math.abs(point.Z) <= center.Size.Z / 2
				and point.Y >= 0
				and point.Y <= 7
			then
				local deck = station:FindFirstChild("BeltCollision")
				if not deck then
					continue
				end
				local params = RaycastParams.new()
				params.FilterType = Enum.RaycastFilterType.Include
				params.FilterDescendantsInstances = { deck }
				local hit = workspace:Raycast(
					root.Position,
					Vector3.new(0, -standingHeight(character, humanoid, root) - 0.6, 0),
					params
				)
				if not hit then
					continue
				end
				attach(player, character, humanoid, root, station, center)
				break
			end
		end
	end
end)
