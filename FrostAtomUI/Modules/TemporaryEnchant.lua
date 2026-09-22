local _, ns = ...

local GetWeaponEnchantInfo = GetWeaponEnchantInfo
local GetInventoryItemTexture = GetInventoryItemTexture
local CancelItemTempEnchantment = CancelItemTempEnchantment
local GameTooltip = GameTooltip

local TemporaryEnchant = ns:NewModule("TemporaryEnchant")
TemporaryEnchant.configKey = "temporaryEnchant"

local MAIN_HAND_SLOT = 16
local MAX_ICONS = 2

local holder

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

local function createIcon()
	local icon = CreateFrame("Button", nil, holder)
	icon:Hide()
	icon:RegisterForClicks("RightButtonDown")
	icon:SetScript("OnClick", onClick)
	icon:SetScript("OnEnter", onEnter)
	icon:SetScript("OnLeave", onLeave)

	icon.texture = icon:CreateTexture(nil, "BORDER")
	icon.texture:SetAllPoints()

	return icon
end

local icons = {}

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

local function applyConfig()
	local config = ns.Config.temporaryEnchant
	local size, gap = config.size, config.gap
	holder:SetSize(MAX_ICONS * (size + gap) - gap, size)
	for i = 1, MAX_ICONS do
		local icon = icons[i]
		icon:SetSize(size, size)
		icon:ClearAllPoints()
		icon:SetPoint("TOPLEFT", (i - 1) * (size + gap), 0)
	end
end

function TemporaryEnchant:Initialize()
	ns.DestroyFrame(TemporaryEnchantFrame, true)

	holder = CreateFrame("Frame", nil, UIParent)
	self:AnchorToConfig(holder, "temporaryEnchant.point")
	for i = 1, MAX_ICONS do
		icons[i] = createIcon()
	end

	applyConfig()
	self:WatchConfig("temporaryEnchant", applyConfig)

	self:RegisterEvent("UNIT_INVENTORY_CHANGED")
	self:RegisterEvent("PLAYER_ENTERING_WORLD", "Update")
end
