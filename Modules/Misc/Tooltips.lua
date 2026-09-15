local _, ns = ...

-- Tooltip extras: icon in the title, spell/item ids, item level and the
-- caster of auras.

local GetSpellInfo = GetSpellInfo
local GetItemInfo = GetItemInfo
local GetItemIcon = GetItemIcon
local UnitAura = UnitAura
local UnitName = UnitName
local UnitIsPlayer = UnitIsPlayer
local UnitClass = UnitClass
local unpack = unpack

local TOOLTIPS = { ItemRefTooltip, GameTooltip, ShoppingTooltip1, ShoppingTooltip2, ShoppingTooltip3 }
local TITLE_ICON = "|T%s:20:20:0:0:64:64:5:59:5:59:20|t %s"

local function labeled(label, value)
	return ("|cff3366ff%s|r: |cffffffff%d|r"):format(label, value)
end

local function titleLine(tooltip, index)
	return _G[tooltip:GetName() .. "TextLeft" .. (index or 1)]
end

--------------------------------------------------
-- Spells

local function onTooltipSetSpell(tooltip)
	local _, _, spellId = tooltip:GetSpell()
	if not (spellId and GetSpellInfo(spellId)) then
		return
	end

	local title = titleLine(tooltip)
	if title then
		local _, _, texture = GetSpellInfo(spellId)
		title:SetFormattedText(TITLE_ICON, texture, title:GetText())
	end

	tooltip:AddLine(labeled("ID", spellId))
	tooltip:Show()
end

--------------------------------------------------
-- Items

local function onTooltipSetItem(tooltip)
	local itemName, link = tooltip:GetItem()
	if not (link and GetItemInfo(link)) then
		return
	end

	-- The name is usually on the first line, but can be pushed to the second.
	for i = 1, 2 do
		local title = titleLine(tooltip, i)
		local text = title and title:GetText()
		if text and text:find(itemName, 1, true) then
			title:SetFormattedText(TITLE_ICON, GetItemIcon(link), text)
			break
		end
	end

	local _, _, _, itemLevel = GetItemInfo(link)
	local itemId = link:match("|Hitem:(%d+):")
	tooltip:AddDoubleLine(itemId and labeled("ID", itemId), itemLevel and labeled("ilvl", itemLevel))
	tooltip:Show()
end

for _, tooltip in ipairs(TOOLTIPS) do
	tooltip:HookScript("OnTooltipSetSpell", onTooltipSetSpell)
	tooltip:HookScript("OnTooltipSetItem", onTooltipSetItem)
end

--------------------------------------------------
-- Auras: spell id and caster (class colored)

local classColors = ns:GetModule("UnitFrames").classColors

local function onSetUnitAura(tooltip, unit, index, filter)
	local _, _, _, _, _, _, _, caster, _, _, spellId = UnitAura(unit, index, filter)
	if not spellId then
		return
	end

	local idText = labeled("ID", spellId)
	if caster then
		local r, g, b = 1, 0.9, 0.8
		if UnitIsPlayer(caster) then
			local _, class = UnitClass(caster)
			r, g, b = unpack(classColors[class])
		end
		tooltip:AddDoubleLine(idText, UnitName(caster), nil, nil, nil, r, g, b)
	else
		tooltip:AddLine(idText)
	end

	tooltip:Show()
end

hooksecurefunc(GameTooltip, "SetUnitAura", onSetUnitAura)
hooksecurefunc(GameTooltip, "SetUnitBuff", onSetUnitAura)
hooksecurefunc(GameTooltip, "SetUnitDebuff", function(tooltip, unit, index, filter)
	onSetUnitAura(tooltip, unit, index, "HARMFUL" .. (filter and "|" .. filter or ""))
end)
