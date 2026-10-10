-- Run through MCP in Edit. Uses fresh source and isolated fixtures, never player profiles.
local RS, server = game.ReplicatedStorage, game.ServerScriptService
local fixture = Instance.new("Folder")
fixture.Name = "AuditBugFixQA"
fixture.Parent = workspace
local modules = {}
local function freshRequire(module)
	return modules[module] or require(module)
end
local function evaluate(source, extras)
	local chunk = assert(loadstring(source))
	local environment = setmetatable(extras or {}, { __index = getfenv() })
	environment.require = rawget(environment, "require") or freshRequire
	setfenv(chunk, environment)
	return chunk()
end
local function copy(value)
	if type(value) ~= "table" then
		return value
	end
	local result = {}
	for key, child in value do
		result[key] = copy(child)
	end
	return result
end
local ok, result = pcall(function()
	local Game = evaluate(RS.GameConfig.Source)
	modules[RS.GameConfig] = Game
	local DataConfig = evaluate(server.PlayerData.Config.Source, { script = server.PlayerData.Config })
	modules[server.PlayerData.Config] = DataConfig
	for _, isStudio in { true, false } do
		local mode = evaluate(server.PlayerData.Config.Source, {
			game = {
				GetService = function()
					return {
						IsStudio = function()
							return isStudio
						end,
					}
				end,
			},
			script = {
				GetAttribute = function()
					return "Mock"
				end,
			},
		})
		assert(mode.StudioMode == (isStudio and "Mock" or "Persistent"), "Studio Mock override affects live")
	end
	local Schema = evaluate(server.PlayerData.Schema.Source, { script = server.PlayerData.Schema })
	modules[server.PlayerData.Schema] = Schema
	modules[RS.PetVisuals] = evaluate(RS.PetVisuals.Source)
	local dataFolder = server.PlayerData:Clone()
	dataFolder.Parent = fixture
	local signal = function()
		local callbacks = {}
		return {
			Connect = function(_, callback)
				table.insert(callbacks, callback)
				return { Disconnect = function() end }
			end,
			Fire = function()
				for _, callback in callbacks do
					callback()
				end
			end,
		}
	end
	local currentProfile
	local store = { Name = "IsolatedAuditQA" }
	function store:StartSessionAsync()
		return currentProfile
	end
	local profileStore = {
		DataStoreState = "Access",
		IsClosing = false,
		SetConstant = function() end,
		New = function()
			return store
		end,
		OnError = signal(),
	}
	local lastWarning
	local service = evaluate(dataFolder.Service.Source, {
		script = dataFolder.Service,
		warn = function(message)
			lastWarning = message
		end,
		require = function(module)
			if module == game.ServerStorage.ServerPackages.ProfileStore then
				return profileStore
			elseif module == dataFolder.Config then
				return DataConfig
			elseif module == dataFolder.Schema then
				return Schema
			end
			return freshRequire(module)
		end,
	})
	local function profile(data, reconcileError)
		local object = {
			Data = copy(data),
			active = true,
			ended = 0,
			OnSave = signal(),
			OnSessionEnd = signal(),
			OnAfterSave = signal(),
		}
		function object:AddUserId() end
		function object:Reconcile()
			if reconcileError then
				error("Injected reconciliation failure")
			end
		end
		function object:IsActive()
			return self.active
		end
		function object:EndSession()
			self.ended += 1
			self.active = false
			self.OnSessionEnd:Fire()
		end
		return object
	end
	local function player()
		local object = { UserId = 991, Parent = game.Players, attributes = {}, kicked = false }
		function object:SetAttribute(key, value)
			self.attributes[key] = value
		end
		function object:Kick()
			self.kicked = true
		end
		return object
	end
	for _, invalidValue in { 7, "bad", false } do
		local data = copy(Schema.Template)
		data.discovered, data.discoveries = true, invalidValue
		currentProfile = profile(data)
		local p = player()
		assert(service.Load(p) == nil and p.kicked, "Malformed profile did not fail cleanly")
		assert(currentProfile.ended == 1 and not service.IsActive(p), "Rejected session leaked")
		assert(currentProfile.Data.discoveries == invalidValue, "Rejected profile was overwritten")
		assert(p.attributes.PetDataReady == false, "Rejected profile enabled gameplay")
		-- A released load can be retried; successful load retains normal legacy migration.
		currentProfile = profile(Schema.Template)
		currentProfile.Data.discovered = true
		p.kicked = false
		local saved = assert(service.Load(p), "Retry after rejection remains blocked: " .. tostring(lastWarning))
		assert(saved.discoveries[1] == "TestChick" and service.IsActive(p), "Valid legacy profile changed")
		service.Release(p)
		assert(currentProfile.ended == 1 and not service.IsActive(p), "Valid release failed")
	end
	currentProfile = profile(Schema.Template, true)
	local p = player()
	assert(service.Load(p) == nil and p.kicked and currentProfile.ended == 1, "Preparation exception leaked a session")

	-- Spawn the actual field egg and aim at a farther egg while a nearer egg is present.
	local adventureSource = server.Adventure.Source
	local stop = assert(adventureSource:find("local function swing", 1, true))
	local spawn = evaluate(
		adventureSource:sub(1, stop - 1)
			.. "\nreturn function(folder,world) field=folder services={world=world} return spawnEgg end"
	)
	local world = { label = function() end }
	local spawnEgg = spawn(fixture, world)
	local nearer = spawnEgg(Game.Eggs[1], Vector3.new(5, 10000, 0), 1)
	local aimed = spawnEgg(Game.Eggs[1], Vector3.new(0, 10000, -5), 1)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { nearer.model, aimed.model }
	local hit = assert(
		workspace:Raycast(Vector3.new(0, 10002, 20), Vector3.new(0, 0, -50), params),
		"Field egg cannot be aimed at"
	)
	assert(hit.Instance:IsDescendantOf(aimed.model), "Ray picked the nearer egg instead of the aimed egg")
	local character = Instance.new("Model", fixture)
	local root = Instance.new("Part", character)
	root.Name, root.Anchored, root.Position = "HumanoidRootPart", true, Vector3.new(0, 10002, 1)
	local pickaxe = Instance.new("Tool", character)
	pickaxe:SetAttribute("Pickaxe", true)
	local fakePlayer = {
		Character = character,
		GetMouse = function()
			return { Target = hit.Instance }
		end,
	}
	local controls = game.StarterPlayer.StarterPlayerScripts.AdventureControls.Source
	controls = controls:sub(1, assert(controls:find("local function swing", 1, true)) - 1)
	controls = controls:gsub("local player = Players.LocalPlayer", "local player = __player")
	-- Avoid waiting for runtime remotes in Edit; target selection does not use them.
	controls = controls:gsub('local action = RS:WaitForChild%("GameplayAction"%)', "local action = nil")
	controls = controls:gsub('local feedback = RS:WaitForChild%("GameplayFeedback"%)', "local feedback = nil")
	controls ..= "\nreturn targetEgg"
	local target = evaluate(controls, { __player = fakePlayer })
	assert(target() == aimed.model, "Cursor selection loses to nearest fallback")
	local camera = workspace.CurrentCamera
	local originalCamera = camera.CFrame
	camera.CFrame = CFrame.lookAt(Vector3.new(0, 10007, 20), Vector3.new(0, 10002, -5))
	local point = camera:WorldToViewportPoint(aimed.model.PrimaryPart.Position)
	fakePlayer.GetMouse = function()
		return { Target = nearer.model.PrimaryPart }
	end
	local touchTarget = target(Vector2.new(point.X, point.Y))
	camera.CFrame = originalCamera
	assert(touchTarget == aimed.model, "Touch aim uses stale mouse target instead of the tap")
	fakePlayer.GetMouse = function()
		return { Target = hit.Instance }
	end
	target = evaluate(controls, { __player = fakePlayer })
	aimed.model:SetAttribute("Hatching", true)
	-- The nearest fallback uses the game's folder; substitute only that folder lookup.
	controls = controls:gsub('local folder = workspace.Map:FindFirstChild%("Adventure"%)', "local folder = __folder")
	target = evaluate(controls, { __player = fakePlayer, __folder = fixture })
	assert(target() == nearer.model, "Hatching egg blocks the nearest valid fallback")
	local visuals = evaluate(RS.PetVisuals.Source)
	for _, model in { visuals.egg(), visuals.pet("Chicken", 1) } do
		for _, part in model:GetDescendants() do
			if part:IsA("BasePart") then
				assert(not part.CanQuery, "Base visuals now intercept placement rays")
			end
		end
		model:Destroy()
	end

	-- Render the real component with controlled hooks. Exercise its actual buttons and payload.
	local confirmation, rendered, texts, request
	local React = {
		useState = function()
			return confirmation, function(value)
				confirmation = value
			end
		end,
		useEffect = function() end,
		createElement = function(kind, props, children)
			local element = { kind = kind, props = props, children = children }
			if props and props.name then
				rendered[props.name] = element
			elseif props and props.Name and not rendered[props.Name] then
				rendered[props.Name] = element
			end
			return element
		end,
	}
	local UI = {
		text = function(text)
			table.insert(texts, text)
			return {}
		end,
	}
	local panel = evaluate(RS.ShopUI.AdventurePanels.Source, {
		script = RS.ShopUI.AdventurePanels,
		require = function(module)
			if module == RS.Packages.React then
				return React
			end
			if module == RS.ShopUI.UI then
				return UI
			end
			if module == RS.ShopUI.Theme then
				return { colors = {} }
			end
			if module == RS.ShopUI.ModelPreview then
				return function() end
			end
			return freshRequire(module)
		end,
	})
	local pets = {
		{ id = "legacy-a", kind = "TestChick", name = "Chicken", weight = 1, equipped = false },
		{ id = "legacy-b", kind = "TestChick", name = "Chicken", weight = 2, equipped = false },
		{ id = "legacy-c", kind = "TestChick", name = "Chicken", weight = 3, equipped = true },
		{ id = "modern", kind = "Chicken", name = "Chicken", weight = 1, equipped = false },
	}
	local function render(items)
		rendered, texts = {}, {}
		panel({
			kind = "Merge Pets",
			width = 800,
			height = 600,
			headerH = 96,
			pets = items,
			data = {},
			onAction = function(name, payload)
				request = { name = name, payload = payload }
			end,
		})
	end
	render(pets)
	assert(rendered.MergeTestChick and not rendered.MergeTestChick.props.disabled, "Legacy merge row missing")
	assert(rendered.MergeChicken.props.disabled, "Legacy pets incorrectly count as modern Chicken")
	rendered.MergeTestChick.props.onClick()
	render(pets)
	assert(rendered.ConfirmMerge.props.disabled, "Merge confirms without three selections")
	for _, pet in { pets[1], pets[2], pets[3] } do
		rendered["SelectMergePet" .. pet.id].props.onClick()
		render(pets)
	end
	assert(not rendered.ConfirmMerge.props.disabled, "Selected triple cannot confirm")
	rendered.ConfirmMerge.props.onClick()
	assert(request.name == "MergePets" and request.payload.kind == "TestChick", "Legacy merge changes saved kind")
	local selection = evaluate(server.MergeSelection.Source)
	local matches, weight = selection.resolve(pets, request.payload.kind, request.payload.pets)
	assert(matches and #matches == 3 and math.abs(weight - 6.9) < 0.0001, "Legacy merge identities or weight changed")
	assert(Game.income(pets[1]) == 5 and pets[4].kind == "Chicken", "Legacy income or modern pet changed")
	-- Any three of four may be selected, including the last item; a fourth is disabled.
	confirmation, request = nil, nil
	local fourth = { id = "legacy-d", kind = "TestChick", name = "Chicken", weight = 4, equipped = false }
	table.insert(pets, fourth)
	render(pets)
	rendered.MergeTestChick.props.onClick()
	render(pets)
	for _, pet in { pets[2], pets[3], fourth } do
		rendered["SelectMergePet" .. pet.id].props.onClick()
		render(pets)
	end
	assert(rendered["SelectMergePetlegacy-a"].props.disabled, "Fourth selection allowed")
	rendered.ConfirmMerge.props.onClick()
	assert(table.find(request.payload.pets, fourth.id) and not table.find(request.payload.pets, pets[1].id), "Merge still uses the first triple")
	rendered["SelectMergePetlegacy-b"].props.onClick()
	render(pets)
	assert(rendered.ConfirmMerge.props.disabled, "Merge confirms after deselection")
	confirmation = nil
	render({})
	assert(#texts == 0 and rendered.MergeList, "Empty Merge shows instructions or loses its list")
	local petSource = game.StarterPlayer.StarterPlayerScripts.PetControls.Source
	local first = assert(petSource:find("local function refreshModel", 1, true))
	local last = assert(petSource:find("local function refreshVisibility", first, true))
	local shown = true
	local refresh = evaluate("local player=__player\n" .. petSource:sub(first, last - 1) .. "\nreturn refreshModel", {
		__player = {
			UserId = 991,
			GetAttribute = function()
				return shown
			end,
		},
	})
	local pet = visuals.pet("Chicken", 1)
	pet:SetAttribute("PetVisual", true)
	pet:SetAttribute("OwnerUserId", 991)
	pet.Parent = fixture
	local label = Instance.new("BillboardGui", pet)
	local outline = Instance.new("Highlight", pet)
	for _, visible in { false, true } do
		shown = visible
		refresh(pet)
		assert(label.Enabled == visible and outline.Enabled == visible, "Pet label/highlight visibility diverged")
		assert(pet.PrimaryPart.LocalTransparencyModifier == (visible and 0 or 1), "Pet body visibility changed")
	end
	local effectsSource, replacements =
		RS.PickaxeEffects.Source:gsub("return Effects%s*$", "return {addCracks=addCracks}")
	assert(replacements == 1, "Crack test hook not found")
	local effects = evaluate(effectsSource)
	local shell = visuals.egg()
	shell.Parent = fixture
	effects.addCracks(shell, 3)
	local crack = assert(shell:FindFirstChild("EggCrack"), "Crack geometry failed to generate")
	assert(crack.Size.X > 0 and not crack.CanQuery and not crack.CanCollide, "Cracks changed hit detection")
	return "PASS: malformed load rejection/release/retry, preparation exceptions, legacy load, cursor/touch egg priority/fallback, base ray exclusion, legacy Merge IDs/kind/weight/income, empty Merge, Studio-only Mock override, pet visibility, crack geometry"
end)
fixture:Destroy()
assert(ok, result)
return result
