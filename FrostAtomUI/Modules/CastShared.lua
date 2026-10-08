local _, ns = ...
local L = ns.L

local UnitName = UnitName
local UnitClass = UnitClass
local UnitIsPlayer = UnitIsPlayer
local UnitIsUnit = UnitIsUnit
local UnitCanAttack = UnitCanAttack
local UnitIsFriend = UnitIsFriend
local IsInInstance = IsInInstance
local GetPlayerInfoByGUID = GetPlayerInfoByGUID
local GetSpellInfo = GetSpellInfo
local GetTime = GetTime
local band = bit.band
local floor = math.floor
local format, gmatch = string.format, string.gmatch
local wipe = wipe

-- 3.3.5: SPELL_INTERRUPT and the silence aura can reach the combat log after the cast already stopped
local LATE_INTERRUPT = 0.3
local PULSE_PERIOD = 2
local INTERRUPTED_TEXT = "|cff8B0000" .. INTERRUPTED .. "|r"
local PLAYER_FLAG = COMBATLOG_OBJECT_TYPE_PLAYER or 0x400
local ARENA_TARGET_ALPHA = 0.5

local Cast = {}
ns.Cast = Cast
Cast.LATE_INTERRUPT = LATE_INTERRUPT
Cast.TIMING = {
	STOP_TIMEOUT = 0.5,
	FINISH_WINDOW = 0.5,
	FLASH_TIME = 0.5,
	FLASH_ALPHA = 0.5,
	FADE_SPEED = 1 / 0.3,
	INTERRUPT_HOLD = 1,
	INTERRUPT_COLOR = { 0.8, 0.1, 0.1 },
	LATE_INTERRUPT = LATE_INTERRUPT,
}
Cast.INTERRUPTED_TEXT = INTERRUPTED_TEXT
Cast.CANCELLED_TEXT = "|cff808080" .. L["Cancelled"] .. "|r"

ns.OnLocaleReady(function()
	Cast.CANCELLED_TEXT = "|cff808080" .. L["Cancelled"] .. "|r"
end)

local DR_SPELLS = ns.DRData.SPELLS
local themeConfig, castConfig = ns.Config.theme, ns.Config.castbar

local IMPORTANT_CASTS = {
	118, -- Polymorph
	5782, -- Fear
	5484, -- Howl of Terror
	6358, -- Seduction
	33786, -- Cyclone
	51514, -- Hex
	605, -- Mind Control
	2637, -- Hibernate
	339, -- Entangling Roots
	1513, -- Scare Beast
	10326, -- Turn Evil
	8129, -- Mana Burn
	2060, -- Greater Heal
	2061, -- Flash Heal
	32546, -- Binding Heal
	596, -- Prayer of Healing
	47540, -- Penance
	64843, -- Divine Hymn
	635, -- Holy Light
	19750, -- Flash of Light
	5185, -- Healing Touch
	8936, -- Regrowth
	50464, -- Nourish
	740, -- Tranquility
	331, -- Healing Wave
	8004, -- Lesser Healing Wave
	1064, -- Chain Heal
	32375, -- Mass Dispel
}

local importantCasts = {}

local function rebuildImportantCasts()
	wipe(importantCasts)
	for i = 1, #IMPORTANT_CASTS do
		local name = GetSpellInfo(IMPORTANT_CASTS[i])
		if name then
			importantCasts[name] = true
		end
	end
	for token in gmatch(castConfig.importantExtra or "", "[^,;]+") do
		token = strtrim(token)
		local id = tonumber(token)
		local name = id and GetSpellInfo(id) or token
		if name and name ~= "" then
			importantCasts[name] = true
		end
	end
end
rebuildImportantCasts()
Cast.importantCasts = importantCasts

local importantWatcher = ns.Mixin({}, ns.EventMixin)
importantWatcher:RegisterEvent(ns.E.CONFIG_CHANGED, function(_, path)
	if not path or path:find("^castbar") then
		rebuildImportantCasts()
	end
end)

local CAST_KINDS = {
	control = {
		118, -- Polymorph
		5782, -- Fear
		6358, -- Seduction
		33786, -- Cyclone
		51514, -- Hex
		605, -- Mind Control
		2637, -- Hibernate
		339, -- Entangling Roots
		1513, -- Scare Beast
		10326, -- Turn Evil
	},
	help = {
		2060, -- Greater Heal
		2061, -- Flash Heal
		2054, -- Heal
		2050, -- Lesser Heal
		32546, -- Binding Heal
		596, -- Prayer of Healing
		635, -- Holy Light
		19750, -- Flash of Light
		5185, -- Healing Touch
		8936, -- Regrowth
		50464, -- Nourish
		331, -- Healing Wave
		8004, -- Lesser Healing Wave
		1064, -- Chain Heal
		2006, -- Resurrection
		7328, -- Redemption
		2008, -- Ancestral Spirit
		50769, -- Revive
		20484, -- Rebirth
	},
	none = {
		5484, -- Howl of Terror
		64843, -- Divine Hymn
		64901, -- Hymn of Hope
		740, -- Tranquility
		12051, -- Evocation
		1949, -- Hellfire
		5740, -- Rain of Fire
		10, -- Blizzard
		16914, -- Hurricane
		1510, -- Volley
	},
	any = {
		47540, -- Penance
	},
}
local castKinds = {}
for kind, ids in pairs(CAST_KINDS) do
	for i = 1, #ids do
		local name = GetSpellInfo(ids[i])
		if name then
			castKinds[name] = kind
		end
	end
end

function Cast.CreateGlow(parent, anchor, size)
	local glow = CreateFrame("Frame", nil, parent)
	glow:SetFrameLevel(parent:GetFrameLevel())
	glow:Hide()

	local function edge(texture)
		local region = glow:CreateTexture(nil, "BACKGROUND")
		region:SetTexture(texture or ns.Media.blank)
		region:SetBlendMode("ADD")
		return region
	end

	local function corner(point, relativePoint, left, right, top, bottom)
		local region = edge(ns.Media.glowCorner)
		region:SetSize(size, size)
		region:SetPoint(point, anchor, relativePoint)
		region:SetTexCoord(left, right, top, bottom)
		return region
	end

	local top = edge()
	top:SetPoint("BOTTOMLEFT", anchor, "TOPLEFT")
	top:SetPoint("BOTTOMRIGHT", anchor, "TOPRIGHT")
	top:SetHeight(size)
	local bottom = edge()
	bottom:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT")
	bottom:SetPoint("TOPRIGHT", anchor, "BOTTOMRIGHT")
	bottom:SetHeight(size)
	local left = edge()
	left:SetPoint("TOPRIGHT", anchor, "TOPLEFT")
	left:SetPoint("BOTTOMRIGHT", anchor, "BOTTOMLEFT")
	left:SetWidth(size)
	local right = edge()
	right:SetPoint("TOPLEFT", anchor, "TOPRIGHT")
	right:SetPoint("BOTTOMLEFT", anchor, "BOTTOMRIGHT")
	right:SetWidth(size)

	glow.top, glow.bottom, glow.left, glow.right = top, bottom, left, right
	glow.corners = {
		corner("BOTTOMRIGHT", "TOPLEFT", 0, 0.5, 0, 0.5),
		corner("BOTTOMLEFT", "TOPRIGHT", 0.5, 1, 0, 0.5),
		corner("TOPRIGHT", "BOTTOMLEFT", 0, 0.5, 0.5, 1),
		corner("TOPLEFT", "BOTTOMRIGHT", 0.5, 1, 0.5, 1),
	}
	return glow
end

function Cast.StartGlow(glow, color)
	local r, g, b = color[1], color[2], color[3]
	if r ~= glow.r or g ~= glow.g or b ~= glow.b then
		glow.r, glow.g, glow.b = r, g, b
		glow.top:SetGradientAlpha("VERTICAL", r, g, b, 1, r, g, b, 0)
		glow.bottom:SetGradientAlpha("VERTICAL", r, g, b, 0, r, g, b, 1)
		glow.left:SetGradientAlpha("HORIZONTAL", r, g, b, 0, r, g, b, 1)
		glow.right:SetGradientAlpha("HORIZONTAL", r, g, b, 1, r, g, b, 0)
		for i = 1, 4 do
			glow.corners[i]:SetVertexColor(r, g, b)
		end
	end
	glow.elapsed = 0
	glow:SetAlpha(0)
	glow:Show()
end

local function pulseCastGlow(glow, elapsed)
	local t = (glow.elapsed + elapsed) % PULSE_PERIOD
	glow.elapsed = t
	glow:SetAlpha(t < 1 and t or PULSE_PERIOD - t)
end
Cast.PulseGlow = pulseCastGlow

local function interruptedByText(color, name)
	return format(
		L["Interrupted by %s"],
		format("|cff%02x%02x%02x%s|r", floor(color[1] * 255), floor(color[2] * 255), floor(color[3] * 255), name)
	)
end

local function interrupterText(sourceGUID, sourceName, sourceFlags)
	if not sourceName then
		return INTERRUPTED_TEXT
	end
	local color
	if sourceFlags and band(sourceFlags, PLAYER_FLAG) > 0 then
		local _, class = GetPlayerInfoByGUID(sourceGUID)
		color = class and ns.Colors.class[class]
	end
	return interruptedByText(color or themeConfig.textColor, sourceName)
end
Cast.InterruptedByText = interruptedByText

local function castTarget(unit, targetUnit, spellName)
	if not castConfig.targetName or UnitIsUnit(targetUnit, unit) then
		return
	end
	local name = UnitName(targetUnit)
	local kind = castKinds[spellName]
	if not name or kind == "none" then
		return
	end
	if kind == "help" then
		if not UnitIsFriend(unit, targetUnit) then
			return
		end
	elseif kind ~= "any" then
		if not UnitCanAttack(unit, targetUnit) then
			return
		end
		if kind == "control" and select(2, IsInInstance()) == "arena" then
			return name, true
		end
	end
	return name, false
end
Cast.CastTarget = castTarget

local function setUnitNameText(text, unit, name, uncertain)
	text:SetText(uncertain and name .. "?" or name)
	text:SetAlpha(uncertain and ARENA_TARGET_ALPHA or 1)
	local _, class = UnitClass(unit)
	local color = UnitIsPlayer(unit) and class and ns.Colors.class[class] or themeConfig.textColor
	text:SetTextColor(color[1], color[2], color[3])
end

function Cast.ShowCastTarget(text, unit, targetUnit, spellName)
	local name, uncertain = castTarget(unit, targetUnit, spellName)
	if name then
		setUnitNameText(text, targetUnit, name, uncertain)
	else
		text:SetText("")
	end
end

local silencedAt, silenceTexts = {}, {}

local function recentSilence(guid)
	local at = guid and silencedAt[guid]
	if at and GetTime() - at < LATE_INTERRUPT then
		return silenceTexts[guid]
	end
end
Cast.RecentSilence = recentSilence

local interruptWatcher = ns.Mixin({}, ns.EventMixin)
ns.CombatLog.Register(
	interruptWatcher,
	{ "SPELL_INTERRUPT", "SPELL_AURA_APPLIED" },
	function(_, _, event, sourceGUID, sourceName, sourceFlags, destGUID, _, _, spellId)
		if event == "SPELL_INTERRUPT" then
			ns:Fire(ns.E.CAST_INTERRUPTED, destGUID, interrupterText(sourceGUID, sourceName, sourceFlags))
		elseif event == "SPELL_AURA_APPLIED" and DR_SPELLS[spellId] == "silence" then
			local text = interrupterText(sourceGUID, sourceName, sourceFlags)
			silencedAt[destGUID] = GetTime()
			silenceTexts[destGUID] = text
			ns:Fire(ns.E.CAST_SILENCED, destGUID, text)
		end
	end
)
interruptWatcher:RegisterEvent("PLAYER_ENTERING_WORLD", function()
	wipe(silencedAt)
	wipe(silenceTexts)
end)
