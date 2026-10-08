local PetAnimation = {}

PetAnimation.WalkCycleSpeed = math.pi * 4

function PetAnimation.bind(model)
	local rig = {
		Body = model:FindFirstChild("Body"),
		LeftLeg = model:FindFirstChild("LegLeft"),
		RightLeg = model:FindFirstChild("LegRight"),
		LeftFoot = model:FindFirstChild("FootLeft"),
		RightFoot = model:FindFirstChild("FootRight"),
		LeftWing = model:FindFirstChild("WingLeft"),
		RightWing = model:FindFirstChild("WingRight"),
	}
	for _, name in { "Body", "LeftLeg", "RightLeg", "LeftFoot", "RightFoot", "LeftWing", "RightWing" } do
		local part = rig[name]
		if not part or not part:IsA("BasePart") then
			return nil
		end
	end
	return rig
end

function PetAnimation.apply(model, rig, root, phase, walkWeight, idleTime)
	local scale = model:GetScale()
	local function offset(x,y,z) return CFrame.new(x*scale,y*scale,z*scale) end
	local idleWeight = 1 - walkWeight
	local step = math.sin(phase) * walkWeight
	local bob = (0.025 + math.abs(math.sin(phase * 2)) * 0.065) * walkWeight
		+ (0.0125 + math.sin(idleTime * 2) * 0.0125) * idleWeight
	local roll = step * 0.025 + math.sin(idleTime * 1.2) * 0.012 * idleWeight
	local pose = root * offset(0, bob, 0) * CFrame.Angles(0, 0, roll)
	model:PivotTo(pose)

	local leftStep, rightStep = step, -step
	local leftLift, rightLift = math.max(0, leftStep), math.max(0, rightStep)
	rig.LeftLeg.CFrame = pose * offset(-0.58, 0.42 + leftLift * 0.045, -0.82 - leftStep * 0.07)
		* CFrame.Angles(leftStep * 0.12, 0, 0)
	rig.RightLeg.CFrame = pose * offset(0.58, 0.42 + rightLift * 0.045, -0.82 - rightStep * 0.07)
		* CFrame.Angles(rightStep * 0.12, 0, 0)
	rig.LeftFoot.CFrame = pose * offset(-0.58, 0.15 + leftLift * 0.11, -0.95 - leftStep * 0.2)
		* CFrame.Angles(leftStep * 0.15, 0, 0)
	rig.RightFoot.CFrame = pose * offset(0.58, 0.15 + rightLift * 0.11, -0.95 - rightStep * 0.2)
		* CFrame.Angles(rightStep * 0.15, 0, 0)

	local flap = math.sin(phase * 2) * walkWeight + math.sin(idleTime * 1.4) * 0.2 * idleWeight
	rig.LeftWing.CFrame = pose * offset(-1.31, 1.32, 0.05) * CFrame.Angles(0, 0, 0.07 + flap * 0.055)
	rig.RightWing.CFrame = pose * offset(1.31, 1.32, 0.05) * CFrame.Angles(0, 0, -0.07 - flap * 0.055)
end

return PetAnimation
