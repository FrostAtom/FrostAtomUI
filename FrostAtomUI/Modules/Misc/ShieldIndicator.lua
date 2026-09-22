local _, ns = ...

if ns.PLAYER_CLASS ~= "WARRIOR" then
	return
end

local GetInventoryItemLink = GetInventoryItemLink
local GetInventoryItemTexture = GetInventoryItemTexture
local GetItemInfo = GetItemInfo

local Misc = ns:GetModule("Misc")
local UF = ns:GetModule("UnitFrames")

local OFFHAND_SLOT = 17
local GAP = 2

local icon = CreateFrame("Frame", nil, UIParent)
icon:SetPoint("RIGHT", FrostAtomUIPlayerPlate, "LEFT", -GAP, 0)
icon:Hide()

local texture = icon:CreateTexture(nil, "BORDER")
UF.SkinIcon(icon, texture)

local function update()
	local link = ns.Config.shieldIndicator.enabled and GetInventoryItemLink("player", OFFHAND_SLOT)
	local equipLoc = link and select(9, GetItemInfo(link))
	if equipLoc == "INVTYPE_SHIELD" then
		texture:SetTexture(GetInventoryItemTexture("player", OFFHAND_SLOT))
		icon:Show()
	else
		icon:Hide()
	end
end

local function applyConfig()
	local size = ns.Config.shieldIndicator.size
	icon:SetSize(size, size)
	update()
end

applyConfig()
Misc:WatchConfig("shieldIndicator", applyConfig)
Misc:RegisterEvent("PLAYER_ENTERING_WORLD", update)
Misc:RegisterEvent("PLAYER_EQUIPMENT_CHANGED", function(_, slot)
	if slot == OFFHAND_SLOT then
		update()
	end
end)
