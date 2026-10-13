assert(not game:GetService("RunService"):IsRunning(),"Apply in Studio Edit")
local map=workspace:WaitForChild("Map")
local Game=require(game.ReplicatedStorage.GameConfig)
local variant=game.MaterialService:FindFirstChild("ReferenceHDStuds") or Instance.new("MaterialVariant")
variant.Name="ReferenceHDStuds";variant.BaseMaterial=Enum.Material.Plastic;variant.ColorMap=Game.StudTexture;variant.NormalMap="rbxassetid://122070354289187";variant.StudsPerTile=2;variant.Parent=game.MaterialService
local storage=game.ServerStorage
local backups=storage:FindFirstChild("WorldBackups") or Instance.new("Folder");backups.Name="WorldBackups";backups.Parent=storage
if not backups:FindFirstChild("BeforeReference_2026_10_07") then local copy=map:Clone();copy.Name="BeforeReference_2026_10_07";copy.Parent=backups end
local details=map.StartZone:FindFirstChild("ReferenceDetails")
if details then details:Destroy() end
details=Instance.new("Folder");details.Name="ReferenceDetails";details.Parent=map.StartZone
local function studs(part,face)
 local t=Instance.new("Texture");t.Name="HDStuds";t.Texture=Game.StudTexture;t.StudsPerTileU=2;t.StudsPerTileV=2;t.Color3=part.Color;t.Face=face;t.OffsetStudsU=part.Position.X%2;t.OffsetStudsV=part.Position.Z%2;t.Parent=part
end
for _,part in map:GetDescendants() do if part:IsA("BasePart") and part.Transparency<1 then
 part.Material=Enum.Material.Plastic;part.MaterialVariant="ReferenceHDStuds";part.TopSurface=Enum.SurfaceType.Smooth;part.BottomSurface=Enum.SurfaceType.Smooth
 if part.Name=="GrassFloor" or part:GetFullName():find("Forest.Floor") then part.Color=Color3.fromRGB(140,235,0) end
 if part:GetFullName():find("BoundaryWalls") or part:GetFullName():find("Wall") then
  if part.Color.R>part.Color.G and part.Color.R>part.Color.B then part.Color=Color3.fromRGB(192,97,111) end
 end
 local hadTexture=false
 for _,child in part:GetChildren() do if child:IsA("Texture") then child.Texture=Game.StudTexture;child.StudsPerTileU=2;child.StudsPerTileV=2;child.Color3=part.Color;hadTexture=true end end
 if not hadTexture and not part:IsA("MeshPart") and part.Name~="SafeZoneBoundary" and part.Name~="BaseAnchor" and part.Name~="BeltCollision" then
  for _,face in {Enum.NormalId.Top,Enum.NormalId.Front,Enum.NormalId.Back,Enum.NormalId.Left,Enum.NormalId.Right} do studs(part,face) end
 end
end end
local function part(name,size,cf,color,parent)
 local p=Instance.new("Part");p.Name=name;p.Size=size;p.CFrame=cf;p.Color=color;p.Material=Enum.Material.Plastic;p.MaterialVariant="ReferenceHDStuds";p.Anchored=true;p.CanCollide=false;p.CanTouch=false;p.Parent=parent or details
 for _,face in {Enum.NormalId.Top,Enum.NormalId.Front,Enum.NormalId.Back,Enum.NormalId.Left,Enum.NormalId.Right} do studs(p,face) end
 return p
end
local function label(parent,text,size,color,position,extent)
 local l=Instance.new("TextLabel");l.Name="Text";l.Text=text;l.RichText=true;l.Font=Enum.Font.GothamBlack;l.TextSize=size;l.TextColor3=color or Color3.new(1,1,1);l.TextWrapped=true;l.BackgroundTransparency=1;l.Position=position or UDim2.fromScale(0,0);l.Size=extent or UDim2.fromScale(1,1);l.Parent=parent
 local s=Instance.new("UIStroke");s.Thickness=math.max(2,size/14);s.Parent=l;return l
end
local beam=part("TitanicBeam",Vector3.new(238,2,1),CFrame.new(0,27,-41),Color3.fromRGB(160,81,94))
local banner=part("TitanicBanner",Vector3.new(76,13,1.5),CFrame.new(0,28,-40)*CFrame.Angles(0,math.pi,0),Color3.fromRGB(194,99,112))
local gui=Instance.new("SurfaceGui");gui.Name="BannerUI";gui.Face=Enum.NormalId.Front;gui.CanvasSize=Vector2.new(1100,190);gui.LightInfluence=0;gui.Parent=banner
label(gui,'<font color="#ffaa00">?</font><font color="#ff4040">??</font>  <font color="#ed24ff">T i</font><font color="#245bff"> t a n</font><font color="#00d9ff"> i c </font><font color="#80ff00">E</font><font color="#e8dc00"> g g</font>',64,nil,UDim2.fromOffset(20,10),UDim2.fromOffset(1060,105))
local countdown=label(gui,"Spawns in: 30:00",46,nil,UDim2.fromOffset(20,111),UDim2.fromOffset(1060,65));countdown.Name="Countdown"
for index,zone in {"Forest","Desert","Snow"} do
 local floor=map.Biomes[zone].Floor
 local point=part(zone.."Difficulty",Vector3.one,CFrame.new(0,13,floor.Position.Z+76),Color3.new(1,1,1));point.Transparency=1
 local b=Instance.new("BillboardGui");b.Name="DifficultyLabel";b.Size=UDim2.fromScale(6,4.9);b.Adornee=point;b.MaxDistance=450;b.Parent=point
 label(b,"☺",76,Color3.fromRGB(255,205,38),UDim2.fromScale(0.12,0),UDim2.fromScale(0.76,0.59)).TextScaled=true
 label(b,({"Easy","Medium","Hard"})[index],32,({Color3.fromRGB(95,255,0),Color3.fromRGB(255,161,26),Color3.fromRGB(255,70,70)})[index],UDim2.fromScale(0,0.61),UDim2.fromScale(1,0.37)).TextScaled=true
end
-- Safe-zone marking faces upward, follows the existing red boundary, and has no collision.
local safe=part("SafeZoneTitle",Vector3.new(88,.03,8),CFrame.new(0,.32,-31),Color3.fromRGB(255,255,255));safe.Transparency=1
local safeGui=Instance.new("SurfaceGui");safeGui.Face=Enum.NormalId.Top;safeGui.CanvasSize=Vector2.new(1100,110);safeGui.LightInfluence=0;safeGui.Parent=safe
label(safeGui,"SAFE ZONE",86)
local function board(name,title,at,color,icon)
 local model=Instance.new("Model");model.Name=name;model.Parent=details
 local plate=part("Board",Vector3.new(15,24,1.2),CFrame.new(at),color,model)
 local surface=Instance.new("SurfaceGui");surface.Name="LeaderboardUI";surface.Face=Enum.NormalId.Front;surface.CanvasSize=Vector2.new(450,720);surface.LightInfluence=0;surface.Parent=plate
 local header=Instance.new("Frame");header.Name="Header";header.Size=UDim2.fromOffset(450,82);header.BackgroundColor3=color;header.BorderSizePixel=3;header.Parent=surface
 label(header,title,35)
 local image=Instance.new("ImageLabel");image.Size=UDim2.fromOffset(54,54);image.Position=UDim2.fromOffset(7,13);image.Image=icon;image.BackgroundTransparency=1;image.Parent=header
 local rows=Instance.new("Frame");rows.Name="Rows";rows.Size=UDim2.fromOffset(420,620);rows.Position=UDim2.fromOffset(15,92);rows.BackgroundColor3=color:Lerp(Color3.new(0,0,0),.55);rows.BorderSizePixel=2;rows.Parent=surface
 for i=1,8 do label(rows,"#"..i.."   —",24,nil,UDim2.fromOffset(10,(i-1)*73),UDim2.fromOffset(400,65)).Name="Row"..i end
 part("Foot",Vector3.new(17,.6,4),CFrame.new(at.X,.5,at.Z),color,model)
end
board("TopMoney","Top Money",Vector3.new(-99,12.3,16),Color3.fromRGB(33,230,52),"rbxassetid://72638283383933")
board("TopSpeed","Top Speed",Vector3.new(-78,12.3,16),Color3.fromRGB(23,171,255),"rbxassetid://124600108076702")
board("TopPlaytime","Top Playtime",Vector3.new(-57,12.3,16),Color3.fromRGB(245,67,144),"rbxassetid://80316475458538")
local gift=part("FreeGift",Vector3.new(5,5,5),CFrame.new(-125,2.7,-10),Color3.fromRGB(250,35,55));gift:SetAttribute("Interaction","Free")
part("GiftRibbonX",Vector3.new(5.1,.7,5.1),CFrame.new(-125,5.1,-10),Color3.fromRGB(255,211,25));part("GiftRibbonY",Vector3.new(.7,5.1,5.1),CFrame.new(-125,2.7,-10),Color3.fromRGB(255,211,25))
local giftGui=Instance.new("BillboardGui");giftGui.Size=UDim2.fromScale(5,2);giftGui.StudsOffsetWorldSpace=Vector3.new(0,5,0);giftGui.Adornee=gift;giftGui.Parent=gift;label(giftGui,"FREE!",40,Color3.fromRGB(183,255,0)).TextScaled=true
local portal=part("AnimalMerging",Vector3.new(11,.3,11),CFrame.new(154,.3,-7),Color3.fromRGB(21,210,255));portal.Material=Enum.Material.Neon;portal:SetAttribute("Interaction","Merge Pets")
local portalGui=Instance.new("BillboardGui");portalGui.Size=UDim2.fromScale(10,2.7);portalGui.StudsOffsetWorldSpace=Vector3.new(0,8,0);portalGui.Adornee=portal;portalGui.Parent=portal;label(portalGui,"Animal Merging",32,Color3.fromRGB(8,219,255)).TextScaled=true
local bag=part("SatchelShop",Vector3.new(7,5,4),CFrame.new(101,2.7,-6),Color3.fromRGB(145,84,45));bag:SetAttribute("Interaction","Satchel Shop")
local bagGui=Instance.new("BillboardGui");bagGui.Size=UDim2.fromScale(8,2.6);bagGui.StudsOffsetWorldSpace=Vector3.new(0,5,0);bagGui.Adornee=bag;bagGui.Parent=bag;label(bagGui,"Satchel Shop",32,Color3.fromRGB(255,205,59)).TextScaled=true
for _,shop in map.StartZone.Shops:GetChildren() do
 if shop:IsA("Model") then local p=shop:FindFirstChildWhichIsA("BasePart",true);local title=shop:FindFirstChild("ShopTitle") or Instance.new("BillboardGui");title.Name="ShopTitle";title.Size=UDim2.fromScale(12,3.3);title.Adornee=p;title.StudsOffsetWorldSpace=Vector3.new(0,12,0);title.Parent=shop
  if #title:GetChildren()==0 then label(title,shop.Name=="BlueShopStand" and "Pickaxe Shop" or "Trails Shop",34,shop.Name=="BlueShopStand" and Color3.fromRGB(0,218,255) or Color3.fromRGB(106,255,0)).TextScaled=true end
 end
end
local bases=map.StartZone.PlayerBases
if not bases:FindFirstChild("Base07") then
 local copy=bases.Base01:Clone();copy.Name="Base07";copy:PivotTo(copy:GetPivot()+Vector3.new(57,0,0));copy.Parent=bases
 local station=map.StartZone.Treadmills.Treadmill_Base01:Clone();station.Name="Treadmill_Base07";station:PivotTo(station:GetPivot()+Vector3.new(57,0,0));station.Parent=map.StartZone.Treadmills
end
local lighting=game.Lighting;lighting.ClockTime=14;lighting.Brightness=2;lighting.Ambient=Color3.fromRGB(112,121,145);lighting.OutdoorAmbient=Color3.fromRGB(135,143,161);lighting.GlobalShadows=true
for _,effect in lighting:GetChildren() do if effect:IsA("BloomEffect") and effect.Name~="ReferenceBloom" then effect.Intensity=.05 elseif effect:IsA("DepthOfFieldEffect") then effect.Enabled=false end end
local correction=lighting:FindFirstChild("ReferenceColor") or Instance.new("ColorCorrectionEffect");correction.Name="ReferenceColor";correction.Saturation=.04;correction.Contrast=.03;correction.Brightness=0;correction.Parent=lighting
local bloom=lighting:FindFirstChild("ReferenceBloom") or Instance.new("BloomEffect");bloom.Name="ReferenceBloom";bloom.Intensity=.25;bloom.Size=24;bloom.Threshold=1.1;bloom.Parent=lighting
local clouds=workspace.Terrain:FindFirstChildOfClass("Clouds") or Instance.new("Clouds");clouds.Cover=.48;clouds.Density=.33;clouds.Color=Color3.new(1,1,1);clouds.Parent=workspace.Terrain
workspace.StreamingEnabled=false
local bat=game.StarterPack:FindFirstChild("Lava Bat")
if bat then
 bat:SetAttribute("UIIcon","lavaBat")
 for _,p in bat:GetDescendants() do if p:IsA("MeshPart") then
  p.TextureID="";p.Color=p.Name:find("wrapped") and Color3.fromRGB(42,25,22) or Color3.fromRGB(255,94,7)
  p.Material=p.Name:find("barrel") and Enum.Material.Neon or Enum.Material.Plastic
 end end
end
return {details=#details:GetDescendants(),bases=#bases:GetChildren(),backup="ServerStorage.WorldBackups.BeforeReference_2026_10_07",texture=Game.StudTexture}
