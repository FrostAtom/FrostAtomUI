local _, ns = ...

local CreateFrame = CreateFrame
local GetWeaponEnchantInfo = GetWeaponEnchantInfo
local GetInventoryItemTexture = GetInventoryItemTexture
local CancelItemTempEnchantment = CancelItemTempEnchantment
local GameTooltip = GameTooltip

local TemporaryEnchant = ns:NewModule("TemporaryEnchant")

local ICON_SIZE = 30
local ICON_GAP = 2
local TOP_OFFSET = 8
local MAIN_HAND_SLOT = 16

local function onClick(icon)
	CancelItemTempEnchantment(icon.weaponIndex)
end

local function onUpdate(icon)
	GameTooltip:SetInventoryItem("player", icon.slot)
end

local function onEnter(icon)
	GameTooltip:SetOwner(icon, "ANCHOR_BOTTOMLEFT")
	onUpdate(icon)
	icon:SetScript("OnUpdate", onUpdate)
end

local function onLeave(icon)
	GameTooltip:Hide()
	icon:SetScript("OnUpdate", nil)
end

local function createIcon(index)
	local icon = CreateFrame("Button", nil, UIParent)
	icon:SetSize(ICON_SIZE, ICON_SIZE)
	icon:SetPoint("TOPLEFT", Minimap, "BOTTOMLEFT", (index - 1) * (ICON_SIZE + ICON_GAP), -TOP_OFFSET)
	icon:RegisterForClicks("RightButtonDown")
	icon:SetScript("OnClick", onClick)
	icon:SetScript("OnEnter", onEnter)
	icon:SetScript("OnLeave", onLeave)

	icon.texture = icon:CreateTexture(nil, "BORDER")
	icon.texture:SetAllPoints()

	return icon
end

local icons = setmetatable({}, {
	__index = function(self, index)
		local icon = createIcon(index)
		self[index] = icon
		return icon
	end,
})

local function showEnchants(...)
	local shown = 0
	local weaponIndex = 0
	for i = 1, select("#", ...), 3 do
		weaponIndex = weaponIndex + 1
		if select(i, ...) then
			shown = shown + 1

			local icon = icons[shown]
			local slot = MAIN_HAND_SLOT - 1 + weaponIndex
			icon.weaponIndex = weaponIndex
			icon.slot = slot
			icon.texture:SetTexture(GetInventoryItemTexture("player", slot))
			icon:Show()
		end
	end

	for i = shown + 1, #icons do
		icons[i]:Hide()
	end
end

function TemporaryEnchant:Update()
	showEnchants(GetWeaponEnchantInfo())
end

function TemporaryEnchant:UNIT_INVENTORY_CHANGED(unit)
	if unit == "player" then
		self:Update()
	end
end

function TemporaryEnchant:Initialize()
	self:RegisterEvent("UNIT_INVENTORY_CHANGED")
	self:RegisterEvent("PLAYER_ENTERING_WORLD", "Update")
end
