--[[
Run in Studio (MCP execute_luau, Edit) after importing Blender FBX animations for a bone rig.

Roblox imports bone poses as full local rotations (rest * delta), but Animator applies a
Pose on top of Bone.CFrame, so bones whose rest is rotated (legs/wings pointing down)
end up rotated twice. This rewrites every bone Pose to rest^-1 * pose (rotation only).
Run once per KeyframeSequence; the "BonePoseRestFixed" attribute prevents a second pass.
Then republish the sequences (Save to Roblox, overwrite) to update the AnimationIds.
]]
local RIG = game.ServerStorage.Assets.Pets.Chicken
local SEQUENCES = game.ServerStorage.RBX_ANIMSAVES["chick-v02"]
local NAMES = { "ChickRig|Idle", "ChickRig|Walk" }

local rest = {}
for _, bone in RIG:GetDescendants() do
	if bone:IsA("Bone") then
		rest[bone.Name] = bone.CFrame.Rotation
	end
end
local fixed = {}
for _, name in NAMES do
	local seq = SEQUENCES[name]
	if not seq:GetAttribute("BonePoseRestFixed") then
		for _, pose in seq:GetDescendants() do
			local r = pose:IsA("Pose") and rest[pose.Name]
			if r then
				pose.CFrame = CFrame.new(pose.CFrame.Position) * r:Inverse() * pose.CFrame.Rotation
			end
		end
		seq:SetAttribute("BonePoseRestFixed", true)
		table.insert(fixed, name)
	end
end
return "fixed: " .. table.concat(fixed, ", ")
