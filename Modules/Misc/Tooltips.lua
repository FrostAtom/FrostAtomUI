local _, ns = ...

local GetSpellInfo = GetSpellInfo
local GetItemInfo = GetItemInfo
local GetItemIcon = GetItemIcon
local GetItemCount = GetItemCount
local UnitAura = UnitAura
local UnitName = UnitName
local UnitIsPlayer = UnitIsPlayer
local UnitClass = UnitClass
local UnitExists = UnitExists
local UnitIsUnit = UnitIsUnit
local UnitGUID = UnitGUID
local UnitReaction = UnitReaction
local GetGuildInfo = GetGuildInfo
local GetMouseFocus = GetMouseFocus
local GetNumRaidMembers = GetNumRaidMembers
local GetNumPartyMembers = GetNumPartyMembers
local InCombatLockdown = InCombatLockdown
local IsShiftKeyDown = IsShiftKeyDown
local CanInspect = CanInspect
local CheckInteractDistance = CheckInteractDistance
local NotifyInspect = NotifyInspect
local GetTime = GetTime
local CreateFrame = CreateFrame
local unpack = unpack
local wipe = wipe
local tconcat = table.concat

local Misc = ns:GetModule("Misc")

local TOOLTIPS = { ItemRefTooltip, GameTooltip, ShoppingTooltip1, ShoppingTooltip2, ShoppingTooltip3 }
local TITLE_ICON = "|T%s:20:20:0:0:64:64:5:59:5:59:20|t %s"

local function labeled(label, value)
	return ("|cff3366ff%s|r: |cffffffff%d|r"):format(label, value)
end

local function titleLine(tooltip, index)
	return _G[tooltip:GetName() .. "TextLeft" .. (index or 1)]
end

local function onTooltipSetSpell(tooltip)
	local _, _, spellId = tooltip:GetSpell()
	if not spellId then
		return
	end
	local spellName, _, texture = GetSpellInfo(spellId)
	if not spellName then
		return
	end

	local title = titleLine(tooltip)
	if title then
		title:SetFormattedText(TITLE_ICON, texture, title:GetText())
	end

	tooltip:AddLine(labeled("ID", spellId))
	tooltip:Show()
end

local function onTooltipSetItem(tooltip)
	local itemName, link = tooltip:GetItem()
	if not link then
		return
	end
	local knownName, _, _, itemLevel = GetItemInfo(link)
	if not knownName then
		return
	end

	for i = 1, 2 do
		local title = titleLine(tooltip, i)
		local text = title and title:GetText()
		if text and text:find(itemName, 1, true) then
			title:SetFormattedText(TITLE_ICON, GetItemIcon(link), text)
			break
		end
	end

	local itemId = link:match("|Hitem:(%d+):")
	tooltip:AddDoubleLine(itemId and labeled("ID", itemId), itemLevel and labeled("ilvl", itemLevel))

	local inBags = GetItemCount(link)
	local inBank = GetItemCount(link, true) - inBags
	if inBags > 0 or inBank > 0 then
		tooltip:AddDoubleLine(labeled("Bags", inBags), inBank > 0 and labeled("Bank", inBank))
	end

	tooltip:Show()
end

for _, tooltip in ipairs(TOOLTIPS) do
	tooltip:HookScript("OnTooltipSetSpell", onTooltipSetSpell)
	tooltip:HookScript("OnTooltipSetItem", onTooltipSetItem)
end

hooksecurefunc("GameTooltip_SetDefaultAnchor", function(tooltip, parent)
	tooltip:SetOwner(parent, "ANCHOR_NONE")
	tooltip:ClearAllPoints()
	tooltip:SetPoint(unpack(ns.Config.tooltip))
end)

local UF = ns:GetModule("UnitFrames")
local classColors = UF.classColors

local function colorize(unit, text)
	local r, g, b
	if UnitIsPlayer(unit) then
		local _, class = UnitClass(unit)
		r, g, b = unpack(classColors[class] or UF.textColor)
	else
		local color = FACTION_BAR_COLORS[UnitReaction(unit, "player") or 4]
		r, g, b = color.r, color.g, color.b
	end
	return ("|cff%02x%02x%02x%s|r"):format(r * 255, g * 255, b * 255, text)
end

local function groupUnits()
	local numRaid = GetNumRaidMembers()
	if numRaid > 0 then
		return "raid", numRaid
	end
	return "party", GetNumPartyMembers()
end

local targetedBy = {}

local ILVL_CACHE_TIME = 120
local ILVL_REQUEST_THROTTLE = 2
local ILVL_RETRY_DELAY = 0.3
local ILVL_MAX_RETRIES = 10

local itemLevels = {}
local inspectGuid, inspectUnit, inspectTime, inspectRetries

local function addItemLevel(tooltip, average)
	tooltip:AddLine(("|cff3366ffilvl|r: |cffffffff%.1f|r"):format(average))
end

local inspectRetry = CreateFrame("Frame")
inspectRetry:Hide()

local function finishInspect()
	local guid = inspectGuid
	if not (guid and inspectUnit and UnitExists(inspectUnit) and UnitGUID(inspectUnit) == guid) then
		inspectGuid = nil
		return
	end

	local average, count, missing = ns.UnitAverageItemLevel(inspectUnit)
	if missing and inspectRetries < ILVL_MAX_RETRIES then
		inspectRetries = inspectRetries + 1
		inspectRetry.remain = ILVL_RETRY_DELAY
		inspectRetry:Show()
		return
	end
	inspectGuid = nil
	if count == 0 then
		return
	end
	itemLevels[guid] = { level = average, time = GetTime() }

	if GameTooltip:IsShown() then
		local _, unit = GameTooltip:GetUnit()
		if unit and UnitGUID(unit) == guid then
			addItemLevel(GameTooltip, average)
			GameTooltip:Show()
		end
	end
end

inspectRetry:SetScript("OnUpdate", function(self, elapsed)
	self.remain = self.remain - elapsed
	if self.remain <= 0 then
		self:Hide()
		finishInspect()
	end
end)

Misc:RegisterEvent("INSPECT_TALENT_READY", function()
	if inspectGuid then
		inspectRetries = 0
		inspectRetry.remain = ILVL_RETRY_DELAY
		inspectRetry:Show()
	end
end)

local function unitItemLevel(tooltip, unit)
	if UnitIsUnit(unit, "player") then
		local average, count = ns.UnitAverageItemLevel("player")
		if count > 0 then
			addItemLevel(tooltip, average)
		end
		return
	end

	local guid = UnitGUID(unit)
	local cached = itemLevels[guid]
	if cached and GetTime() - cached.time < ILVL_CACHE_TIME then
		addItemLevel(tooltip, cached.level)
		return
	end

	if InspectFrame and InspectFrame:IsShown() then
		return
	end
	if inspectGuid and GetTime() - inspectTime < ILVL_REQUEST_THROTTLE then
		return
	end
	if CanInspect(unit) and CheckInteractDistance(unit, 1) then
		inspectGuid, inspectUnit, inspectTime = guid, unit, GetTime()
		NotifyInspect(unit)
	end
end

local function onTooltipSetUnit(tooltip)
	local _, unit = tooltip:GetUnit()
	if not unit then
		local focus = GetMouseFocus()
		unit = focus and focus.GetAttribute and focus:GetAttribute("unit")
	end
	if not (unit and UnitExists(unit)) then
		return
	end

	if tooltip:GetOwner() ~= UIParent and InCombatLockdown() and not IsShiftKeyDown() then
		tooltip:Hide()
		return
	end

	local title = titleLine(tooltip)
	if title then
		title:SetText(colorize(unit, title:GetText() or UnitName(unit)))
	end
	local isPlayer = UnitIsPlayer(unit)
	if isPlayer then
		local guild, rank = GetGuildInfo(unit)
		local second = titleLine(tooltip, 2)
		local secondText = guild and second and second:GetText()
		if secondText and secondText:find(guild, 1, true) then
			second:SetFormattedText("<|cff00ff10%s|r> |cffaaaaaa%s|r", guild, rank or "")
		end
		unitItemLevel(tooltip, unit)
	end

	local target = unit .. "target"
	if unit ~= "player" and UnitExists(target) then
		local name = UnitIsUnit(target, "player") and "|cffff0000<YOU>|r" or colorize(target, UnitName(target))
		tooltip:AddDoubleLine("Target", name)
	end

	local prefix, count = groupUnits()
	wipe(targetedBy)
	for i = 1, count do
		local member = prefix .. i
		if not UnitIsUnit(member, "player") and UnitIsUnit(member .. "target", unit) then
			targetedBy[#targetedBy + 1] = colorize(member, UnitName(member))
		end
	end
	local numTargeting = #targetedBy
	if numTargeting > 0 then
		tooltip:AddLine(("Targeted by (%d): %s"):format(numTargeting, tconcat(targetedBy, ", ")), 1, 1, 1, true)
	end

	if not isPlayer then
		local guid = UnitGUID(unit)
		local npcId = guid and tonumber(guid:sub(7, 12), 16)
		if npcId and npcId > 0 then
			tooltip:AddLine(labeled("NPC ID", npcId))
		end
	end

	tooltip:Show()
end

GameTooltip:HookScript("OnTooltipSetUnit", onTooltipSetUnit)

local healthText = GameTooltipStatusBar:CreateFontString(nil, "OVERLAY", "SystemFont_Outline_Small")
healthText:SetPoint("CENTER")

GameTooltipStatusBar:HookScript("OnValueChanged", function(bar, value)
	local _, max = bar:GetMinMaxValues()
	if not value or max == 0 then
		healthText:SetText("")
	elseif max == 1 then
		healthText:SetFormattedText("%d%%", value * 100)
	else
		healthText:SetFormattedText("%s / %s", ns.FormatValue(value), ns.FormatValue(max))
	end
end)

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
