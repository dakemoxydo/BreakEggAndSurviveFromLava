-- Mounts the dev panel only after the server marks this player DevAccess; the server re-checks every command.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local player = Players.LocalPlayer
if not player:GetAttribute("DevAccess") then
	player:GetAttributeChangedSignal("DevAccess"):Wait()
end
local React = require(ReplicatedStorage.Packages.React)
local ReactRoblox = require(ReplicatedStorage.Packages.ReactRoblox)
local DevPanel = require(ReplicatedStorage:WaitForChild("ShopUI"):WaitForChild("DevPanel"))
local bootstrap = script.Parent:WaitForChild("ShopUIBootstrap", 10)
local controller = bootstrap and bootstrap:WaitForChild("UIController", 10)
local playerGui = player:WaitForChild("PlayerGui")
local previous = playerGui:FindFirstChild("DevPanel")
if previous then
	previous:Destroy()
end
local gui = Instance.new("ScreenGui")
gui.Name = "DevPanel"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.ScreenInsets = Enum.ScreenInsets.None
gui.DisplayOrder = 20
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = playerGui
local root = ReactRoblox.createRoot(gui)
root:render(React.createElement(DevPanel, { controller = controller }))
script.Destroying:Connect(function()
	root:unmount()
	gui:Destroy()
end)
