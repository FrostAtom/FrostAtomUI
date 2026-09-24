local _, ns = ...

local UpdatePaperdollStats = UpdatePaperdollStats

local Misc = ns:GetModule("Misc")

local ROW_COUNT = 6
local WIDTH = 168
local PADDING = 8
local HEADER_HEIGHT = 17
local ROW_HEIGHT = 13
local SECTION_GAP = 5
local FONT_SIZE = 11

local ALL_CATEGORIES = {
	"PLAYERSTAT_DEFENSES",
	"PLAYERSTAT_MELEE_COMBAT",
	"PLAYERSTAT_SPELL_COMBAT",
	"PLAYERSTAT_RANGED_COMBAT",
	"PLAYERSTAT_BASE_STATS",
}
local MELEE = { "PLAYERSTAT_DEFENSES", "PLAYERSTAT_MELEE_COMBAT", "PLAYERSTAT_BASE_STATS" }
local CASTER = { "PLAYERSTAT_DEFENSES", "PLAYERSTAT_SPELL_COMBAT", "PLAYERSTAT_BASE_STATS" }
local HYBRID = { "PLAYERSTAT_DEFENSES", "PLAYERSTAT_MELEE_COMBAT", "PLAYERSTAT_SPELL_COMBAT", "PLAYERSTAT_BASE_STATS" }
local CLASS_CATEGORIES = {
	WARRIOR = MELEE,
	ROGUE = MELEE,
	DEATHKNIGHT = MELEE,
	MAGE = CASTER,
	PRIEST = CASTER,
	WARLOCK = CASTER,
	PALADIN = HYBRID,
	SHAMAN = HYBRID,
	DRUID = HYBRID,
	HUNTER = { "PLAYERSTAT_DEFENSES", "PLAYERSTAT_RANGED_COMBAT", "PLAYERSTAT_MELEE_COMBAT", "PLAYERSTAT_BASE_STATS" },
}

local UNIT_EVENTS = {
	"UNIT_STATS",
	"UNIT_RESISTANCES",
	"UNIT_DAMAGE",
	"UNIT_RANGEDDAMAGE",
	"UNIT_ATTACK_SPEED",
	"UNIT_ATTACK_POWER",
	"UNIT_RANGED_ATTACK_POWER",
	"UNIT_ATTACK",
	"UNIT_LEVEL",
}
local EVENTS = {
	"COMBAT_RATING_UPDATE",
	"PLAYER_DAMAGE_DONE_MODS",
	"PLAYER_EQUIPMENT_CHANGED",
	"SKILL_LINES_CHANGED",
}

local panel, sections
local active = {}
local watcher = ns.Mixin({}, ns.EventMixin)

local function refresh()
	local y = -PADDING
	for i = 1, #active do
		local section = active[i]
		UpdatePaperdollStats(section.prefix, section.category)
		section.header:SetPoint("TOPLEFT", PADDING, y)
		y = y - HEADER_HEIGHT
		local rows = section.rows
		for r = 1, ROW_COUNT do
			local row = rows[r]
			if row:IsShown() then
				row:SetPoint("TOPLEFT", PADDING, y)
				y = y - ROW_HEIGHT
			end
		end
		y = y - SECTION_GAP
	end
	local height = PADDING - y - SECTION_GAP
	if panel.height ~= height then
		panel.height = height
		panel:SetHeight(height)
	end
end

local function queueRefresh()
	ns.Defer(panel, refresh)
end

local function position()
	panel:ClearAllPoints()
	if GearManagerDialog:IsShown() then
		panel:SetPoint("TOPLEFT", GearManagerDialog, "BOTTOMLEFT", 0, -2)
	else
		panel:SetPoint("TOPLEFT", PaperDollFrame, "TOPRIGHT", -32, -13)
	end
end

local function selectCategories()
	local list = ns.Config.characterStats.classCategories and CLASS_CATEGORIES[ns.PLAYER_CLASS] or ALL_CATEGORIES
	wipe(active)
	for _, section in pairs(sections) do
		section.frame:Hide()
	end
	for i = 1, #list do
		local section = sections[list[i]]
		section.frame:Show()
		active[i] = section
	end
end

local function createSection(category)
	local frame = CreateFrame("Frame", nil, panel)
	frame:SetAllPoints()

	local header = frame:CreateFontString(nil, "OVERLAY")
	ns.SetFont(header, FONT_SIZE + 1, "", true)
	header:SetTextColor(1, 0.82, 0)
	header:SetText(_G[category])

	local line = frame:CreateTexture(nil, "ARTWORK")
	line:SetTexture(ns.Media.blank)
	line:SetVertexColor(1, 1, 1, 0.12)
	line:SetHeight(1)
	line:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -2)
	line:SetWidth(WIDTH - PADDING * 2)

	local prefix = "FrostAtomUIStats" .. category
	local rows = {}
	for i = 1, ROW_COUNT do
		local row = CreateFrame("Frame", prefix .. i, frame, "StatFrameTemplate")
		row:SetWidth(WIDTH - PADDING * 2)
		row:EnableMouse(true)
		ns.SetFont(_G[prefix .. i .. "Label"], FONT_SIZE, "")
		ns.SetFont(_G[prefix .. i .. "StatText"], FONT_SIZE, "")
		rows[i] = row
	end

	return { category = category, prefix = prefix, frame = frame, header = header, rows = rows }
end

local function onShow()
	for i = 1, #UNIT_EVENTS do
		watcher:RegisterUnitEvent(UNIT_EVENTS[i], "player", queueRefresh)
	end
	for i = 1, #EVENTS do
		watcher:RegisterEvent(EVENTS[i], queueRefresh)
	end
	position()
	refresh()
end

local function onHide()
	watcher:UnregisterAllEvents()
end

local function create()
	panel = CreateFrame("Frame", nil, PaperDollFrame)
	panel:Hide()
	panel:SetWidth(WIDTH)
	panel:SetFrameLevel(PaperDollFrame:GetFrameLevel() + 5)
	panel:SetBackdrop(ns.CreateBackdrop(14, 3))
	panel:SetBackdropColor(0.06, 0.06, 0.06, 0.9)
	panel:SetBackdropBorderColor(0.35, 0.35, 0.35)
	panel:EnableMouse(true)

	sections = {}
	for i = 1, #ALL_CATEGORIES do
		local category = ALL_CATEGORIES[i]
		sections[category] = createSection(category)
	end

	panel:SetScript("OnShow", onShow)
	panel:SetScript("OnHide", onHide)
	GearManagerDialog:HookScript("OnShow", position)
	GearManagerDialog:HookScript("OnHide", position)
end

local function apply()
	local config = ns.Config.characterStats
	if not config.enabled then
		if panel then
			panel:Hide()
		end
		return
	end
	if not panel then
		create()
	end
	selectCategories()
	if panel:IsVisible() then
		refresh()
	end
	panel:Show()
end

Misc:OnInitialize(apply)
Misc:WatchConfig("characterStats", apply)
