local _, ns = ...

local CreateFrame = CreateFrame
local GetInventoryItemLink = GetInventoryItemLink
local GetInventoryItemTexture = GetInventoryItemTexture
local GetItemInfo = GetItemInfo
local select = select

if ns.PLAYER_CLASS ~= "WARRIOR" then
	return
end

local Misc = ns:GetModule("Misc")

local ICON_SIZE = 28
local OFFHAND_SLOT = 17

local icon = CreateFrame("Frame", nil, UIParent)
icon:SetSize(ICON_SIZE, ICON_SIZE)
icon:SetPoint(unpack(ns.Config.shieldIndicator))
icon:Hide()

local texture = icon:CreateTexture(nil, "ARTWORK")
texture:SetAllPoints()
texture:SetTexCoord(0.07, 0.93, 0.07, 0.93)

local borderSize = ns.PixelPerfect(1)
local border = icon:CreateTexture(nil, "BACKGROUND")
border:SetTexture(0, 0, 0)
border:SetPoint("TOPRIGHT", borderSize, borderSize)
border:SetPoint("BOTTOMLEFT", -borderSize, -borderSize)

local function update()
	local link = GetInventoryItemLink("player", OFFHAND_SLOT)
	local equipLoc = link and select(9, GetItemInfo(link))
	if equipLoc == "INVTYPE_SHIELD" then
		texture:SetTexture(GetInventoryItemTexture("player", OFFHAND_SLOT))
		icon:Show()
	else
		icon:Hide()
	end
end

Misc:RegisterEvent("PLAYER_ENTERING_WORLD", update)
Misc:RegisterEvent("PLAYER_EQUIPMENT_CHANGED", function(_, slot)
	if slot == OFFHAND_SLOT then
		update()
	end
end)
