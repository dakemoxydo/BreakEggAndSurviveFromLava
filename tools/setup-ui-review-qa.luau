-- Client-only UI fixture. Canonical components; delayed UIAction substitute.
-- No server purchase, profile mutation, or fabricated items in the shipped UI.
assert(not _G.UIReviewQA,"UI review fixture already mounted")
local RS=game.ReplicatedStorage
local player=game.Players.LocalPlayer
local React=require(RS.Packages.React)
local ReactRoblox=require(RS.Packages.ReactRoblox)
local folder=Instance.new("Folder")
folder.Name="UIReviewQA"
folder.Parent=RS
for _,module in RS.ShopUI:GetChildren() do if module:IsA("ModuleScript") then module:Clone().Parent=folder end end
local qa={folder=folder,requests={},delay=1,success=true,coreBackpack=game:GetService("StarterGui"):GetCoreGuiEnabled(Enum.CoreGuiType.Backpack)}
_G.UIReviewQA=qa
function qa.invoke(name,payload)
    table.insert(qa.requests,{name=name,payload=payload})
    task.wait(qa.delay)
    local result={success=qa.success}
    if not qa.success then result.message="QA request rejected" end
    return result
end
local source=folder.App.Source
local replacementCount
source,replacementCount=string.gsub(source,"return remote:InvokeServer%(name,payload%)","return _G.UIReviewQA.invoke(name,payload)")
assert(replacementCount==1,"UIAction seam changed")
folder.App.Source=source
local gui=Instance.new("ScreenGui")
gui.Name="UIReviewQA"
gui.IgnoreGuiInset=true
gui.DisplayOrder=20
gui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling
gui.Parent=player.PlayerGui
qa.gui=gui
qa.original=player.PlayerGui.ShopReferenceUI
qa.original.Enabled=false
qa.controller=Instance.new("BindableEvent",folder)
qa.controller.Name="UIController"
qa.root=ReactRoblox.createRoot(gui)
qa.root:render(React.createElement(require(folder.App),{controller=qa.controller}))
function qa.cleanup()
    qa.root:unmount()
    qa.gui:Destroy()
    qa.folder:Destroy()
    qa.original.Enabled=true
    game:GetService("StarterGui"):SetCoreGuiEnabled(Enum.CoreGuiType.Backpack,qa.coreBackpack)
    _G.UIReviewQA=nil
end
return "Client UI fixture mounted"
