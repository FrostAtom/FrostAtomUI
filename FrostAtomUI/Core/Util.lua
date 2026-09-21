local ADDON_NAME, ns = ...

local tremove = table.remove
local floor, modf, min, abs = math.floor, math.modf, math.min, math.abs
local select, ipairs, pairs, next = select, ipairs, pairs, next

local function tContains(tbl, item)
	for i = 1, #tbl do
		if tbl[i] == item then
			return i
		end
	end
end
ns.tContains = tContains

function ns.tDeleteItem(tbl, item)
	local index = tContains(tbl, item)
	if index then
		return tremove(tbl, index)
	end
end

local UnitAura = UnitAura
local MAX_AURAS = 40

function ns.FindAura(unit, wantedSpellId, filter)
	for i = 1, MAX_AURAS do
		local name, _, _, _, _, _, _, _, _, _, spellId = UnitAura(unit, i, filter)
		if not name then
			return
		end
		if spellId == wantedSpellId then
			return UnitAura(unit, i, filter)
		end
	end
end

local UnitGUID = UnitGUID
-- stylua: ignore
local GUID_UNITS = {
	"player", "target", "focus",
	"party1", "party2", "party3", "party4",
	"arena1", "arena2", "arena3",
	"pet", "partypet1", "partypet2", "partypet3", "partypet4",
	"arenapet1", "arenapet2", "arenapet3",
}

function ns.UnitByGUID(guid)
	for i = 1, #GUID_UNITS do
		local unit = GUID_UNITS[i]
		if UnitGUID(unit) == guid then
			return unit
		end
	end
end

function ns.noop() end

local function destroyFrame(frame, deep)
	if not frame then
		return
	end

	frame:Hide()
	frame:SetScript("OnShow", frame.Hide)
	frame:UnregisterAllEvents()

	if deep then
		for _, child in ipairs({ frame:GetChildren() }) do
			destroyFrame(child)
		end
	end
end
ns.DestroyFrame = destroyFrame

local SMOOTH_SPEED = 12
local smoothing = {}

local smoother = CreateFrame("Frame")
smoother:Hide()
smoother:SetScript("OnUpdate", function(_, elapsed)
	local step = min(elapsed * SMOOTH_SPEED, 1)
	for bar, target in pairs(smoothing) do
		local current = bar:GetValue()
		local low, high = bar:GetMinMaxValues()
		local new = current + (target - current) * step
		if abs(target - new) < (high - low) * 0.002 or not bar:IsVisible() then
			new = target
			smoothing[bar] = nil
		end
		bar:SetValueRaw(new)
	end
	if not next(smoothing) then
		smoother:Hide()
	end
end)

local function smoothSetValue(bar, value)
	smoothing[bar] = value
	smoother:Show()
end

local function snapValue(bar, value)
	smoothing[bar] = nil
	bar:SetValueRaw(value)
end

function ns.SmoothBar(bar)
	bar.SetValueRaw = bar.SetValue
	bar.SetValue = smoothSetValue
	bar.SnapValue = snapValue
	return bar
end

function ns.PixelPerfect(size)
	return size * (2 - UIParent:GetEffectiveScale())
end

local PRINT_PREFIX = "|cff177cbf[" .. ADDON_NAME .. "]|r: "

function ns.Print(format, ...)
	print(PRINT_PREFIX .. format:format(...))
end

function ns.TruncateUTF8(text, maxChars)
	local chars, i, length = 0, 1, #text
	while i <= length do
		chars = chars + 1
		if chars > maxChars then
			return text:sub(1, i - 1)
		end

		local byte = text:byte(i)
		if byte >= 0xF0 then
			i = i + 4
		elseif byte >= 0xE0 then
			i = i + 3
		elseif byte >= 0xC0 then
			i = i + 2
		else
			i = i + 1
		end
	end
	return text
end

function ns.FormatValue(value)
	if value < 1e3 then
		return value
	elseif value < 1e6 then
		return ("%.1fk"):format(value / 1e3)
	else
		return ("%.1fm"):format(value / 1e6)
	end
end

local function splitMoney(copper)
	return floor(copper / 1e4), floor(copper % 1e4 / 100), copper % 100
end

function ns.FormatMoney(money)
	local gold, silver, copper = splitMoney(money)
	if gold > 0 then
		return ("%d|cffffd700g|r %d|cffc7c7cfs|r"):format(gold, silver)
	elseif silver > 0 then
		return ("%d|cffc7c7cfs|r %d|cffeda55fc|r"):format(silver, copper)
	end
	return ("%d|cffeda55fc|r"):format(copper)
end

local GOLD_ICON = "|TInterface\\MoneyFrame\\UI-GoldIcon:%d:%d:2:0|t"
local SILVER_ICON = "|TInterface\\MoneyFrame\\UI-SilverIcon:%d:%d:2:0|t"
local COPPER_ICON = "|TInterface\\MoneyFrame\\UI-CopperIcon:%d:%d:2:0|t"

function ns.FormatMoneyIcons(money, iconSize)
	iconSize = iconSize or 12
	local gold, silver, copper = splitMoney(money)
	local goldIcon = GOLD_ICON:format(iconSize, iconSize)
	local silverIcon = SILVER_ICON:format(iconSize, iconSize)
	local copperIcon = COPPER_ICON:format(iconSize, iconSize)
	if gold > 0 then
		return ("%d%s %d%s %d%s"):format(gold, goldIcon, silver, silverIcon, copper, copperIcon)
	elseif silver > 0 then
		return ("%d%s %d%s"):format(silver, silverIcon, copper, copperIcon)
	end
	return ("%d%s"):format(copper, copperIcon)
end

function ns.ColorGradient(percent, ...)
	if percent ~= percent then
		percent = 0
	end

	local numColors = select("#", ...) / 3
	if percent >= 1 then
		return select(numColors * 3 - 2, ...)
	elseif percent <= 0 then
		return ...
	end

	local segment, relativePercent = modf(percent * (numColors - 1))
	local r1, g1, b1, r2, g2, b2 = select(segment * 3 + 1, ...)

	return r1 + (r2 - r1) * relativePercent, g1 + (g2 - g1) * relativePercent, b1 + (b2 - b1) * relativePercent
end

function ns.GridPoint(point, i, perRow, size)
	i = i - 1
	local column, row = i % perRow, floor(i / perRow)

	local xSign = point:find("RIGHT") and -1 or 1
	local ySign = point:find("BOTTOM") and 1 or -1
	return point, xSign * column * size, ySign * row * size
end
