local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ContextActionService = game:GetService("ContextActionService")
local UserInputService = game:GetService("UserInputService")
local player = Players.LocalPlayer
local exit = ReplicatedStorage:WaitForChild("ExitTreadmill")
local lastRequest = 0
local function requestExit()
	if player:GetAttribute("OnTreadmill") and os.clock() - lastRequest > 0.25 then
		lastRequest = os.clock()
		exit:FireServer()
	end
end
local function jumpAction(_, state)
	if state == Enum.UserInputState.Begin then
		requestExit()
	end
	return Enum.ContextActionResult.Sink
end
local function update()
	if player:GetAttribute("OnTreadmill") then
		ContextActionService:BindActionAtPriority("ExitTreadmill", jumpAction, false, 3000, Enum.KeyCode.Space)
	else
		ContextActionService:UnbindAction("ExitTreadmill")
	end
end
player:GetAttributeChangedSignal("OnTreadmill"):Connect(update)
UserInputService.JumpRequest:Connect(function()
	if UserInputService:GetLastInputType() == Enum.UserInputType.Touch then
		requestExit()
	end
end)
update()
