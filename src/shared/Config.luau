-- Paid offers remain unconfigured. Pet gameplay supplies authoritative state.
local Game = require(game.ReplicatedStorage:WaitForChild("GameConfig"))
local Config = {
	PetCapacity = 8,
	PetSlotCost = 100,
	DataDefaults = { Cash = 0, Speed = 0, Multiplier = 1, Income = 0, OfflineCash = 0, EventRemaining = 0 },
	FeaturedName = "FALLEN ANGEL EGG",
	Offers = {
		{ key = "egg50", section = "Featured", amount = "50 Eggs", price = 3499, icon = "angelEgg", productId = 0 },
		{ key = "egg10", section = "Featured", amount = "10 Eggs", price = 799, icon = "angelEgg", productId = 0 },
		{ key = "egg3", section = "Featured", amount = "3 Eggs", price = 249, icon = "angelEgg", productId = 0 },
		{ key = "egg1", section = "Featured", amount = "1 Egg", price = 99, icon = "angelEgg", productId = 0 },
		{
			key = "swing",
			section = "Game Passes",
			amount = "x2 Swing",
			description = "Swing pickaxe\n2x faster!",
			price = 299,
			icon = "pickaxe",
			gamePassId = 0,
		},
		{
			key = "cash2",
			section = "Game Passes",
			amount = "x2 Cash",
			description = "Earn 2x money!",
			price = 199,
			icon = "cash",
			gamePassId = 0,
		},
		{ key = "speed150k", section = "Speed Packs", amount = "+150K SPEED", price = 59, icon = "shoe", productId = 0 },
		{ key = "speed1m", section = "Speed Packs", amount = "+1M SPEED", price = 199, icon = "shoes", productId = 0 },
		{ key = "speed10m", section = "Speed Packs", amount = "+10M SPEED", price = 459, icon = "shoes", productId = 0 },
		{ key = "speed50m", section = "Speed Packs", amount = "+50M SPEED", price = 799, icon = "speedBucket", productId = 0 },
		{ key = "speed250m", section = "Speed Packs", amount = "+250M SPEED", price = 1799, icon = "speedChest", productId = 0 },
		{ key = "speed1b", section = "Speed Packs", amount = "+1B SPEED", price = 3499, icon = "speedChest", productId = 0 },
		{ key = "cash100k", section = "Cash Packs", amount = "$100K", price = 24, icon = "cash", productId = 0 },
		{ key = "cash500k", section = "Cash Packs", amount = "$500K", price = 49, icon = "cashDouble", productId = 0 },
		{ key = "cash2m", section = "Cash Packs", amount = "$2M", price = 79, icon = "cashPile", productId = 0 },
		{ key = "cash20m", section = "Cash Packs", amount = "$20M", price = 199, icon = "cashBag", productId = 0 },
		{ key = "cash100m", section = "Cash Packs", amount = "$100M", price = 499, icon = "cashChest", productId = 0 },
	},
	Pets = {},
	-- Theme color key per rarity; Common reads white like the reference Index.
	RarityColor = {
		Common = "white",
		Uncommon = "green",
		Rare = "blue",
		Epic = "purple",
		Legendary = "gold",
		Mythic = "red",
		Titanic = "purple",
	},
}
for _, pet in Game.Pets do
	table.insert(
		Config.Pets,
		{
			key = pet.key,
			name = pet.name,
			icon = pet.icon,
			rarity = pet.rarity,
			income = pet.income,
			owned = false,
			biome = pet.biome,
			color = Config.RarityColor[pet.rarity] or "gold",
		}
	)
end
return Config
