-- HUD timer for the lava cycle: countdown to the wave, then the wave's own phases.
-- Phases come from the same LavaWaveAt + GameConfig.LavaWave the client uses to draw the lava.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local React = require(ReplicatedStorage.Packages.React)
local Game = require(ReplicatedStorage.GameConfig)
local Theme = require(script.Parent.Theme)
local UI = require(script.Parent.UI)
local e = React.createElement
local C = Theme.colors
local ORANGE = Color3.fromRGB(255, 120, 40)

local function read()
	local wave = Game.LavaWave
	local started = workspace:GetAttribute("LavaWaveAt")
	if workspace:GetAttribute("LavaActive") and started then
		local t = workspace:GetServerTimeNow() - started
		if t < wave.rise then
			return "RISING", wave.rise - t, ORANGE
		elseif t < wave.rise + wave.hold then
			return "LAVA!", wave.rise + wave.hold - t, C.red
		elseif t < wave.rise + wave.hold + wave.fall then
			return "FALLING", wave.rise + wave.hold + wave.fall - t, C.gold
		end
	end
	local left = Players.LocalPlayer:GetAttribute("EventRemaining") or 0
	return "LAVA IN", left, left <= 5 and C.red or C.green
end

local function LavaTimer(p)
	local view, setView = React.useState(function()
		local phase, left, color = read()
		return { phase = phase, seconds = math.ceil(left), color = color }
	end)
	React.useEffect(function()
		local elapsed = 0
		local connection = RunService.Heartbeat:Connect(function(dt)
			elapsed += dt
			if elapsed < 0.1 then
				return
			end
			elapsed = 0
			local phase, left, color = read()
			local seconds = math.max(0, math.ceil(left))
			setView(function(old)
				if old.phase == phase and old.seconds == seconds and old.color == color then
					return old
				end
				return { phase = phase, seconds = seconds, color = color }
			end)
		end)
		return function()
			connection:Disconnect()
		end
	end, {})
	return e(UI.Surface, {
		name = "LavaTimer",
		variant = "utility",
		x = p.x,
		y = p.y,
		w = 236,
		h = 84,
		z = 3,
		children = {
			Accent = e("Frame", {
				Name = "Accent",
				Position = UDim2.fromOffset(12, 14),
				Size = UDim2.fromOffset(8, 56),
				BackgroundColor3 = view.color,
				BorderSizePixel = 0,
				ZIndex = 7,
			}, { Corner = e("UICorner", { CornerRadius = UDim.new(0.5, 0) }) }),
			Phase = UI.text(view.phase, 32, 8, 192, 26, 22, view.color, Enum.TextXAlignment.Left),
			Time = UI.text(
				string.format("%d:%02d", math.floor(view.seconds / 60), view.seconds % 60),
				32,
				32,
				192,
				46,
				40,
				C.white,
				Enum.TextXAlignment.Left
			),
		},
	})
end

return React.memo(LavaTimer)
