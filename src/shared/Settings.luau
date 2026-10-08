local React=require(game.ReplicatedStorage.Packages.React)
local UIS=game:GetService("UserInputService")
local UI=require(script.Parent.UI)
local C=require(script.Parent.Theme).colors
local e=React.createElement

local function Volume(p)
    local ref=React.useRef(nil)
    local pointer=React.useRef(nil)
    local value=math.clamp(p.value,0,1)
    local function setVolume(nextValue)
        p.onAction("SetSetting",{setting=p.setting,value=math.clamp(nextValue,0,1)})
    end
    return e(UI.Button,{name=p.setting,x=p.x,y=p.y,w=p.w,h=48,variant="utility",buttonRef=ref,
        onInput=function(input)
            if input.UserInputType==Enum.UserInputType.Touch then pointer.current=input.Position.X end
            if input.KeyCode==Enum.KeyCode.Left or input.KeyCode==Enum.KeyCode.DPadLeft then setVolume(value-.1) end
            if input.KeyCode==Enum.KeyCode.Right or input.KeyCode==Enum.KeyCode.DPadRight then setVolume(value+.1) end
        end,
        onClick=function()
            if not ref.current then return end
            local x=pointer.current or UIS:GetMouseLocation().X
            pointer.current=nil
            setVolume((x-ref.current.AbsolutePosition.X)/ref.current.AbsoluteSize.X)
        end,
        children={
            Track=e(UI.Surface,{x=12,y=18,w=p.w-24,h=12,variant="utility"}),
            Fill=e(UI.Surface,{x=12,y=18,w=math.max(4,(p.w-24)*value),h=12,color=C.gold}),
            Handle=e(UI.Surface,{x=12+(p.w-52)*value,y=10,w=28,h=28,color=C.gold,z=10}),
        },
    })
end

local function Settings(p)
    local narrow=p.width<520
    local rowW=p.width-48
    local rows={
        Padding=e("UIPadding",{PaddingLeft=UDim.new(0,20),PaddingRight=UDim.new(0,20),PaddingTop=UDim.new(0,12),PaddingBottom=UDim.new(0,20)}),
        Layout=e("UIListLayout",{Padding=UDim.new(0,20),SortOrder=Enum.SortOrder.LayoutOrder}),
    }
    for i,item in {{"Music","Background music","MusicVolume"},{"SFX","Sound effects","SFXVolume"}} do
        local value=p.data[item[3]] or 1
        rows[item[3]]=e("Frame",{Name=item[3].."Row",BackgroundTransparency=1,Size=UDim2.fromOffset(rowW,narrow and 148 or 100),LayoutOrder=i},{
            Card=e(UI.Surface,{w=rowW,h=narrow and 148 or 100,color=C.muted,quiet=true,children={
                Name=UI.text(item[1],16,8,narrow and rowW-90 or rowW*.43,42,30,nil,Enum.TextXAlignment.Left),
                Description=UI.text(item[2],16,52,narrow and rowW-32 or rowW*.43,30,20,nil,Enum.TextXAlignment.Left),
                Percent=UI.text(math.floor(value*100).."%",rowW-78,10,62,32,22,C.gold),
                Slider=e(Volume,{setting=item[3],value=value,x=narrow and 16 or rowW*.48,y=narrow and 88 or 44,w=narrow and rowW-32 or rowW*.48-16,onAction=p.onAction}),
            }}),
        })
    end
    for i,item in {{"Other players' pets","ViewOthersPets"},{"My pets","ViewMyPets"},{"My eggs","ViewMyEggs"}} do
        local enabled=p.data[item[2]]~=false
        rows[item[2]]=e("Frame",{Name=item[2].."Row",BackgroundTransparency=1,Size=UDim2.fromOffset(rowW,narrow and 124 or 84),LayoutOrder=i+2},{
            Card=e(UI.Surface,{w=rowW,h=narrow and 124 or 84,color=C.muted,quiet=true,children={
                Name=UI.text(item[1],16,8,narrow and rowW-32 or rowW-166,52,narrow and 24 or 30,nil,Enum.TextXAlignment.Left),
                Toggle=e(UI.Button,{name=item[2],label=enabled and "ON" or "OFF",x=rowW-136,y=narrow and 64 or 18,w=120,h=48,color=enabled and C.green or C.red,textSize=24,
                    onClick=function()p.onAction("SetSetting",{setting=item[2],value=not enabled})end}),
            }}),
        })
    end
    return e("ScrollingFrame",{Name="SettingsScroll",BackgroundTransparency=1,BorderSizePixel=0,
        Position=UDim2.fromOffset(4,p.headerH+12),Size=UDim2.fromOffset(p.width-8,p.height-p.headerH-32),
        CanvasSize=UDim2.fromOffset(0,(narrow and 148 or 100)*2+(narrow and 124 or 84)*3+112),
        ScrollBarThickness=5,ScrollBarImageColor3=C.white,ScrollingDirection=Enum.ScrollingDirection.Y,Active=true},rows)
end
return React.memo(Settings)
