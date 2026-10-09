-- Client audio runtime. Every sound goes through a SoundGroup whose volume is
-- the group base volume times the player's setting, so individual Sound.Volume
-- is never rescaled after creation (this used to apply SFXVolume twice).
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local ContentProvider = game:GetService("ContentProvider")
local TweenService = game:GetService("TweenService")
local Library = require(script.Parent:WaitForChild("SoundLibrary"))

local Audio = {}
local groups = {}
local active = {}
local lastPlayed = {}
local random = Random.new()
local started = false
local music, musicKey

local function applyVolume(key)
	local info = Library.Groups[key]
	local player = Players.LocalPlayer
	local setting = player and player:GetAttribute(info.setting)
	groups[key].Volume = info.volume * (type(setting) == "number" and math.clamp(setting, 0, 1) or 1)
end

-- Sounds created outside Audio (character sounds, sounds placed in Studio)
-- still follow the settings: music when tagged IsMusic, otherwise SFX.
local function adopt(sound)
	pcall(function()
		if sound:IsA("Sound") and not sound.SoundGroup then
			sound.SoundGroup = groups[sound:GetAttribute("IsMusic") == true and "Music" or "SFX"]
		end
	end)
end

function Audio.start()
	if started or not RunService:IsClient() then
		return
	end
	started = true
	local folder = Instance.new("Folder")
	folder.Name = "AudioGroups"
	for key in Library.Groups do
		local group = Instance.new("SoundGroup")
		group.Name = key
		group.Parent = folder
		groups[key] = group
		applyVolume(key)
		Players.LocalPlayer:GetAttributeChangedSignal(Library.Groups[key].setting):Connect(function()
			applyVolume(key)
		end)
	end
	folder.Parent = SoundService
	for _, item in game:GetDescendants() do
		adopt(item)
	end
	game.DescendantAdded:Connect(function(item)
		if item:IsA("Sound") then
			task.defer(adopt, item)
		end
	end)
	task.spawn(function()
		local preload = {}
		for _, info in Library.Sounds do
			for _, id in info.ids do
				local sound = Instance.new("Sound")
				sound.SoundId = id
				table.insert(preload, sound)
			end
		end
		pcall(ContentProvider.PreloadAsync, ContentProvider, preload)
		for _, sound in preload do
			sound:Destroy()
		end
	end)
end

function Audio.group(key)
	Audio.start()
	return groups[key]
end

-- target: nil plays 2D, a BasePart/Attachment follows it, a Vector3 is a fixed point.
-- options.pitch and options.volume multiply the catalogue values.
function Audio.play(key, target, options)
	local info = Library.Sounds[key]
	if not info then
		warn("Audio: unknown sound " .. tostring(key))
		return nil
	end
	if not RunService:IsClient() then
		return nil
	end
	Audio.start()
	local now = os.clock()
	if info.cooldown and now - (lastPlayed[key] or -1e6) < info.cooldown then
		return nil
	end
	lastPlayed[key] = now
	local list = active[key] or {}
	active[key] = list
	while #list >= (info.voices or 8) do
		local oldest = table.remove(list, 1)
		if oldest.Parent then
			oldest:Destroy()
		end
	end
	options = options or {}
	local sound = Instance.new("Sound")
	sound.Name = key
	sound.SoundId = info.ids[random:NextInteger(1, #info.ids)]
	sound.Volume = info.volume * (options.volume or 1)
	local pitch = info.pitch or { 1, 1 }
	sound.PlaybackSpeed = random:NextNumber(pitch[1], pitch[2]) * (options.pitch or 1)
	sound.Looped = info.looped == true
	sound.SoundGroup = groups[info.group] or groups.SFX
	local rolloff = info.rolloff or { 8, 80 }
	sound.RollOffMinDistance, sound.RollOffMaxDistance = rolloff[1], rolloff[2]
	local holder
	if typeof(target) == "Vector3" then
		holder = Instance.new("Attachment")
		holder.Name = "AudioPoint"
		holder.Position = target -- Terrain sits at the origin
		holder.Parent = workspace.Terrain
		sound.Parent = holder
	elseif
		typeof(target) == "Instance"
		and (target:IsA("BasePart") or target:IsA("Attachment"))
		and target:IsDescendantOf(workspace)
	then
		sound.Parent = target
	else
		sound.Parent = sound.SoundGroup
	end
	table.insert(list, sound)
	local function cleanup()
		local index = table.find(list, sound)
		if index then
			table.remove(list, index)
		end
		if holder then
			holder:Destroy()
		else
			sound:Destroy()
		end
	end
	sound.Ended:Once(cleanup)
	sound.Destroying:Once(function()
		local index = table.find(list, sound)
		if index then
			table.remove(list, index)
		end
		if holder and holder.Parent then
			holder:Destroy()
		end
	end)
	if not sound.Looped then
		-- Fallback when Ended never fires (asset failed to load, parent removed).
		task.delay(10, function()
			if sound.Parent then
				cleanup()
			end
		end)
	end
	sound:Play()
	return sound
end

local function fadeOut(sound, time)
	local tween = TweenService:Create(sound, TweenInfo.new(time), { Volume = 0 })
	tween.Completed:Once(function()
		sound:Destroy()
	end)
	tween:Play()
end

-- Crossfades to a looped catalogue entry; the same key keeps playing.
function Audio.playMusic(key, fade)
	if musicKey == key and music and music.Parent then
		return music
	end
	Audio.stopMusic(fade)
	local sound = Audio.play(key)
	if not sound then
		return nil
	end
	sound.Looped = true
	local volume = sound.Volume
	sound.Volume = 0
	TweenService:Create(sound, TweenInfo.new(fade or 1.5), { Volume = volume }):Play()
	music, musicKey = sound, key
	return sound
end

function Audio.stopMusic(fade)
	if music and music.Parent then
		fadeOut(music, fade or 1.5)
	end
	music, musicKey = nil, nil
end

return Audio
