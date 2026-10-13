-- Single catalogue of every sound in the game. Gameplay and UI code refer to
-- sounds only by key; Audio resolves the asset, group, volume and limits.
--   ids      one or more asset ids, picked at random per play
--   group    SoundGroup key from Groups
--   volume   base volume before group and player settings
--   pitch    {min,max} random PlaybackSpeed range
--   cooldown minimum seconds between two plays of the same key
--   voices   maximum simultaneous instances; the oldest stops first
--   rolloff  {min,max} distance for 3D playback
--   looped   music and ambience loops
local Library = {}

-- `setting` is the replicated player attribute that scales the whole group.
Library.Groups = {
	Music = { volume = 0.5, setting = "MusicVolume" },
	SFX = { volume = 1, setting = "SFXVolume" },
	UI = { volume = 0.7, setting = "SFXVolume" },
	Ambient = { volume = 0.6, setting = "SFXVolume" },
}

-- Sources (all free, public in any experience): Roblox, ProSoundEffects and
-- APM licensed libraries, DailySoundsFX (synthesized originals), one community
-- upload (Glockenspiel C6 by AEinsertnamelol).
local function id(n)
	return "rbxassetid://" .. n
end
local crunch = { id(9113959343), id(9113959332), id(9113959737) } -- PSE "Crack Egg Crunchy" 11/9/15
local coin = { id(130378474223829) } -- DailySounds "Coin Pickup"

Library.Sounds = {
	-- Tool swing
	SwingWhoosh = {
		ids = { id(12222200) },
		group = "SFX",
		volume = 0.45,
		pitch = { 1.05, 1.25 },
		voices = 6,
		rolloff = { 8, 60 },
	}, -- Roblox swoosh.wav

	-- Egg hits; EggHit pitch also rises with the local combo
	EggHit = { ids = crunch, group = "SFX", volume = 0.75, pitch = { 1.1, 1.25 }, voices = 8, rolloff = { 8, 70 } },
	EggHitCrit = { ids = coin, group = "SFX", volume = 0.6, pitch = { 1.25, 1.35 }, voices = 4, rolloff = { 8, 70 } },
	EggCrack = {
		ids = { id(9113959071), id(9113958797) },
		group = "SFX",
		volume = 0.9,
		pitch = { 0.85, 0.95 },
		voices = 4,
		rolloff = { 8, 80 },
	}, -- PSE crunchy 6/4
	EggBreak = {
		ids = { id(94978851787238) },
		group = "SFX",
		volume = 0.55,
		pitch = { 1.15, 1.25 },
		voices = 3,
		rolloff = { 10, 90 },
	}, -- DailySounds "Deep Impact Boom"

	-- Hatching
	HatchHeart = {
		ids = { id(9119882039) },
		group = "SFX",
		volume = 0.7,
		pitch = { 1, 1 },
		voices = 3,
		rolloff = { 10, 100 },
	}, -- PSE "Synth Whomps 38"
	HatchTry = {
		ids = { id(9119879867) },
		group = "SFX",
		volume = 0.45,
		pitch = { 0.95, 1.05 },
		voices = 3,
		rolloff = { 10, 100 },
	}, -- PSE "Synth Whomps 9"
	-- One clean note; HatchEffects pitches it along a pentatonic scale.
	HatchChime = {
		ids = { id(72644163309528) },
		group = "SFX",
		volume = 0.6,
		pitch = { 1, 1 },
		voices = 4,
		rolloff = { 10, 110 },
	}, -- "Glockenspiel C6"
	HatchShimmer = {
		ids = { id(9114369623) },
		group = "SFX",
		volume = 0.45,
		pitch = { 1, 1 },
		voices = 2,
		rolloff = { 10, 110 },
	}, -- PSE "Fairy Dust 1"
	HatchRiser = {
		ids = { id(9040281199) },
		group = "SFX",
		volume = 0.4,
		pitch = { 1, 1 },
		voices = 2,
		rolloff = { 10, 110 },
	}, -- APM "Heated Hijack" (orchestral riser, 6 s)
	HatchInhale = {
		ids = { id(9118158113) },
		group = "SFX",
		volume = 0.6,
		pitch = { 1, 1 },
		voices = 2,
		rolloff = { 10, 110 },
	}, -- PSE "Reversed Whoosh Backwards Hissing Burst 2"
	HatchShatter = {
		ids = { id(9114592102) },
		group = "SFX",
		volume = 0.55,
		pitch = { 1.15, 1.3 },
		voices = 3,
		rolloff = { 10, 120 },
	}, -- PSE "Glass Breaks 11"
	HatchPop = {
		ids = { id(106984966606682) },
		group = "SFX",
		volume = 0.9,
		pitch = { 0.75, 0.85 },
		voices = 3,
		rolloff = { 10, 120 },
	}, -- DailySounds "Cartoon Pop"
	RevealCommon = {
		ids = { id(9116394545) },
		group = "SFX",
		volume = 0.35,
		pitch = { 1.1, 1.1 },
		voices = 2,
		rolloff = { 10, 120 },
	}, -- PSE "Magic Glows" 1
	RevealRare = {
		ids = { id(9116395089) },
		group = "SFX",
		volume = 0.6,
		pitch = { 1, 1 },
		voices = 2,
		rolloff = { 10, 140 },
	}, -- PSE "Magic Glows" 4
	RevealEpic = {
		ids = { id(1839997962) },
		group = "SFX",
		volume = 0.5,
		pitch = { 1, 1 },
		voices = 2,
		rolloff = { 10, 160 },
	}, -- APM "Right Answer"
	RevealLegendary = {
		ids = { id(1839881844) },
		group = "SFX",
		volume = 0.7,
		pitch = { 1, 1 },
		voices = 2,
		rolloff = { 10, 180 },
	}, -- APM "Spinning Around (b)"

	-- Interface
	UIClick = {
		ids = { id(88442833509532) },
		group = "UI",
		volume = 1.5,
		pitch = { 1, 1.05 },
		cooldown = 0.03,
		voices = 3,
	}, -- "ui-simple-button-click" (assets/audio/sfx/ui-click.mp3)
}

-- Reveal sound by pet rarity; unknown rarities fall back to RevealCommon.
Library.Reveal = {
	Common = "RevealCommon",
	Uncommon = "RevealCommon",
	Rare = "RevealRare",
	Epic = "RevealEpic",
	Legendary = "RevealLegendary",
	Mythic = "RevealLegendary",
	Titanic = "RevealLegendary",
}

return Library
