local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local React = require(ReplicatedStorage.Packages.React)
local ReactRoblox = require(ReplicatedStorage.Packages.ReactRoblox)
local App = require(ReplicatedStorage.ShopUI.App)
local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
local previous = playerGui:FindFirstChild("ShopReferenceUI")
if previous then
	previous:Destroy()
end
local gui = Instance.new("ScreenGui")
gui.Name = "ShopReferenceUI"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 10
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = playerGui
local root = ReactRoblox.createRoot(gui)
local controller = Instance.new("BindableEvent")
controller.Name = "UIController"
controller.Parent = script
root:render(React.createElement(App, { controller = controller }))
script.Destroying:Connect(function()
	root:unmount()
	gui:Destroy()
end)
