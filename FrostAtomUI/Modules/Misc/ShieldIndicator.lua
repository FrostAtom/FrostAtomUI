local _, ns = ...

if ns.PLAYER_CLASS ~= "WARRIOR" then
	return
end

local CreateFrame = CreateFrame
local GetInventoryItemLink = GetInventoryItemLink
local GetInventoryItemTexture = GetInventoryItemTexture
local GetItemInfo = GetItemInfo
local select = select

local Misc = ns:GetModule("Misc")

local OFFHAND_SLOT = 17

local icon = CreateFrame("Frame", nil, UIParent)
Misc:AnchorToConfig(icon, "shieldIndicator.point")
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
