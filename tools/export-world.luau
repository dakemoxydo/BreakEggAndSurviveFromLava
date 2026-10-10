-- Edit-only snapshot. Exports manual geometry without regenerating or moving it.
assert(not game:GetService("RunService"):IsRunning(),"Export in Edit mode")
local Http=game:GetService("HttpService")
local ids={};local nextId=0
local function ref(instance)
 if not instance then return "null" end
 if not ids[instance] then nextId+=1;ids[instance]="WORLD"..nextId end
 return ids[instance]
end
local function encode(v)
 local t=typeof(v)
 if t=="Instance" then return {type="Ref",value=ref(v)}
 elseif t=="EnumItem" then return {type="token",value=v.Value}
 elseif t=="CFrame" then return {type="CoordinateFrame",value={v:GetComponents()}}
 elseif t=="Vector3" then return {type="Vector3",value={v.X,v.Y,v.Z}}
 elseif t=="Vector2" then return {type="Vector2",value={v.X,v.Y}}
 elseif t=="Color3" then return {type="Color3",value={v.R,v.G,v.B}}
 elseif t=="UDim2" then return {type="UDim2",value={v.X.Scale,v.X.Offset,v.Y.Scale,v.Y.Offset}}
 elseif t=="UDim" then return {type="UDim",value={v.Scale,v.Offset}}
 elseif t=="ColorSequence" then local s={} for _,k in v.Keypoints do table.insert(s,k.Time.." "..k.Value.R.." "..k.Value.G.." "..k.Value.B.." 0") end return {type="ColorSequence",value=table.concat(s," ")}
 elseif t=="NumberSequence" then local s={} for _,k in v.Keypoints do table.insert(s,k.Time.." "..k.Value.." "..k.Envelope) end return {type="NumberSequence",value=table.concat(s," ")}
 elseif t=="NumberRange" then return {type="NumberRange",value={v.Min,v.Max}}
 elseif t=="boolean" then return {type="bool",value=v}
 elseif t=="number" then return {type="float",value=v}
 elseif t=="string" then return {type="string",value=v}
 end
end
local groups={
 {"BasePart",{"CFrame","Size","Color","Material","MaterialVariant","Anchored","CanCollide","CanTouch","CanQuery","Transparency","Reflectance","CastShadow","TopSurface","BottomSurface","PivotOffset"}},
 {"Part",{"Shape"}}, {"MeshPart",{"MeshId","TextureID","DoubleSided","RenderFidelity"}},
 {"Model",{"PrimaryPart"}}, {"Tool",{"Grip","RequiresHandle","CanBeDropped","ToolTip","TextureId"}},
 {"DataModelMesh",{"Scale","Offset","VertexColor"}}, {"SpecialMesh",{"MeshId","TextureId","MeshType"}},
 {"Decal",{"Texture","Color3","Transparency","Face"}}, {"Texture",{"StudsPerTileU","StudsPerTileV","OffsetStudsU","OffsetStudsV"}},
 {"GuiBase2d",{}}, {"GuiObject",{"Position","Size","AnchorPoint","BackgroundColor3","BackgroundTransparency","BorderSizePixel","BorderColor3","ZIndex","Visible","ClipsDescendants","Rotation"}},
 {"TextLabel",{"Text","Font","TextSize","TextColor3","TextTransparency","TextWrapped","TextScaled","RichText","TextXAlignment","TextYAlignment","TextStrokeTransparency","TextStrokeColor3"}},
 {"ImageLabel",{"Image","ImageColor3","ImageTransparency","ImageRectOffset","ImageRectSize","ScaleType"}},
 {"BillboardGui",{"Size","StudsOffsetWorldSpace","AlwaysOnTop","MaxDistance","Adornee","Enabled","LightInfluence"}},
 {"SurfaceGui",{"Face","CanvasSize","LightInfluence","AlwaysOnTop","Enabled","SizingMode","PixelsPerStud"}},
 {"UIStroke",{"Color","Thickness","Transparency","ApplyStrokeMode","LineJoinMode"}}, {"UICorner",{"CornerRadius"}},
 {"UIGradient",{"Rotation","Color","Transparency","Offset"}},
 {"WeldConstraint",{"Part0","Part1","Enabled"}}, {"JointInstance",{"Part0","Part1","C0","C1"}},
 {"Light",{"Brightness","Color","Enabled","Shadows"}}, {"PointLight",{"Range"}},
 {"SurfaceAppearance",{"ColorMap","MetalnessMap","NormalMap","RoughnessMap","AlphaMode"}},
 {"MaterialVariant",{"BaseMaterial","ColorMap","NormalMap","RoughnessMap","MetalnessMap","StudsPerTile"}},
 {"Clouds",{"Cover","Density","Color","Enabled"}},
 {"Sky",{"SkyboxBk","SkyboxDn","SkyboxFt","SkyboxLf","SkyboxRt","SkyboxUp","CelestialBodiesShown","SunAngularSize","MoonAngularSize","StarCount"}},
 {"Atmosphere",{"Color","Decay","Density","Glare","Haze","Offset"}},
 {"PostEffect",{"Enabled"}}, {"BloomEffect",{"Intensity","Size","Threshold"}}, {"SunRaysEffect",{"Intensity","Spread"}},
 {"ColorCorrectionEffect",{"Brightness","Contrast","Saturation","TintColor"}}, {"DepthOfFieldEffect",{"FarIntensity","FocusDistance","InFocusRadius","NearIntensity"}},
 {"Lighting",{"Ambient","OutdoorAmbient","Brightness","ClockTime","ExposureCompensation","GlobalShadows","EnvironmentDiffuseScale","EnvironmentSpecularScale"}},
 {"SpawnLocation",{"Neutral","Duration","Enabled","AllowTeamChangeOnTouch"}},
}
local contentNames={MeshId=true,TextureId=true,TextureID=true,Texture=true,Image=true,ColorMap=true,NormalMap=true,RoughnessMap=true,MetalnessMap=true,SkyboxBk=true,SkyboxDn=true,SkyboxFt=true,SkyboxLf=true,SkyboxRt=true,SkyboxUp=true}
local function snapshot(instance)
 if nextId > 0 and nextId % 1000 == 0 then task.wait() end
 local node={class=instance.ClassName,id=ref(instance),properties={Name=encode(instance.Name)},attributes={},children={}}
 for _,group in groups do if instance:IsA(group[1]) then for _,name in group[2] do
  local ok,v=pcall(function()return instance[name]end)
  if ok and v~=nil then local value=encode(v);if value then if contentNames[name] then value.type="Content" end;node.properties[name=="Color" and instance:IsA("BasePart") and "Color3" or name]=value end end
 end end end
 for name,value in instance:GetAttributes() do node.attributes[name]=encode(value) end
 if instance:IsA("Model") then
  node.properties.WorldPivotData={type="OptionalCoordinateFrame",value={instance:GetPivot():GetComponents()}}
 end
 if instance:IsA("MeshPart") then node.properties.InitialSize=encode(instance.MeshSize) end
 for _,child in instance:GetChildren() do if child.Archivable and not child:IsA("LuaSourceContainer") then table.insert(node.children,snapshot(child)) end end
 return node
end
local roots={snapshot(workspace.Map),snapshot(game.ServerStorage.Assets),snapshot(game.MaterialService.ReferenceHDStuds),snapshot(game.Lighting)}
if workspace.Terrain:FindFirstChildOfClass("Clouds") then table.insert(roots,snapshot(workspace.Terrain:FindFirstChildOfClass("Clouds"))) end
local bat=game.StarterPack:FindFirstChild("Lava Bat");if bat then table.insert(roots,snapshot(bat)) end
local previous=Http.HttpEnabled
Http.HttpEnabled=true
local ok,response=pcall(function()
 local payload=Http:JSONEncode(roots)
 local total=math.ceil(#payload/400000)
 for chunk=1,total do
  Http:PostAsync("http://127.0.0.1:8866/snapshot",Http:JSONEncode({chunk=chunk,total=total,data=payload:sub((chunk-1)*400000+1,chunk*400000)}),Enum.HttpContentType.ApplicationJson)
 end
 return "saved"
end)
Http.HttpEnabled=previous
assert(ok,response)
return {roots=#roots,instances=nextId,result=response}
