local React=require(game.ReplicatedStorage.Packages.React)
local UI=require(script.Parent.UI)
local Theme=require(script.Parent.Theme)
local Preview=require(script.Parent.ModelPreview)
local e=React.createElement
local C=Theme.colors
local function Inventory(p)
    local query,setQuery=React.useState("")
    React.useEffect(function()setQuery("")end,{p.kind})
    local narrow=p.width<600
    local short=p.height<520
    local lane=narrow and 0 or 96
    local desktop=not narrow and not short
    local w=desktop and math.min(820,p.width*.5)+lane or math.min(1180,p.width-(narrow and 32 or short and 64 or 280))
    local x=desktop and (p.width-(w-lane))/2-lane or (p.width-w)/2
    local bottom=narrow and 236 or short and 138 or 132
    local top=narrow and 128 or short and 64 or p.height-bottom-math.min(400,p.height*.4)
    local h=math.max(120,p.height-top-bottom)
    local panelW=w-lane
    local stacked=panelW<640 and not short
    local header=short and 60 or stacked and 132 or 84
    local listH=math.max(60,h-header-12)
    local gap=16
    local cols=math.max(1,math.floor((panelW-40+gap)/132))
    local cell=(panelW-40-(cols-1)*gap)/cols
    local cardH=112
    local imageW=math.min(104,cell-20)
    local imageH=56
    local isPets=p.kind=="Pets"
    local isEggs=p.kind=="Eggs"
    local list=isPets and p.pets or p.eggs
    local shown={}
    for _,item in list do
        local name=item.name
        if string.find(string.lower(name),string.lower(query),1,true) then table.insert(shown,item)end
    end
    local active=0
    for _,pet in p.pets do if pet.equipped then active+=1 end end
    local function action(name,payload)if p.visible then p.onAction(name,payload or {})end end
    local cards={Layout=e("UIGridLayout",{CellSize=UDim2.fromOffset(cell,cardH),CellPadding=UDim2.fromOffset(gap,gap),SortOrder=Enum.SortOrder.LayoutOrder}),
        Padding=e("UIPadding",{PaddingLeft=UDim.new(0,12),PaddingTop=UDim.new(0,8),PaddingBottom=UDim.new(0,12)})}
    for i,item in shown do
        local name=item.name
        local selected=isPets and item.equipped or isEggs and item.held
        local content={Image=isPets and e(Preview,{kind=item.kind,weight=item.weight,x=(cell-imageW)/2,y=4,w=imageW,h=imageH}) or UI.icon(item.icon or "egg",(cell-imageW)/2,4,imageW,imageH),
            Name=UI.text(name,6,60,cell-12,28,18),
            Status=UI.text(isPets and "$"..item.income.."/s" or (item.held and "In hand" or "Hold"),6,88,cell-12,22,18,isPets and C.green or C.white)}
        cards["Item"..i]=e("Frame",{Name="InventoryItem"..i,BackgroundTransparency=1,LayoutOrder=i},{
            Card=e(UI.Button,{name="InventorySelect"..i,w=cell,h=cardH,variant="utility",selected=selected,hoverScale=1.025,disabled=p.busy,
                onClick=function()
                    if isPets then action(item.equipped and "UnequipPet" or "EquipPet",{pet=item.id or item.name})
                    elseif p.onHoldEgg then p.onHoldEgg(item.tool) end
                end,children=content})})
    end
    if #shown==0 and query~="" then
        cards.Empty=e("Frame",{Name="NoMatches",BackgroundTransparency=1,Size=UDim2.fromOffset(cell,cardH)}, {Text=UI.text("No matches",8,12,cell-16,48,22)})
    end
    local title=isPets and "All Pets" or "Eggs"
    local body={
        Title=UI.text(title,16,8,stacked and panelW-88 or panelW*.43,38,30,nil,Enum.TextXAlignment.Left),
        Count=not short and UI.text(isPets and (#p.pets.." Pets · "..active.."/"..p.capacity.." Active") or (#list.." Items"),16,47,stacked and panelW-32 or panelW*.48,28,20,nil,Enum.TextXAlignment.Left),
        Close=e(UI.Button,{name="CloseInventory",buttonRef=p.closeRef,label="X",x=panelW-62,y=12,w=44,h=44,color=C.red,textSize=26,onClick=p.onClose}),
        Search=e("TextBox",{Name="InventorySearch",Position=UDim2.fromOffset(stacked and 16 or panelW*.51,stacked and 84 or 20),Size=UDim2.fromOffset(stacked and panelW-32 or panelW*.49-84,40),BackgroundColor3=C.ink,BackgroundTransparency=.25,BorderSizePixel=0,Text=query,PlaceholderText="Search",PlaceholderColor3=C.white,TextColor3=C.white,TextSize=22,Font=Enum.Font.GothamBold,ClearTextOnFocus=false,TextXAlignment=Enum.TextXAlignment.Left,TextEditable=p.visible,
            [React.Change.Text]=function(object)setQuery(object.Text)end},{Corner=e("UICorner",{CornerRadius=UDim.new(0,Theme.radius)}),Padding=e("UIPadding",{PaddingLeft=UDim.new(0,10)})}),
        List=e("ScrollingFrame",{Name="InventoryScroll",Position=UDim2.fromOffset(8,header),Size=UDim2.fromOffset(panelW-16,listH),BackgroundTransparency=1,BorderSizePixel=0,CanvasSize=UDim2.fromOffset(0,math.max(0,math.ceil(#shown/cols)*(cardH+gap)-gap)+20),ScrollBarThickness=5,ScrollBarImageColor3=C.white,ScrollingDirection=Enum.ScrollingDirection.Y,Active=p.visible},cards),
    }
    local children={Panel=e("Frame",{Name="InventoryPanel",Position=UDim2.fromOffset(lane,0),Size=UDim2.fromOffset(panelW,h),BackgroundColor3=C.ink,BackgroundTransparency=.25,BorderSizePixel=0,Active=true},{Corner=e("UICorner",{CornerRadius=UDim.new(0,Theme.radius)}),Content=e("Frame",{BackgroundTransparency=1,Size=UDim2.fromScale(1,1)},body)})}
    for i,kind in {"Pets","Eggs"} do
        children[kind]=e(UI.Button,{name="InventoryTab"..kind,label=narrow and kind or nil,x=narrow and (i-1)*((w+4)/2) or 0,y=narrow and -56 or (i-1)*100,w=narrow and (w-8)/2 or 76,h=narrow and 44 or 80,variant="utility",selected=p.kind==kind,textSize=20,onClick=function()p.onTab(kind)end,
            children=not narrow and {Icon=UI.icon(kind=="Pets" and "pets" or "egg",14,4,48,40),Label=UI.text(kind,4,47,68,26,20)} or nil})
    end
    local tabSpace=narrow and 56 or 0
    return e(UI.Transition,{name="InventoryTransition",x=x,y=top-tabSpace,w=w,h=h+tabSpace,visible=p.visible,transitionKey="Inventory",reduced=p.reduced,onClosed=p.onClosed,z=32,
        children={Layout=e("Frame",{BackgroundTransparency=1,Position=UDim2.fromOffset(0,tabSpace),Size=UDim2.fromOffset(w,h)},children)}})
end
return React.memo(Inventory)
