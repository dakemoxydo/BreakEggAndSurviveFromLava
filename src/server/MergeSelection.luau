-- Validate all three identities before any ownership changes. Never substitute
-- another animal when a confirmed input has disappeared.
local Selection = {}
function Selection.resolve(pets, kind, ids)
	if type(ids) ~= "table" or #ids ~= 3 then
		return nil, "Confirm exactly 3 animals."
	end
	local count = 0
	for key in ids do
		if type(key) ~= "number" or key % 1 ~= 0 or key < 1 or key > 3 then
			return nil, "Invalid merge selection."
		end
		count += 1
	end
	if count ~= 3 then
		return nil, "Confirm exactly 3 animals."
	end
	local wanted = {}
	for _, id in ids do
		if type(id) ~= "string" or id == "" or wanted[id] then
			return nil, "Choose 3 different animals."
		end
		wanted[id] = true
	end
	local matches, weight = {}, 0
	for index, pet in pets do
		if wanted[pet.id] then
			if (pet.kind or "TestChick") ~= kind then
				return nil, "Choose 3 matching animals."
			end
			table.insert(matches, { index = index, pet = pet })
			weight += pet.weight or 1
		end
	end
	if #matches ~= 3 then
		return nil, "These animals changed. Choose again."
	end
	if weight * 1.15 > 1e12 then
		return nil, "This egg would be too heavy."
	end
	table.sort(matches, function(a, b)
		return a.index > b.index
	end)
	return matches, weight * 1.15
end
return Selection
