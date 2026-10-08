local RS=game:GetService("ReplicatedStorage")
local React=require(RS.Packages.React)
local UI=require(script.Parent.UI)
local Theme=require(script.Parent.Theme)
local Config=require(script.Parent.Config)
local GrowingEggs=require(script.Parent.GrowingEggs)
local e=React.createElement
local C=Theme.colors
local function amount(value)
    for _,unit in {{1e12,"T"},{1e9,"B"},{1e6,"M"},{1e3,"K"}} do
        if value>=unit[1] then return string.format("%.1f",value/unit[1]):gsub("%.0$","")..unit[2] end
    end
    return tostring(math.floor(value))
end
local function Sidebar(p)
    if p.kind=="Eggs" then return e(GrowingEggs,p) end
    local short=p.height<650
    local compact=p.compact and (p.width<600 or not short)
    local lane=compact and 60 or 84
    local panelW=math.min(400,p.width-lane-32)
    local stacked=compact
    local headerH=stacked and 112 or 64
    local isPets=p.kind=="Pets"
    local footerSpace=isPets and 84 or 0
    local panelH=compact and math.min(430,p.height-(short and 64 or 180)-(short and 16 or 105)-footerSpace-32) or math.min(408,p.height-footerSpace-112)
    panelH=math.max(headerH+64,panelH)
    local top=short and 64 or (compact and 180 or math.max(96,(p.height-panelH)/2-16))
    local equipped=0
    for _,pet in p.pets do if pet.equipped then equipped+=1 end end
    local function act(name,payload) if p.onAction then p.onAction(name,payload or {}) end end
    local function button(label,x,y,w,h,color,callback,name,size)
        return e(UI.Button,{label=label,x=x,y=y,w=w,h=h,color=color,onClick=callback,name=name,textSize=size or 28,disabled=p.busy})
    end
    local header={}
    local title=isPets and tostring(equipped).."/"..p.capacity.." Active" or "Growing Eggs"
    header.Title=UI.text(title,16,stacked and 4 or 6,stacked and panelW-32 or panelW-212,stacked and 43 or 48,24,nil,Enum.TextXAlignment.Left)
    header.Action=button(isPets and "+1 Slot [$"..amount(p.slotCost or Config.PetSlotCost).."]" or "Grow All $"..amount(p.growCost or 20),
        stacked and 14 or panelW-184,stacked and 58 or 10,
        stacked and panelW-28 or 168,44,isPets and C.green or C.gold,
        function()act(isPets and "AddPetSlot" or "GrowAllEggs")end,isPets and "AddPetSlot" or "GrowAllEggs",compact and 23 or (isPets and 20 or 22))
    local rowW=panelW-40
    local rowH=compact and 164 or 84
    local rows={
        Padding=e("UIPadding",{PaddingTop=UDim.new(0,12),PaddingBottom=UDim.new(0,16),PaddingLeft=UDim.new(0,16),PaddingRight=UDim.new(0,16)}),
        Layout=e("UIListLayout",{Padding=UDim.new(0,16),SortOrder=Enum.SortOrder.LayoutOrder}),
    }
    if isPets then
        for i,pet in p.pets do
            local textX=compact and 94 or 86
            local textW=compact and rowW-106 or rowW-222
            local contents={
                Image=UI.icon(pet.icon,10,10,compact and 74 or 64,compact and 77 or 64),
                Name=UI.text(pet.name,textX,6,textW,compact and 46 or 44,22,C.white,Enum.TextXAlignment.Left),
                Income=UI.text("$"..amount(pet.income).."/s",textX,compact and 61 or 51,textW,26,22,C.green,Enum.TextXAlignment.Left),
                Action=button(pet.equipped and "Unequip" or "Equip",compact and 12 or rowW-124,compact and 104 or 18,
                    compact and rowW-24 or 112,48,pet.equipped and C.red or C.green,
                    function()act(pet.equipped and "UnequipPet" or "EquipPet",{pet=pet.id or pet.name})end,"PetAction"..i,compact and 25 or 22),
            }
            rows["Pet"..i]=e("Frame",{Name="InventoryPet"..i,Size=UDim2.fromOffset(rowW,rowH),BackgroundTransparency=1,LayoutOrder=i}, {
                Card=e(UI.Surface,{name="PetRow",w=rowW,h=rowH,color=C.gold,children=contents}),
            })
        end
    else
        for i,egg in p.eggs do
            rows["Egg"..i]=e("Frame",{Name="GrowingEgg"..i,Size=UDim2.fromOffset(rowW,rowH),BackgroundTransparency=1,LayoutOrder=i}, {
                Card=e(UI.Surface,{w=rowW,h=rowH,color=C.gold,children={
                    Image=UI.icon(egg.icon or "egg",10,12,74,78),
                    Name=UI.text(egg.name or "Egg",94,8,rowW-108,42,24,nil,Enum.TextXAlignment.Left),
                    Status=UI.text(egg.status or "Growing",94,55,rowW-108,32,22,C.green,Enum.TextXAlignment.Left),
                }}),
            })
        end
    end
    local contents={
        Header=e(UI.Surface,{w=panelW,h=headerH,color=C.gold,children=header}),
        List=e("ScrollingFrame",{Name=isPets and "PetsInventoryScroll" or "GrowingEggsScroll",BackgroundTransparency=1,BorderSizePixel=0,
            Position=UDim2.fromOffset(4,headerH+12),Size=UDim2.fromOffset(panelW-8,panelH-headerH-26),
            CanvasSize=UDim2.fromOffset(0,math.max(100,(isPets and #p.pets or #p.eggs)*(rowH+16)-16)+28),
            ScrollBarThickness=5,ScrollBarImageColor3=C.white,ScrollingDirection=Enum.ScrollingDirection.Y,Active=true},rows),
    }
    local children={
        Panel=e(UI.Surface,{name=isPets and "PetsSidebar" or "EggsSidebar",x=lane,y=0,w=panelW,h=panelH,color=C.body,quiet=true,active=true,children=contents}),
        Collapse=e(UI.Button,{name="CollapseSidebar",buttonRef=p.closeRef,label=">",x=compact and 2 or 8,y=math.floor((panelH-64)/2),
            w=compact and 44 or 64,h=64,color=C.red,textSize=compact and 36 or 48,onClick=p.onClose}),
    }
    if isPets then children.EquipBest=button("Equip Best",lane+panelW-(compact and panelW-32 or 280),panelH+20,compact and panelW-32 or 264,56,C.green,function()act("EquipBestPets")end,"EquipBestPets",30) end
    return e(UI.Transition,{name="RightSidebar",x=p.width-panelW-lane-20,y=top,
        w=panelW+lane,h=panelH+footerSpace,slide=true,visible=p.visible,transitionKey=p.kind,reduced=p.reduced,onClosed=p.onClosed,z=20,children=children})
end
return Sidebar
