-- Players tab of the dev panel: server roster, the selected player's profile, stats, actions, pets and eggs.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.React)
local Game = require(ReplicatedStorage:WaitForChild("GameConfig"))
local Theme = require(script.Parent.Theme)
local UI = require(script.Parent.UI)
local Kit = require(script.Parent.DevKit)
local e = React.createElement
local C = Theme.colors
local MAX_ROWS = 60

local function grid(children, order, cellW, cellH)
	children.Layout = e("UIGridLayout", {
		CellSize = UDim2.fromOffset(cellW, cellH),
		CellPadding = UDim2.fromOffset(8, 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
	})
	return e("Frame", {
		LayoutOrder = order,
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
	}, children)
end
local function block(name, order, h, children)
	return e("Frame", {
		Name = name,
		LayoutOrder = order,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, h),
	}, {
		Surface = e(UI.Surface, { variant = "utility", size = UDim2.fromScale(1, 1), children = children }),
	})
end
local function playtime(seconds)
	local h = math.floor(seconds / 3600)
	return h > 0 and string.format("%dh %02dm", h, math.floor(seconds % 3600 / 60))
		or string.format("%dm %02ds", math.floor(seconds / 60), seconds % 60)
end

local function DevPlayers(p)
	local ui, layout, info = p.ui, p.ui.layout, p.info
	local target = p.target
	local isMe = target == p.me.UserId
	local content = {}

	-- Roster: everyone on the server, the owner first.
	local cards = {}
	for i, player in p.roster do
		local you = player == p.me
		cards["Player" .. i] = e(UI.Button, {
			name = "Player" .. player.UserId,
			w = layout.wide,
			h = 64,
			variant = "utility",
			selected = player.UserId == target,
			disabled = false,
			onClick = function()
				p.setTarget(player.UserId)
			end,
			children = {
				Avatar = Kit.avatar(player.UserId, 44, 10, 10),
				Name = UI.text(
					player.DisplayName,
					64,
					6,
					layout.wide - 170,
					28,
					20,
					C.white,
					Enum.TextXAlignment.Left,
					nil,
					{ fit = true }
				),
				Handle = Kit.small(
					"@" .. player.Name .. (you and "  · YOU" or ""),
					64,
					36,
					layout.wide - 170,
					18,
					you and C.gold
				),
				Cash = Kit.small(
					"$" .. Game.number(player:GetAttribute("Cash") or 0),
					layout.wide - 104,
					12,
					92,
					18,
					C.green,
					Enum.TextXAlignment.Right
				),
				Rebirths = Kit.small(
					"R" .. (player:GetAttribute("Rebirths") or 0),
					layout.wide - 104,
					34,
					92,
					18,
					C.white,
					Enum.TextXAlignment.Right
				),
			},
		})
	end
	content.Roster = ui.section(
		"Players on server",
		1,
		{ Grid = grid(cards, 1, layout.wide, 64) },
		nil,
		"list",
		#p.roster .. (#p.roster == 1 and " player" or " players")
	)

	if not info then
		content.Loading = block("Loading", 2, 64, {
			Text = UI.text("Loading player…", 16, 12, layout.full - 32, 40, 22, C.white, Enum.TextXAlignment.Left),
		})
		return content
	end
	local s = info.stats

	content.Profile = block("Profile", 2, 100, {
		Avatar = Kit.avatar(info.userId, 76, 12, 12),
		Name = UI.text(
			info.displayName,
			102,
			10,
			layout.full - 300,
			36,
			28,
			C.white,
			Enum.TextXAlignment.Left,
			nil,
			{ fit = true }
		),
		Handle = Kit.small("@" .. info.name .. "  ·  " .. info.userId, 102, 48, layout.full - 300, 18, C.white),
		Where = Kit.small(s.place .. "  ·  " .. s.base, 102, 70, layout.full - 300, 18, C.gold),
		ReadOnly = not p.canEdit
				and UI.text("LIVE: READ-ONLY", layout.full - 196, 30, 180, 40, 18, C.red, Enum.TextXAlignment.Right)
			or nil,
	})

	local tiles = {
		{ "Cash", "$" .. Game.number(s.cash), C.green },
		{ "Income", "$" .. Game.number(s.income) .. "/s", C.green },
		{ "Speed", Game.number(s.speed), C.blue },
		{ "Rebirths", tostring(s.rebirths), C.purple },
		{ "On base", s.equipped .. " / " .. s.capacity },
		{ "Index", s.discovered .. " / " .. s.totalPets },
		{ "Pickaxe", s.pickaxe },
		{ "Trail", s.trail },
		{ "Pen", "Lv " .. s.penLevel },
		{ "Treadmill", "Lv " .. s.treadmillLevel },
		{ "Satchel", "Lv " .. s.satchelLevel },
		{ "Carrying", tostring(s.carrying) },
		{ "Offline", "$" .. Game.number(s.offline) },
		{ "Playtime", playtime(s.playtime) },
	}
	content.Stats = ui.section("Stats", 3, { Grid = Kit.tiles(tiles, 1, layout.cell) }, nil, "list")

	local actions = {
		ui.button("Ragdoll", C.purple, function()
			p.run("Ragdoll", { target = target })
		end),
		ui.button("Drop cargo", C.gold, function()
			p.run("DropCargo", { target = target })
		end),
		ui.button("Respawn", C.muted, function()
			p.run("Respawn", { target = target })
		end),
	}
	if not isMe then
		table.insert(
			actions,
			1,
			ui.button("Go to", C.blue, function()
				p.run("GoTo", { target = target })
			end)
		)
		table.insert(
			actions,
			2,
			ui.button("Bring", C.blue, function()
				p.run("Bring", { target = target })
			end)
		)
		table.insert(actions, ui.confirm("kick" .. target, "Kick", "Kick", { target = target }, { editsData = false }))
	end
	local places = {}
	for _, place in { "Base", "Forest", "Desert", "Snow", "Titan" } do
		table.insert(
			places,
			ui.button(place, C.blue, function()
				p.run("Teleport", { target = target, to = place })
			end, { color = C.blue })
		)
	end
	content.Actions = ui.section("Actions", 4, {
		Main = ui.grid(actions, 1),
		Places = ui.grid(places, 2),
	}, nil, "list", isMe and "Teleports move you" or "Teleports move " .. info.name)

	-- Pet and egg rows: icon, name, details on the left; actions on the right.
	local function row(key, order, icon, name, rarity, meta, buttons)
		local children = {
			Icon = UI.icon(icon, 10, 8, 36, 36),
			Name = UI.text(
				name,
				54,
				4,
				layout.full - 360,
				26,
				18,
				Kit.rarityColor(rarity),
				Enum.TextXAlignment.Left,
				nil,
				{ fit = true }
			),
			Meta = Kit.small(meta, 54, 29, layout.full - 360, 18, C.white),
		}
		for name2, child in buttons do
			children[name2] = child
		end
		return e("Frame", {
			Name = key,
			LayoutOrder = order,
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, Kit.ROW_H),
		}, {
			Surface = e(UI.Surface, { variant = "utility", size = UDim2.fromScale(1, 1), children = children }),
		})
	end
	local function removeButton(kind, id)
		return ui.confirm(
			"rm" .. id,
			"Del",
			kind == "Pet" and "RemovePet" or "RemoveEgg",
			{ target = target, pet = id, egg = id },
			{ w = 60, x = layout.full - 68, y = 6, sure = "OK?" }
		)
	end
	-- Rows live in name-keyed tables (React children), so counts are kept separately.
	local base, backpack = {}, {}
	local equipped, stored = 0, 0
	for _, pet in info.pets do
		local list = pet.equipped and base or backpack
		local order
		if pet.equipped then
			equipped += 1
			order = equipped
		else
			stored += 1
			order = stored
		end
		if order > MAX_ROWS then
			continue
		end
		list["Pet" .. order] = row(
			pet.id,
			order,
			pet.icon,
			pet.name,
			pet.rarity,
			Game.number(pet.weight) .. " kg  ·  $" .. Game.number(pet.income) .. "/s",
			{
				Move = ui.edit(
					pet.equipped and "To backpack" or "Place on base",
					pet.equipped and C.muted or C.green,
					"SetPetEquipped",
					{ target = target, pet = pet.id, equipped = not pet.equipped },
					{ w = 150, x = layout.full - 338, y = 6 }
				),
				Weight = e(Kit.Input, {
					x = layout.full - 180,
					y = 6,
					w = 104,
					placeholder = Game.number(pet.weight) .. " kg",
					editable = p.canEdit,
					onSubmit = function(text, box)
						local weight = Kit.parse(text)
						if weight then
							box.Text = ""
							p.run("SetPetWeight", { target = target, pet = pet.id, weight = weight })
						end
					end,
				}),
				Remove = removeButton("Pet", pet.id),
			}
		)
	end
	local function more(total, shown)
		return total > shown and string.format("%d (showing %d)", total, shown) or tostring(total)
	end
	content.Base = ui.section(
		"Pets on base",
		5,
		base,
		nil,
		"list",
		more(equipped, math.min(equipped, MAX_ROWS)) .. "  ·  type kg + Enter to reweigh"
	)
	content.Backpack =
		ui.section("Pets in backpack", 6, backpack, nil, "list", more(stored, math.min(stored, MAX_ROWS)))
	local eggs = {}
	for i, egg in info.backpackEggs do
		if i > MAX_ROWS then
			break
		end
		eggs["Egg" .. i] =
			row(egg.id, i, "egg", egg.name .. " Egg", egg.rarity, Game.number(egg.weight) .. " kg  ·  in backpack", {
				Remove = removeButton("Egg", egg.id),
			})
	end
	for i, egg in info.baseEggs do
		local order = #info.backpackEggs + i
		if order > MAX_ROWS then
			break
		end
		eggs["BaseEgg" .. i] = row(
			egg.id,
			order,
			"egg",
			egg.name .. " Egg",
			egg.rarity,
			Game.number(egg.weight) .. " kg  ·  hatches in " .. egg.seconds .. "s",
			{ Remove = removeButton("Egg", egg.id) }
		)
	end
	content.Eggs = ui.section("Eggs", 7, eggs, nil, "list", (#info.backpackEggs + #info.baseEggs) .. " total")
	return content
end

return DevPlayers
