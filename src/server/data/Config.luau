local Config = {
	StudioStoreName = "PlayerProfiles_Studio_v1",
	LiveStoreName = "PlayerProfiles_Live_v1",
	-- Persistent Studio saves use a separate real DataStore. Mock is an explicit opt-in.
	StudioMode = "Persistent",
	AutoSaveSeconds = 60,
	LoadTimeoutSeconds = 90,
	OfflineLimitSeconds = 8 * 3600,
	MigrateLegacyLive = true,
	LegacyLiveStoreName = "PetBases_v1",
}
function Config.StoreName(isStudio)
	return isStudio and Config.StudioStoreName or Config.LiveStoreName
end
assert(Config.StudioStoreName ~= Config.LiveStoreName, "Studio and live DataStores must be different")
return table.freeze(Config)
