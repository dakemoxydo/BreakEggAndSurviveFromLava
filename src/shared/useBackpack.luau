local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")
local UIS = game:GetService("UserInputService")
local React = require(game.ReplicatedStorage.Packages.React)
local player = Players.LocalPlayer

-- Slots retain identity when Roblox moves a Tool between Backpack and Character.
return function(onToggle, canEquip)
    local snapshot, setSnapshot = React.useState({slots={}, tools={},held=nil,revision=0})
    local state = React.useRef(snapshot)
    local dirty = React.useRef(false)
    local latest = React.useRef({})
    latest.current = {toggle=onToggle, canEquip=canEquip}
    local function refresh()
        local tools, present = {}, {}
        for _, container in {player:FindFirstChildOfClass("Backpack"), player.Character} do
            if container then for _, tool in container:GetChildren() do
                if tool:IsA("Tool") then table.insert(tools, tool); present[tool]=true end
            end end
        end
        local ordered,seen={},{}
        for _,tool in state.current.tools do if present[tool] then table.insert(ordered,tool);seen[tool]=true end end
        for _,tool in tools do if not seen[tool] then table.insert(ordered,tool);seen[tool]=true end end
        tools=ordered
        local slots = table.clone(state.current.slots)
        local assigned = {}
        for i=1,10 do
            if slots[i] and not present[slots[i]] then slots[i]=nil end
            if slots[i] then assigned[slots[i]]=true end
        end
        for _, tool in tools do if not assigned[tool] then
            for i=1,10 do if not slots[i] then slots[i]=tool;assigned[tool]=true;break end end
        end end
        local previous=state.current
        local held=player.Character and player.Character:FindFirstChildOfClass("Tool")
        local changed=dirty.current or held~=previous.held or #tools~=#previous.tools
        for i,tool in tools do if previous.tools[i]~=tool then changed=true;break end end
        for i=1,10 do if previous.slots[i]~=slots[i] then changed=true;break end end
        if not changed then return end
        if #tools==#previous.tools then
            local same=true
            for i,tool in tools do if previous.tools[i]~=tool then same=false;break end end
            if same then tools=previous.tools end
        end
        local revision=previous.revision+(dirty.current and 1 or 0)
        dirty.current=false
        state.current={slots=slots, tools=tools,held=held,revision=revision}
        setSnapshot(state.current)
    end
    local equip=React.useCallback(function(tool)
        if not latest.current.canEquip or not tool or not tool.Parent then return end
        local character=player.Character
        local humanoid=character and character:FindFirstChildOfClass("Humanoid")
        if not humanoid or humanoid.Health<=0 then return end
        if tool.Parent==character then humanoid:UnequipTools() else humanoid:EquipTool(tool) end
    end,{})
    local assign=React.useCallback(function(tool, index)
        if not tool or not tool.Parent or index<1 or index>10 or state.current.slots[index]==tool then return end
        local slots=table.clone(state.current.slots)
        local previous
        for i=1,10 do if slots[i]==tool then previous=i; break end end
        if previous then slots[previous]=slots[index] end
        slots[index]=tool
        state.current={slots=slots,tools=state.current.tools,held=state.current.held,revision=state.current.revision}
        setSnapshot(state.current)
    end,{})
    React.useEffect(function()
        local connections, containerConnections, toolConnections = {}, {}, {}
        local active, queued=true, false
        local function schedule()
            if not active or queued then return end
            queued=true
            task.defer(function() queued=false; if active then refresh() end end)
        end
        local function watchTool(tool)
            if not tool:IsA("Tool") or toolConnections[tool] then return end
            local function displayChanged()dirty.current=true;schedule()end
            toolConnections[tool]={
                tool:GetPropertyChangedSignal("Name"):Connect(displayChanged),
                tool:GetPropertyChangedSignal("TextureId"):Connect(displayChanged),
                tool:GetAttributeChangedSignal("UIIcon"):Connect(displayChanged),
                tool:GetAttributeChangedSignal("PlacementKind"):Connect(displayChanged),
                tool:GetAttributeChangedSignal("PetWeight"):Connect(displayChanged),
            }
        end
        local function removed(tool)
            if not tool:IsA("Tool") then return end
            schedule()
            task.defer(function()
                if not active or tool.Parent==player.Character or tool.Parent==player:FindFirstChildOfClass("Backpack") then return end
                for _,c in toolConnections[tool] or {} do c:Disconnect()end
                toolConnections[tool]=nil
            end)
        end
        local function unwatchContainer(container)
            for _,c in containerConnections[container] or {} do c:Disconnect()end
            containerConnections[container]=nil
            for _,tool in container:GetChildren() do
                for _,c in toolConnections[tool] or {} do c:Disconnect()end
                toolConnections[tool]=nil
            end
            schedule()
        end
        local function watchContainer(container)
            if not container or containerConnections[container] then return end
            containerConnections[container]={
                container.ChildAdded:Connect(function(tool)if tool:IsA("Tool") then watchTool(tool);schedule()end end),
                container.ChildRemoved:Connect(removed),
            }
            for _,tool in container:GetChildren() do watchTool(tool)end
            schedule()
        end
        table.insert(connections,player.CharacterAdded:Connect(watchContainer))
        table.insert(connections,player.CharacterRemoving:Connect(unwatchContainer))
        table.insert(connections,player.ChildAdded:Connect(function(child)if child:IsA("Backpack") then watchContainer(child)end end))
        table.insert(connections,player.ChildRemoved:Connect(function(child)if child:IsA("Backpack") then unwatchContainer(child)end end))
        local keys={Enum.KeyCode.One,Enum.KeyCode.Two,Enum.KeyCode.Three,Enum.KeyCode.Four,Enum.KeyCode.Five,Enum.KeyCode.Six,Enum.KeyCode.Seven,Enum.KeyCode.Eight,Enum.KeyCode.Nine,Enum.KeyCode.Zero}
        table.insert(connections,UIS.InputBegan:Connect(function(input,processed)
            if processed or UIS:GetFocusedTextBox() then return end
            if input.KeyCode==Enum.KeyCode.Backquote then latest.current.toggle();return end
            for i,key in keys do if input.KeyCode==key then equip(state.current.slots[i]);return end end
            if input.KeyCode==Enum.KeyCode.ButtonL1 or input.KeyCode==Enum.KeyCode.ButtonR1 then
                local held=0
                for i=1,10 do if state.current.slots[i] and state.current.slots[i].Parent==player.Character then held=i end end
                local direction=input.KeyCode==Enum.KeyCode.ButtonR1 and 1 or -1
                for step=1,10 do
                    local index=(held-1+step*direction)%10+1
                    if state.current.slots[index] then equip(state.current.slots[index]);break end
                end
            end
        end))
        task.spawn(function()
            for _=1,20 do
                if not active then return end
                local ok=pcall(function()StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack,false)end)
                if ok then return end
                task.wait(.25)
            end
        end)
        watchContainer(player:FindFirstChildOfClass("Backpack"))
        watchContainer(player.Character)
        return function()
            active=false
            for _,c in connections do c:Disconnect()end
            for _,map in {containerConnections,toolConnections} do for _,list in map do for _,c in list do c:Disconnect()end end end
            pcall(function()StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack,true)end)
        end
    end,{})
    return snapshot,equip,assign
end
