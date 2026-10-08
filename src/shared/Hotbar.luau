local RS=game:GetService("ReplicatedStorage")
local Players=game:GetService("Players")
local UIS=game:GetService("UserInputService")
local React=require(RS.Packages.React)
local Ripple=require(RS.Packages.Ripple)
local UI=require(script.Parent.UI)
local Theme=require(script.Parent.Theme)
local e=React.createElement
local player=Players.LocalPlayer
local Hotbar={}
function Hotbar.icon(tool,x,y,w,h)
    local key=tool:GetAttribute("UIIcon") or ({["Secret Pickaxe"]="pickaxe",["Lava Bat"]="lavaBat"})[tool.Name]
        or (tool:GetAttribute("PlacementKind")=="Egg" and "egg" or tool:GetAttribute("PlacementKind")=="Pet" and "chicken")
    if key then return UI.icon(key,x,y,w,h) end
    if tool.TextureId~="" then return e("ImageLabel",{BackgroundTransparency=1,Position=UDim2.fromOffset(x,y),Size=UDim2.fromOffset(w,h),Image=tool.TextureId,ScaleType=Enum.ScaleType.Fit,ZIndex=7}) end
    return nil
end
function Hotbar.Bar(p)
    local refs=React.useRef({})
    local dragging=React.useRef(nil)
    local suppressClick=React.useRef(false)
    local latest=React.useRef(p)
    latest.current=p
    local binding,update=React.useBinding(0)
    local motion=React.useMemo(function()return Ripple.createSpring(0,{frequency=Theme.motion.transitionFrequency,dampingRatio=1,precision=Theme.motion.transitionPrecision,start=true})end,{})
    React.useEffect(function()
        local disconnect=motion:onChange(update)
        return function()disconnect();motion:destroy()end
    end,{motion})
    React.useEffect(function()
        local goal=p.open and 1 or 0
        if p.reduced then motion:stop();motion:setGoal(goal);motion:setPosition(goal);motion:setVelocity(0);update(goal)
        else motion:start();motion:setGoal(goal)end
        dragging.current=nil
    end,{p.open,p.reduced})
    React.useEffect(function()
        local connection=UIS.InputEnded:Connect(function(input)
            if input.UserInputType~=Enum.UserInputType.MouseButton1 and input.UserInputType~=Enum.UserInputType.Touch then return end
            local drag=dragging.current
            dragging.current=nil
            if not drag or not latest.current.open then return end
            local at=Vector2.new(input.Position.X,input.Position.Y)
            if (at-drag.start).Magnitude<12 then return end
            suppressClick.current=true
            task.defer(function()suppressClick.current=false end)
            for i,ref in refs.current do
                local object=ref.current
                if object and at.X>=object.AbsolutePosition.X and at.Y>=object.AbsolutePosition.Y and at.X<=object.AbsolutePosition.X+object.AbsoluteSize.X and at.Y<=object.AbsolutePosition.Y+object.AbsoluteSize.Y then
                    latest.current.assign(drag.tool,i);return
                end
            end
        end)
        return function()connection:Disconnect()end
    end,{})
    local narrow=p.width<600
    local columns=narrow and 5 or 10
    local available=(narrow or p.height<520) and p.width-32 or math.min(820,p.width*.5)
    local gap=8
    local cell=math.min(108,(available-(columns-1)*gap)/columns)
    local h=92
    local fullW=columns*(cell+gap)-gap
    local fullH=narrow and h*2+12 or h
    local closed={}
    for i=1,10 do if p.slots[i] then table.insert(closed,i) end end
    local closedColumns=math.min(columns,#closed)
    local closedW=math.max(0,closedColumns*(cell+gap)-gap)
    local content={}
    for i=1,10 do
        local tool=p.slots[i]
        local rank=table.find(closed,i)
        if p.open or tool then
            if not refs.current[i] then refs.current[i]=React.createRef() end
            local col=(i-1)%columns;local row=math.floor((i-1)/columns)
            local closedCol=rank and (rank-1)%columns or col
            local closedRow=rank and math.floor((rank-1)/columns) or row
            local selected=tool and tool.Parent==player.Character
            local children={Number=UI.text(tostring(i%10),5,2,28,30,25,nil,Enum.TextXAlignment.Left)}
            if tool then
                local small=cell<90 or p.height<520
                children.Image=Hotbar.icon(tool,10,6,cell-20,small and 38 or 60)
                local label=small and tool.Name=="Secret Pickaxe" and "Pickaxe" or tool.Name
                children.Label=UI.text(label,small and 2 or 5,small and 46 or 70,cell-(small and 4 or 10),small and 40 or 36,small and 16 or 18)
            end
            content["Slot"..i]=e(UI.Button,{name="HotbarSlot"..i,buttonRef=refs.current[i],w=cell,h=h,variant="utility",selected=selected,hoverScale=1.025,
                position=binding:map(function(t)
                    local cx=(p.width-closedW)/2+closedCol*(cell+gap)
                    local ox=(p.width-fullW)/2+col*(cell+gap)
                    local cy=p.height-20-h-closedRow*(h+12)
                    local oy=p.height-20-fullH+row*(h+12)
                    if not tool then return UDim2.fromOffset(ox,oy)end
                    return UDim2.fromOffset(cx+(ox-cx)*t,cy+(oy-cy)*t)
                end),
                onClick=function()
                    if suppressClick.current then return end
                    local drag=dragging.current
                    if drag and drag.clickStart and (UIS:GetMouseLocation()-drag.clickStart).Magnitude>=12 then return end
                    if p.open and p.selectedTool then p.assign(p.selectedTool,i);p.onAssigned() else p.equip(tool)end
                end,
                onInput=function(input)
                    if p.open and tool and (input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch) then
                        dragging.current={tool=tool,start=Vector2.new(input.Position.X,input.Position.Y),clickStart=input.UserInputType==Enum.UserInputType.MouseButton1 and UIS:GetMouseLocation() or nil}
                    end
                end,children=children})
        end
    end
    return e("Frame",{Name="CustomHotbar",BackgroundTransparency=1,Size=UDim2.fromOffset(p.width,p.height),ZIndex=35},content)
end
Hotbar.Bar=React.memo(Hotbar.Bar)
return Hotbar
