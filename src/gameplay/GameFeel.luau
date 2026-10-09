-- Local camera feedback: trauma-based shake and an additive FOV punch.
-- Both are applied after the camera scripts each frame and never accumulate
-- into the camera state, so they cannot drift the view. ReducedMotion skips them.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local GameFeel = {}
local trauma = 0
local punch, punchTime, punchDuration = 0, 0, 0
local appliedFov = 0
local bound = false

local function reduced()
	return Players.LocalPlayer:GetAttribute("ReducedMotion") == true
end

local function step(dt)
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	trauma = math.max(0, trauma - dt * 1.6)
	if trauma > 0 then
		local power = trauma * trauma
		local t = os.clock() * 28
		camera.CFrame *= CFrame.Angles(
			math.rad(2.2 * power * math.noise(t, 1.3)),
			math.rad(2.2 * power * math.noise(t, 7.1)),
			math.rad(3 * power * math.noise(t, 13.7))
		)
	end
	local fov = 0
	if punchDuration > 0 then
		local alpha = math.clamp((os.clock() - punchTime) / punchDuration, 0, 1)
		-- Fast attack, smooth release.
		fov = punch * (alpha < 0.15 and alpha / 0.15 or (1 - (alpha - 0.15) / 0.85) ^ 2)
		if alpha >= 1 then
			punchDuration = 0
		end
	end
	if fov ~= appliedFov then
		camera.FieldOfView += fov - appliedFov
		appliedFov = fov
	end
end

local function bind()
	if bound then
		return
	end
	bound = true
	RunService:BindToRenderStep("GameFeelCamera", Enum.RenderPriority.Camera.Value + 1, step)
end

-- amount is trauma in 0..1; small hits ~0.15, a final blow ~0.45.
function GameFeel.shake(amount)
	if reduced() then
		return
	end
	trauma = math.min(1, trauma + amount)
	bind()
end

-- Positive degrees widen the view briefly.
function GameFeel.punch(degrees, duration)
	if reduced() then
		return
	end
	punch, punchTime, punchDuration = degrees, os.clock(), duration or 0.5
	bind()
end

return GameFeel
