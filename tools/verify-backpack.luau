-- Run through Studio MCP in Edit. Exercises canonical server functions with
-- isolated ownership, character and world fixtures; never reads player profiles.
local server=game.ServerScriptService
local source=server.PetGameplay.Source
local stop=assert(string.find(source,"remote.OnServerInvoke =",1,true))
source=string.sub(source,1,stop-1)
-- Each stub must match exactly once; formatting changes in Pets.server.luau must fail loudly.
local function stub(pattern,replacement)local count;source,count=string.gsub(source,pattern,replacement);assert(count==1,"verify-backpack: pattern not found: "..pattern)end
stub("local DataService = require%(script.Parent.PlayerData.Service%)","local DataService = __data")
stub("local World = require%(script.Parent.PetWorld%)","local World = __world")
stub("local Adventure = require%(script.Parent.Adventure%)","local Adventure = __adventure")
stub("local MergeSelection = require%(script.Parent.MergeSelection%)","local MergeSelection = __merge")
stub('assert%(not RS:FindFirstChild%(remote.Name%), "UIAction already exists"%)',"")
stub("remote.Parent = RS","")
source..="\nreturn {reconcile=reconcileTools,perform=perform,give=giveTool,sync=sync}"
local fixture=Instance.new("Folder")
fixture.Name="BackpackQA"
fixture.Parent=workspace
local selectionClone=server.MergeSelection:Clone()
selectionClone.Parent=fixture
local function tool(kind,data)
    local result=Instance.new("Tool")
    result.Name=data.kind
    result.RequiresHandle=false
    result:SetAttribute("PlacementKind",kind)
    result:SetAttribute("PetKind",data.kind)
    return result
end
local function model()local result=Instance.new("Model");Instance.new("Part",result).Anchored=true;return result end
local environment=setmetatable({script=server.PetGameplay,
    __merge=require(selectionClone),
    __data={IsActive=function()return true end,Commit=function()end,SessionEnded={Connect=function()end}},
    __world={tool=tool,pet=model,egg=model,label=function()return {} end},
    __adventure={hasCargo=function()return false end}}, {__index=getfenv()})
local compiled=assert(loadstring(source))
setfenv(compiled,environment)
local api=compiled()
local player={UserId=991,attributes={}}
function player:SetAttribute(key,value)self.attributes[key]=value end
function player:GetAttribute(key)return self.attributes[key]end
function player:FindFirstChildOfClass(kind)if kind=="Backpack" then return self.Backpack end end
local function character()
    player.Character=Instance.new("Model",fixture)
    Instance.new("Humanoid",player.Character)
    local root=Instance.new("Part",player.Character)
    root.Name="HumanoidRootPart";root.Anchored=true;root.Position=Vector3.zero
    player.Backpack=Instance.new("Backpack",fixture)
end
character()
local base=Instance.new("Model",fixture)
base:SetAttribute("OwnerUserId",player.UserId)
local anchor=Instance.new("Part",base);anchor.Name="BaseAnchor";anchor.Anchored=true;anchor.CFrame=CFrame.new()
local state={ready=true,base=base,floor=0,contents=Instance.new("Folder",base),pets={},eggs={},backpackEggs={},capacity=8,
    cash=100,offline=0,discoveries={},ownedPickaxes={1},ownedTrails={1},pickaxe=1,trail=1,penLevel=1,treadmillLevel=1,satchelLevel=1,playtime=0,rewardClaimed=false}
local function find(id)
    for _,container in {player.Backpack,player.Character} do for _,item in container:GetChildren() do
        if item:IsA("Tool") and item:GetAttribute("InventoryId")==id then return item end
    end end
end
local function count()
    local n=0
    for _,container in {player.Backpack,player.Character} do for _,item in container:GetChildren() do if item:IsA("Tool") then n+=1 end end end
    return n
end
local ok,result=pcall(function()
    for i=1,12 do table.insert(state.pets,{id="pet-"..i,kind="Chicken",weight=1,equipped=false}) end
    api.reconcile(player,state)
    assert(count()==12,"Not every unplaced pet received a Tool")
    local first=find("pet-1")
    api.reconcile(player,state)
    assert(count()==12 and find("pet-1")==first,"Tools duplicated or identity changed")
    local humanoid=player.Character:FindFirstChildOfClass("Humanoid")
    first.Parent=player.Character
    local placed=api.perform(player,state,"PlacePet",{position=Vector3.zero})
    assert(placed.success,"Pet placement failed: "..tostring(placed.message))
    api.sync(player,state)
    assert(#state.pets==12 and state.pets[1].equipped and not find("pet-1"),"Placed pet remained in Backpack or duplicated")
    assert(api.perform(player,state,"UnequipPet",{pet="pet-1"}).success)
    api.sync(player,state)
    assert(find("pet-1") and count()==12,"Base removal did not return a Tool")
    assert(api.give(player,state,"Egg",{kind="Chicken",weight=3}).success)
    assert(api.give(player,state,"Egg",{kind="Chicken",weight=7}).success)
    assert(#state.backpackEggs==2 and count()==14,"Giving an egg erased other items")
    local eggId=state.backpackEggs[1].id
    for _,item in player.Character:GetChildren() do if item:IsA("Tool") then item.Parent=player.Backpack end end
    find(eggId).Parent=player.Character
    assert(api.perform(player,state,"PlaceEgg",{position=Vector3.new(5,0,0)}).success,"Selected egg placement failed")
    api.sync(player,state)
    assert(#state.backpackEggs==1 and #state.eggs==1 and state.eggs[1].id==eggId and state.eggs[1].weight==3,"Wrong egg placed")
    assert(api.perform(player,state,"CarryPet",{pet="pet-2"}).success,"Carry failed with eggs already in Backpack")
    assert(count()==13,"Carry erased another item")
    -- A confirmed selection is exact, even when it is not the first three.
    local before=#state.pets
    for _,ids in {{"pet-2","pet-2","pet-6"},{"pet-2","missing","pet-6"},{"pet-2","pet-4"}} do
        assert(not api.perform(player,state,"MergePets",{kind="Chicken",pets=ids}).success,"Invalid merge selection accepted")
        assert(#state.pets==before and #state.backpackEggs==1,"Rejected merge changed ownership")
    end
    assert(not api.perform(player,state,"MergePets",{kind="Chicken"}).success,"Unconfirmed kind-only merge accepted")
    state.pets[4].weight=4;state.pets[6].weight=6
    assert(api.perform(player,state,"EquipPet",{pet="pet-4"}).success,"Selected pet did not reach base")
    assert(api.perform(player,state,"MergePets",{kind="Chicken",pets={"pet-2","pet-4","pet-6"}}).success,"Merge blocked by existing Backpack items")
    api.sync(player,state)
    assert(#state.pets==9 and #state.backpackEggs==2 and count()==11,"Merge left stale Tools or erased eggs")
    assert(find("pet-1") and find("pet-3") and not find("pet-2") and not find("pet-4") and not find("pet-6"),"Merge consumed the wrong identities")
    assert(math.abs(state.backpackEggs[2].weight-12.65)<.0001,"Merge changed the weight formula")
    player.Character:Destroy();player.Backpack:Destroy();character()
    api.reconcile(player,state)
    assert(count()==11,"Respawn did not restore every unplaced item")
    local stale=tool("Pet",{kind="Chicken"});stale:SetAttribute("InventoryId","forged");stale.Parent=player.Character
    assert(not api.perform(player,state,"PlacePet",{position=Vector3.zero}).success,"Unknown item accepted")
    api.reconcile(player,state)
    assert(stale.Parent==nil,"Unknown Tool survived reconciliation")
    return "PASS: all unplaced pets, stable identity, placement, base removal, multiple eggs, selected egg, carry, merge, respawn, stale ID rejection"
end)
fixture:Destroy()
assert(ok,result)
return result
