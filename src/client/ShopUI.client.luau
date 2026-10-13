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
-- Figma windows clone their templates on open; loading the art up front keeps the first open from popping in.
task.spawn(function()
	local templates = ReplicatedStorage:WaitForChild("UITemplates", 10)
	if templates then
		pcall(game:GetService("ContentProvider").PreloadAsync, game:GetService("ContentProvider"), { templates })
	end
end)
script.Destroying:Connect(function()
	root:unmount()
	gui:Destroy()
end)
