-- UI route probe for UI-01..UI-05 (docs/ui.md). Run with MCP execute_luau in the Client datamodel during Play.
-- execute_luau cannot send input (VirtualInputManager needs RobloxScript capability), so clicks and keys
-- come from MCP user_mouse_input (instance_path from `paths`) and user_keyboard_input; this probe reads the result.
-- Procedure and expected results: docs/verification.md, section "Маршруты UI".
local player = game:GetService("Players").LocalPlayer
local gui = player.PlayerGui:WaitForChild("ShopReferenceUI", 10)
assert(gui, "verify-ui-routes: ShopReferenceUI not found")

local function find(name)
	return gui:FindFirstChild(name, true)
end
-- The Figma HUD hides buttons with Visible instead of unmounting them.
local function shown(item)
	while item and item:IsA("GuiObject") do
		if not item.Visible then
			return false
		end
		item = item.Parent
	end
	return item ~= nil
end
local function path(item)
	return item and "LocalPlayer.PlayerGui." .. item:GetFullName():match("PlayerGui%.(.+)$") or nil
end

local openInventoryButtons = 0
for _, item in gui:GetDescendants() do
	if item.Name == "OpenInventory" and item:IsA("GuiButton") then
		openInventoryButtons += 1
	end
end

local state = {
	ready = player:GetAttribute("PetDataReady") == true,
	windowOpen = player:GetAttribute("UIWindowOpen") == true,
	petsSidebar = find("PetsSidebar") ~= nil,
	eggsSidebar = find("EggsSidebar") ~= nil,
	inventoryPanel = find("InventoryPanel") ~= nil,
	rightButtonsVisible = shown(find("OpenPets")) and shown(find("Eggs")),
	openInventoryButtons = openInventoryButtons,
	paths = {
		OpenPets = path(find("OpenPets")),
		Eggs = path(find("Eggs")),
		OpenInventory = path(find("OpenInventory")),
		CollapseSidebar = path(find("CollapseSidebar")),
	},
}
-- UI-04: never two surfaces at once.
assert(
	not (state.inventoryPanel and (state.petsSidebar or state.eggsSidebar)),
	"UI-04 violated: inventory and sidebar together"
)
-- UI-02: exactly one OpenInventory entry.
assert(openInventoryButtons == 1, "UI-02 violated: OpenInventory buttons = " .. openInventoryButtons)
return game:GetService("HttpService"):JSONEncode(state)
