local RS = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local MarketplaceService = game:GetService("MarketplaceService")
local GuiService = game:GetService("GuiService")
local React = require(RS.Packages.React)
local UI = require(script.Parent.UI)
local Theme = require(script.Parent.Theme)
local Config = require(script.Parent.Config)
local Inventory = require(script.Parent.Inventory)
local OfflineCash = require(script.Parent.OfflineCash)
local Sidebar = require(script.Parent.Sidebar)
local Hotbar = require(script.Parent.Hotbar)
local useBackpack = require(script.Parent.useBackpack)
local useToolDrag = require(script.Parent.useToolDrag)
local ToolDragPreview = require(script.Parent.ToolDragPreview)
local Settings = require(script.Parent.Settings)
local EquipmentShop = require(script.Parent.EquipmentShop)
local ModelPreview = require(script.Parent.ModelPreview)
local Game = require(RS:WaitForChild("GameConfig"))
local AdventurePanels = require(script.Parent.AdventurePanels)
local e = React.createElement
local C = Theme.colors
local player = Players.LocalPlayer
local function decode(value)
	if type(value) ~= "string" then
		return nil
	end
	local ok, list = pcall(function()
		return game.HttpService:JSONDecode(value)
	end)
	return ok and type(list) == "table" and list or nil
end
local function number(value)
	for _, unit in { { 1e15, "Qa" }, { 1e12, "T" }, { 1e9, "B" }, { 1e6, "M" }, { 1e3, "K" } } do
		if math.abs(value) >= unit[1] then
			return string.format("%.1f", value / unit[1]):gsub("%.0$", "") .. unit[2]
		end
	end
	return tostring(math.floor(value))
end
local function readData()
	local data = {}
	for key, value in Config.DataDefaults do
		data[key] = player:GetAttribute(key)
		if data[key] == nil then
			data[key] = value
		end
	end
	data.DiscoveredPets = player:GetAttribute("DiscoveredPets")
	data.UnlockedPets = player:GetAttribute("UnlockedPets")
	data.TotalPets = player:GetAttribute("TotalPets")
	data.InField = player:GetAttribute("InField")
	data.PetInventory = player:GetAttribute("PetInventory")
	data.GrowingEggs = player:GetAttribute("GrowingEggs")
	data.PetCapacity = player:GetAttribute("PetCapacity") or Config.PetCapacity
	data.ReducedMotion = player:GetAttribute("ReducedMotion") == true
	for _, key in
		{
			"MusicVolume",
			"SFXVolume",
			"ViewOthersPets",
			"ViewMyPets",
			"ViewMyEggs",
			"PetSlotCost",
			"GrowAllCost",
			"CollectionRewardClaimed",
			"PetDataReady",
			"PlacementKind",
			"PlacementValid",
			"PlacementError",
			"OwnedPickaxes",
			"OwnedTrails",
			"PickaxeLevel",
			"TrailLevel",
			"PenLevel",
			"TreadmillLevel",
			"SatchelLevel",
			"CarryingCount",
			"CarryingName",
			"GameplayNotice",
			"GameplayNoticeAt",
			"AutoSwing",
		}
	do
		data[key] = player:GetAttribute(key)
	end
	return data
end
local function transparent(x, y, w, h, children, name)
	return e(
		"Frame",
		{ Name = name, BackgroundTransparency = 1, Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(w, h) },
		children
	)
end
local function App(props)
	local viewport, setViewport = React.useState(workspace.CurrentCamera.ViewportSize)
	local data, setData = React.useState(readData)
	local screen, setScreen = React.useState((readData().OfflineCash > 0) and "Offline Cash" or nil)
	local indexSelection, setIndexSelection = React.useState("Chicken")
	local closing, setClosing = React.useState(false)
	local inventoryKind, setInventoryKind = React.useState("Pets")
	local busy, setBusy = React.useState(false)
	local pendingLabel, setPendingLabel = React.useState(nil)
	local busyRef = React.useRef(false)
	local message, setMessage = React.useState(nil)
	local offlineShown = React.useRef(false)
	local slow, setSlow = React.useState(player:GetAttribute("SlowMode") == true)
	local shopCategory, setShopCategory = React.useState("Featured")
	local current = React.useRef({ screen = screen, category = shopCategory })
	local navigationRevision = React.useRef(0)
	current.current = { screen = screen, category = shopCategory, closing = closing }
	local focusBefore = React.useRef(nil)
	local scrollRef = React.useRef(nil)
	local sectionOffsets = React.useRef({})
	local scrollPositions = React.useRef({})
	local closingRef = React.useRef(nil)
	local mounted = React.useRef(true)
	local rootRef = React.useRef(nil)
	local compact = viewport.X < 900
	local scale = compact and 1 or math.clamp(math.min(viewport.X / 1600, viewport.Y / 900), 0.75, 1.25)
	local width, height = viewport.X / scale, viewport.Y / scale
	local short = height < 520
	local narrow = width < 600
	local windowW = compact and width - 32
		or math.min(screen == "Settings" and 720 or screen == "Offline Cash" and 900 or 1100, width - 460)
	local windowH = compact and (short and height - (narrow and 204 or 148) or height - (narrow and 314 or 258))
		or math.min(660, height - 210)
	local wx, wy =
		(width - windowW) / 2, compact and (narrow and 180 or 124) or math.max(64, (height - windowH) / 2 - 24)
	local headerH = compact and 72 or 96
	if (screen == "Shop" or screen == "Pickaxe Shop" or screen == "Trails Shop") and compact then
		windowH = height - 80
		wy = 56
		headerH = 64
	end
	if screen == "Index" and compact and short then
		windowH = height - 76
		wy = 52
		headerH = 48
	end
	if screen == "Merge Pets" and short then
		windowH = height - 80
		wy = 56
		headerH = 64
	end
	if screen == "Offline Cash" then
		windowW = math.min(1040, width - 32)
		windowH = math.min(width < 600 and 560 or 740, height - 112)
		if width >= 600 then
			windowW = math.min(windowW, windowH * 1.48)
		end
		wx, wy = (width - windowW) / 2, (height - windowH) / 2
		headerH = width < 600 and 72 or short and 64 or 110
	end
	local open = React.useCallback(function(name)
		navigationRevision.current += 1
		if current.current.screen == name and not current.current.closing then
			if name == "Shop" and scrollRef.current then
				scrollPositions.current.Shop = scrollRef.current.CanvasPosition
				scrollPositions.current.category = current.current.category
			end
			setClosing(true)
			return
		end
		setClosing(false)
		setScreen(name)
	end, {})
	local close = React.useCallback(function()
		navigationRevision.current += 1
		if current.current.screen == "Shop" and scrollRef.current then
			scrollPositions.current.Shop = scrollRef.current.CanvasPosition
			scrollPositions.current.category = current.current.category
		end
		setClosing(true)
	end, {})
	local closed = React.useCallback(function()
		if not current.current.closing then
			return
		end
		setScreen(nil)
		setClosing(false)
	end, {})
	local inventoryOpen = screen == "Inventory"
	local sidebarOpen = screen == "Pets" or screen == "Eggs"
	local toggleInventory = React.useCallback(function()
		open("Inventory")
	end, { open })
	local backpack, equipTool, assignTool = useBackpack(toggleInventory, not screen or (inventoryOpen and not closing))
	local drag = useToolDrag({
		enabled = inventoryOpen and not closing,
		kind = inventoryKind,
		tools = backpack.tools,
		slotRefs = backpack.slotRefs,
		inventoryRef = backpack.inventoryRef,
		assign = assignTool,
	})
	local action = React.useCallback(function(name, payload, onSuccess)
		if name == "SetSetting" and payload.setting == "ReducedMotion" then
			player:SetAttribute("ReducedMotion", payload.value == true)
			return
		end
		local remote = RS:FindFirstChild("UIAction")
		if not remote or not remote:IsA("RemoteFunction") then
			setMessage("Loading your base...")
			return
		end
		if busyRef.current then
			return
		end
		busyRef.current = true
		local owner = current.current.screen
		local ownerRevision = navigationRevision.current
		local pending = "Updating…"
		if name == "SetSetting" then
			pending = "Saving…"
		elseif name == "BuyPickaxe" or name == "BuyTrail" then
			local owned = decode(player:GetAttribute(name == "BuyPickaxe" and "OwnedPickaxes" or "OwnedTrails"))
				or { 1 }
			pending = table.find(owned, payload.index) and "Equipping…" or "Buying…"
		elseif name == "AddPetSlot" or name == "UpgradeSatchel" then
			pending = "Buying…"
		elseif name == "MergePets" then
			pending = "Merging…"
		elseif name == "ClaimOffline" or name == "ClaimCollectionReward" then
			pending = "Claiming…"
		end
		setPendingLabel(pending)
		setMessage(nil)
		setBusy(true)
		task.spawn(function()
			local ok, result = pcall(function()
				return remote:InvokeServer(name, payload)
			end)
			busyRef.current = false
			if not mounted.current then
				return
			end
			setBusy(false)
			setPendingLabel(nil)
			if ok and type(result) == "table" and result.success == true then
				if
					onSuccess
					and current.current.screen == owner
					and navigationRevision.current == ownerRevision
					and not current.current.closing
				then
					onSuccess(result)
				end
				setData(readData())
				setMessage(result.message)
			else
				setMessage(ok and type(result) == "table" and result.message or "Couldn't complete. Try again.")
			end
		end)
	end, { close })
	local pets = React.useMemo(function()
		return decode(data.PetInventory) or {}
	end, { data.PetInventory })
	local eggs = React.useMemo(function()
		return decode(data.GrowingEggs) or {}
	end, { data.GrowingEggs })
	local inventoryTools = React.useMemo(function()
		local result = { Pets = {}, Eggs = {} }
		for _, tool in backpack.tools do
			local kind = tool:GetAttribute("PlacementKind") == "Egg" and "Eggs" or "Pets"
			local assigned = false
			for i = 1, 10 do
				if backpack.slots[i] == tool then
					assigned = true
					break
				end
			end
			if not assigned then
				table.insert(
					result[kind],
					{
						name = tool.Name,
						tool = tool,
						kind = tool:GetAttribute("PetKind"),
						weight = tool:GetAttribute("PetWeight") or 1,
						held = tool == backpack.held,
					}
				)
			end
		end
		return result
	end, { backpack.tools, backpack.slots, backpack.held, backpack.revision })
	local settingsData = React.useMemo(
		function()
			return {
				MusicVolume = data.MusicVolume,
				SFXVolume = data.SFXVolume,
				ViewOthersPets = data.ViewOthersPets,
				ViewMyPets = data.ViewMyPets,
				ViewMyEggs = data.ViewMyEggs,
				ReducedMotion = data.ReducedMotion,
			}
		end,
		{ data.MusicVolume, data.SFXVolume, data.ViewOthersPets, data.ViewMyPets, data.ViewMyEggs, data.ReducedMotion }
	)
	local function purchase(offer)
		local id = offer.gamePassId or offer.productId
		if not id or id <= 0 then
			setMessage("This purchase is not available yet.")
			return
		end
		local ok = pcall(function()
			if offer.gamePassId then
				MarketplaceService:PromptGamePassPurchase(player, id)
			else
				MarketplaceService:PromptProductPurchase(player, id)
			end
		end)
	end
	React.useEffect(function()
		mounted.current = true
		local pending, queued = {}, false
		local function queueData(key)
			pending[key] = true
			if queued then
				return
			end
			queued = true
			task.defer(function()
				queued = false
				if not mounted.current then
					return
				end
				local changes = pending
				pending = {}
				setData(function(previous)
					local nextData
					for changedKey in changes do
						local value = player:GetAttribute(changedKey)
						if changedKey == "ReducedMotion" then
							value = value == true
						elseif changedKey == "PetCapacity" then
							value = value or Config.PetCapacity
						elseif Config.DataDefaults[changedKey] ~= nil and value == nil then
							value = Config.DataDefaults[changedKey]
						end
						if previous[changedKey] ~= value then
							nextData = nextData or table.clone(previous)
							nextData[changedKey] = value
						end
					end
					return nextData or previous
				end)
			end)
		end
		local camera = workspace.CurrentCamera
		local connections =
			{ camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
				setViewport(camera.ViewportSize)
			end) }
		for key in Config.DataDefaults do
			table.insert(
				connections,
				player:GetAttributeChangedSignal(key):Connect(function()
					queueData(key)
				end)
			)
		end
		for _, key in
			{
				"DiscoveredPets",
				"UnlockedPets",
				"TotalPets",
				"PetInventory",
				"GrowingEggs",
				"PetCapacity",
				"ReducedMotion",
				"MusicVolume",
				"SFXVolume",
				"ViewOthersPets",
				"ViewMyPets",
				"ViewMyEggs",
				"PetSlotCost",
				"GrowAllCost",
				"CollectionRewardClaimed",
				"PetDataReady",
				"PlacementKind",
				"PlacementValid",
				"PlacementError",
				"OwnedPickaxes",
				"OwnedTrails",
				"PickaxeLevel",
				"TrailLevel",
				"PenLevel",
				"TreadmillLevel",
				"SatchelLevel",
				"CarryingCount",
				"CarryingName",
				"GameplayNotice",
				"GameplayNoticeAt",
				"AutoSwing",
				"InField",
			}
		do
			table.insert(
				connections,
				player:GetAttributeChangedSignal(key):Connect(function()
					queueData(key)
				end)
			)
		end
		table.insert(
			connections,
			player:GetAttributeChangedSignal("SlowMode"):Connect(function()
				setSlow(player:GetAttribute("SlowMode") == true)
			end)
		)
		if props.controller then
			table.insert(
				connections,
				props.controller.Event:Connect(function(command, value)
					if command == "Open" then
						open(value)
					elseif command == "Close" then
						close()
					elseif command == "Category" then
						setShopCategory(value)
					elseif command == "PreviewViewport" and game:GetService("RunService"):IsStudio() then
						setViewport(value)
					elseif command == "Refresh" then
						setData(readData())
					end
				end)
			)
		end
		return function()
			mounted.current = false
			for _, connection in connections do
				connection:Disconnect()
			end
		end
	end, {})
	React.useEffect(function()
		if player:GetAttribute("UIWindowOpen") ~= (screen ~= nil) then
			player:SetAttribute("UIWindowOpen", screen ~= nil)
		end
		setMessage(nil)
	end, { screen })
	React.useEffect(function()
		return function()
			player:SetAttribute("UIWindowOpen", false)
		end
	end, {})
	React.useEffect(function()
		if data.PetDataReady and data.OfflineCash > 0 and not offlineShown.current then
			offlineShown.current = true
			open("Offline Cash")
		end
	end, { data.PetDataReady, data.OfflineCash })
	React.useEffect(function()
		if not message then
			return
		end
		local active = true
		task.delay(4, function()
			if active and mounted.current then
				setMessage(nil)
			end
		end)
		return function()
			active = false
		end
	end, { message })
	React.useEffect(function()
		if data.GameplayNotice then
			setMessage(data.GameplayNotice)
		end
	end, { data.GameplayNoticeAt })
	React.useEffect(function()
		if screen then
			focusBefore.current = GuiService.SelectedObject
			task.defer(function()
				if mounted.current and UserInputService.GamepadEnabled then
					GuiService.SelectedObject = closingRef.current
				end
			end)
		else
			if focusBefore.current and focusBefore.current.Parent then
				GuiService.SelectedObject = focusBefore.current
			end
		end
		local connection = UserInputService.InputBegan:Connect(function(input, processed)
			if input.KeyCode == Enum.KeyCode.Escape or input.KeyCode == Enum.KeyCode.ButtonB then
				close()
			end
			if processed then
				return
			end
		end)
		return function()
			connection:Disconnect()
		end
	end, { screen })
	React.useEffect(function()
		if screen == "Shop" and scrollRef.current then
			scrollRef.current.CanvasPosition = scrollPositions.current.category == shopCategory
					and scrollPositions.current.Shop
				or Vector2.new(0, math.max(0, (sectionOffsets.current[shopCategory] or 0) - 8) * scale)
		end
	end, { screen })
	React.useEffect(function()
		if screen == "Shop" and scrollRef.current then
			scrollRef.current.CanvasPosition =
				Vector2.new(0, math.max(0, (sectionOffsets.current[shopCategory] or 0) - 8) * scale)
		end
	end, { shopCategory, scale })
	React.useEffect(function()
		return nil
	end, {})
	local function button(label, x, y, w, h, color, callback, icon, textSize, name)
		local section = (
			{ OpenShop = "Shop", OpenIndex = "Index", OpenPets = "Pets", Eggs = "Eggs", OpenSettings = "Settings" }
		)[name or ""]
		return e(
			UI.Button,
			{
				label = label,
				x = x,
				y = y,
				w = w,
				h = h,
				color = color,
				onClick = callback,
				icon = icon,
				textSize = textSize,
				name = name,
				selected = section ~= nil and screen == section and not closing,
			}
		)
	end
	local function shopText(label, x, y, w, h, size, color, align)
		return UI.text(label, x, y, w, h, size, color, align, Theme.index.outline)
	end
	local function shopBuy(offer, x, y, w, h, size)
		local available = (offer.gamePassId or offer.productId or 0) > 0
		return e(UI.Button, {
			variant = "shop",
			name = "Buy_" .. offer.key,
			label = available and "R$ " .. offer.price or "Unavailable",
			disabled = not available,
			x = x,
			y = y,
			w = w,
			h = h,
			textSize = size or 28,
			color = C.green,
			halftone = true,
			hoverScale = 1.025,
			onClick = function()
				purchase(offer)
			end,
		})
	end
	local function offerCard(offer, w, h)
		local compact = compact or w < 440
		local pass = offer.section == "Game Passes"
		local color = offer.section == "Cash Packs" and C.green
			or pass and (offer.key == "cash2" and C.gold or C.blue)
			or C.blue
		local contents
		if pass and w < 300 then
			contents = {
				Title = shopText(offer.amount, 20, 24, w - 40, 48, 27),
				Item = UI.icon(offer.icon, (w - 120) / 2, 84, 120, 108),
				Description = shopText(offer.description, 20, 208, w - 40, 60, 22),
				Buy = shopBuy(offer, 20, h - 76, w - 40, 52),
			}
		elseif pass then
			contents = {
				Item = UI.icon(offer.icon, 20, 22, w * 0.36, h - 118),
				Title = shopText(offer.amount, w * 0.42, 20, w * 0.54 - 16, 56, compact and 30 or 44),
				Description = shopText(offer.description, w * 0.42, 84, w * 0.54 - 16, 100, compact and 22 or 30),
				Buy = shopBuy(offer, 20, h - 76, w - 40, 52),
			}
		else
			contents = {
				Item = UI.icon(offer.icon, 40, 20, w - 80, h - 156),
				Amount = shopText(offer.amount, 16, h - 130, w - 32, 42, compact and 26 or 29),
				Buy = shopBuy(offer, 20, h - 76, w - 40, 52),
			}
		end
		return e(
			UI.Surface,
			{ variant = "shop", shine = true, w = w, h = h, color = color:Lerp(C.body, 0.08), children = contents }
		)
	end
	local function shop()
		local compact = compact or windowW < 900
		local innerW = windowW - 48
		local sections = {}
		local y = 8
		sectionOffsets.current = {}
		sections.Layout = e("UIListLayout", { Padding = UDim.new(0, 24), SortOrder = Enum.SortOrder.LayoutOrder })
		sections.Padding = e(
			"UIPadding",
			{
				PaddingLeft = UDim.new(0, 8),
				PaddingRight = UDim.new(0, 8),
				PaddingTop = UDim.new(0, 8),
				PaddingBottom = UDim.new(0, 20),
			}
		)
		local order = 0
		local function add(name, h, content)
			order += 1
			sections[name] = e(
				"Frame",
				{ Name = name, BackgroundTransparency = 1, Size = UDim2.fromOffset(innerW, h), LayoutOrder = order },
				content
			)
			y += h + 24
		end
		sectionOffsets.current.Featured = 0
		add("FeaturedTitle", 48, { Title = shopText("~Featured~", 8, 0, innerW - 16, 48, 40, C.gold) })
		local heroW = innerW
		local petColumns = compact and math.clamp(math.floor((heroW - 36) / 88), 2, 4) or 7
		local petStart = compact and 20 or 224
		local petWidth = (heroW - petStart - 20 - (petColumns - 1) * 12) / petColumns
		local petH = compact and 112 or 120
		local petY = compact and 270 or 128
		local petRows = math.ceil(7 / petColumns)
		local buyY = petY + petRows * (petH + 12) + 16
		local buyColumns = compact and (heroW < 300 and 1 or 2) or 4
		local buyW = (heroW - 40 - (buyColumns - 1) * 16) / buyColumns
		local featured = {}
		local anyAvailable = false
		for _, offer in Config.Offers do
			if offer.section == "Featured" then
				table.insert(featured, offer)
				if (offer.gamePassId or offer.productId or 0) > 0 then
					anyAvailable = true
				end
			end
		end
		local heroH = anyAvailable and buyY + (math.ceil(#featured / buyColumns) - 1) * 100 + 86 + 16 or buyY + 80
		local hero = {
			Name = shopText(
				Config.FeaturedName,
				compact and 20 or 224,
				20,
				compact and heroW - 40 or heroW - 244,
				58,
				compact and 27 or 37,
				C.gold,
				compact and Enum.TextXAlignment.Center or Enum.TextXAlignment.Left
			),
			Subtitle = shopText(
				"Discover seven powerful pets!",
				compact and 20 or 224,
				84,
				compact and heroW - 40 or heroW - 244,
				compact and 44 or 34,
				compact and 20 or 24,
				nil,
				compact and Enum.TextXAlignment.Center or Enum.TextXAlignment.Left
			),
			Egg = UI.icon(
				"angelEgg",
				compact and heroW < 280 and (heroW - 108) / 2 or 24,
				compact and 140 or 82,
				compact and 108 or 174,
				compact and 112 or 194
			),
		}
		if compact and heroW >= 280 then
			hero.Collection = shopText("Fallen Angel\nCollection", 148, 156, heroW - 168, 72, 24, C.white)
		end
		local chances = { "40%", "30%", "18%", "9.9%", "1%", "1%", "0.1%" }
		for i, chance in chances do
			local col = (i - 1) % petColumns
			local row = math.floor((i - 1) / petColumns)
			hero["Pet" .. i] = e(
				UI.Surface,
				{
					variant = "shop",
					quiet = true,
					x = petStart + col * (petWidth + 12),
					y = petY + row * (petH + 12),
					w = petWidth,
					h = petH,
					color = i > 5 and C.purple:Lerp(C.body, 0.3) or C.muted:Lerp(C.body, 0.4),
					children = {
						Pet = UI.icon("dragon" .. i, 8, 10, petWidth - 16, petH - 50),
						Chance = shopText(chance, 6, petH - 36, petWidth - 12, 26, 20, i > 5 and C.gold or C.white),
					},
				}
			)
		end
		-- Keep quantity and price together, ascending from the smallest pack.
		if anyAvailable then
			for i = 1, #featured do
				local offer = featured[#featured - i + 1]
				local col = (i - 1) % buyColumns
				local row = math.floor((i - 1) / buyColumns)
				local x = 20 + col * (buyW + 16)
				local top = buyY + row * 100
				hero["Amount" .. i] = shopText(offer.amount, x, top, buyW, 28, 23)
				hero["Offer" .. i] = shopBuy(offer, x, top + 34, buyW, 52, compact and 23 or 28)
			end
		else
			hero.Availability = shopText("Unavailable", 20, buyY, heroW - 40, 32, 26, C.white)
			hero.PackSummary = shopText("Egg packs are not available yet.", 20, buyY + 36, heroW - 40, 28, 20, C.white)
		end
		add(
			"Featured",
			heroH + 4,
			{ Hero = e(
				UI.Surface,
				{ variant = "shop", w = heroW, h = heroH, color = C.purple:Lerp(C.body, 0.72), children = hero }
			) }
		)
		for _, section in { "Game Passes", "Speed Packs", "Cash Packs" } do
			sectionOffsets.current[section] = y
			add(
				section .. "Title",
				48,
				{ Title = shopText(
					"~" .. section .. "~",
					8,
					0,
					innerW - 16,
					48,
					40,
					section == "Speed Packs" and C.blue or C.green
				) }
			)
			local list = {}
			for _, offer in Config.Offers do
				if offer.section == section then
					table.insert(list, offer)
				end
			end
			local columns = section == "Game Passes" and (innerW >= 720 and 2 or 1)
				or math.clamp(math.floor((innerW + 24) / 280), 1, 3)
			local cw = (innerW - (columns - 1) * 24) / columns
			local ch = section == "Game Passes" and (cw < 300 and 376 or 276) or 288
			local cards = {
				Layout = e(
					"UIGridLayout",
					{
						CellSize = UDim2.fromOffset(cw, ch),
						CellPadding = UDim2.fromOffset(24, 24),
						FillDirectionMaxCells = columns,
						SortOrder = Enum.SortOrder.LayoutOrder,
					}
				),
			}
			for i, offer in list do
				cards[offer.key] = e(
					"Frame",
					{ Name = offer.key, BackgroundTransparency = 1, LayoutOrder = i },
					{ Card = offerCard(offer, cw, ch) }
				)
			end
			add(section, math.ceil(#list / columns) * (ch + 24) - 24 + 4, cards)
		end
		local tabs = {}
		local tabColumns = windowW < 420 and 2 or 4
		local tabRows = math.ceil(4 / tabColumns)
		local tabW = (windowW - 40 - (tabColumns - 1) * 12) / tabColumns
		local scrollTop = headerH + 76 + (tabRows - 1) * 56
		for i, name in { "Featured", "Game Passes", "Speed Packs", "Cash Packs" } do
			local selected = shopCategory == name
			tabs[name] = e(UI.Button, {
				variant = "shop",
				name = name,
				label = compact and ({ "Egg", "Passes", "Speed", "Cash" })[i] or name,
				x = 20 + ((i - 1) % tabColumns) * (tabW + 12),
				y = headerH + 12 + math.floor((i - 1) / tabColumns) * 56,
				w = tabW,
				h = 44,
				textSize = compact and 18 or 22,
				color = selected and C.green or C.body:Lerp(C.muted, 0.35),
				quiet = not selected,
				selected = selected,
				hoverScale = 1.015,
				onClick = function()
					setShopCategory(name)
				end,
			})
		end
		return {
			Tabs = transparent(0, 0, windowW, scrollTop - 14, tabs),
			ShopScroller = e(
				"ScrollingFrame",
				{
					Name = "ShopScroll",
					ref = scrollRef,
					BackgroundTransparency = 1,
					BorderSizePixel = 0,
					Position = UDim2.fromOffset(16, scrollTop),
					Size = UDim2.fromOffset(windowW - 32, windowH - scrollTop - 24),
					CanvasSize = UDim2.fromOffset(0, y + 12),
					ScrollBarThickness = 5,
					ScrollBarImageColor3 = C.muted:Lerp(C.white, 0.35),
					ScrollingDirection = Enum.ScrollingDirection.Y,
					Active = true,
				},
				sections
			),
		}
	end
	local function index()
		local function text(...)
			local args = table.pack(...)
			return UI.text(args[1], args[2], args[3], args[4], args[5], args[6], args[7], args[8], Theme.index.outline)
		end
		local discovered = decode(data.DiscoveredPets) or {}
		local discoveries = {}
		for _, name in discovered do
			discoveries[name] = true
		end
		local groups = { Forest = {}, Desert = {}, Snow = {}, Titanic = {} }
		local totalOwned, forestOwned = 0, 0
		local selectedPet
		for _, item in Config.Pets do
			local pet = table.clone(item)
			pet.owned = discoveries[item.name] == true
			if pet.owned then
				totalOwned += 1
				if pet.biome == "Forest" then
					forestOwned += 1
				end
			end
			table.insert(groups[pet.biome], pet)
			if pet.key == indexSelection then
				selectedPet = pet
			end
		end
		selectedPet = selectedPet or groups.Forest[1]
		local wide = windowW >= 650
		local gap = short and 16 or 24
		local bodyY = headerH + 16
		local bodyH = windowH - bodyY - 20
		local rightW = wide and math.clamp(windowW * 0.28, 240, 304) or windowW - 32
		local leftW = wide and windowW - rightW - 56 or windowW - 32
		local rightX = wide and 16 + leftW + gap or 16
		local totalH = wide and not short and 56 or 44
		local rewardH = wide and not short and 184 or 88
		local detailH = wide and bodyH - rewardH - gap or 100
		local scrollY = wide and bodyY or bodyY + detailH + 16
		local scrollH = wide and bodyH - totalH - 24 or bodyH - detailH - rewardH - totalH - 48
		local rewardY = wide and bodyY + detailH + gap or bodyY + bodyH - totalH - 16 - rewardH
		local sections = {}
		local sectionY = 12
		local showContext = wide and windowW >= 900
		local contextW = showContext and 110 or 0
		local gridX = showContext and contextW + 28 or 12
		local gridW = leftW - gridX - 18
		local cols = math.clamp(math.floor((gridW + 18) / 130), 2, 4)
		local cell = (gridW - (cols - 1) * 18) / cols
		local cardH = cell + 18
		for _, category in { "Forest", "Desert", "Snow", "Titanic" } do
			local pets = groups[category]
			local owned = 0
			local cards = {
				Layout = e("UIGridLayout", {
					CellSize = UDim2.fromOffset(cell, cardH),
					CellPadding = UDim2.fromOffset(18, 20),
					FillDirectionMaxCells = cols,
					SortOrder = Enum.SortOrder.LayoutOrder,
				}),
			}
			for i, pet in pets do
				if pet.owned then
					owned += 1
				end
				cards[pet.key] = e("Frame", { Name = "PetSlot" .. i, BackgroundTransparency = 1, LayoutOrder = i }, {
					Button = e(UI.Button, {
						name = "SelectPet" .. i,
						w = cell,
						h = cardH,
						variant = "index",
						hoverScale = 1.025,
						color = pet.owned and C[pet.color] or C[pet.color]:Lerp(C.body, 0.7),
						selected = pet.key == selectedPet.key,
						onClick = function()
							setIndexSelection(pet.key)
						end,
						children = {
							Name = text(pet.owned and pet.name or "???", 8, 6, cell - 16, 40, 20),
							Image = e(
								ModelPreview,
								{ kind = pet.key, x = 10, y = 48, w = cell - 20, h = cardH - 60, locked = not pet.owned }
							),
						},
					}),
				})
			end
			local gridY = showContext and 0 or 44
			local gridH = math.ceil(#pets / cols) * (cardH + 20) - 20
			local progressY = gridY + gridH + 22
			local sectionH = progressY + 52 + 12
			local contents = {
				Grid = transparent(gridX, gridY, gridW, gridH, cards, "PetGrid"),
				Progress = UI.progress(category, owned, #pets, gridX, progressY, gridW, 52, C.green, "index"),
			}
			if showContext then
				contents.Context = e(
					UI.Surface,
					{
						variant = "index",
						quiet = true,
						x = 12,
						y = 0,
						w = contextW,
						h = sectionH - 12,
						color = ({ Forest = C.green, Desert = C.gold, Snow = C.blue, Titanic = C.purple })[category]:Lerp(
							C.body,
							0.6
						),
						children = {
							Title = text(category, 8, 16, contextW - 16, 32, 23),
							Egg = UI.icon("egg", 14, 66, contextW - 28, math.min(140, sectionH - 134)),
							Count = text(owned .. "/" .. #pets, 8, sectionH - 64, contextW - 16, 32, 24),
						},
					}
				)
			else
				contents.Title = text(category, 12, 0, leftW - 36, 32, 25, C.white, Enum.TextXAlignment.Left)
			end
			sections[category] = transparent(0, sectionY, leftW, sectionH, contents, category .. "Section")
			sectionY += sectionH + 24
		end
		local pet = selectedPet
		local detailColor = pet.owned and C[pet.color]:Lerp(C.body, 0.35) or C.muted
		local detailContents
		if wide and not short then
			local imageH = math.max(80, detailH - 148)
			detailContents = {
				Image = e(
					ModelPreview,
					{ kind = pet.key, x = 24, y = 12, w = rightW - 48, h = imageH, locked = not pet.owned }
				),
				Name = text(
					pet.owned and pet.name or "???",
					12,
					imageH + 22,
					rightW - 24,
					44,
					pet.name == "Golden Retriever" and 24 or 30
				),
				Rarity = text(pet.owned and pet.rarity or "Not discovered", 12, imageH + 72, rightW - 24, 28, 22),
				Income = text(
					pet.owned and "$" .. number(pet.income) .. "/s" or "Hatch eggs to discover",
					12,
					imageH + 106,
					rightW - 24,
					28,
					pet.owned and 28 or 20,
					pet.owned and C.green or C.white
				),
			}
		else
			detailContents = {
				Image = e(ModelPreview, { kind = pet.key, x = 8, y = 8, w = 84, h = 80, locked = not pet.owned }),
				Name = text(
					pet.owned and pet.name or "???",
					104,
					8,
					rightW - 116,
					38,
					22,
					C.white,
					Enum.TextXAlignment.Left
				),
				Rarity = text(
					pet.owned and pet.rarity or "Undiscovered",
					104,
					46,
					rightW - 116,
					22,
					18,
					C.white,
					Enum.TextXAlignment.Left
				),
				Income = text(
					pet.owned and "$" .. number(pet.income) .. "/s" or "Hatch an egg",
					104,
					70,
					rightW - 116,
					22,
					18,
					pet.owned and C.green or C.white,
					Enum.TextXAlignment.Left
				),
			}
		end
		local claimed = data.CollectionRewardClaimed == true
		local ready = forestOwned == #groups.Forest
		local rewardContents = {
			Label = text("Forest rewards", 12, 8, rightW - 24, 26, 22),
			Action = e(UI.Button, {
				name = "ClaimCollectionReward",
				variant = "index",
				halftone = true,
				label = claimed and "Claimed" or ready and "Claim reward" or "Find all Forest pets",
				x = 12,
				y = wide and not short and 128 or 42,
				w = rightW - 24,
				h = wide and not short and 40 or 32,
				color = C.green,
				textSize = wide and not short and 20 or 18,
				disabled = busy or claimed or not ready,
				onClick = function()
					action("ClaimCollectionReward", {})
				end,
			}),
		}
		if wide and not short then
			rewardContents.Speed = UI.icon("shoe", rightW * 0.25 - 26, 40, 52, 48)
			rewardContents.Cash = UI.icon("cash", rightW * 0.75 - 26, 40, 52, 48)
			rewardContents.SpeedLabel = text("+60", 12, 92, rightW / 2 - 18, 26, 22)
			rewardContents.CashLabel = text("$100", rightW / 2 + 6, 92, rightW / 2 - 18, 26, 22)
		else
			rewardContents.Label = text("$100 · +60 Speed", 12, 8, rightW - 24, 26, 20)
		end
		return {
			ScrollBody = e(
				UI.Surface,
				{
					variant = "index",
					name = "IndexCollection",
					x = 16,
					y = scrollY,
					w = leftW,
					h = scrollH,
					color = C.body,
					quiet = true,
					children = {
						IndexScroller = e("ScrollingFrame", {
							Name = "IndexScroll",
							BackgroundTransparency = 1,
							BorderSizePixel = 0,
							Position = UDim2.fromOffset(0, 4),
							Size = UDim2.new(1, 0, 1, -8),
							CanvasSize = UDim2.fromOffset(0, sectionY),
							ScrollBarThickness = 5,
							ScrollBarImageColor3 = C.white,
							ScrollingDirection = Enum.ScrollingDirection.Y,
							Active = true,
						}, sections),
					},
				}
			),
			Detail = e(
				UI.Surface,
				{
					variant = "index",
					burst = wide and not short and pet.owned,
					name = "IndexDetail",
					x = rightX,
					y = bodyY,
					w = rightW,
					h = detailH,
					color = detailColor,
					children = detailContents,
				}
			),
			Rewards = e(
				UI.Surface,
				{
					variant = "index",
					name = "IndexRewards",
					x = rightX,
					y = rewardY,
					w = rightW,
					h = rewardH,
					color = C.green:Lerp(C.body, 0.7),
					children = rewardContents,
				}
			),
			Total = UI.progress(
				"Unlocked",
				data.UnlockedPets or totalOwned,
				data.TotalPets or #Config.Pets,
				16,
				bodyY + bodyH - totalH,
				leftW,
				totalH,
				C.blue,
				"index"
			),
		}
	end
	local function offline()
		return {
			Reward = e(OfflineCash, {
				width = windowW,
				height = windowH,
				headerH = headerH,
				amount = number(data.OfflineCash),
				busy = busy,
				onClaim = function()
					action("ClaimOffline", {}, function()
						close()
					end)
				end,
			}),
		}
	end
	local shopContent = React.useMemo(function()
		return screen == "Shop" and shop() or nil
	end, { screen == "Shop", windowW, windowH, headerH, compact, shopCategory })
	local hud = {}
	if compact then
		local navW = math.min(168, (width - 184) / 2)
		local navY = narrow and 118 or 62
		hud.Shop = button("Shop", 16, navY, navW, 44, C.green, function()
			open("Shop")
		end, nil, 21, "OpenShop")
		hud.Index = button("Index", 36 + navW, navY, navW, 44, C.blue, function()
			open("Index")
		end, nil, 21, "OpenIndex")
		hud.Egg = button(nil, width - 120, navY, 44, 44, C.red, function()
			open("Eggs")
		end, "egg", nil, "Eggs")
		hud.Pets = button(nil, width - 64, navY, 44, 44, C.gold, function()
			open("Pets")
		end, "pets", nil, "OpenPets")
	else
		hud.Shop = button("Shop", 20, height * 0.36, 208, 68, C.green, function()
			open("Shop")
		end, "cart", 38, "OpenShop")
		hud.Index = button("Index", 20, height * 0.36 + 88, 208, 68, C.blue, function()
			open("Index")
		end, "index", 38, "OpenIndex")
		-- Reference toggle: knob slides inside the track; ON/OFF text keeps the state readable without color.
		hud.Slow = e(UI.Button, {
			name = "SlowMode",
			x = 20,
			y = height * 0.36 + 176,
			w = 120,
			h = 52,
			variant = "utility",
			disabled = busy,
			onClick = function()
				action("SetSlowMode", { enabled = not slow })
			end,
			children = {
				Knob = e(
					UI.Surface,
					{ x = slow and 70 or 6, y = 6, w = 44, h = 40, color = slow and C.green or C.red }
				),
				State = UI.text(slow and "ON" or "OFF", slow and 6 or 52, 8, 62, 36, 20),
			},
		})
		hud.SlowLabel = UI.text("Slow Mode", 148, height * 0.36 + 176, 170, 52, 26, nil, Enum.TextXAlignment.Left)
		hud.Egg = button(nil, width - 100, height * 0.38, 80, 80, C.red, function()
			open("Eggs")
		end, "egg", nil, "Eggs")
		hud.Pets = button(nil, width - 100, height * 0.38 + 96, 80, 80, C.gold, function()
			open("Pets")
		end, "pets", nil, "OpenPets")
	end
	if sidebarOpen or (inventoryOpen and compact) then
		hud.Egg = nil
		hud.Pets = nil
	end
	-- The label reaches past the left HUD column; keep it clear of central windows.
	if screen and not sidebarOpen and not inventoryOpen then
		hud.SlowLabel = nil
	end
	hud.Settings = e(UI.Button, {
		name = "OpenSettings",
		x = compact and width - 64 or 244,
		y = compact and (narrow and 62 or 14) or 12,
		w = 44,
		h = 44,
		variant = "utility",
		selected = screen == "Settings" and not closing,
		onClick = function()
			open("Settings")
		end,
		children = { Icon = UI.icon("settings", 8, 8, 28, 28) },
	})
	local inventoryIcon = {}
	for i = 0, 3 do
		inventoryIcon["Cell" .. i] = e(
			"Frame",
			{
				Position = UDim2.fromOffset(9 + (i % 2) * 14, 9 + math.floor(i / 2) * 14),
				Size = UDim2.fromOffset(12, 12),
				BackgroundColor3 = C.white,
				BorderSizePixel = 0,
			},
			{ Corner = e("UICorner", { CornerRadius = UDim.new(0, 3) }) }
		)
	end
	hud.Inventory = e(
		UI.Button,
		{
			name = "OpenInventory",
			x = compact and width - 120 or 300,
			y = compact and (narrow and 62 or 14) or 12,
			w = 44,
			h = 44,
			variant = "utility",
			selected = inventoryOpen and not closing,
			onClick = toggleInventory,
			children = inventoryIcon,
		}
	)
	local toolCount = #backpack.tools
	local hotbarLayout = Hotbar.layout(width, height, backpack.slots, false)
	local autoSwingVisible = not screen and data.InField and not data.PlacementKind
	local autoSwingY = compact and hotbarLayout.top - 70 or height - 176
	local resourceY = compact and (autoSwingVisible and autoSwingY or hotbarLayout.top) - 104
		or height - (toolCount > 5 and 250 or 144)
	local speedText = number(data.Speed)
		.. ' <font color="'
		.. UI.hex(C.green)
		.. '">(x'
		.. number(data.Multiplier)
		.. ")</font>"
	hud.SpeedIcon = UI.icon("shoe", 20, resourceY, compact and 42 or 64, compact and 40 or 62)
	hud.Speed = UI.text(
		speedText,
		compact and 76 or 100,
		resourceY,
		compact and width - 92 or 420,
		compact and 40 or 62,
		compact and 26 or 46,
		C.blue,
		Enum.TextXAlignment.Left,
		nil,
		{ rich = true }
	)
	hud.CashIcon = UI.icon("cash", 20, resourceY + (compact and 48 or 72), compact and 42 or 64, compact and 40 or 62)
	hud.Cash = UI.text(
		"$" .. number(data.Cash) .. "  +$" .. number(data.Income) .. "/s",
		compact and 76 or 100,
		resourceY + (compact and 48 or 72),
		compact and width - 92 or 460,
		compact and 40 or 62,
		compact and 26 or 46,
		C.green,
		Enum.TextXAlignment.Left
	)
	if compact and short and not narrow then
		local resourceW = (width - 296) / 2
		hud.SpeedIcon = UI.icon("shoe", 144, 18, 28, 28)
		hud.Speed =
			UI.text(speedText, 178, 14, resourceW - 34, 36, 20, C.blue, Enum.TextXAlignment.Left, nil, { rich = true })
		hud.CashIcon = UI.icon("cash", 160 + resourceW, 18, 28, 28)
		hud.Cash = UI.text(
			"$" .. number(data.Cash) .. "  +$" .. number(data.Income) .. "/s",
			194 + resourceW,
			14,
			resourceW - 34,
			36,
			20,
			C.green,
			Enum.TextXAlignment.Left
		)
	end
	if not compact then
		hud.SpeedPlus = e(UI.Button, {
			name = "GetSpeed",
			label = "+",
			x = 62,
			y = resourceY + 34,
			w = 30,
			h = 30,
			color = C.gold,
			textSize = 22,
			z = 9,
			onClick = function()
				setShopCategory("Speed Packs")
				open("Shop")
			end,
		})
		if data.EventRemaining > 0 then
			hud.EventIcon = UI.icon("lavaBat", width - 272, height - 108, 64, 84)
			hud.Event = UI.text(
				string.format("In %dm %02ds", math.floor(data.EventRemaining / 60), data.EventRemaining % 60),
				width - 212,
				height - 80,
				196,
				56,
				40
			)
		end
	end
	if compact then
		hud.Slow = e(UI.Button, {
			name = "SlowMode",
			label = slow and "Slow: ON" or "Slow: OFF",
			x = 16,
			y = 14,
			w = 112,
			h = 36,
			variant = "utility",
			textSize = 20,
			disabled = busy,
			onClick = function()
				action("SetSlowMode", { enabled = not slow })
			end,
		})
	end
	if compact and screen then
		hud.SpeedIcon = nil
		hud.Speed = nil
		hud.CashIcon = nil
		hud.Cash = nil
	end
	if inventoryOpen then
		if compact then
			hud.Settings = nil
			hud.Inventory = nil
			hud.Shop = nil
			hud.Index = nil
			hud.Slow = nil
			hud.SlowLabel = nil
		end
		hud.SpeedIcon = nil
		hud.Speed = nil
		hud.SpeedPlus = nil
		hud.CashIcon = nil
		hud.Cash = nil
		hud.EventIcon = nil
		hud.Event = nil
	end
	if (compact and screen ~= nil and not inventoryOpen and not sidebarOpen) or screen == "Offline Cash" then
		hud = {}
	end
	local rootChildren = {
		Scale = e("UIScale", { Scale = scale }),
		HUD = e(
			"Frame",
			{ Name = "HUD", BackgroundTransparency = 1, Size = UDim2.fromOffset(width, height), ZIndex = 30 },
			hud
		),
	}
	if inventoryOpen then
		rootChildren.Inventory = e(Inventory, {
			kind = inventoryKind,
			visible = not closing,
			width = width,
			height = height,
			compact = compact,
			pets = inventoryTools.Pets,
			eggs = inventoryTools.Eggs,
			onHoldTool = equipTool,
			slotRefs = backpack.slotRefs,
			inventoryRef = backpack.inventoryRef,
			assign = assignTool,
			drag = drag,
			onTab = function(kind)
				if kind == "Pets" or kind == "Eggs" then
					setInventoryKind(kind)
				end
			end,
			reduced = data.ReducedMotion,
			closeRef = closingRef,
			onClose = close,
			onClosed = closed,
		})
	elseif sidebarOpen then
		rootChildren.Sidebar = e(
			Sidebar,
			{
				kind = screen,
				visible = not closing,
				width = width,
				height = height,
				compact = compact,
				pets = pets,
				eggs = eggs,
				capacity = data.PetCapacity,
				cash = data.Cash,
				slotCost = data.PetSlotCost,
				growCost = data.GrowAllCost,
				reduced = data.ReducedMotion,
				busy = busy,
				closeRef = closingRef,
				onClose = close,
				onClosed = closed,
				onAction = action,
			}
		)
	elseif screen then
		local body
		if screen == "Pickaxe Shop" or screen == "Trails Shop" then
			body = {
				Equipment = e(
					EquipmentShop,
					{
						kind = screen,
						width = windowW,
						height = windowH,
						headerH = headerH,
						compact = compact,
						owned = decode(screen == "Pickaxe Shop" and data.OwnedPickaxes or data.OwnedTrails) or { 1 },
						equipped = screen == "Pickaxe Shop" and data.PickaxeLevel or data.TrailLevel,
						cash = data.Cash,
						busy = busy,
						onAction = action,
					}
				),
			}
		elseif screen == "Merge Pets" or screen == "Satchel Shop" then
			body = {
				Adventure = e(
					AdventurePanels,
					{
						kind = screen,
						width = windowW,
						height = windowH,
						headerH = headerH,
						compact = compact,
						data = data,
						pets = pets,
						busy = busy,
						enabled = not closing,
						onAction = action,
					}
				),
			}
		else
			body = screen == "Settings"
					and {
						Settings = e(
							Settings,
							{
								width = windowW,
								height = windowH,
								headerH = headerH,
								compact = compact,
								data = settingsData,
								onAction = action,
								enabled = not closing and not busy,
							}
						),
					}
				or screen == "Shop" and table.clone(shopContent)
				or screen == "Offline Cash" and offline()
				or index()
		end
		body.Header = e(
			UI.Surface,
			{
				variant = (screen == "Index" or screen == "Shop") and "index" or nil,
				shine = screen == "Index" or screen == "Shop" or screen == "Offline Cash",
				x = 0,
				y = 0,
				w = windowW,
				h = headerH,
				color = screen == "Settings" and C.muted:Lerp(C.white, 0.65)
					or screen == "Index" and C.purple
					or screen == "Pickaxe Shop" and C.gold
					or screen == "Trails Shop" and C.blue
					or C.green,
				children = {
					Title = UI.text(
						screen,
						22,
						8,
						windowW - (compact and 104 or 140),
						math.max(36, headerH - 20),
						screen == "Offline Cash" and (width < 600 and 32 or short and 36 or 80) or compact and 32 or 56,
						nil,
						Enum.TextXAlignment.Left,
						(screen == "Index" or screen == "Shop") and Theme.index.outline or nil
					),
				},
			}
		)
		body.Close = e(
			UI.Button,
			{
				variant = (screen == "Index" or screen == "Shop") and "index" or nil,
				name = "CloseWindow",
				buttonRef = closingRef,
				x = windowW - (compact and 61 or 79),
				y = 14,
				w = compact and 48 or 62,
				h = compact and 48 or 62,
				label = "X",
				textSize = compact and 34 or 48,
				color = C.red,
				onClick = close,
				z = 10,
			}
		)
		rootChildren.Modal = e(
			"Frame",
			{
				Name = "Modal",
				Size = UDim2.fromOffset(width, height),
				BackgroundTransparency = 1,
				ZIndex = 20,
				SelectionGroup = true,
				SelectionBehaviorUp = Enum.SelectionBehavior.Stop,
				SelectionBehaviorDown = Enum.SelectionBehavior.Stop,
				SelectionBehaviorLeft = Enum.SelectionBehavior.Stop,
				SelectionBehaviorRight = Enum.SelectionBehavior.Stop,
			},
			{
				Blocker = e(
					"TextButton",
					{
						Name = "ModalBlocker",
						Size = UDim2.fromScale(1, 1),
						BackgroundColor3 = C.ink,
						BackgroundTransparency = 0.55,
						Text = "",
						AutoButtonColor = false,
						Selectable = false,
					}
				),
				Window = e(
					UI.Transition,
					{
						name = "ModalTransition",
						x = wx,
						y = wy,
						w = windowW,
						h = windowH,
						visible = not closing,
						transitionKey = screen,
						reduced = data.ReducedMotion,
						onClosed = closed,
						children = {
							Window = e(
								UI.Surface,
								{
									variant = (screen == "Index" or screen == "Shop") and "index" or nil,
									name = screen,
									w = windowW,
									h = windowH,
									color = C.body,
									quiet = true,
									z = 2,
									children = body,
								}
							),
						},
					}
				),
			}
		)
	end
	rootChildren.Hotbar = screen ~= "Offline Cash"
		and not (compact and screen ~= nil and not inventoryOpen)
		and e(
			Hotbar.Bar,
			{
				width = width,
				height = height,
				slots = backpack.slots,
				slotRefs = backpack.slotRefs,
				inventoryRef = backpack.inventoryRef,
				held = backpack.held,
				revision = backpack.revision,
				open = inventoryOpen and not closing,
				reduced = data.ReducedMotion,
				equip = equipTool,
				assign = assignTool,
				drag = drag,
			}
		)
	rootChildren.Drag =
		e(ToolDragPreview, { drag = drag, rootRef = rootRef, scale = scale, width = width, height = height })
	if pendingLabel then
		rootChildren.Pending = e(
			UI.Surface,
			{
				name = "PendingAction",
				x = (width - 220) / 2,
				y = compact and narrow and not short and 124 or 8,
				w = 220,
				h = 40,
				variant = "utility",
				z = 60,
				children = { Text = UI.text(pendingLabel, 8, 2, 204, 36, 22) },
			}
		)
	end
	if autoSwingVisible then
		rootChildren.AutoSwing = e(UI.Button, {
			name = "AutoSwing",
			label = data.AutoSwing and "Auto Swing: ON" or "Auto Swing",
			icon = "pickaxe",
			x = (width - 272) / 2,
			y = autoSwingY,
			w = 272,
			h = 54,
			color = data.AutoSwing and C.green or C.red,
			textSize = 28,
			onClick = function()
				player:SetAttribute("AutoSwing", not player:GetAttribute("AutoSwing"))
			end,
			z = 40,
		})
	end
	if not screen and data.PlacementKind == "Egg" then
		local bannerW = math.min(620, width - 32)
		rootChildren.Placement = e(
			UI.Surface,
			{
				name = "PlacementGuide",
				x = (width - bannerW) / 2,
				y = compact and (narrow and 180 or 124) or 76,
				w = bannerW,
				h = 142,
				color = C.body,
				quiet = true,
				z = 40,
				children = {
					Title = UI.text(
						data.PlacementKind == "Egg" and "Place your egg" or "Place your animal",
						12,
						8,
						bannerW - 24,
						36,
						26,
						C.gold
					),
					Hint = UI.text(
						data.PlacementValid and "Click / tap the green spot on your base"
							or "Aim inside the highlighted pen",
						12,
						50,
						bannerW - 24,
						38,
						20
					),
					Cancel = e(UI.Button, {
						name = "CancelPlacement",
						label = "Cancel",
						x = (bannerW - 128) / 2,
						y = 98,
						w = 128,
						h = 32,
						variant = "utility",
						textSize = 20,
						onClick = function()
							local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
							if humanoid then
								humanoid:UnequipTools()
							end
						end,
					}),
				},
			}
		)
	end
	if message or (not screen and data.PlacementKind and data.PlacementError) then
		local noticeW = math.min(580, width - 32)
		rootChildren.ActionMessage = e(
			UI.Surface,
			{
				name = "ActionMessage",
				x = (width - noticeW) / 2,
				y = compact and (narrow and 330 or 276) or 232,
				w = noticeW,
				h = 60,
				color = C.body,
				quiet = true,
				z = 50,
				children = { Text = UI.text(message or data.PlacementError, 12, 8, noticeW - 24, 42, 20) },
			}
		)
	end
	return e(
		UI.ReducedMotion.Provider,
		{ value = data.ReducedMotion },
		e(
			"Frame",
			{ Name = "SimulatorUI", ref = rootRef, BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) },
			rootChildren
		)
	)
end
return App
