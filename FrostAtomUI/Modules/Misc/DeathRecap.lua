local _, ns = ...

local L = ns.L

local GetTime = GetTime
local GetSpellInfo = GetSpellInfo
local GetPlayerInfoByGUID = GetPlayerInfoByGUID
local UnitGUID = UnitGUID
local UnitHealth = UnitHealth
local UnitHealthMax = UnitHealthMax
local UnitIsFeignDeath = UnitIsFeignDeath
local IsInInstance = IsInInstance
local GameTooltip = GameTooltip
local RAID_CLASS_COLORS = RAID_CLASS_COLORS
local COMBATLOG_OBJECT_TYPE_PLAYER = COMBATLOG_OBJECT_TYPE_PLAYER
local floor = math.floor
local band = bit.band
local concat = table.concat
local format = string.format
local gsub = string.gsub

local Misc = ns:GetModule("Misc")

local FRAME_NAME = "FrostAtomUIDeathRecap"
local LINK_PREFIX = "farecap:"
local CHAT_LINE = "%s |cffff4d4d|H" .. LINK_PREFIX .. "%d|h[%s]|h|r"
local NAME_COLOR = "|cff%02x%02x%02x%s|r"
local RECAPS_KEPT = 30
local BUFFER_SIZE = 20
local RECAP_WINDOW = 10
local WIDTH = 340
local PADDING = 12
local HEADER_HEIGHT = 26
local ROW_HEIGHT = 34
local ICON_SIZE = 26
local ICON_TRIM = 0.08
local AMOUNT_WIDTH = 80
local TOMBSTONE_SIZE = 16
local TOMBSTONE_ICON = "Interface\\TargetingFrame\\UI-TargetingFrame-Skull"
local ENVIRONMENT_ICON = "Interface\\Icons\\Ability_Creature_Cursed_05"
local MELEE_SPELL = 6603 -- Auto Attack
local DAMAGE_COLOR = { 0.75, 0.1, 0.1 }
local LARGEST_COLOR = { 1, 0.2, 0.2 }
local ABSORBED_COLOR = { 0.6, 0.6, 0.6 }
local CASTER_COLOR = { 0.6, 0.6, 0.6 }
local EXTRA_COLOR = { 0.7, 0.7, 0.7 }
local TIME_COLOR = { 1, 0.82, 0 }

local SCHOOLS = {
	{ 1, "Physical" },
	{ 2, "Holy" },
	{ 4, "Fire" },
	{ 8, "Nature" },
	{ 16, "Frost" },
	{ 32, "Shadow" },
	{ 64, "Arcane" },
}

local ENVIRONMENT = {
	FALLING = { "Falling", "Interface\\Icons\\Ability_Rogue_QuickRecovery" },
	DROWNING = { "Drowning", "Interface\\Icons\\Spell_Shadow_DemonBreath" },
	FATIGUE = { "Fatigue", ENVIRONMENT_ICON },
	FIRE = { "Fire", "Interface\\Icons\\Spell_Fire_Fire" },
	LAVA = { "Lava", "Interface\\Icons\\Spell_Fire_Fire" },
	SLIME = { "Slime", "Interface\\Icons\\INV_Misc_Slime_01" },
}

local SPELL_DAMAGE_EVENTS = {
	SPELL_DAMAGE = true,
	SPELL_PERIODIC_DAMAGE = true,
	RANGE_DAMAGE = true,
	DAMAGE_SHIELD = true,
	DAMAGE_SPLIT = true,
}

local SPELL_MISSED_EVENTS = {
	SPELL_MISSED = true,
	SPELL_PERIODIC_MISSED = true,
	RANGE_MISSED = true,
	DAMAGE_SHIELD_MISSED = true,
}

local ENTRY_FIELDS = {
	"time",
	"source",
	"spellId",
	"spellName",
	"environment",
	"amount",
	"overkill",
	"school",
	"resisted",
	"blocked",
	"absorbed",
	"critical",
	"health",
	"healthMax",
}

local playerGUID
local buffers = {}
local units = {}
local trackArena = false

local recaps = {}
local lastRecapId = 0
local shownId
local deathTime = 0

local frame

local function unitFor(guid)
	if guid == playerGUID then
		return "player"
	end
	local unit = units[guid]
	if unit and UnitGUID(unit) == guid then
		return unit
	end
	unit = ns.UnitByGUID(guid)
	units[guid] = unit
	return unit
end

local function recordHit(
	guid,
	sourceName,
	spellId,
	spellName,
	environment,
	amount,
	overkill,
	school,
	resisted,
	blocked,
	absorbed,
	critical
)
	local buffer = buffers[guid]
	if not buffer then
		buffer = { head = 0 }
		buffers[guid] = buffer
	end
	local head = buffer.head % BUFFER_SIZE + 1
	buffer.head = head
	local entry = buffer[head]
	if not entry then
		entry = {}
		buffer[head] = entry
	end
	entry.time = GetTime()
	entry.source = sourceName
	entry.spellId = spellId
	entry.spellName = spellName
	entry.environment = environment
	entry.amount = amount or 0
	entry.overkill = overkill or 0
	entry.school = school
	entry.resisted = resisted or 0
	entry.blocked = blocked or 0
	entry.absorbed = absorbed or 0
	entry.critical = critical
	local unit = unitFor(guid)
	entry.health = unit and UnitHealth(unit)
	entry.healthMax = unit and UnitHealthMax(unit)
end

local onUnitDied

local function onCombatLogEvent(
	_,
	_,
	event,
	_,
	sourceName,
	_,
	destGUID,
	destName,
	destFlags,
	a1,
	a2,
	a3,
	a4,
	a5,
	a6,
	a7,
	a8,
	a9,
	a10
)
	if destGUID ~= playerGUID then
		if not trackArena or band(destFlags, COMBATLOG_OBJECT_TYPE_PLAYER) == 0 then
			return
		end
		if event == "UNIT_DIED" then
			onUnitDied(destGUID, destName)
			return
		end
	end
	if event == "SWING_DAMAGE" then
		recordHit(destGUID, sourceName, MELEE_SPELL, nil, nil, a1, a2, a3, a4, a5, a6, a7)
	elseif SPELL_DAMAGE_EVENTS[event] then
		recordHit(destGUID, sourceName, a1, a2, nil, a4, a5, a6, a7, a8, a9, a10)
	elseif event == "ENVIRONMENTAL_DAMAGE" then
		recordHit(destGUID, nil, nil, nil, a1, a2, a3, a4, a5, a6, a7, a8)
	elseif event == "SWING_MISSED" then
		if a1 == "ABSORB" then
			recordHit(destGUID, sourceName, MELEE_SPELL, nil, nil, 0, 0, 1, 0, 0, a2, nil)
		end
	elseif SPELL_MISSED_EVENTS[event] then
		if a4 == "ABSORB" then
			recordHit(destGUID, sourceName, a1, a2, nil, 0, 0, a3, 0, 0, a5, nil)
		end
	end
end

local schoolNames = {}
local schoolParts = {}

local function schoolName(school)
	if not school or school == 0 then
		return
	end
	local name = schoolNames[school]
	if not name then
		wipe(schoolParts)
		for i = 1, #SCHOOLS do
			if band(school, SCHOOLS[i][1]) ~= 0 then
				schoolParts[#schoolParts + 1] = L[SCHOOLS[i][2]]
			end
		end
		name = concat(schoolParts, "/")
		schoolNames[school] = name
	end
	return name
end

local function resolveNameAndIcon(entry)
	local environment = entry.environment
	if environment then
		local info = ENVIRONMENT[environment]
		entry.name = info and L[info[1]] or environment
		entry.icon = info and info[2] or ENVIRONMENT_ICON
		return
	end
	local spellId = entry.spellId
	local name, _, icon = GetSpellInfo(spellId)
	if spellId == MELEE_SPELL then
		entry.name = L["Melee"]
	else
		entry.name = entry.spellName or name or UNKNOWN
	end
	entry.icon = icon or ns.Media.questionMark
end

local function freezeRecap(guid, name)
	local buffer = buffers[guid]
	if not buffer then
		return
	end
	local now = GetTime()
	local limit = ns.Config.deathRecap.entries
	local entries = {}
	local index = buffer.head
	for _ = 1, BUFFER_SIZE do
		local entry = buffer[index]
		if not entry or not entry.time or now - entry.time > RECAP_WINDOW or #entries >= limit then
			break
		end
		local target = {}
		for i = 1, #ENTRY_FIELDS do
			local field = ENTRY_FIELDS[i]
			target[field] = entry[field]
		end
		entries[#entries + 1] = target
		index = (index - 2) % BUFFER_SIZE + 1
	end
	for i = 1, #buffer do
		buffer[i].time = nil
	end
	if #entries == 0 then
		return
	end

	local largest, largestAmount = nil, 0
	for i = 1, #entries do
		local entry = entries[i]
		resolveNameAndIcon(entry)
		if entry.amount > largestAmount then
			largest, largestAmount = entry, entry.amount
		end
	end
	if largest then
		largest.largest = true
	end

	lastRecapId = lastRecapId + 1
	recaps[lastRecapId] = { name = name, entries = entries, deathTime = entries[1].time }
	recaps[lastRecapId - RECAPS_KEPT] = nil
	return lastRecapId
end

local function onIconEnter(self)
	local spellId = self.row.entry.spellId
	if not spellId then
		return
	end
	GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
	GameTooltip:SetHyperlink("spell:" .. spellId)
	GameTooltip:Show()
end

local function addTooltipLine(text, color)
	GameTooltip:AddLine(text, color[1], color[2], color[3])
end

local function addExtra(template, value)
	if value and value > 0 then
		addTooltipLine(format(template, value), EXTRA_COLOR)
	end
end

local function onRowEnter(self)
	local entry = self.entry
	GameTooltip:SetOwner(self, "ANCHOR_LEFT")
	local school = schoolName(entry.school)
	if school then
		addTooltipLine(format(L["%d %s damage"], entry.amount, school), LARGEST_COLOR)
	else
		addTooltipLine(format(L["%d damage"], entry.amount), LARGEST_COLOR)
	end
	if entry.critical then
		addTooltipLine(L["Critical hit"], EXTRA_COLOR)
	end
	addExtra(L["%d overkill"], entry.overkill)
	addExtra(L["%d absorbed"], entry.absorbed)
	addExtra(L["%d resisted"], entry.resisted)
	addExtra(L["%d blocked"], entry.blocked)

	if entry.source then
		GameTooltip:AddLine(format(L["%s by %s"], entry.name, entry.source), 1, 1, 1, true)
	else
		GameTooltip:AddLine(entry.name, 1, 1, 1, true)
	end

	if entry.healthMax and entry.healthMax > 0 then
		local percent = floor(entry.health / entry.healthMax * 100)
		if self.index == 1 then
			addTooltipLine(format(L["Killing blow at %d%% health"], percent), TIME_COLOR)
		else
			addTooltipLine(format(L["%.1fs before death at %d%% health"], deathTime - entry.time, percent), TIME_COLOR)
		end
	end
	GameTooltip:Show()
end

local function createRow(index)
	local row = CreateFrame("Button", nil, frame)
	row:SetHeight(ROW_HEIGHT)
	row:SetPoint("TOPLEFT", PADDING, -(PADDING + HEADER_HEIGHT + (index - 1) * ROW_HEIGHT))
	row:SetPoint("RIGHT", -PADDING, 0)
	row:SetHighlightTexture(ns.Media.blank)
	row:GetHighlightTexture():SetVertexColor(1, 1, 1, 0.08)
	row:SetScript("OnEnter", onRowEnter)
	row:SetScript("OnLeave", GameTooltip_Hide)

	local icon = row:CreateTexture(nil, "ARTWORK")
	icon:SetSize(ICON_SIZE, ICON_SIZE)
	icon:SetPoint("LEFT", 4, 0)
	icon:SetTexCoord(ICON_TRIM, 1 - ICON_TRIM, ICON_TRIM, 1 - ICON_TRIM)
	row.icon = icon

	local iconHover = CreateFrame("Frame", nil, row)
	iconHover:SetAllPoints(icon)
	iconHover:EnableMouse(true)
	iconHover.row = row
	iconHover:SetScript("OnEnter", onIconEnter)
	iconHover:SetScript("OnLeave", GameTooltip_Hide)

	local textWidth = WIDTH - PADDING * 2 - ICON_SIZE - AMOUNT_WIDTH - 20

	local name = row:CreateFontString(nil, "OVERLAY")
	ns.SetFont(name, 12)
	name:SetPoint("TOPLEFT", icon, "TOPRIGHT", 8, 0)
	name:SetSize(textWidth, 14)
	name:SetJustifyH("LEFT")
	row.name = name

	local caster = row:CreateFontString(nil, "OVERLAY")
	ns.SetFont(caster, 11)
	caster:SetPoint("TOPLEFT", name, "BOTTOMLEFT", 0, -1)
	caster:SetSize(textWidth, 12)
	caster:SetJustifyH("LEFT")
	caster:SetTextColor(CASTER_COLOR[1], CASTER_COLOR[2], CASTER_COLOR[3])
	row.caster = caster

	local amount = row:CreateFontString(nil, "OVERLAY")
	ns.SetFont(amount, 13, "OUTLINE")
	amount:SetPoint("RIGHT", -4, 0)
	row.amount = amount

	local amountLarge = row:CreateFontString(nil, "OVERLAY")
	ns.SetFont(amountLarge, 17, "OUTLINE", true)
	amountLarge:SetPoint("RIGHT", -4, 0)
	row.amountLarge = amountLarge

	local tombstone = row:CreateTexture(nil, "OVERLAY")
	tombstone:SetSize(TOMBSTONE_SIZE, TOMBSTONE_SIZE)
	tombstone:SetTexture(TOMBSTONE_ICON)
	row.tombstone = tombstone

	frame.rows[index] = row
	return row
end

local function fillRow(row, entry, index)
	row.entry = entry
	row.index = index
	row.icon:SetTexture(entry.icon)
	row.name:SetText(entry.name)
	row.caster:SetText(entry.source or "")

	local text, other = row.amount, row.amountLarge
	local color = DAMAGE_COLOR
	if entry.largest then
		text, other = other, text
		color = LARGEST_COLOR
	end
	other:Hide()
	text:Show()
	if entry.amount > 0 then
		text:SetFormattedText("-%d", entry.amount)
	else
		text:SetText("0")
		color = ABSORBED_COLOR
	end
	text:SetTextColor(color[1], color[2], color[3])

	if index == 1 then
		row.tombstone:ClearAllPoints()
		row.tombstone:SetPoint("RIGHT", text, "LEFT", -4, 0)
		row.tombstone:Show()
	else
		row.tombstone:Hide()
	end
end

local function refresh()
	if not frame or not frame:IsShown() then
		return
	end
	local recap = recaps[shownId]
	local entries = recap and recap.entries
	local count = entries and #entries or 0
	deathTime = recap and recap.deathTime or 0
	if recap and recap.name then
		frame.title:SetText(format("%s: %s", L["Death recap"], recap.name))
	else
		frame.title:SetText(L["Death recap"])
	end
	local rows = frame.rows
	for i = 1, count do
		local row = rows[i] or createRow(i)
		fillRow(row, entries[i], i)
		row:Show()
	end
	for i = count + 1, #rows do
		rows[i]:Hide()
	end
	ns.SetShown(frame.empty, count == 0)
	frame:SetHeight(PADDING * 2 + HEADER_HEIGHT + (count > 0 and count or 1) * ROW_HEIGHT)
end

local function createFrame()
	frame = ns.CreateWindow(FRAME_NAME, { width = WIDTH, title = L["Death recap"] })
	Misc:AnchorToConfig(frame, "deathRecap.point", "Death recap")
	frame:SetScript("OnShow", refresh)
	frame.rows = {}

	local empty = frame:CreateFontString(nil, "OVERLAY")
	ns.SetFont(empty, 13)
	empty:SetTextColor(0.5, 0.5, 0.5)
	empty:SetPoint("TOP", 0, -(PADDING + HEADER_HEIGHT + ROW_HEIGHT / 2 - 7))
	empty:SetText(L["No death recorded yet"])
	frame.empty = empty
end

local function show(id)
	if not frame then
		createFrame()
	end
	shownId = id or lastRecapId
	if frame:IsShown() then
		refresh()
	else
		frame:Show()
	end
end

local function coloredName(guid, name)
	local _, class = GetPlayerInfoByGUID(guid)
	local color = class and RAID_CLASS_COLORS[class]
	if not color then
		return name
	end
	return format(NAME_COLOR, color.r * 255, color.g * 255, color.b * 255, name)
end

local function onPlayerDead()
	local id = freezeRecap(playerGUID)
	if not id then
		return
	end
	local config = ns.Config.deathRecap
	if config.chatLink or trackArena then
		ns.Print(CHAT_LINE, L["You died."], id, L["Death recap"])
	end
	if config.autoOpen then
		local _, instanceType = IsInInstance()
		if instanceType == "arena" or instanceType == "pvp" then
			show(id)
			return
		end
	end
	if frame and frame:IsShown() then
		show(id)
	end
end

function onUnitDied(guid, name)
	local unit = unitFor(guid)
	if unit and UnitIsFeignDeath(unit) then
		return
	end
	name = name or UNKNOWN
	if ns.Config.chat.stripRealm then
		name = gsub(name, "%-.+", "", 1)
	end
	name = coloredName(guid, name)
	local id = freezeRecap(guid, name)
	if id then
		ns.Print(CHAT_LINE, format(L["%s died."], name), id, L["Death recap"])
	end
end

local originalSetItemRef = SetItemRef
SetItemRef = function(link, ...)
	if link and link:sub(1, #LINK_PREFIX) == LINK_PREFIX then
		show(tonumber(link:sub(#LINK_PREFIX + 1)))
		return
	end
	return originalSetItemRef(link, ...)
end

local function updateZone()
	local _, instanceType = IsInInstance()
	trackArena = instanceType == "arena" and ns.Config.deathRecap.arenaDeaths
	if not trackArena then
		for guid in pairs(buffers) do
			if guid ~= playerGUID then
				buffers[guid] = nil
			end
		end
		wipe(units)
	end
end

local function applyConfig()
	if ns.Config.deathRecap.enabled then
		Misc:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED", onCombatLogEvent)
		Misc:RegisterEvent("PLAYER_DEAD", onPlayerDead)
		Misc:RegisterEvent("PLAYER_ENTERING_WORLD", updateZone)
	else
		Misc:UnregisterEvent("COMBAT_LOG_EVENT_UNFILTERED", onCombatLogEvent)
		Misc:UnregisterEvent("PLAYER_DEAD", onPlayerDead)
		Misc:UnregisterEvent("PLAYER_ENTERING_WORLD", updateZone)
	end
	updateZone()
end

Misc:RegisterEvent("PLAYER_LOGIN", function()
	playerGUID = UnitGUID("player")
end)
Misc:WatchConfig("deathRecap", applyConfig)

SlashCmdList.FROSTATOMUI_DEATH_RECAP = function()
	if frame and frame:IsShown() then
		frame:Hide()
	else
		show()
	end
end
SLASH_FROSTATOMUI_DEATH_RECAP1 = "/recap"
