local C = Color3.fromRGB
local Config = {}
Config.MaxCash = 1e18
Config.MaxSpeed = 1e18
Config.SafeZ = -39.5
Config.SwingRange = 15
Config.SwingCooldown = 0.6
Config.SwingImpactTime = 0.275
Config.CritChance = 0.12
Config.CritMultiplier = 2
Config.FieldHatchDuration = 7
Config.FieldHatchGrowth = 1.65
Config.FieldRevealDuration = 0.65
Config.EggRespawnSeconds = 12
Config.LavaInterval = 90
Config.LavaSpeed = 35
Config.TitanInterval = 1800
Config.TitanDuration = 120
Config.StudTexture = "rbxassetid://107033945808299"
-- Ascending rarity ladder; hatch effects climb it up to the rolled rarity.
Config.Rarities = {
	{ key = "Common", color = C(235, 240, 245) },
	{ key = "Uncommon", color = C(110, 240, 70) },
	{ key = "Rare", color = C(55, 170, 255) },
	{ key = "Epic", color = C(185, 70, 255) },
	{ key = "Legendary", color = C(255, 200, 30) },
	{ key = "Mythic", color = C(255, 55, 90) },
	{ key = "Titanic", color = C(255, 90, 200) },
}
Config.RarityIndex = {}
for i, item in Config.Rarities do
	Config.RarityIndex[item.key] = i
end
Config.Pickaxes = {
	{ key = "Wooden", name = "Wooden Pickaxe", power = 1, cost = 0, rarity = "Common", color = C(194, 91, 32) },
	{ key = "Stone", name = "Stone Pickaxe", power = 4, cost = 80, rarity = "Common", color = C(158, 165, 181) },
	{ key = "Iron", name = "Iron Pickaxe", power = 15, cost = 800, rarity = "Uncommon", color = C(224, 235, 245) },
	{ key = "Golden", name = "Golden Pickaxe", power = 60, cost = 20000, rarity = "Uncommon", color = C(255, 205, 25) },
	{ key = "Diamond", name = "Diamond Pickaxe", power = 250, cost = 160000, rarity = "Rare", color = C(60, 226, 255) },
	{
		key = "Strawberry",
		name = "Strawberry Pickaxe",
		power = 1000,
		cost = 1200000,
		rarity = "Rare",
		color = C(239, 47, 89),
	},
	{ key = "Cactus", name = "Cactus Pickaxe", power = 4000, cost = 6000000, rarity = "Epic", color = C(64, 199, 61) },
	{
		key = "Lightning",
		name = "Lightning Pickaxe",
		power = 15000,
		cost = 40000000,
		rarity = "Legendary",
		color = C(255, 228, 54),
	},
	{
		key = "Candy",
		name = "Candy Pickaxe",
		power = 60000,
		cost = 400000000,
		rarity = "Mythic",
		color = C(255, 117, 208),
	},
	{
		key = "Rainbow",
		name = "Rainbow Pickaxe",
		power = 250000,
		cost = 2800000000,
		rarity = "Mythic",
		color = C(193, 58, 255),
	},
	{
		key = "Crystal",
		name = "Crystal Pickaxe",
		power = 1000000,
		cost = 20000000000,
		rarity = "Mythic",
		color = C(151, 217, 255),
	},
	{
		key = "Demon",
		name = "Demon Pickaxe",
		power = 4000000,
		cost = 120000000000,
		rarity = "Mythic",
		color = C(213, 23, 44),
	},
	{
		key = "Hacker",
		name = "Hacker Pickaxe",
		power = 15000000,
		cost = 1200000000000,
		rarity = "Secret",
		color = C(69, 255, 77),
	},
	{
		key = "UFO",
		name = "UFO Pickaxe",
		power = 60000000,
		cost = 12000000000000,
		rarity = "Cosmic",
		color = C(112, 241, 206),
	},
	{
		key = "Secret",
		name = "Secret Pickaxe",
		power = 250000000,
		cost = 80000000000000,
		rarity = "Secret",
		color = C(46, 33, 66),
	},
	{
		key = "Cool",
		name = "Cool Pickaxe",
		power = 1000000000,
		cost = 600000000000000,
		rarity = "Secret",
		color = C(32, 92, 209),
	},
	{
		key = "Galaxy",
		name = "Galaxy Pickaxe",
		power = 5000000000,
		cost = 4000000000000000,
		rarity = "Celestial",
		color = C(167, 64, 231),
	},
	{
		key = "Celestial",
		name = "Celestial Pickaxe",
		power = 25000000000,
		cost = 20000000000000000,
		rarity = "Celestial",
		color = C(254, 234, 138),
	},
}
Config.Treadmills = {
	{ name = "Standard", cost = 0, gain = 1, color = C(39, 139, 255) },
	{ name = "Turbo", cost = 500, gain = 5, color = C(255, 50, 54) },
	{ name = "Electric", cost = 15000, gain = 25, color = C(255, 219, 18) },
	{ name = "Ice", cost = 300000, gain = 150, color = C(38, 231, 255) },
	{ name = "Fire", cost = 10000000, gain = 1000, color = C(255, 103, 16) },
	{ name = "Nuclear", cost = 500000000, gain = 10000, color = C(120, 255, 6) },
	{ name = "Demonic", cost = 100000000000, gain = 100000, color = C(255, 28, 47) },
	{ name = "Angelic", cost = 5000000000000, gain = 2500000, color = C(255, 209, 22) },
	{ name = "Cosmic", cost = 250000000000000, gain = 10000000, color = C(183, 66, 255) },
	{ name = "Divine", cost = 7500000000000000, gain = 50000000, color = C(255, 251, 216) },
}
Config.PenCosts = { 100, 1500, 25000, 500000, 25000000, 1000000000, 50000000000000, 1000000000000000 }
Config.Trails = {
	{ key = "Gray", name = "Gray Trail", cost = 0, multiplier = 1, color = C(210, 220, 231), icon = "shoe" },
	{ key = "Green", name = "Green Trail", cost = 500, multiplier = 2, color = C(110, 255, 14), icon = "shoe" },
	{ key = "Blue", name = "Blue Trail", cost = 12000, multiplier = 4, color = C(11, 209, 255), icon = "shoes" },
	{ key = "Purple", name = "Purple Trail", cost = 300000, multiplier = 10, color = C(168, 50, 255), icon = "shoes" },
	{
		key = "Golden",
		name = "Golden Trail",
		cost = 10000000,
		multiplier = 25,
		color = C(255, 214, 35),
		icon = "shoes",
	},
	{
		key = "Galaxy",
		name = "Galaxy Trail",
		cost = 1000000000,
		multiplier = 100,
		color = C(110, 33, 255),
		icon = "speedBucket",
	},
	{
		key = "Divine",
		name = "Divine Trail",
		cost = 100000000000,
		multiplier = 500,
		color = C(251, 244, 181),
		icon = "speedChest",
	},
	{
		key = "Eternal",
		name = "Eternal Trail",
		cost = 10000000000000,
		multiplier = 2500,
		color = C(255, 64, 186),
		icon = "speedChest",
	},
	{
		key = "Secret",
		name = "Secret Trail",
		cost = 1000000000000000,
		multiplier = 20000,
		color = C(25, 244, 255),
		icon = "speedChest",
	},
}
Config.Pets = {}
local function pet(key, name, biome, rarity, income, weight, shape, color, icon, size)
	local item = {
		key = key,
		name = name,
		biome = biome,
		rarity = rarity,
		income = income,
		weight = weight,
		shape = shape,
		color = color,
		icon = icon,
		size = size or 1,
	}
	table.insert(Config.Pets, item)
	return item
end
pet("Chicken", "Chicken", "Forest", "Common", 1, 40, "chicken", C(247, 244, 228), "chicken")
pet("Bat", "Bat", "Forest", "Common", 3, 26, "bat", C(118, 66, 160), "bat")
pet("Anteater", "Anteater", "Forest", "Uncommon", 8, 16, "anteater", C(204, 173, 130), "anteater", 1.15)
pet("Retriever", "Golden Retriever", "Forest", "Uncommon", 20, 10, "dog", C(242, 178, 69), "dog", 1.2)
pet("Fox", "Fox", "Forest", "Rare", 70, 5, "fox", C(242, 127, 41), "dog", 1.35)
pet("Wolf", "Wolf", "Forest", "Epic", 250, 2, "wolf", C(124, 139, 166), "dog", 1.5)
pet("Bear", "Bear", "Forest", "Legendary", 1200, 0.9, "bear", C(117, 75, 42), "dog", 1.8)
pet("ForestDragon", "Forest Dragon", "Forest", "Mythic", 8500, 0.1, "dragon", C(49, 146, 69), "dragon", 2.3)
pet("Rabbit", "Jackalope", "Desert", "Common", 100, 40, "rabbit", C(224, 185, 142), "anteater", 1.3)
pet("Scorpion", "Scorpion", "Desert", "Common", 250, 26, "scorpion", C(143, 61, 35), "bat", 1.5)
pet("Camel", "Camel", "Desert", "Uncommon", 650, 16, "camel", C(211, 166, 93), "anteater", 1.6)
pet("Cobra", "Cobra", "Desert", "Uncommon", 1800, 10, "snake", C(209, 152, 31), "dragon", 1.8)
pet("Lion", "Lion", "Desert", "Rare", 6500, 5, "lion", C(215, 149, 43), "dog", 1.8)
pet("Dimetrodon", "Dimetrodon", "Desert", "Epic", 24000, 2, "dinosaur", C(175, 47, 40), "dragon", 2.1)
pet("Brontosaurus", "Brontosaurus", "Desert", "Legendary", 125000, 0.9, "longneck", C(199, 135, 58), "dragon", 2.7)
pet("Lindwurm", "Lindwurm", "Desert", "Mythic", 950000, 0.1, "dragon", C(57, 129, 222), "dragon", 3)
pet("Penguin", "Penguin", "Snow", "Common", 12000, 40, "penguin", C(45, 52, 69), "chicken", 1.4)
pet("SnowOwl", "Snow Owl", "Snow", "Common", 32000, 26, "owl", C(235, 245, 255), "bat", 1.5)
pet("ArcticFox", "Arctic Fox", "Snow", "Uncommon", 85000, 16, "fox", C(220, 241, 255), "dog", 1.8)
pet("PolarBear", "Polar Bear", "Snow", "Uncommon", 220000, 10, "bear", C(234, 244, 255), "dog", 2)
pet("IceWolf", "Ice Wolf", "Snow", "Rare", 850000, 5, "wolf", C(113, 192, 240), "dog", 2.3)
pet("Yeti", "Yeti", "Snow", "Epic", 3200000, 2, "bear", C(176, 222, 240), "anteater", 2.6)
pet("FrostDragon", "Frost Dragon", "Snow", "Legendary", 15000000, 0.9, "dragon", C(119, 212, 255), "dragon", 3.2)
pet("Cerberus", "Cerberus", "Snow", "Mythic", 120000000, 0.1, "cerberus", C(45, 34, 61), "dog", 3.7)
pet("TitanDragon", "Titanic Dragon", "Titanic", "Titanic", 240000000, 1, "dragon", C(220, 40, 77), "dragon", 7)
Config.ByPet = {}
for _, item in Config.Pets do
	Config.ByPet[item.key] = item
end
Config.ByPet.TestChick = {
	key = "TestChick",
	name = "Chicken",
	biome = "Forest",
	rarity = "Common",
	income = 5,
	shape = "chicken",
	color = C(247, 244, 228),
	icon = "chicken",
	size = 1,
	weight = 0,
}
Config.Eggs = {
	{ biome = "Forest", name = "Forest Egg", rarity = "Common", hp = 5, color = C(255, 204, 159), luck = 0.53 },
	{ biome = "Forest", name = "Forest Egg", rarity = "Uncommon", hp = 25, color = C(135, 238, 90), luck = 1.67 },
	{ biome = "Forest", name = "Forest Egg", rarity = "Rare", hp = 120, color = C(72, 187, 255), luck = 3 },
	{ biome = "Desert", name = "Desert Egg", rarity = "Common", hp = 250, color = C(249, 199, 85), luck = 0.53 },
	{ biome = "Desert", name = "Desert Egg", rarity = "Uncommon", hp = 1200, color = C(227, 148, 64), luck = 1.67 },
	{ biome = "Desert", name = "Desert Egg", rarity = "Rare", hp = 6000, color = C(216, 83, 40), luck = 3 },
	{ biome = "Snow", name = "Snow Egg", rarity = "Common", hp = 15000, color = C(226, 243, 255), luck = 0.53 },
	{ biome = "Snow", name = "Snow Egg", rarity = "Uncommon", hp = 60000, color = C(104, 224, 255), luck = 1.67 },
	{ biome = "Snow", name = "Snow Egg", rarity = "Rare", hp = 250000, color = C(145, 125, 249), luck = 3 },
	{ biome = "Titanic", name = "Titanic Egg", rarity = "Titanic", hp = 1000000, color = C(237, 50, 123), luck = 10 },
}
function Config.pet(kind)
	return Config.ByPet[kind or "TestChick"] or Config.ByPet.TestChick
end
function Config.income(petData)
	return math.max(1, math.floor(Config.pet(petData.kind).income * math.clamp((petData.weight or 1) ^ 0.7, 0.5, 1e4)))
end
function Config.weight(value)
	if value >= 1000 then
		return Config.number(value)
	end
	return string.format("%.1f", value):gsub("%.0$", "")
end
function Config.walkSpeed(speed, slow)
	return slow and 16 or math.clamp(16 + math.log(1 + math.max(0, speed - 16)) * 4, 16, 96)
end
function Config.number(value)
	for _, unit in { { 1e15, "Qa" }, { 1e12, "T" }, { 1e9, "B" }, { 1e6, "M" }, { 1e3, "K" } } do
		if math.abs(value) >= unit[1] then
			return string.format("%.1f", value / unit[1]):gsub("%.0$", "") .. unit[2]
		end
	end
	return tostring(math.floor(value))
end
return Config
