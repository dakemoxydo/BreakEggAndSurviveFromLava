local assets = {
    indexHalftone={image="rbxassetid://97608267032141"},
    settings={image="rbxassetid://93020891544824",offset=Vector2.new(31,73),rect=Vector2.new(962,894)},
    trailGray={image="rbxassetid://82046206195556"},trailGreen={image="rbxassetid://103181857711473"},trailBlue={image="rbxassetid://99173064702974"},trailPurple={image="rbxassetid://128821148168712"},trailGolden={image="rbxassetid://99151635730890"},trailGalaxy={image="rbxassetid://110984098003307"},trailSecret={image="rbxassetid://119362428725462"},trailEternal={image="rbxassetid://74766850436673"},trailDivine={image="rbxassetid://131938132845749"},
    cash = { image = "rbxassetid://72638283383933" },
    index = { image = "rbxassetid://76096389003906", offset=Vector2.new(213,127), rect=Vector2.new(599,769) },
    egg = { image = "rbxassetid://120031849641660", offset=Vector2.new(148,63), rect=Vector2.new(729,913) },
    pets = { image = "rbxassetid://118382351876288", offset=Vector2.new(30,63), rect=Vector2.new(963,844) },
    home = { image = "rbxassetid://119104635069423", offset=Vector2.new(33,65), rect=Vector2.new(956,873) },
    cart = { image = "rbxassetid://82216367327862", offset = Vector2.new(23,97), rect = Vector2.new(1213,1117) },
    sunburst = { image = "rbxassetid://93658144719385" },
}
local atlas = "rbxassetid://124600108076702"
local regions = {
    shoe={23,95,276,292}, shoes={308,120,318,244}, speedChest={627,71,331,337}, chicken={970,69,266,324},
    bat={0,465,334,260}, anteater={334,497,286,265}, dog={627,480,295,285}, dragon={923,440,317,320},
    angelEgg={9,811,344,361}, gift={359,855,268,312}, pickaxe={642,843,326,330}, lavaBat={938,799,302,391},
}
-- Roblox imports this atlas at 1024 px; rects refer to the imported resolution.
local atlasScale=1024/1254
for key, r in regions do assets[key]={image=atlas,offset=Vector2.new(math.floor(r[1]*atlasScale),math.floor(r[2]*atlasScale)),rect=Vector2.new(math.floor(r[3]*atlasScale),math.floor(r[4]*atlasScale))} end
local offerAtlas="rbxassetid://97764213374400"
local offerRegions={
    dragon1={12,138,300,242},dragon2={323,82,300,305},dragon3={627,111,299,270},dragon4={932,91,312,278},
    dragon5={8,453,310,326},dragon6={320,457,307,323},dragon7={627,452,327,325},speedBucket={960,478,283,310},
    cashDouble={5,879,307,290},cashPile={313,839,310,335},cashBag={627,839,307,335},cashChest={932,837,312,337},
}
for key,r in offerRegions do assets[key]={image=offerAtlas,offset=Vector2.new(math.floor(r[1]*atlasScale),math.floor(r[2]*atlasScale)),rect=Vector2.new(math.floor(r[3]*atlasScale),math.floor(r[4]*atlasScale))} end
local cleanAtlas="rbxassetid://129626962813547"
local cleanRegions={chicken={51,179,315,383},bat={401,192,449,319},anteater={862,244,368,312},dog={24,685,335,407},pickaxe={460,678,366,401},lavaBat={879,681,330,417}}
for key,r in cleanRegions do assets[key]={image=cleanAtlas,offset=Vector2.new(math.floor(r[1]*atlasScale),math.floor(r[2]*atlasScale)),rect=Vector2.new(math.floor(r[3]*atlasScale),math.floor(r[4]*atlasScale)),outlineExtension=1.5} end
-- Generated pickaxe concepts; two native 1024 px atlases.
assets.pickaxeWooden={image="rbxassetid://99300582266284",offset=Vector2.new(0,0),rect=Vector2.new(341,341)}
assets.pickaxeStone={image="rbxassetid://99300582266284",offset=Vector2.new(341,0),rect=Vector2.new(341,341)}
assets.pickaxeIron={image="rbxassetid://99300582266284",offset=Vector2.new(682,0),rect=Vector2.new(341,341)}
assets.pickaxeGolden={image="rbxassetid://99300582266284",offset=Vector2.new(0,341),rect=Vector2.new(341,341)}
assets.pickaxeDiamond={image="rbxassetid://99300582266284",offset=Vector2.new(341,341),rect=Vector2.new(341,341)}
assets.pickaxeStrawberry={image="rbxassetid://99300582266284",offset=Vector2.new(682,341),rect=Vector2.new(341,341)}
assets.pickaxeCactus={image="rbxassetid://99300582266284",offset=Vector2.new(0,682),rect=Vector2.new(341,341)}
assets.pickaxeLightning={image="rbxassetid://99300582266284",offset=Vector2.new(341,682),rect=Vector2.new(341,341)}
assets.pickaxeCandy={image="rbxassetid://99300582266284",offset=Vector2.new(682,682),rect=Vector2.new(341,341)}
assets.pickaxeRainbow={image="rbxassetid://99607759575544",offset=Vector2.new(0,0),rect=Vector2.new(341,341)}
assets.pickaxeCrystal={image="rbxassetid://99607759575544",offset=Vector2.new(341,0),rect=Vector2.new(341,341)}
assets.pickaxeDemon={image="rbxassetid://99607759575544",offset=Vector2.new(682,0),rect=Vector2.new(341,341)}
assets.pickaxeHacker={image="rbxassetid://99607759575544",offset=Vector2.new(0,341),rect=Vector2.new(341,341)}
assets.pickaxeUFO={image="rbxassetid://99607759575544",offset=Vector2.new(341,341),rect=Vector2.new(341,341)}
assets.pickaxeSecret={image="rbxassetid://99607759575544",offset=Vector2.new(682,341),rect=Vector2.new(341,341)}
assets.pickaxeCool={image="rbxassetid://99607759575544",offset=Vector2.new(0,682),rect=Vector2.new(341,341)}
assets.pickaxeGalaxy={image="rbxassetid://99607759575544",offset=Vector2.new(341,682),rect=Vector2.new(341,341)}
assets.pickaxeCelestial={image="rbxassetid://99607759575544",offset=Vector2.new(682,682),rect=Vector2.new(341,341)}
return assets
