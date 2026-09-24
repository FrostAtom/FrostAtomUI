local _, ns = ...

local L = ns.L

local GetSpellInfo = GetSpellInfo
local GetTime = GetTime
local UnitGUID = UnitGUID
local huge, random = math.huge, math.random

local Auras = ns.Auras
local LossOfControl = ns:NewModule("LossOfControl")
local UF = ns:GetModule("UnitFrames")

local FRAME_WIDTH, FRAME_HEIGHT = 256, 58
local LINE_WIDTH, LINE_HEIGHT = 236, 2
local ICON_SIZE = 48
local TEXT_GAP = 6
local NAME_SIZE, NAME_MAX_SIZE = 22, 32
local TIME_SIZE, TIME_MAX_SIZE = 20, 28
local INTRO_STEP = 0.1
local TEXT_DOWN_TIME = 0.2
local ICON_POP_SCALE = 1.33
local ICON_POP_OFFSET = -20
local LINE_START_SCALE, LINE_PEAK_SCALE = 0.1, 1.4
local SHADOW_ALPHA = 0.6

local PRIORITY = {
	cyclone = 5,
	stun = 5,
	fear = 5,
	horror = 5,
	charm = 5,
	seduce = 5,
	sleep = 5,
	polymorph = 5,
	incapacitate = 5,
	disorient = 5,
	banish = 5,
	silence = 4,
	lockout = 3,
	disarm = 2,
	root = 1,
}

local TEXT = {
	cyclone = "Cycloned",
	stun = "Stunned",
	fear = "Feared",
	horror = "Horrified",
	charm = "Charmed",
	seduce = "Seduced",
	sleep = "Asleep",
	polymorph = "Polymorphed",
	incapacitate = "Incapacitated",
	disorient = "Disoriented",
	banish = "Banished",
	silence = "Silenced",
	lockout = "%s locked",
	disarm = "Disarmed",
	root = "Rooted",
}

local CC_BY_NAME_IDS = {
	[33786] = "cyclone", -- Cyclone
	[853] = "stun", -- Hammer of Justice
	[2812] = "stun", -- Holy Wrath
	[20170] = "stun", -- Stun
	[408] = "stun", -- Kidney Shot
	[1833] = "stun", -- Cheap Shot
	[5211] = "stun", -- Bash
	[9005] = "stun", -- Pounce
	[22570] = "stun", -- Maim
	[12809] = "stun", -- Concussion Blow
	[7922] = "stun", -- Charge Stun
	[20253] = "stun", -- Intercept
	[46968] = "stun", -- Shockwave
	[44572] = "stun", -- Deep Freeze
	[12355] = "stun", -- Impact
	[30283] = "stun", -- Shadowfury
	[22703] = "stun", -- Inferno Effect
	[60995] = "stun", -- Demon Charge
	[47481] = "stun", -- Gnaw
	[24394] = "stun", -- Intimidation
	[50519] = "stun", -- Sonic Blast
	[50518] = "stun", -- Ravage
	[53148] = "stun", -- Charge
	[58861] = "stun", -- Bash
	[20549] = "stun", -- War Stomp
	[39796] = "stun", -- Stoneclaw Stun
	[31367] = "stun", -- Netherweave Net
	[31368] = "stun", -- Heavy Netherweave Net
	[46567] = "stun", -- Rocket Launch
	[30216] = "incapacitate", -- Fel Iron Bomb
	[30217] = "incapacitate", -- Adamantite Grenade
	[30461] = "incapacitate", -- The Bigger One
	[67769] = "incapacitate", -- Cobalt Frag Bomb
	[56350] = "incapacitate", -- Saronite Bomb
	[71988] = "incapacitate", -- Vile Fumes
	[5782] = "fear", -- Fear
	[5484] = "fear", -- Howl of Terror
	[8122] = "fear", -- Psychic Scream
	[5246] = "fear", -- Intimidating Shout
	[1513] = "fear", -- Scare Beast
	[10326] = "fear", -- Turn Evil
	[35474] = "fear", -- Drums of Panic
	[6789] = "horror", -- Death Coil
	[64044] = "horror", -- Psychic Horror
	[605] = "charm", -- Mind Control
	[13181] = "charm", -- Gnomish Mind Control Cap
	[6358] = "seduce", -- Seduction
	[2637] = "sleep", -- Hibernate
	[19386] = "sleep", -- Wyvern Sting
	[118] = "polymorph", -- Polymorph
	[51514] = "polymorph", -- Hex
	[30501] = "polymorph", -- Poultryized!
	[6770] = "incapacitate", -- Sap
	[1776] = "incapacitate", -- Gouge
	[20066] = "incapacitate", -- Repentance
	[51209] = "incapacitate", -- Hungering Cold
	[3355] = "incapacitate", -- Freezing Trap Effect
	[60210] = "incapacitate", -- Freezing Arrow Effect
	[9484] = "incapacitate", -- Shackle Undead
	[2094] = "disorient", -- Blind
	[19503] = "disorient", -- Scatter Shot
	[31661] = "disorient", -- Dragon's Breath
	[710] = "banish", -- Banish
	[15487] = "silence", -- Silence
	[1330] = "silence", -- Garrote - Silence
	[34490] = "silence", -- Silencing Shot
	[28730] = "silence", -- Arcane Torrent
	[47476] = "silence", -- Strangulate
	[24259] = "silence", -- Spell Lock
	[18469] = "silence", -- Silenced - Improved Counterspell
	[18498] = "silence", -- Silenced - Gag Order
	[18425] = "silence", -- Silenced - Improved Kick
	[63529] = "silence", -- Silenced - Shield of the Templar
	[19821] = "silence", -- Arcane Bomb
	[676] = "disarm", -- Disarm
	[51722] = "disarm", -- Dismantle
	[50541] = "disarm", -- Snatch
	[53359] = "disarm", -- Chimera Shot - Scorpid
	[64346] = "disarm", -- Fiery Payback
	[339] = "root", -- Entangling Roots
	[122] = "root", -- Frost Nova
	[33395] = "root", -- Freeze
	[12494] = "root", -- Frostbite
	[55080] = "root", -- Shattered Barrier
	[23694] = "root", -- Improved Hamstring
	[58373] = "root", -- Glyph of Hamstring
	[50245] = "root", -- Pin
	[54706] = "root", -- Venom Web Spray
	[4167] = "root", -- Web
	[19185] = "root", -- Entrapment
	[45334] = "root", -- Feral Charge Effect
	[19306] = "root", -- Counterattack
	[64695] = "root", -- Earthgrab
	[39965] = "root", -- Frost Grenade
	[55536] = "root", -- Frostweave Net
}

local CC_BY_ID = {
	[31117] = "silence", -- Unstable Affliction
	[64058] = "disarm", -- Psychic Horror
}

local LOCKOUTS = {
	[1766] = 5, -- Kick
	[1767] = 5, -- Kick
	[1768] = 5, -- Kick
	[1769] = 5, -- Kick
	[38768] = 5, -- Kick
	[6552] = 4, -- Pummel
	[6554] = 4, -- Pummel
	[72] = 6, -- Shield Bash
	[1671] = 6, -- Shield Bash
	[1672] = 6, -- Shield Bash
	[29704] = 6, -- Shield Bash
	[2139] = 8, -- Counterspell
	[57994] = 2, -- Wind Shear
	[47528] = 4, -- Mind Freeze
	[19244] = 5, -- Spell Lock
	[19647] = 6, -- Spell Lock
	[16979] = 4, -- Feral Charge - Bear
	[19675] = 4, -- Feral Charge Effect
	[62347] = 2, -- Nether Shock
	[26090] = 2, -- Pummel
}

local function schoolString(name)
	return _G["STRING_SCHOOL_" .. name]
end

local SCHOOLS = {
	[0x01] = schoolString("PHYSICAL"),
	[0x02] = schoolString("HOLY"),
	[0x04] = schoolString("FIRE"),
	[0x08] = schoolString("NATURE"),
	[0x10] = schoolString("FROST"),
	[0x20] = schoolString("SHADOW"),
	[0x40] = schoolString("ARCANE"),
	[0x05] = schoolString("FLAMESTRIKE"),
	[0x11] = schoolString("FROSTSTRIKE"),
	[0x41] = schoolString("SPELLSTRIKE"),
	[0x09] = schoolString("STORMSTRIKE"),
	[0x21] = schoolString("SHADOWSTRIKE"),
	[0x03] = schoolString("HOLYSTRIKE"),
	[0x14] = schoolString("FROSTFIRE"),
	[0x44] = schoolString("SPELLFIRE"),
	[0x0C] = schoolString("FIRESTORM"),
	[0x24] = schoolString("SHADOWFLAME"),
	[0x06] = schoolString("HOLYFIRE"),
	[0x50] = schoolString("SPELLFROST"),
	[0x18] = schoolString("FROSTSTORM"),
	[0x30] = schoolString("SHADOWFROST"),
	[0x12] = schoolString("HOLYFROST"),
	[0x48] = schoolString("SPELLSTORM"),
	[0x60] = schoolString("SPELLSHADOW"),
	[0x42] = schoolString("DIVINE"),
	[0x28] = schoolString("SHADOWSTORM"),
	[0x0A] = schoolString("HOLYSTORM"),
	[0x22] = schoolString("SHADOWLIGHT"),
	[0x1C] = schoolString("ELEMENTAL"),
	[0x7C] = schoolString("CHROMATIC"),
	[0x7E] = schoolString("MAGIC"),
	[0x7F] = schoolString("CHAOS"),
}

local TEST_SPELLS = {
	{ 33786, "cyclone" }, -- Cyclone
	{ 853, "stun" }, -- Hammer of Justice
	{ 8122, "fear" }, -- Psychic Scream
	{ 118, "polymorph" }, -- Polymorph
	{ 15487, "silence" }, -- Silence
	{ 2139, "lockout", 0x10 }, -- Counterspell
	{ 676, "disarm" }, -- Disarm
	{ 122, "root" }, -- Frost Nova
}

local CC_BY_NAME = {}
for spellId, category in pairs(CC_BY_NAME_IDS) do
	local name = GetSpellInfo(spellId)
	if name then
		CC_BY_NAME[name] = category
	end
end

local frame, icon, cooldown, nameText, timeText
local lines = {}
local shadows = {}

local playerGUID
local lockout = { category = "lockout", expires = 0 }
local testEntry = { expires = 0 }
local testIndex = 0
local testing

local shownSpell, shownStart, shownDuration, shownExpires
local timeIntFormat, timeFloatFormat
local iconX = 0
local introTime

local bestCategory, bestSpell, bestIcon, bestStart, bestDuration, bestExpires, bestSchool, bestRank

local function consider(category, spellId, texture, start, duration, expires, schoolMask)
	local rank = expires == 0 and huge or expires
	local priority = PRIORITY[category]
	if bestCategory then
		local bestPriority = PRIORITY[bestCategory]
		if priority < bestPriority or (priority == bestPriority and rank <= bestRank) then
			return
		end
	end
	bestCategory, bestSpell, bestIcon = category, spellId, texture
	bestStart, bestDuration, bestExpires, bestSchool, bestRank = start, duration, expires, schoolMask, rank
end

local function considerEntry(entry)
	consider(entry.category, entry.spellId, entry.icon, entry.start, entry.duration, entry.expires, entry.school)
end

local function setLineWidth(width)
	local half = width / 2
	for i = 1, #lines do
		lines[i]:SetWidth(half)
	end
end

local function setIcon(scale, offset)
	local size = ICON_SIZE * scale
	icon:SetSize(size, size)
	icon:SetPoint("CENTER", frame, "CENTER", iconX + offset, 0)
end

local function setTextHeight(t)
	local progress
	if t < INTRO_STEP then
		progress = t / INTRO_STEP
	else
		progress = 1 - (t - INTRO_STEP) / TEXT_DOWN_TIME
	end
	nameText:SetTextHeight(NAME_SIZE + (NAME_MAX_SIZE - NAME_SIZE) * progress)
	timeText:SetTextHeight(TIME_SIZE + (TIME_MAX_SIZE - TIME_SIZE) * progress)
end

local function applyIntro(t)
	if t < INTRO_STEP then
		local progress = t / INTRO_STEP
		setLineWidth(LINE_WIDTH * (LINE_START_SCALE + (LINE_PEAK_SCALE - LINE_START_SCALE) * progress))
		setIcon(1 + (ICON_POP_SCALE - 1) * progress, ICON_POP_OFFSET * progress)
	elseif t < INTRO_STEP * 2 then
		local progress = (t - INTRO_STEP) / INTRO_STEP
		setLineWidth(LINE_WIDTH * (LINE_PEAK_SCALE + (1 - LINE_PEAK_SCALE) * progress))
		setIcon(ICON_POP_SCALE + (1 - ICON_POP_SCALE) * progress, ICON_POP_OFFSET * (1 - progress))
	elseif not cooldown.intro then
		cooldown.intro = true
		setLineWidth(LINE_WIDTH)
		setIcon(1, 0)
		if shownDuration > 0 then
			cooldown:Show()
		end
	end

	if t < INTRO_STEP + TEXT_DOWN_TIME then
		setTextHeight(t)
	else
		nameText:SetTextHeight(NAME_SIZE)
		timeText:SetTextHeight(TIME_SIZE)
		introTime = nil
	end
end

local function setTime(remaining)
	if remaining >= 10 then
		timeText:SetFormattedText(timeIntFormat, remaining)
	elseif remaining < 9.95 then
		timeText:SetFormattedText(timeFloatFormat, remaining)
	end
end

local function layout()
	nameText:SetTextHeight(NAME_SIZE)
	timeText:SetTextHeight(TIME_SIZE)
	local nameWidth, timeWidth = nameText:GetStringWidth(), timeText:GetStringWidth()
	local textWidth = nameWidth > timeWidth and nameWidth or timeWidth
	local total = ICON_SIZE + TEXT_GAP + textWidth
	iconX = (ICON_SIZE - total) / 2
	local textX = ICON_SIZE + TEXT_GAP - total / 2
	nameText:SetPoint("LEFT", frame, "CENTER", textX, 11)
	timeText:SetPoint("LEFT", frame, "CENTER", textX, -12)
	setIcon(1, 0)
end

local function setUp(animate)
	shownSpell, shownStart, shownDuration, shownExpires = bestSpell, bestStart, bestDuration, bestExpires

	local text = L[TEXT[bestCategory]]
	if bestCategory == "lockout" then
		text = text:format(SCHOOLS[bestSchool] or schoolString("UNKNOWN"))
	end
	nameText:SetText(text)
	icon:SetTexture(bestIcon)

	timeIntFormat, timeFloatFormat = L["%d seconds"], L["%.1f seconds"]
	if bestExpires > 0 then
		timeText:SetFormattedText(timeFloatFormat, 8.8)
		timeText:Show()
	else
		timeText:SetText("")
		timeText:Hide()
	end
	layout()
	if bestExpires > 0 then
		setTime(bestExpires - GetTime())
	end

	if bestDuration > 0 then
		cooldown:SetCooldown(bestStart, bestDuration)
	end

	if animate then
		introTime = 0
		cooldown.intro = nil
		cooldown:Hide()
		applyIntro(0)
		if ns.Config.lossOfControl.sound then
			ns.PlayAlertSound("RaidWarning")
		end
	elseif not introTime then
		cooldown.intro = true
		setLineWidth(LINE_WIDTH)
		if bestDuration > 0 then
			cooldown:Show()
		else
			cooldown:Hide()
		end
	end

	frame:Show()
end

local function nextTest(now)
	testIndex = testIndex % #TEST_SPELLS + 1
	local spellId, category, schoolMask = unpack(TEST_SPELLS[testIndex])
	local _, _, texture = GetSpellInfo(spellId)
	local duration = random(4, 8)
	testEntry.category, testEntry.spellId, testEntry.icon, testEntry.school = category, spellId, texture, schoolMask
	testEntry.start, testEntry.duration, testEntry.expires = now, duration, now + duration
end

local function refresh()
	local config = ns.Config.lossOfControl
	bestCategory = nil
	if config.enabled then
		local now = GetTime()
		if testing then
			if testEntry.expires <= now then
				nextTest(now)
			end
			considerEntry(testEntry)
		else
			local auras, count = Auras.Get("player", "HARMFUL")
			for i = 1, count do
				local aura = auras[i]
				local category = CC_BY_ID[aura.spellId] or CC_BY_NAME[aura.name]
				local expires = aura.expires
				if category and config.categories[category] ~= false and (expires == 0 or expires > now) then
					consider(category, aura.spellId, aura.icon, expires - aura.duration, aura.duration, expires)
				end
			end
			if config.lockouts and lockout.expires > now then
				considerEntry(lockout)
			end
		end
	end

	if not bestCategory then
		shownSpell = nil
		frame:Hide()
		return
	end

	local isNew = not frame:IsShown() or bestSpell ~= shownSpell or bestStart ~= shownStart
	if isNew or bestDuration ~= shownDuration or bestExpires ~= shownExpires then
		setUp(isNew)
	end
end

local function onUpdate(_, elapsed)
	if introTime then
		introTime = introTime + elapsed
		applyIntro(introTime)
	end
	if shownExpires > 0 then
		local remaining = shownExpires - GetTime()
		if remaining <= 0 then
			refresh()
		else
			setTime(remaining)
		end
	end
end

local function onCombatLogEvent(_, _, event, _, _, _, destGUID, _, _, spellId, _, _, _, _, extraSchool)
	if event ~= "SPELL_INTERRUPT" or destGUID ~= playerGUID then
		return
	end
	local duration = LOCKOUTS[spellId]
	if not duration then
		return
	end
	local now = GetTime()
	local _, _, texture = GetSpellInfo(spellId)
	lockout.spellId, lockout.icon, lockout.school = spellId, texture, extraSchool
	lockout.start, lockout.duration, lockout.expires = now, duration, now + duration
	refresh()
end

local function onEnteringWorld()
	playerGUID = UnitGUID("player")
	lockout.expires = 0
	refresh()
end

local function createGradient(r, g, b, fromAlpha, toAlpha)
	local texture = frame:CreateTexture(nil, "BACKGROUND")
	texture:SetTexture(ns.Media.blank)
	texture:SetGradientAlpha("HORIZONTAL", r, g, b, fromAlpha, r, g, b, toAlpha)
	return texture
end

local function createLineHalf(point, relativePoint, fromAlpha, toAlpha)
	local half = createGradient(1, 0.1, 0.1, fromAlpha, toAlpha)
	half:SetHeight(LINE_HEIGHT)
	half:SetPoint(point, frame, relativePoint, 0, 0)
	lines[#lines + 1] = half
end

local function createLine(point, relativePoint)
	createLineHalf(point .. "RIGHT", relativePoint, 0, 1)
	createLineHalf(point .. "LEFT", relativePoint, 1, 0)
end

local function createFrame()
	frame = CreateFrame("Frame", nil, UIParent)
	frame:SetSize(FRAME_WIDTH, FRAME_HEIGHT)
	frame:SetFrameStrata("HIGH")
	frame:Hide()
	frame:SetScript("OnUpdate", onUpdate)

	local shadowLeft = createGradient(0, 0, 0, 0, SHADOW_ALPHA)
	shadowLeft:SetPoint("TOPLEFT")
	shadowLeft:SetPoint("BOTTOMRIGHT", frame, "BOTTOM")

	local shadowRight = createGradient(0, 0, 0, SHADOW_ALPHA, 0)
	shadowRight:SetPoint("TOPLEFT", frame, "TOP")
	shadowRight:SetPoint("BOTTOMRIGHT")
	shadows[1], shadows[2] = shadowLeft, shadowRight

	createLine("BOTTOM", "TOP")
	createLine("TOP", "BOTTOM")
	setLineWidth(LINE_WIDTH)

	icon = frame:CreateTexture(nil, "ARTWORK")
	icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)

	cooldown = CreateFrame("Cooldown", nil, frame)
	cooldown:SetReverse(true)
	cooldown:SetAllPoints(icon)
	cooldown.noCooldownCount = true

	nameText = frame:CreateFontString(nil, "OVERLAY")
	ns.SetFont(nameText, NAME_SIZE, "", true)
	nameText:SetShadowOffset(2, -2)
	nameText:SetTextColor(1, 0.82, 0)

	timeText = frame:CreateFontString(nil, "OVERLAY")
	ns.SetFont(timeText, TIME_SIZE, "", true)
	timeText:SetShadowOffset(2, -2)
	timeText:SetTextColor(1, 1, 1)
end

local function applyConfig()
	local config = ns.Config.lossOfControl
	frame:SetScale(config.scale)
	for _, list in ipairs({ shadows, lines }) do
		for i = 1, #list do
			if config.background then
				list[i]:Show()
			else
				list[i]:Hide()
			end
		end
	end
	if config.enabled then
		LossOfControl:RegisterUnitEvent("UNIT_AURA", "player", refresh)
		LossOfControl:RegisterEvent("PLAYER_ENTERING_WORLD", onEnteringWorld)
	else
		LossOfControl:UnregisterUnitEvent("UNIT_AURA", "player", refresh)
		LossOfControl:UnregisterEvent("PLAYER_ENTERING_WORLD", onEnteringWorld)
	end
	if config.enabled and config.lockouts then
		LossOfControl:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED", onCombatLogEvent)
	else
		LossOfControl:UnregisterEvent("COMBAT_LOG_EVENT_UNFILTERED", onCombatLogEvent)
		lockout.expires = 0
	end
	playerGUID = UnitGUID("player")
	shownDuration = nil
	refresh()
end

function LossOfControl:SetTestMode(enabled)
	enabled = enabled and true or nil
	if enabled == testing then
		return
	end
	testing = enabled
	testEntry.expires = 0
	shownSpell = nil
	if frame then
		refresh()
	end
end

function LossOfControl:IsTesting()
	return testing or false
end

function LossOfControl:Initialize()
	createFrame()
	self:AnchorToConfig(frame, "lossOfControl.point", "Loss of control", { floating = true })
	applyConfig()
	self:WatchConfig("lossOfControl", applyConfig)
	hooksecurefunc(UF, "SetTestMode", function()
		LossOfControl:SetTestMode(UF.testing)
	end)
end
