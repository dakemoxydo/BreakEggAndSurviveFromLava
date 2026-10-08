local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.React)
local Ripple = require(ReplicatedStorage.Packages.Ripple)
local UserInputService = game:GetService("UserInputService")
local Theme = require(script.Parent.Theme)
local Assets = require(script.Parent.Assets)
local IndexSurface = require(script.Parent.IndexSurface)
local e = React.createElement
local UI = {}
UI.InputEnabled=React.createContext(true)
UI.ReducedMotion=React.createContext(false)
local function corner(radius) return e("UICorner", {CornerRadius = UDim.new(0, radius)}) end
function UI.text(text, x, y, w, h, size, color, align, outline)
    return e("TextLabel", {
        BackgroundTransparency=1, Position=UDim2.fromOffset(x,y), Size=UDim2.fromOffset(w,h),
        Text=text, Font=Enum.Font.GothamBlack, TextSize=size, TextColor3=color or Theme.colors.white,
        TextXAlignment=align or Enum.TextXAlignment.Center, TextWrapped=true, ZIndex=8,
    }, {Outline=e("UIStroke", {Color=Theme.colors.ink, Thickness=outline or Theme.outline, StrokeSizingMode=Enum.StrokeSizingMode.FixedSize, LineJoinMode=Enum.LineJoinMode.Round})})
end
function UI.icon(key, x, y, w, h, color)
    local a = Assets[key]
    if not a then return nil end
    local properties={
        Name=key, BackgroundTransparency=1, Position=UDim2.fromOffset(x,y), Size=UDim2.fromOffset(w,h),
        Image=a.image, ImageRectOffset=a.offset or Vector2.zero, ImageRectSize=a.rect or Vector2.zero,
        ImageColor3=color or Color3.new(1,1,1), ScaleType=Enum.ScaleType.Fit, ZIndex=7,
    }
    if a.outlineExtension then
        local children={}
        for i=1,8 do
            local angle=i*math.pi/4
            local layer=table.clone(properties)
            layer.Position=UDim2.fromOffset(math.cos(angle)*a.outlineExtension,math.sin(angle)*a.outlineExtension)
            layer.Size=UDim2.fromScale(1,1)
            layer.ImageColor3=Theme.colors.ink
            layer.ZIndex=1
            children["Contour"..i]=e("ImageLabel",layer)
        end
        properties.Position=UDim2.fromOffset(0,0)
        properties.Size=UDim2.fromScale(1,1)
        properties.ZIndex=2
        children.Image=e("ImageLabel",properties)
        return e("Frame",{Name=key,BackgroundTransparency=1,Position=UDim2.fromOffset(x,y),Size=UDim2.fromOffset(w,h),ZIndex=7},children)
    end
    return e("ImageLabel",properties)
end
function UI.Surface(p)
    if p.variant=="utility" then
        return e("Frame",{Name=p.name,BackgroundColor3=p.selected and Theme.colors.muted or Theme.colors.ink,
            BackgroundTransparency=p.selected and .15 or .35,BorderSizePixel=0,
            Position=p.position or UDim2.fromOffset(p.x or 0,p.y or 0),Size=p.size or UDim2.fromOffset(p.w,p.h),ZIndex=p.z or 1}, {
            Corner=corner(Theme.radius),
            Content=e("Frame",{Name="Content",BackgroundTransparency=1,Size=UDim2.fromScale(1,1),ZIndex=6},p.children),
        })
    end
    return e(IndexSurface,p)
end
function UI.Button(p)
    local inputEnabled=React.useContext(UI.InputEnabled)
    local reduced=React.useContext(UI.ReducedMotion)
    local binding, update = React.useBinding(0)
    local states=React.useRef({hover=false,focus=false,pressed=false})
    local hoverScale=p.hoverScale or (p.w>240 and Theme.motion.denseHoverScale or Theme.motion.hoverScale)
    local motion = React.useMemo(function() return Ripple.createSpring(0,{frequency=Theme.motion.frequency,dampingRatio=1,precision=Theme.motion.precision,start=true}) end,{})
    -- Scale one centered visual subtree. Keep layout, child geometry and stroke
    -- thickness in design units; Roblox applies the shared scale exactly once.
    local scaleBinding=React.useMemo(function()
        return binding:map(function(t)
            return t<0 and 1+(1-Theme.motion.pressedScale)*t or 1+(hoverScale-1)*t
        end)
    end,{binding,hoverScale})
    React.useEffect(function()
        local disconnect=motion:onChange(update)
        return function() disconnect();motion:destroy() end
    end,{motion})
    local function state(key,value)
        if states.current[key]==value then return end
        states.current[key]=value
        local s=states.current
        local goal=(p.disabled or not inputEnabled) and 0 or (s.pressed and -1 or ((s.hover or s.focus) and 1 or 0))
        if reduced then motion:stop();motion:setGoal(goal);motion:setPosition(goal);motion:setVelocity(0);update(goal)
        elseif motion:getGoal()~=goal then motion:start();motion:setGoal(goal)end
    end
    React.useEffect(function()
        if p.disabled or not inputEnabled then
            states.current={hover=false,focus=false,pressed=false}
            motion:stop();motion:setGoal(0);motion:setPosition(0);motion:setVelocity(0);update(0)
        end
    end,{p.disabled,inputEnabled})
    React.useEffect(function()
        if reduced then
            local goal=motion:getGoal()
            motion:stop();motion:setPosition(goal);motion:setVelocity(0);update(goal)
        end
    end,{reduced})
    local function press(input,value)
        if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch or input.KeyCode==Enum.KeyCode.ButtonA then state("pressed",value) end
    end
    React.useEffect(function()
        local ended=UserInputService.InputEnded:Connect(function(input) press(input,false) end)
        local lost=UserInputService.WindowFocusReleased:Connect(function()
            state("pressed",false);state("hover",false);state("focus",false)
        end)
        return function() ended:Disconnect();lost:Disconnect() end
    end,{p.disabled,inputEnabled,reduced})
    local contents=React.useMemo(function()
        local children=table.clone(p.children or {})
        if p.label then
            local inset=math.min(10,p.w*.15)
            children.Label=UI.text(p.label,p.icon and 62 or inset,p.h<40 and 1 or 3,p.w-(p.icon and 74 or inset*2),p.h-(p.h<40 and 2 or 10),p.textSize or 30,p.textColor,nil,(p.variant=="index" or p.variant=="shop") and Theme.index.outline or nil)
        end
        if p.icon then
            local iconSize=math.min(48,p.w-16,p.h-14)
            children.Icon=UI.icon(p.icon,p.label and 8 or (p.w-iconSize)/2,(p.h-iconSize)/2,iconSize,iconSize)
        end
        return children
    end,{p.children,p.label,p.icon,p.w,p.h,p.textSize,p.textColor,p.variant})
    return e("TextButton", {
        Name=p.name or p.label,ref=p.buttonRef, Position=p.position or UDim2.fromOffset(p.x or 0,p.y or 0), Size=UDim2.fromOffset(p.w,p.h),
        Text="", BackgroundTransparency=1, AutoButtonColor=false, Selectable=inputEnabled and not p.disabled, Active=inputEnabled and not p.disabled, ZIndex=p.z or 1,
        [React.Event.Activated]=function() if inputEnabled and not p.disabled and p.onClick then p.onClick() end end,
        [React.Event.MouseEnter]=function() state("hover",true) end,
        [React.Event.MouseLeave]=function() state("pressed",false);state("hover",false) end,
        [React.Event.SelectionGained]=function() state("focus",true) end,
        [React.Event.SelectionLost]=function() state("pressed",false);state("focus",false) end,
        [React.Event.InputBegan]=function(_,input) if inputEnabled and not p.disabled then
            press(input,true)
            if p.onInput then p.onInput(input) end
        end end,
        [React.Event.InputEnded]=function(_,input) press(input,false) end,
    }, {
        Visual=e("Frame",{Name="Visual",AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(.5,.5),Size=UDim2.fromOffset(p.w,p.h),BackgroundTransparency=1}, {
            Scale=e("UIScale",{Scale=scaleBinding}),
            Surface=e(UI.Surface,{w=p.w,h=p.h,variant=p.variant,motion=binding,color=p.disabled and (p.disabledColor or Theme.colors.muted) or p.color,selected=p.selected,quiet=p.quiet,halftone=p.halftone,children=contents}),
        }),
    })
end
function UI.Transition(p)
    local inputEnabled=React.useContext(UI.InputEnabled)
    local progress,update=React.useBinding(0)
    local latest=React.useRef(p)
    latest.current=p
    local motion=React.useMemo(function()return Ripple.createSpring(0,{frequency=Theme.motion.transitionFrequency,dampingRatio=1,precision=Theme.motion.transitionPrecision,start=true})end,{})
    React.useEffect(function()
        local change=motion:onChange(update)
        local complete=motion:onComplete(function(value)
            if value==0 and not latest.current.visible and latest.current.onClosed then latest.current.onClosed() end
        end)
        return function()change();complete();motion:destroy()end
    end,{motion})
    React.useEffect(function()
        motion:setPosition(0);motion:setVelocity(0);update(0)
    end,{p.transitionKey})
    React.useEffect(function()
        local goal=p.visible and 1 or 0
        if p.reduced then
            motion:stop();motion:setGoal(goal);motion:setPosition(goal);motion:setVelocity(0);update(goal)
            if goal==0 then task.defer(function()if not latest.current.visible and latest.current.onClosed then latest.current.onClosed()end end)end
        else motion:start();motion:setGoal(goal) end
    end,{p.visible,p.transitionKey,p.reduced})
    return e("Frame",{Name=p.name or "Transition",Position=UDim2.fromOffset(p.x,p.y),Size=UDim2.fromOffset(p.w,p.h),BackgroundTransparency=1,ZIndex=p.z or 2}, {
        Group=e("CanvasGroup",{Name="AnimatedGroup",AnchorPoint=Vector2.new(.5,.5),Size=UDim2.fromOffset(p.w+32,p.h+32),BackgroundTransparency=1,
            Position=progress:map(function(t)return UDim2.fromOffset(p.w/2+(p.slide and (1-t)*(p.w+32) or 0),p.h/2+(p.slide and 0 or (1-t)*10))end),
            GroupTransparency=progress:map(function(t)return 1-math.clamp(t,0,1)end)}, {
            
            Content=e("Frame",{Name="Content",Position=UDim2.fromOffset(16,16),Size=UDim2.fromOffset(p.w,p.h),BackgroundTransparency=1},{
                Input=e(UI.InputEnabled.Provider,{value=p.visible and inputEnabled},p.children),
            }),
        }),
    })
end
function UI.progress(label, value, total, x,y,w,h,color,variant)
    local ratio=total>0 and math.clamp(value/total,0,1) or 0
    if variant=="index" then
        return e(UI.Surface,{variant="index",x=x,y=y,w=w,h=h,color=Theme.colors.body,quiet=true,children={
            Fill=ratio>0 and e("Frame",{Name="ProgressFill",Position=UDim2.fromOffset(7,7),Size=UDim2.fromOffset((w-14)*ratio,h-18),BackgroundColor3=color,BorderSizePixel=0,ZIndex=5},{
                Corner=corner(4),Gradient=e("UIGradient",{Rotation=90,Color=ColorSequence.new(color:Lerp(Theme.colors.white,.15),color:Lerp(Theme.colors.ink,.12))}),
                Studs=e("ImageLabel",{BackgroundTransparency=1,Size=UDim2.fromScale(1,1),Image=Theme.studs,ScaleType=Enum.ScaleType.Tile,TileSize=UDim2.fromScale(40/(w-14),40/(h-18)),ImageColor3=Theme.colors.ink,ImageTransparency=.88,ZIndex=5},{Corner=corner(4)}),
            }) or nil,
            Label=UI.text(label.." "..value.."/"..total,12,4,w-24,h-10,24,nil,nil,Theme.index.outline),
        }})
    end
    return e(UI.Surface,{x=x,y=y,w=w,h=h,color=Theme.colors.muted,quiet=true,children={
        Fill=e("Frame",{Position=UDim2.fromOffset(3,3),Size=UDim2.new(ratio,-6,1,-11),BackgroundColor3=color,BorderSizePixel=0,ZIndex=5},{Corner=corner(3)}),
        Label=UI.text(label.." "..value.."/"..total,12,4,w-24,h-10,30),
    }})
end
UI.Button=React.memo(UI.Button)
UI.Surface=React.memo(UI.Surface)
return UI
