local ADDON_NAME, ns = ...

local UnitGUID, GetSpellInfo = UnitGUID, GetSpellInfo
local tremove = table.remove
local floor, modf, min, abs = math.floor, math.modf, math.min, math.abs

local function indexOf(tbl, item)
	for i = 1, #tbl do
		if tbl[i] == item then
			return i
		end
	end
end
ns.tContains = indexOf

function ns.tDeleteItem(tbl, item)
	local index = indexOf(tbl, item)
	if index then
		return tremove(tbl, index)
	end
end

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

local spellTextures = {}

function ns.SpellTexture(spellId)
	local texture = spellTextures[spellId]
	if texture == nil then
		local _, _, icon = GetSpellInfo(spellId)
		texture = icon or false
		spellTextures[spellId] = texture
	end
	return texture or nil
end

local destroyFrame

local function destroyChildren(child, ...)
	if child then
		destroyFrame(child)
		return destroyChildren(...)
	end
end

function destroyFrame(frame, deep)
	if not frame then
		return
	end

	frame:Hide()
	frame:SetScript("OnShow", frame.Hide)
	frame:UnregisterAllEvents()

	if deep then
		destroyChildren(frame:GetChildren())
	end
end
ns.DestroyFrame = destroyFrame

local SMOOTH_SPEED = 12
local SMOOTH_SNAP_FRACTION = 0.002
local smoothing = {}

local smoother = CreateFrame("Frame")
smoother:Hide()
smoother:SetScript("OnUpdate", function(_, elapsed)
	local step = min(elapsed * SMOOTH_SPEED, 1)
	for bar, target in pairs(smoothing) do
		local new = target
		if bar:IsVisible() then
			local current = bar:GetValue()
			local low, high = bar:GetMinMaxValues()
			new = current + (target - current) * step
			if abs(target - new) < (high - low) * SMOOTH_SNAP_FRACTION then
				new = target
			end
		end
		if new == target then
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

local FADE_INTERVAL = 0.05
local FADE_IN_SPEED = 6
local FADE_OUT_SPEED = 2.5
local FADE_EPSILON = 0.01

local faders = {}
local FaderMixin = {}
local inCombat = InCombatLockdown() and true or false

local function anyMouseOver(frames)
	for i = 1, #frames do
		local frame = frames[i]
		if frame:IsVisible() and frame:IsMouseOver() then
			return true
		end
	end
	return false
end

local function isAwake(fader)
	if not fader.enabled then
		return true
	end
	local combat = fader.combat
	if combat == "combat" then
		if inCombat then
			return true
		end
	elseif combat == "nocombat" then
		if not inCombat then
			return true
		end
	elseif not fader.mouseover then
		return true
	end
	if fader.isActive and fader.isActive() then
		return true
	end
	return fader.mouseover and anyMouseOver(fader.hover)
end

function FaderMixin:UpdateMouse(awake)
	local frames = self.mouse
	if not frames or InCombatLockdown() then
		return
	end
	if awake == nil then
		awake = isAwake(self)
	end
	local enabled = self.combat == "any" or awake or (inCombat and self.mouseover)
	if enabled == self.mouseEnabled then
		return
	end
	self.mouseEnabled = enabled
	for i = 1, #frames do
		frames[i]:EnableMouse(enabled)
	end
end

function FaderMixin:SetMouseFrames(frames)
	self.mouse = frames
	self.mouseEnabled = nil
	self:UpdateMouse()
end

function FaderMixin:SetAlpha(alpha)
	self.current = alpha
	for i = 1, #self.frames do
		self.frames[i]:SetAlpha(alpha)
	end
	for i = 1, #self.inverse do
		self.inverse[i]:SetAlpha(1 - alpha)
	end
end

function FaderMixin:Update(elapsed)
	local awake = isAwake(self)
	if self.mouse then
		self:UpdateMouse(awake)
	end
	local target = awake and 1 or self.alpha
	if abs(target - self.current) < FADE_EPSILON then
		self:SetAlpha(target)
		return
	end
	local speed = target > self.current and FADE_IN_SPEED or FADE_OUT_SPEED
	self:SetAlpha(self.current + (target - self.current) * min(elapsed * speed, 1))
end

function FaderMixin:Configure(mouseover, alpha, combat)
	self.mouseover = mouseover and true or false
	self.combat = combat or "any"
	self.enabled = self.mouseover or self.combat ~= "any"
	self.alpha = alpha or 0
	if not self.enabled then
		self:SetAlpha(1)
	end
	self:UpdateMouse()
end

function ns.CreateFader(frames, hover, isActive, inverse)
	local fader = ns.Mixin({
		frames = frames,
		hover = hover or frames,
		isActive = isActive,
		inverse = inverse or {},
		enabled = false,
		mouseover = false,
		combat = "any",
		alpha = 0,
		current = 1,
	}, FaderMixin)
	faders[#faders + 1] = fader
	return fader
end

local untilNextFade = 0

local fadeRunner = CreateFrame("Frame")

fadeRunner:SetScript("OnUpdate", function(_, elapsed)
	untilNextFade = untilNextFade - elapsed
	if untilNextFade > 0 then
		return
	end
	elapsed = FADE_INTERVAL - untilNextFade
	untilNextFade = FADE_INTERVAL

	for i = 1, #faders do
		local fader = faders[i]
		if fader.enabled or fader.current ~= 1 then
			fader:Update(elapsed)
		end
	end
end)

local combatWatcher = CreateFrame("Frame")
combatWatcher:RegisterEvent("PLAYER_REGEN_DISABLED")
combatWatcher:RegisterEvent("PLAYER_REGEN_ENABLED")
combatWatcher:SetScript("OnEvent", function(_, event)
	inCombat = event == "PLAYER_REGEN_DISABLED"
	for i = 1, #faders do
		local fader = faders[i]
		if fader.combat ~= "any" then
			fader:Update(1)
		elseif fader.mouse then
			fader:UpdateMouse()
		end
	end
end)

local HEALTH_HUE_LOW, HEALTH_HUE_HIGH = 0, 110
local HEALTH_SATURATION = 0.5
local HEALTH_LIGHTNESS = 0.6
local HEALTH_STEPS = 100

local healthColors = {}

local function hueChannel(p, q, t)
	if t < 0 then
		t = t + 1
	elseif t > 1 then
		t = t - 1
	end
	if t < 1 / 6 then
		return p + (q - p) * 6 * t
	elseif t < 0.5 then
		return q
	elseif t < 2 / 3 then
		return p + (q - p) * (2 / 3 - t) * 6
	end
	return p
end

function ns.HealthColor(percent)
	if percent ~= percent or percent < 0 then
		percent = 0
	elseif percent > 1 then
		percent = 1
	end

	local step = floor(percent * HEALTH_STEPS + 0.5)
	local color = healthColors[step]
	if not color then
		local hue = (HEALTH_HUE_LOW + (HEALTH_HUE_HIGH - HEALTH_HUE_LOW) * step / HEALTH_STEPS) / 360
		local q = HEALTH_LIGHTNESS + HEALTH_SATURATION - HEALTH_LIGHTNESS * HEALTH_SATURATION
		local p = 2 * HEALTH_LIGHTNESS - q
		color = { hueChannel(p, q, hue + 1 / 3), hueChannel(p, q, hue), hueChannel(p, q, hue - 1 / 3) }
		healthColors[step] = color
	end
	return color[1], color[2], color[3]
end

function ns.PixelPerfect(size)
	return size * (2 - UIParent:GetEffectiveScale())
end

local PRINT_PREFIX = "|cff177cbf[" .. ADDON_NAME .. "]|r: "
ns.PRINT_PREFIX = PRINT_PREFIX

function ns.Print(format, ...)
	print(PRINT_PREFIX .. format:format(...))
end

function ns.ParseToggle(args, current)
	local arg = strtrim(args or ""):lower()
	if arg == "on" then
		return true
	elseif arg == "off" then
		return false
	elseif arg == "status" then
		return current, true
	end
	return not current
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

local thousandsCache, millionsCache = {}, {}

local function formatTenths(cache, tenths, pattern)
	local text = cache[tenths]
	if not text then
		text = pattern:format(tenths / 10)
		cache[tenths] = text
	end
	return text
end

function ns.FormatValue(value)
	if value < 1e3 then
		return value
	elseif value < 1e6 then
		return formatTenths(thousandsCache, floor(value / 100 + 0.5), "%.1fk")
	end
	return formatTenths(millionsCache, floor(value / 1e5 + 0.5), "%.1fm")
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
