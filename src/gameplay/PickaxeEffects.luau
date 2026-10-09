local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local Game = require(game.ReplicatedStorage.GameConfig)
local Audio = require(game.ReplicatedStorage.Audio)
local GameFeel = require(game.ReplicatedStorage.GameFeel)
local Effects = {}
local active = setmetatable({}, { __mode = "k" })
local frozen = setmetatable({}, { __mode = "k" })
local eggAnimations = setmetatable({}, { __mode = "k" })
local predicted = setmetatable({}, { __mode = "k" })
local random = Random.new()
local player = Players.LocalPlayer
local combo, lastComboHit = 0, 0

local function reducedMotion()
	return player:GetAttribute("ReducedMotion") == true
end

-- Swings are authored as a path of the tool itself, in HumanoidRootPart space
-- (X right, Y up, -Z forward): `at` is the right hand's grip point on the
-- shaft, `dir` is the shaft toward the head / barrel. `lean` tips
-- the upper body forward (+) or back (-) in degrees, `twist` turns it to the
-- left (+) or right (-), `elbow` is where the right elbow points in torso space
-- (the left arm mirrors X). The tool never moves in the hand: shoulders,
-- elbows and wrists are solved so the held tool follows the path. `support` is
-- the left hand's grip point relative to the right one (shaft = +Y). Grip +Z
-- runs back along the forearm, as in the normal hold with the shaft up.
local SwingEnd = 0.575
local DefaultElbow = Vector3.new(0.6, -1, 0.4)
-- Past this bend the wrist stays stiff and the tool follows the forearm.
local MaxWrist = math.rad(55)
local Swings = {
	-- Overhead two-handed chop: shaft behind the head, then straight down in
	-- front while the upper body bends forward.
	Pickaxe = {
		support = Vector3.new(0, -0.4, 0),
		keys = {
			{
				time = 0.16,
				at = Vector3.new(0.3, 2.15, 0.2),
				dir = Vector3.new(0, 0.55, 0.85),
				lean = -6,
				elbow = Vector3.new(0.8, 0.1, -0.6),
				ease = "out",
			},
			{
				time = 0.21,
				at = Vector3.new(0.3, 2.2, 0.3),
				dir = Vector3.new(0, 0.4, 0.9),
				lean = -9,
				elbow = Vector3.new(0.8, 0.1, -0.6),
				ease = "inout",
			},
			{
				time = Game.SwingImpactTime,
				at = Vector3.new(0.1, 0.45, -1.4),
				dir = Vector3.new(0, -0.3, -1),
				lean = 24,
				elbow = Vector3.new(0.7, -1, 0.2),
				ease = "in",
			},
			{
				time = Game.SwingImpactTime + 0.075,
				at = Vector3.new(0.1, 0.15, -1.25),
				dir = Vector3.new(0, -0.7, -0.7),
				lean = 30,
				elbow = Vector3.new(0.7, -1, 0.3),
				ease = "out",
			},
		},
	},
	-- Two-handed side swing: the bat goes back over the right shoulder, then
	-- sweeps horizontally from right to left through the front.
	Bat = {
		support = Vector3.new(0, -0.45, 0),
		keys = {
			{ time = 0.16, at = Vector3.new(0.65, 1.2, 0.25), dir = Vector3.new(0.25, 0.35, 1), twist = -35, ease = "out" },
			{ time = 0.2, at = Vector3.new(0.7, 1.25, 0.35), dir = Vector3.new(0.15, 0.4, 1), twist = -45, ease = "inout" },
			{ time = 0.245, at = Vector3.new(0.85, 0.95, -0.55), dir = Vector3.new(1, 0.1, -0.1), lean = 5, twist = -15, ease = "in" },
			{
				time = Game.SwingImpactTime,
				at = Vector3.new(0.25, 0.9, -1.15),
				dir = Vector3.new(0, 0.05, -1),
				lean = 8,
				twist = 10,
				ease = "linear",
			},
			{
				time = Game.SwingImpactTime + 0.075,
				at = Vector3.new(-0.5, 0.95, -0.95),
				dir = Vector3.new(-1, 0.15, -0.1),
				lean = 8,
				twist = 40,
				elbow = Vector3.new(0.3, -1, -0.2),
				ease = "out",
			},
		},
	},
}
local function ease(kind, alpha)
	if kind == "linear" then
		return alpha
	end
	if kind == "in" then
		return alpha * alpha * alpha
	end
	if kind == "out" then
		return 1 - (1 - alpha) ^ 3
	end
	return alpha * alpha * (3 - 2 * alpha)
end
local function smooth(edge0, edge1, x)
	local t = math.clamp((x - edge0) / (edge1 - edge0), 0, 1)
	return t * t * (3 - 2 * t)
end
-- Blend between the Animator pose and the swing: in while winding up, out
-- during recovery, so idle and walking holds stay untouched.
local function swingWeight(elapsed)
	return smooth(0, 0.1, elapsed) * (1 - smooth(0.4, 0.55, elapsed))
end

-- `rest` is the current grip frame (right hand * RightGrip.C0) in root space;
-- the path starts and ends there. `hold` is the right hand in grip space
-- (RightGrip.C0^-1).
function Effects.swingPlan(kind, rest, hold, support)
	local plan = Swings[kind] or Swings.Pickaxe
	local keys = { { time = 0, at = rest.Position, rot = rest.Rotation, lean = 0, twist = 0, elbow = DefaultElbow } }
	for _, k in plan.keys do
		table.insert(
			keys,
			{
				time = k.time,
				at = k.at,
				rot = CFrame.fromRotationBetweenVectors(Vector3.yAxis, k.dir.Unit),
				lean = k.lean or 0,
				twist = k.twist or 0,
				elbow = k.elbow or DefaultElbow,
				ease = k.ease,
			}
		)
	end
	table.insert(
		keys,
		{ time = SwingEnd, at = rest.Position, rot = rest.Rotation, lean = 0, twist = 0, elbow = DefaultElbow, ease = "inout" }
	)
	return { keys = keys, hold = hold, support = support or plan.support }
end
local function sample(plan, elapsed)
	local keys = plan.keys
	local a, b = keys[#keys - 1], keys[#keys]
	for i = 2, #keys do
		if elapsed <= keys[i].time then
			a, b = keys[i - 1], keys[i]
			break
		end
	end
	local alpha = ease(b.ease, math.clamp((elapsed - a.time) / (b.time - a.time), 0, 1))
	return CFrame.new(a.at:Lerp(b.at, alpha)) * a.rot:Lerp(b.rot, alpha),
		a.lean + (b.lean - a.lean) * alpha,
		a.twist + (b.twist - a.twist) * alpha,
		a.elbow:Lerp(b.elbow, alpha)
end

-- Part CFrame through the joint chain for this frame, including Transform
-- values written earlier in the same step (physics has not moved parts yet).
function Effects.rig(character)
	local root = character:FindFirstChild("HumanoidRootPart")
	local motors = {}
	for _, joint in character:GetDescendants() do
		-- Kinematic AnimationConstraint exposes the same C0/C1/Part0/Part1/Transform.
		if (joint:IsA("Motor6D") or joint:IsA("AnimationConstraint")) and joint.Part1 then
			motors[joint.Part1] = joint
		end
	end
	local cache = {}
	local function partCF(part)
		if cache[part] then
			return cache[part]
		end
		local motor = motors[part]
		local cf = (part == root or not motor or not motor.Part0) and part.CFrame
			or partCF(motor.Part0) * motor.C0 * motor.Transform * motor.C1:Inverse()
		cache[part] = cf
		return cf
	end
	return partCF, function()
		table.clear(cache)
	end, motors
end

-- World rotation for an arm part so that `segment` (part space, from the
-- proximal pivot to the distal point) runs from `from` to `to`, with the back
-- of the arm (+Z) facing the pole. Rig pivots are not exactly on the Y axis.
local function limbRotation(from, to, pole, segment)
	local up = from - to
	up = up.Magnitude > 1e-4 and up.Unit or Vector3.yAxis
	local back = pole - up * pole:Dot(up)
	back = back.Magnitude > 1e-4 and back.Unit or up:Cross(Vector3.xAxis).Unit
	local frame = CFrame.fromMatrix(Vector3.zero, up:Cross(back), up, back)
	return frame * CFrame.fromRotationBetweenVectors(Vector3.yAxis, -segment.Unit):Inverse()
end
-- Transform that places motor.Part1 with the given world rotation while its
-- pivot stays where Part0 dictates.
local function motorTransform(parentCF, motor, rot)
	local pivot = parentCF * motor.C0
	local part1 = CFrame.new(pivot.Position - rot:VectorToWorldSpace(motor.C1.Position)) * rot
	return pivot:Inverse() * part1 * motor.C1
end

-- One arm places its hand at the world CFrame `handCF`: analytic two-bone
-- solve to the wrist plus wrist rotation for R15, aiming the whole arm at the
-- grip for R6. `elbow` is the right-arm elbow direction in torso space.
-- Returns pairs {joint, transform} without writing them.
local function armIK(character, motors, partCF, side, handCF, elbow)
	local mirror = side == "Left" and Vector3.new(-1, 1, 1) or Vector3.one
	local upper = character:FindFirstChild(side .. "UpperArm")
	if upper then
		local lower = character:FindFirstChild(side .. "LowerArm")
		local hand = character:FindFirstChild(side .. "Hand")
		local shoulder = motors[upper]
		local elbowJoint = lower and motors[lower]
		local wrist = hand and motors[hand]
		if not (shoulder and elbowJoint and wrist and shoulder.Part0) then
			return
		end
		local torso = partCF(shoulder.Part0)
		local target = (handCF * wrist.C1).Position
		local upperSegment = elbowJoint.C0.Position - shoulder.C1.Position
		local lowerSegment = wrist.C0.Position - elbowJoint.C1.Position
		local l1, l2 = upperSegment.Magnitude, lowerSegment.Magnitude
		local s = (torso * shoulder.C0).Position
		local delta = target - s
		local direction = delta.Magnitude > 1e-3 and delta.Unit or -torso.UpVector
		local d = math.clamp(delta.Magnitude, math.abs(l1 - l2) + 1e-3, l1 + l2 - 1e-3)
		-- Elbow toward where the forearm would lie straight behind the gripping
		-- hand (smallest wrist bend), nudged by the authored elbow direction.
		local handUp = handCF.Rotation:VectorToWorldSpace(-lowerSegment.Unit)
		local ideal = target + handUp * l2 - s
		local pole = (ideal.Magnitude > 1e-3 and ideal.Unit or Vector3.zero)
			+ torso:VectorToWorldSpace(elbow * mirror) * 0.5
		local bend = pole - direction * pole:Dot(direction)
		bend = bend.Magnitude > 1e-4 and bend.Unit or -torso.UpVector
		local cosA = math.clamp((l1 * l1 + d * d - l2 * l2) / (2 * l1 * d), -1, 1)
		local e = s + direction * (l1 * cosA) + bend * (l1 * math.sqrt(1 - cosA * cosA))
		local w = s + direction * d
		local upperT = motorTransform(torso, shoulder, limbRotation(s, e, bend, upperSegment))
		local upperCF = torso * shoulder.C0 * upperT * shoulder.C1:Inverse()
		-- The forearm takes the hand's roll (minimal swing onto its axis), so the
		-- wrist only bends instead of spinning the hand around the forearm.
		local up = (upperCF * elbowJoint.C0).Position - w
		local handRot = handCF.Rotation
		local lowerRot = CFrame.fromRotationBetweenVectors(handRot:VectorToWorldSpace(-lowerSegment.Unit), up.Unit)
			* handRot
		local lowerT = motorTransform(upperCF, elbowJoint, lowerRot)
		local lowerCF = upperCF * elbowJoint.C0 * lowerT * elbowJoint.C1:Inverse()
		local axis, angle = (lowerCF.Rotation:Inverse() * handRot):ToAxisAngle()
		local handFinal = angle > MaxWrist and lowerCF.Rotation * CFrame.fromAxisAngle(axis, MaxWrist) or handRot
		return { { shoulder, upperT }, { elbowJoint, lowerT }, { wrist, motorTransform(lowerCF, wrist, handFinal) } }
	end
	local arm = character:FindFirstChild(side .. " Arm")
	local shoulder = arm and motors[arm]
	if not shoulder or not shoulder.Part0 then
		return
	end
	local torso = partCF(shoulder.Part0)
	local s = (torso * shoulder.C0).Position
	local gripAttachment = arm:FindFirstChild(side .. "GripAttachment")
	local grip = gripAttachment and gripAttachment.Position or Vector3.new(0, -1, 0)
	local segment = grip - shoulder.C1.Position
	return {
		{
			shoulder,
			motorTransform(
				torso,
				shoulder,
				limbRotation(s, handCF * grip, torso:VectorToWorldSpace(elbow * mirror), segment)
			),
		},
	}
end

-- Writes the swing pose at `elapsed` over the Animator pose already held in
-- the joints, blended by `weight`. Returns the grip world CFrame on the path;
-- the held tool reaches it only as far as the arms and wrists allow.
function Effects.applySwingPose(character, motors, partCF, resetCF, plan, elapsed, weight)
	local root = character:FindFirstChild("HumanoidRootPart")
	local path, lean, twist, elbow = sample(plan, elapsed)
	local torsoPart = character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso")
	local torsoJoint = torsoPart and motors[torsoPart]
	if torsoJoint then
		-- Rotate in the parent's frame, so lean and twist follow the root axes.
		local base = torsoJoint.C0.Rotation
		torsoJoint.Transform = base:Inverse()
			* CFrame.Angles(math.rad(-lean * weight), math.rad(twist * weight), 0)
			* base
			* torsoJoint.Transform
	end
	resetCF()
	local gripCF = partCF(root) * path
	local function solve(side, handCF)
		local solution = armIK(character, motors, partCF, side, handCF, elbow)
		if solution then
			for _, pair in solution do
				pair[1].Transform = pair[1].Transform:Lerp(pair[2], weight)
			end
		end
		resetCF()
	end
	solve("Right", gripCF * plan.hold)
	-- The left hand grips the tool where the right hand actually holds it, and
	-- turns around the shaft so its forearm points toward its shoulder.
	local rightPart = character:FindFirstChild("RightHand") or character:FindFirstChild("Right Arm")
	local frame = (rightPart and partCF(rightPart) * plan.hold:Inverse() or gripCF) * CFrame.new(plan.support)
	local leftPart = character:FindFirstChild("LeftHand") or character:FindFirstChild("Left Arm")
	local shoulderPart = character:FindFirstChild("LeftUpperArm") or leftPart
	if shoulderPart then
		local toward = frame:PointToObjectSpace(partCF(shoulderPart).Position)
		frame *= CFrame.Angles(0, math.atan2(toward.X, toward.Z), 0)
	end
	local leftGrip = leftPart and leftPart:FindFirstChild("LeftGripAttachment")
	solve("Left", frame * (leftGrip and leftGrip.CFrame:Inverse() or plan.hold))
	return gripCF
end

local SwingJoints = {
	Waist = true,
	RootJoint = true,
	RightShoulder = true,
	["Right Shoulder"] = true,
	RightElbow = true,
	RightWrist = true,
	LeftShoulder = true,
	["Left Shoulder"] = true,
	LeftElbow = true,
	LeftWrist = true,
}
function Effects.swing(character, contactOnly)
	local tool = character and character:FindFirstChildOfClass("Tool")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not tool or not humanoid or humanoid.Health <= 0 then
		return
	end
	if active[character] then
		active[character]()
	end
	local handle = tool:FindFirstChild("Handle")
	local root = character:FindFirstChild("HumanoidRootPart")
	local hand = character:FindFirstChild("RightHand") or character:FindFirstChild("Right Arm")
	local rightGrip = hand and hand:FindFirstChild("RightGrip")
	if not handle or not root or not rightGrip or not rightGrip:IsA("JointInstance") then
		return
	end
	local joints = {}
	for _, joint in character:GetDescendants() do
		if (joint:IsA("Motor6D") or joint:IsA("AnimationConstraint")) and SwingJoints[joint.Name] then
			table.insert(joints, { joint = joint, transform = joint.Transform })
		end
	end
	local partCF, resetCF, motors = Effects.rig(character)
	local support = tool:GetAttribute("SupportGrip")
	local plan = Effects.swingPlan(
		tool:GetAttribute("Pickaxe") and "Pickaxe" or "Bat",
		root.CFrame:ToObjectSpace(partCF(hand) * rightGrip.C0),
		rightGrip.C0:Inverse(),
		typeof(support) == "Vector3" and support or nil
	)
	local trail = tool:FindFirstChild("PickaxeSwingTrail", true)
	local elapsed = contactOnly and Game.SwingImpactTime or 0
	local connection, preAnimation, finished
	local function stop()
		if finished then
			return
		end
		finished = true
		if connection then
			connection:Disconnect()
		end
		if preAnimation then
			preAnimation:Disconnect()
		end
		for _, item in joints do
			if item.joint.Parent then
				item.joint.Transform = item.transform
			end
		end
		if trail and trail.Parent then
			trail.Enabled = false
		end
		active[character] = nil
		frozen[character] = nil
	end
	active[character] = stop
	-- Remove our previous offset before Animator computes this frame's pose.
	-- Apply the next offset after Animator, without accumulating joint rotations.
	preAnimation = RunService.PreAnimation:Connect(function()
		for _, item in joints do
			if item.joint.Parent then
				item.joint.Transform = item.transform
			end
		end
	end)
	if not contactOnly then
		task.delay(0.19, function()
			if not finished then
				Audio.play("SwingWhoosh", handle)
			end
		end)
	end
	connection = RunService.PreSimulation:Connect(function(dt)
		-- Hitstop freezes the pose on contact for a few frames.
		if not frozen[character] or os.clock() >= frozen[character] then
			elapsed += dt
		end
		if tool.Parent ~= character or not character.Parent or humanoid.Health <= 0 or elapsed >= SwingEnd then
			stop()
			return
		end
		for _, item in joints do
			if item.joint.Parent then
				item.transform = item.joint.Transform
			end
		end
		resetCF()
		local weight = swingWeight(elapsed)
		Effects.applySwingPose(character, motors, partCF, resetCF, plan, elapsed, weight)
		if trail then
			trail.Enabled = elapsed >= 0.175 and elapsed <= Game.SwingImpactTime + 0.075
		end
	end)
	return stop
end

function Effects.hitstop(character, seconds)
	if character and active[character] and not reducedMotion() then
		frozen[character] = os.clock() + seconds
	end
end

local function part(name, position, size, color)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Position = position
	p.Color = color
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.CastShadow = false
	p.Material = Enum.Material.Neon
	p.Parent = workspace
	return p
end
Effects.part = part

-- Shell fragments follow a ballistic arc, bounce once or twice on the ground
-- plane and fade. One shared Heartbeat drives every fragment.
local flying = {}
local flyConnection
local function flyStep(dt)
	for i = #flying, 1, -1 do
		local item = flying[i]
		item.age += dt
		local p = item.part
		if item.age >= item.life or not p.Parent then
			table.remove(flying, i)
			if p.Parent then
				p:Destroy()
			end
			continue
		end
		item.velocity += Vector3.new(0, -workspace.Gravity * 0.45 * dt, 0)
		local position = item.position + item.velocity * dt
		if position.Y < item.ground then
			position = Vector3.new(position.X, item.ground, position.Z)
			item.velocity = Vector3.new(item.velocity.X * 0.55, -item.velocity.Y * 0.35, item.velocity.Z * 0.55)
			item.spin *= 0.5
		end
		item.position = position
		item.angle += item.spin * dt
		p.CFrame = CFrame.new(position) * CFrame.fromAxisAngle(item.axis, item.angle)
		local fadeStart = item.life * 0.6
		if item.age > fadeStart then
			p.Transparency = (item.age - fadeStart) / (item.life - fadeStart)
		end
	end
	if #flying == 0 and flyConnection then
		flyConnection:Disconnect()
		flyConnection = nil
	end
end
function Effects.fling(p, velocity, ground, life)
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	local axis = Vector3.new(random:NextNumber(-1, 1), random:NextNumber(-1, 1), random:NextNumber(-1, 1))
	table.insert(
		flying,
		{
			part = p,
			position = p.Position,
			velocity = velocity,
			ground = ground + p.Size.Y / 2,
			life = life or 0.9,
			age = 0,
			axis = axis.Magnitude > 1e-3 and axis.Unit or Vector3.yAxis,
			angle = 0,
			spin = random:NextNumber(6, 16),
		}
	)
	if not flyConnection then
		flyConnection = RunService.Heartbeat:Connect(flyStep)
	end
end
function Effects.chips(at, count, colors, scale, speed, ground)
	for i = 1, count do
		local direction =
			Vector3.new(random:NextNumber(-1, 1), random:NextNumber(0.5, 1.6), random:NextNumber(-1, 1)).Unit
		local size = random:NextNumber(0.18, 0.34) * scale
		local chip = part("EggShellChip", at, Vector3.new(size, size * 0.6, size), colors[(i - 1) % #colors + 1])
		chip.Material = Enum.Material.SmoothPlastic
		Effects.fling(
			chip,
			direction * random:NextNumber(0.6, 1.2) * speed * scale,
			ground,
			random:NextNumber(0.7, 1.1)
		)
	end
end

local emitters
local function emitterTemplates()
	if emitters then
		return emitters
	end
	local sparks = Instance.new("ParticleEmitter")
	sparks.Name = "Sparks"
	sparks.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	sparks.LightEmission = 1
	sparks.LightInfluence = 0
	sparks.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.55), NumberSequenceKeypoint.new(1, 0) })
	sparks.Lifetime = NumberRange.new(0.18, 0.35)
	sparks.Speed = NumberRange.new(14, 26)
	sparks.SpreadAngle = Vector2.new(180, 180)
	sparks.Drag = 7
	sparks.Rate = 0
	sparks.Enabled = false
	sparks.RotSpeed = NumberRange.new(-200, 200)
	local dust = Instance.new("ParticleEmitter")
	dust.Name = "Dust"
	dust.Texture = "rbxasset://textures/particles/smoke_main.dds"
	dust.LightInfluence = 0.6
	dust.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.8), NumberSequenceKeypoint.new(1, 2.6) })
	dust.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.45), NumberSequenceKeypoint.new(1, 1) })
	dust.Lifetime = NumberRange.new(0.35, 0.55)
	dust.Speed = NumberRange.new(2, 5)
	dust.SpreadAngle = Vector2.new(180, 180)
	dust.Drag = 4
	dust.Rate = 0
	dust.Enabled = false
	dust.Rotation = NumberRange.new(0, 360)
	emitters = { Sparks = sparks, Dust = dust }
	return emitters
end
-- Emits a one-shot particle burst at a point. counts maps template name to amount.
function Effects.burst(at, color, counts, sizeScale)
	local anchor = part("ImpactParticles", at, Vector3.one * 0.1, color)
	anchor.Transparency = 1
	local attachment = Instance.new("Attachment")
	attachment.Parent = anchor
	for name, count in counts do
		local emitter = emitterTemplates()[name]:Clone()
		if name == "Sparks" then
			emitter.Color = ColorSequence.new(color, Color3.new(1, 1, 1))
		else
			emitter.Color = ColorSequence.new(color:Lerp(Color3.new(1, 1, 1), 0.6))
		end
		if sizeScale and sizeScale ~= 1 then
			local keys = {}
			for _, key in emitter.Size.Keypoints do
				table.insert(keys, NumberSequenceKeypoint.new(key.Time, key.Value * sizeScale))
			end
			emitter.Size = NumberSequence.new(keys)
		end
		emitter.Parent = attachment
		emitter:Emit(count)
	end
	Debris:AddItem(anchor, 1)
	return anchor
end

-- Lean away from the hitter, then spring back: a damped rotation about the
-- axis perpendicular to the hit direction.
local function recoil(model, direction, strength)
	if not model or not model.Parent or model:GetAttribute("Hatching") then
		return
	end
	if eggAnimations[model] then
		eggAnimations[model]()
	end
	local originals = {}
	for _, p in model:GetChildren() do
		if p:IsA("BasePart") and p.Name ~= "NestTwig" then
			table.insert(originals, { part = p, cf = p.CFrame })
		end
	end
	local pivot = model:GetPivot()
	local started = os.clock()
	local connection, finished
	local flat = Vector3.new(direction.X, 0, direction.Z)
	local axis = flat.Magnitude > 1e-3 and flat.Unit:Cross(Vector3.yAxis) or Vector3.xAxis
	local function stop()
		if finished then
			return
		end
		finished = true
		if connection then
			connection:Disconnect()
		end
		for _, item in originals do
			if item.part.Parent then
				item.part.CFrame = item.cf
			end
		end
		eggAnimations[model] = nil
	end
	eggAnimations[model] = stop
	connection = RunService.RenderStepped:Connect(function()
		local t = os.clock() - started
		if t >= 0.42 or not model.Parent or model:GetAttribute("Hatching") then
			stop()
			return
		end
		local angle = -0.16 * strength * math.exp(-t * 9) * math.cos(t * 30)
		local squash = 1 - 0.05 * strength * math.exp(-t * 14)
		local offset = pivot * CFrame.fromAxisAngle(axis, angle) * CFrame.new(0, (squash - 1) * 2, 0) * pivot:Inverse()
		for _, item in originals do
			if item.part.Parent then
				item.part.CFrame = offset * item.cf
			end
		end
	end)
end

function Effects.stopEggRecoil(model)
	if eggAnimations[model] then
		eggAnimations[model]()
	end
end

local function impactPoint(model, character, scale, at)
	local origin = at + Vector3.new(0, 2.3 * scale, 0)
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local normal = root and (root.Position - origin) or Vector3.new(0, 0, 1)
	normal = normal.Magnitude > 0.01 and normal.Unit or Vector3.new(0, 0, 1)
	return origin + normal * 1.5 * scale, normal
end

-- The physical part of a hit: sound, flash, particles, fragments and recoil.
-- Played immediately on the attacker's client at contact time (prediction),
-- and on confirmation for everyone else.
local function impact(model, at, character, scale, color, own)
	local point, normal = impactPoint(model, character, scale, at)
	local reduced = reducedMotion()
	local pitch = own and 1 + math.min(combo, 12) * 0.035 or 1
	Audio.play("EggHit", point, { pitch = pitch })
	local flash = Instance.new("Highlight")
	flash.Name = "EggHitFlash"
	flash.Adornee = model
	flash.FillColor = Color3.new(1, 1, 1)
	flash.FillTransparency = 0.15
	flash.OutlineTransparency = 1
	flash.DepthMode = Enum.HighlightDepthMode.Occluded
	flash.Parent = workspace
	TweenService:Create(flash, TweenInfo.new(0.14), { FillTransparency = 1 }):Play()
	Debris:AddItem(flash, 0.2)
	local orb = part("EggHitSpark", point, Vector3.one * 0.6 * scale, color)
	orb.Shape = Enum.PartType.Ball
	TweenService:Create(
		orb,
		TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Size = Vector3.one * 2.2 * scale, Transparency = 1 }
	):Play()
	Debris:AddItem(orb, 0.2)
	Effects.burst(point, color, { Sparks = reduced and 6 or 14, Dust = reduced and 0 or 3 }, scale)
	if not reduced then
		recoil(model, -normal, 1)
		Effects.chips(point, 5, { color, Color3.new(1, 1, 1) }, scale, 14, at.Y)
	end
	if own then
		GameFeel.shake(0.12)
		Effects.hitstop(character, 0.045)
	end
end

-- Called by the attacker at contact time, before the server answers.
function Effects.predict(model, character)
	if not model or not model.Parent or not model.PrimaryPart then
		return
	end
	predicted[model] = os.clock()
	local scale = model:GetScale()
	local color = model.PrimaryPart.Color
	impact(model, model:GetPivot().Position, character, scale, color, true)
end

local function damageNumber(point, damage, crit, final, own)
	local anchor = part(
		"EggDamageAnchor",
		point + Vector3.new(random:NextNumber(-0.8, 0.8), 0, random:NextNumber(-0.8, 0.8)),
		Vector3.one * 0.1,
		Color3.new(1, 1, 1)
	)
	anchor.Transparency = 1
	Debris:AddItem(anchor, 1.1)
	local gui = Instance.new("BillboardGui")
	gui.Name = "EggDamage"
	gui.Size = UDim2.fromOffset(220, 90)
	gui.StudsOffsetWorldSpace = Vector3.new(0, 1, 0)
	gui.AlwaysOnTop = false
	gui.LightInfluence = 0
	gui.Parent = anchor
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 0.7)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBlack
	label.TextSize = crit and 52 or final and 46 or 36
	label.TextColor3 = crit and Color3.fromRGB(255, 120, 40) or Color3.fromRGB(255, 235, 138)
	label.Text = (crit and "CRIT -" or "-") .. Game.number(damage or 0)
	label.Parent = gui
	local outline = Instance.new("UIStroke")
	outline.Thickness = crit and 4 or 3
	outline.Parent = label
	local scale = Instance.new("UIScale")
	scale.Scale = 0.35
	scale.Parent = gui
	local fades = { label, outline }
	if own and combo >= 3 then
		local comboLabel = Instance.new("TextLabel")
		comboLabel.Size = UDim2.fromScale(1, 0.32)
		comboLabel.Position = UDim2.fromScale(0, 0.68)
		comboLabel.BackgroundTransparency = 1
		comboLabel.Font = Enum.Font.GothamBlack
		comboLabel.TextSize = 24
		comboLabel.TextColor3 = Color3.fromHSV((combo * 0.07) % 1, 0.55, 1)
		comboLabel.Text = "x" .. combo .. " COMBO"
		comboLabel.Parent = gui
		local stroke = Instance.new("UIStroke")
		stroke.Thickness = 2.5
		stroke.Parent = comboLabel
		table.insert(fades, comboLabel)
		table.insert(fades, stroke)
	end
	TweenService
		:Create(
			scale,
			TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
			{ Scale = crit and 1.15 or 1 }
		)
		:Play()
	TweenService:Create(
		gui,
		TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ StudsOffsetWorldSpace = Vector3.new(0, crit and 3.4 or 2.6, 0) }
	):Play()
	local fadeInfo = TweenInfo.new(0.25, Enum.EasingStyle.Linear, Enum.EasingDirection.Out, 0, false, 0.5)
	for _, item in fades do
		TweenService:Create(item, fadeInfo, item:IsA("UIStroke") and { Transparency = 1 } or { TextTransparency = 1 })
			:Play()
	end
end

-- Server-confirmed hit, sent to every client.
function Effects.hit(at, data)
	if typeof(at) ~= "Vector3" or type(data) ~= "table" then
		return
	end
	local camera = workspace.CurrentCamera
	if camera and (camera.CFrame.Position - at).Magnitude > 120 then
		return
	end
	local model = data.model
	local scale = math.clamp(data.scale or 1, 1, 3)
	local color = data.color or Color3.fromRGB(255, 218, 110)
	local own = data.character ~= nil and data.character == player.Character
	if own then
		combo = os.clock() - lastComboHit < 1.6 and combo + 1 or 1
		lastComboHit = os.clock()
	end
	-- The attacker already played the physical impact at contact time.
	local wasPredicted = own and model and predicted[model] and os.clock() - predicted[model] < 0.8
	if model then
		predicted[model] = nil
	end
	if not wasPredicted and typeof(model) == "Instance" and model.Parent then
		impact(model, at, data.character, scale, color, own)
	end
	local point = impactPoint(model, data.character, scale, at)
	if data.crit then
		Audio.play("EggHitCrit", point)
		Effects.burst(point, Color3.fromRGB(255, 150, 40), { Sparks = 22 }, scale * 1.3)
		if own then
			GameFeel.shake(0.2)
			Effects.hitstop(data.character, 0.06)
		end
	end
	if data.final then
		Audio.play("EggBreak", point)
		if own then
			GameFeel.shake(0.4)
			Effects.hitstop(data.character, 0.1)
		end
	end
	damageNumber(point, data.damage, data.crit, data.final, own)
end

-- Cracks spread over the shell as HP drops: stage 1..3 at 25/50/75% damage.
-- The pattern is seeded by EggId so every client draws the same cracks.
local CrackStages = 3
local function seed(text)
	local value = 0
	for i = 1, #text do
		value = (value * 31 + string.byte(text, i)) % 2147483647
	end
	return value
end
local function addCracks(model, stage)
	local faces = {}
	for _, p in model:GetChildren() do
		if p:IsA("BasePart") and (p.Name == "Shell" or string.match(p.Name, "^ShellTier")) and p.Size.Y > 0.4 then
			table.insert(faces, p)
		end
	end
	if #faces == 0 then
		return
	end
	local rng = Random.new(seed(tostring(model:GetAttribute("EggId") or model.Name) .. stage))
	local color = (model.PrimaryPart and model.PrimaryPart.Color or Color3.new(1, 1, 1)):Lerp(Color3.new(0, 0, 0), 0.65)
	for _ = 1, 2 + stage do
		local base = faces[rng:NextInteger(1, #faces)]
		local side = rng:NextInteger(1, 4)
		local normal = ({ Vector3.xAxis, -Vector3.xAxis, Vector3.zAxis, -Vector3.zAxis })[side]
		local tangent = Vector3.yAxis:Cross(normal) -- keeps (tangent, Y, normal) right-handed
		local halfW = (side <= 2 and base.Size.Z or base.Size.X) / 2 - 0.1
		local halfH = base.Size.Y / 2 - 0.05
		local u, v = rng:NextNumber(-halfW, halfW) * 0.7, rng:NextNumber(-halfH, halfH)
		local angle = rng:NextNumber(0, math.pi * 2)
		local thickness = math.max(0.06, base.Size.Y * 0.07)
		for _ = 1, 3 do
			local length = rng:NextNumber(0.35, 0.75) * base.Size.Y
			local du, dv = math.cos(angle) * length, math.sin(angle) * length
			local nu, nv = math.clamp(u + du, -halfW, halfW), math.clamp(v + dv, -halfH, halfH)
			local mid = Vector3.new(0, (v + nv) / 2, 0)
				+ tangent * ((u + nu) / 2)
				+ normal * (base.Size.X * math.abs(normal.X) + base.Size.Z * math.abs(normal.Z)) / 2
			local span = math.sqrt((nu - u) ^ 2 + (nv - v) ^ 2)
			if span > 0.05 then
				local crack = Instance.new("Part")
				crack.Name = "EggCrack"
				crack.Anchored = true
				crack.CanCollide = false
				crack.CanTouch = false
				crack.CanQuery = false
				crack.CastShadow = false
				crack.Material = Enum.Material.SmoothPlastic
				crack.Color = color
				crack.Size = Vector3.new(span, thickness, 0.04)
				crack.CFrame = base.CFrame
					* CFrame.fromMatrix(mid, tangent, Vector3.yAxis, normal)
					* CFrame.Angles(0, 0, math.atan2(nv - v, nu - u))
				crack.Parent = model
			end
			u, v = nu, nv
			angle += rng:NextNumber(-1, 1)
		end
	end
end
local function crackStage(model)
	local hp, max = model:GetAttribute("HP"), model:GetAttribute("MaxHP")
	if type(hp) ~= "number" or type(max) ~= "number" or max <= 0 then
		return 0
	end
	return math.clamp(math.floor((1 - hp / max) * (CrackStages + 1)), 0, CrackStages)
end
local function watchCracks(model)
	if not model:IsA("Model") or not model:GetAttribute("BreakableEgg") then
		return
	end
	local shown = 0
	local function update(initial)
		local stage = crackStage(model)
		if stage <= shown or model:GetAttribute("Hatching") then
			return
		end
		for s = shown + 1, stage do
			addCracks(model, s)
		end
		shown = stage
		if initial ~= true and model.PrimaryPart then
			local at = model:GetPivot().Position
			local scale = model:GetScale()
			local camera = workspace.CurrentCamera
			if camera and (camera.CFrame.Position - at).Magnitude < 120 then
				Audio.play("EggCrack", at + Vector3.new(0, 2 * scale, 0), { pitch = 1 + stage * 0.08 })
				if not reducedMotion() then
					Effects.chips(
						at + Vector3.new(0, 2.6 * scale, 0),
						4 + stage * 2,
						{ model.PrimaryPart.Color },
						scale,
						12,
						at.Y
					)
				end
			end
		end
	end
	model:GetAttributeChangedSignal("HP"):Connect(update)
	update(true)
end
function Effects.watchEggs(folder)
	folder.ChildAdded:Connect(function(model)
		task.defer(watchCracks, model)
	end)
	for _, model in folder:GetChildren() do
		watchCracks(model)
	end
end

return Effects
