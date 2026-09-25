local _, ns = ...

local L = ns.L

local UnitGUID, UnitName, UnitClass, UnitRace, UnitLevel, UnitPVPName =
	UnitGUID, UnitName, UnitClass, UnitRace, UnitLevel, UnitPVPName
local UnitIsUnit, UnitIsPlayer, UnitExists, UnitFactionGroup = UnitIsUnit, UnitIsPlayer, UnitExists, UnitFactionGroup
local GetGuildInfo, CanInspect, CheckInteractDistance, UnitIsVisible, UnitIsConnected =
	GetGuildInfo, CanInspect, CheckInteractDistance, UnitIsVisible, UnitIsConnected
local GetTalentTabInfo, GetNumTalentTabs, GetNumTalentGroups, GetActiveTalentGroup, GetUnspentTalentPoints =
	GetTalentTabInfo, GetNumTalentTabs, GetNumTalentGroups, GetActiveTalentGroup, GetUnspentTalentPoints
local GetInspectArenaTeamData, GetInspectHonorData, HasInspectHonorData, RequestInspectHonorData =
	GetInspectArenaTeamData, GetInspectHonorData, HasInspectHonorData, RequestInspectHonorData
local GetAchievementInfo, GetAchievementComparisonInfo, GetComparisonStatistic =
	GetAchievementInfo, GetAchievementComparisonInfo, GetComparisonStatistic
local GetInventorySlotInfo, GetTime = GetInventorySlotInfo, GetTime
local floor, max, min, tonumber = math.floor, math.max, math.min, tonumber

local InspectFrame = ns:NewModule("InspectFrame")
InspectFrame.configKey = "inspectFrame"

local Inspect = ns:GetModule("Inspect")
local UF = ns:GetModule("UnitFrames")
local Gear = ns.InspectGear
local StatData = ns.InspectStatData
local Tree = ns.TalentTree

local FRAME_NAME = "FrostAtomUIInspect"
local INSET = ns.WINDOW_INSET
local PANE_GAP = 8
local CONTENT_WIDTH = 3 * Tree.PANE_WIDTH + 2 * PANE_GAP
local WIDTH = INSET.left + INSET.right + CONTENT_WIDTH
local HEADER_TOP = 36
local CONTENT_TOP = 100
local TALENT_TIERS = 11
local PANE_HEIGHT, PANE_BODY = Tree.PaneHeight(TALENT_TIERS)
local PAGE_HEIGHT = PANE_HEIGHT
local HEIGHT = CONTENT_TOP + PAGE_HEIGHT + INSET.bottom
local SIDE_TAB_X, SIDE_TAB_Y, SIDE_TAB_STEP = -3, -60, 54

local ICON_SIZE = 36
local ROW_HEIGHT = 42
local ROW_GAP = 6
local TEXT_WIDTH = 196
local WEAPON_TEXT_WIDTH = 180
local GEM_SIZE = 13
local ROWS = 8
local WEAPON_Y = ROWS * ROW_HEIGHT + 2
local PANEL_TOP = WEAPON_Y + ROW_HEIGHT + 16
local PANEL_HEIGHT = PAGE_HEIGHT - PANEL_TOP
local STAT_GROUP_GAP = 6
local STAT_GROUP_WIDTH = (CONTENT_WIDTH - 2 * STAT_GROUP_GAP) / 3
local LIST_ROW = 14
local LIST_ROWS = floor((PANEL_HEIGHT - 12) / LIST_ROW)
local FORM_BUTTONS, FORM_SIZE = 5, 16

local TEAM_WIDTH = Tree.PANE_WIDTH
local TEAM_HEIGHT = 128
local STATS_TOP = TEAM_HEIGHT + 22
local STATS_HEIGHT = 150
local ACHIEVEMENTS_TOP = STATS_TOP + STATS_HEIGHT + 22
local ACHIEVEMENT_SIZE = 30
local ACHIEVEMENT_GAP = 5
local ACHIEVEMENT_LABEL_WIDTH = 90

local RETRY_INTERVAL = 2.5
local MAX_ATTEMPTS = 8
local GEAR_RETRY_DELAY = 0.4
local GEAR_RETRIES = 10
local REFRESH_DELAY = 1
local TICK = 0.5

local GLOW_TEXTURE = "Interface\\Buttons\\UI-ActionButton-Border"
local GLOW_SCALE = 1.7
local UNDERLAY_ALPHA = 0.75
local TINY_SHIELD = "|TInterface\\AchievementFrame\\UI-Achievement-TinyShield:16:16:0:0:32:32:0:20:0:20|t"
local BANNER = "Interface\\PVPFrame\\PVP-Banner-%d"
local BANNER_BORDER = "Interface\\PVPFrame\\PVP-Banner-%d-Border-%d"
local BANNER_EMBLEM = "Interface\\PVPFrame\\Icons\\PVP-Banner-Emblem-%d"
local DEFAULT_SPEC_ICON = "Interface\\Icons\\Ability_Marksmanship"
local GREY = "|cff999999"
local RED = { 1, 0.25, 0.25 }
local YELLOW = { 1, 0.82, 0 }
local GREEN = { 0.25, 1, 0.25 }
local GUILD_COLOR = { 0.25, 1, 0.25 }

local ARENA_SIZES = { 2, 3, 5 }
local CASTER_CLASSES = { MAGE = true, WARLOCK = true, PRIEST = true }
local HYBRID_CLASSES = { DRUID = true, SHAMAN = true, PALADIN = true }
local CRIT_TAKEN = {
	{ "melee", PLAYERSTAT_MELEE_COMBAT },
	{ "ranged", PLAYERSTAT_RANGED_COMBAT },
	{ "spell", PLAYERSTAT_SPELL_COMBAT },
}

local STAT_LABELS = {
	ITEM_MOD_STAMINA_SHORT = "Stamina",
	ITEM_MOD_RESILIENCE_RATING_SHORT = "Resilience",
	ITEM_MOD_STRENGTH_SHORT = "Strength",
	ITEM_MOD_AGILITY_SHORT = "Agility",
	ITEM_MOD_INTELLECT_SHORT = "Intellect",
	ITEM_MOD_SPIRIT_SHORT = "Spirit",
	ITEM_MOD_ATTACK_POWER_SHORT = "Attack power",
	ITEM_MOD_SPELL_POWER_SHORT = "Spell power",
	ITEM_MOD_CRIT_RATING_SHORT = "Crit",
	ITEM_MOD_HASTE_RATING_SHORT = "Haste",
	ITEM_MOD_HIT_RATING_SHORT = "Hit",
	ITEM_MOD_ARMOR_PENETRATION_RATING_SHORT = "Armor pen.",
	ITEM_MOD_EXPERTISE_RATING_SHORT = "Expertise",
	ITEM_MOD_SPELL_PENETRATION_SHORT = "Spell pen.",
	ITEM_MOD_POWER_REGEN0_SHORT = "MP5",
	ITEM_MOD_DEFENSE_SKILL_RATING_SHORT = "Defense",
	ITEM_MOD_DODGE_RATING_SHORT = "Dodge",
	ITEM_MOD_PARRY_RATING_SHORT = "Parry",
	ITEM_MOD_BLOCK_RATING_SHORT = "Block",
	ITEM_MOD_BLOCK_VALUE_SHORT = "Block value",
	RESISTANCE0_NAME = "Armor",
}

local STAT_GROUPS = {
	{
		title = "Attributes",
		keys = {
			"ITEM_MOD_STAMINA_SHORT",
			"ITEM_MOD_STRENGTH_SHORT",
			"ITEM_MOD_AGILITY_SHORT",
			"ITEM_MOD_INTELLECT_SHORT",
			"ITEM_MOD_SPIRIT_SHORT",
		},
	},
	{
		keys = {
			"ITEM_MOD_ATTACK_POWER_SHORT",
			"ITEM_MOD_SPELL_POWER_SHORT",
			"ITEM_MOD_CRIT_RATING_SHORT",
			"ITEM_MOD_HASTE_RATING_SHORT",
			"ITEM_MOD_HIT_RATING_SHORT",
			"ITEM_MOD_EXPERTISE_RATING_SHORT",
			"ITEM_MOD_ARMOR_PENETRATION_RATING_SHORT",
			"ITEM_MOD_SPELL_PENETRATION_SHORT",
			"ITEM_MOD_POWER_REGEN0_SHORT",
		},
	},
	{
		title = "Defenses",
		keys = {
			"ITEM_MOD_RESILIENCE_RATING_SHORT",
			"RESISTANCE0_NAME",
			"ITEM_MOD_DEFENSE_SKILL_RATING_SHORT",
			"ITEM_MOD_DODGE_RATING_SHORT",
			"ITEM_MOD_PARRY_RATING_SHORT",
			"ITEM_MOD_BLOCK_RATING_SHORT",
			"ITEM_MOD_BLOCK_VALUE_SHORT",
		},
	},
}

local ARENA_STATISTICS = {
	{ label = "Highest personal rating", ids = { 370, 595, 596 } },
	{ label = "Highest team rating", ids = { 374, 590, 589 } },
}
local STAT_BG_PLAYED, STAT_BG_WON = 839, 840
local STAT_KILLING_BLOWS = 1487
local STAT_DUELS_WON, STAT_DUELS_LOST = 319, 320
local STAT_PLAYER_DEATHS = 1501

local ACHIEVEMENT_ROWS = {
	{
		label = "Titles",
		ids = {
			2090, -- Challenger
			2093, -- Rival
			2092, -- Duelist
			2091, -- Gladiator
			418, -- Merciless Gladiator
			419, -- Vengeful Gladiator
			420, -- Brutal Gladiator
			3336, -- Deadly Gladiator
			3436, -- Furious Gladiator
			3758, -- Relentless Gladiator
			4599, -- Wrathful Gladiator
			{ Alliance = 433, Horde = 443 }, -- Grand Marshal / High Warlord
		},
	},
	{
		label = "Rating",
		ids = {
			399, -- Just the Two of Us: 1550
			400, -- Just the Two of Us: 1750
			401, -- Just the Two of Us: 2000
			1159, -- Just the Two of Us: 2200
			402, -- Three's Company: 1550
			403, -- Three's Company: 1750
			405, -- Three's Company: 2000
			1160, -- Three's Company: 2200
			406, -- High Five: 1550
			407, -- High Five: 1750
			404, -- High Five: 2000
			1161, -- High Five: 2200
		},
	},
	{
		label = "Other",
		ids = {
			1174, -- The Arena Master
			408, -- Hot Streak
			1162, -- Hotter Streak
			409, -- Last Man Standing
			699, -- World Wide Winner
			{ chain = { 397, 398, 875, 876 } }, -- Step Into The Arena .. Brutally Dedicated
			{ Alliance = 230, Horde = 1175 }, -- Battlemaster
			{ Alliance = 907, Horde = 714 }, -- The Justicar / The Conqueror
			{ chain = { 513, 515, 516, 512, 509, 239, 869, 870 } }, -- 100 .. 100000 Honorable Kills
			1157, -- Duel-icious
		},
	},
}

local frame
local pages = {}
local panes = {}
local talentView = { inspect = true, pet = false, group = 1, readOnly = true }
local state = {}
local gearRetries = 0
local gearToken = 0

local function hex(color)
	return ("|cff%02x%02x%02x"):format(color[1] * 255, color[2] * 255, color[3] * 255)
end

local function classHex(class)
	local color = class and UF.classColors[class]
	return color and hex(color) or "|cffffffff"
end

local function unitValid()
	return state.unit ~= nil and state.guid ~= nil and UnitGUID(state.unit) == state.guid
end

local function resolveUnit()
	if state.guid and not unitValid() then
		state.unit = Inspect:UnitByGUID(state.guid) or state.unit
	end
	return unitValid()
end

local function isReachable(unit)
	return UnitIsVisible(unit) and UnitIsConnected(unit) and CanInspect(unit) and CheckInteractDistance(unit, 1)
end

local function dataLoaded()
	return state.guid ~= nil and (state.isSelf or Inspect:IsLoaded(state.guid)) and unitValid()
end

local function arenaTeamData(index)
	if not state.isSelf then
		return GetInspectArenaTeamData(index)
	end
	local name, size, rating, _, _, played, wins, _, playerPlayed, _, playerRating, bgR, bgG, bgB, emblem, emR, emG, emB, border, bR, bG, bB =
		GetArenaTeam(index)
	return name, size, rating, played, wins, playerPlayed, playerRating, bgR, bgG, bgB, emblem, emR, emG, emB, border, bR, bG, bB
end

local function honorData()
	if not state.isSelf then
		return GetInspectHonorData()
	end
	local todayHK, todayHonor = GetPVPSessionStats()
	local yesterdayHK, yesterdayHonor = GetPVPYesterdayStats()
	return todayHK, todayHonor, yesterdayHK, yesterdayHonor, (GetPVPLifetimeStats())
end

local function achievementDate(id)
	if state.isSelf then
		local _, _, _, completed, month, day, year = GetAchievementInfo(id)
		return completed, month, day, year
	end
	return GetAchievementComparisonInfo(id)
end

local function setStatus(text)
	state.status = text
	if frame then
		frame.status:SetText(text or "")
		frame.gearStatus:SetText(state.gear and "" or text or "")
	end
end

local function comparisonAllowed()
	return not (AchievementFrame and AchievementFrame:IsShown() and AchievementFrame.isComparison)
end

local loadSelf

local function requestInspect()
	if not resolveUnit() then
		setStatus(L["Player not available"])
		return
	end
	if state.isSelf then
		loadSelf()
		return
	end
	local unit = state.unit
	if not isReachable(unit) then
		setStatus(L["Out of inspect range"])
		return
	end
	state.sent = GetTime()
	state.attempts = state.attempts + 1
	NotifyInspect(unit)
	if not state.achievementsReady and comparisonAllowed() then
		ClearAchievementComparisonUnit()
		SetAchievementComparisonUnit(unit)
		state.comparing = true
	end
	if not state.gear then
		setStatus(L["Inspecting..."])
	end
end

local function captureIdentity(unit)
	local name, realm = UnitName(unit)
	local className, class = UnitClass(unit)
	state.name = name
	state.realm = realm ~= "" and realm or nil
	state.pvpName = UnitPVPName(unit) or name
	state.className, state.class = className, class
	state.race, state.raceFile = UnitRace(unit)
	state.level = UnitLevel(unit)
	state.faction = UnitFactionGroup(unit)
	state.guild, state.guildRank = GetGuildInfo(unit)
end

local function readSpecs()
	local specs = {}
	local inspect = not state.isSelf
	local numGroups = GetNumTalentGroups(inspect) or 1
	local active = GetActiveTalentGroup(inspect) or 1
	for group = 1, max(numGroups, 1) do
		local spec = { points = {}, names = {}, icons = {}, talents = {}, primary = nil, group = group }
		local best = 0
		for tab = 1, min(GetNumTalentTabs(inspect) or 0, 3) do
			local name, icon, points = GetTalentTabInfo(tab, inspect, false, group)
			points = points or 0
			for i = 1, GetNumTalents(tab, inspect) or 0 do
				local talentName, _, _, _, rank = GetTalentInfo(tab, i, inspect, false, group)
				local id = rank and rank > 0 and (GetTalentLink(tab, i, inspect, false, group) or ""):match("talent:(%d+)")
				if id then
					spec.talents[#spec.talents + 1] = { id = tonumber(id), rank = rank, name = talentName }
				end
			end
			spec.points[tab], spec.names[tab], spec.icons[tab] = points, name, icon
			if points > best then
				best, spec.primary = points, tab
			elseif points == best then
				spec.primary = nil
			end
		end
		spec.total = (spec.points[1] or 0) + (spec.points[2] or 0) + (spec.points[3] or 0)
		specs[group] = spec
	end
	state.specs = specs
	state.numGroups = numGroups
	state.activeGroup = active
	state.unspent = GetUnspentTalentPoints(inspect, false, active) or 0
	if not state.group or state.group > numGroups then
		state.group = active
	end
end

local function specLabel(spec)
	local name = spec.primary and spec.names[spec.primary] or (spec.total > 0 and L["Hybrid"] or NONE)
	return name, ("%d/%d/%d"):format(spec.points[1] or 0, spec.points[2] or 0, spec.points[3] or 0)
end

local function specIcon(spec)
	if spec.primary then
		return spec.icons[spec.primary]
	end
	return spec.total > 0 and TALENT_HYBRID_ICON or DEFAULT_SPEC_ICON
end

local function formatNumber(value)
	return tostring(floor(value + 0.5))
end

local function updateHeader()
	local color = classHex(state.class)
	local title = color .. (state.pvpName or state.name or "") .. "|r"
	if state.realm then
		title = title .. GREY .. " - " .. state.realm .. "|r"
	end
	frame.nameText:SetText(title)

	local level = state.level and state.level > 0 and state.level or "??"
	frame.infoText:SetFormattedText(PLAYER_LEVEL, level, state.race or "", color .. (state.className or "") .. "|r")
	if state.guild then
		frame.guildText:SetFormattedText("<%s> %s%s|r", state.guild, GREY, state.guildRank or "")
	else
		frame.guildText:SetText("")
	end

	local specs = state.specs
	if specs and specs[state.activeGroup] then
		local active = specs[state.activeGroup]
		local name, points = specLabel(active)
		frame.specIcon:SetTexture(specIcon(active))
		frame.specIcon:Show()
		frame.specText:SetFormattedText("%s%s|r %s%s|r", color, name, GREY, points)
		local other = state.numGroups > 1 and specs[state.activeGroup == 1 and 2 or 1]
		if other then
			local otherName, otherPoints = specLabel(other)
			frame.specText2:SetFormattedText("%s%s %s|r", GREY, otherName, otherPoints)
		else
			frame.specText2:SetText("")
		end
		if state.unspent > 0 then
			frame.specText3:SetFormattedText(L["%d unspent talent points"], state.unspent)
		else
			frame.specText3:SetText("")
		end
	else
		frame.specIcon:Hide()
		frame.specText:SetText(state.status and GREY .. L["Talents not loaded"] .. "|r" or "")
		frame.specText2:SetText("")
		frame.specText3:SetText("")
	end

	local gear = state.gear
	if gear and gear.count > 0 then
		local r, g, b = ns.AverageItemLevelColor(gear.average)
		frame.itemLevel:SetFormattedText("%.1f", gear.average)
		frame.itemLevel:SetTextColor(r, g, b)
		frame.itemLevelLabel:Show()
	else
		frame.itemLevel:SetText("")
		frame.itemLevelLabel:Hide()
	end

	if unitValid() then
		SetPortraitTexture(frame.portrait, state.unit)
	end
	frame.refresh:SetEnabled(unitValid())
end

local function itemLevelColor(difference)
	if difference >= 0 then
		return 0.1, 1, 0.1
	end
	return ns.ColorGradient(math.pi / -difference, 1, 0.1, 0.1, 1, 1, 0.1, 0.1, 1, 0.1)
end

local function showItemTooltip(self)
	local row = self.row
	local item = state.gear and state.gear.slots[row.slot]
	GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
	if item and item.link then
		if not (dataLoaded() and GameTooltip:SetInventoryItem(state.unit, row.slot)) then
			GameTooltip:SetHyperlink(item.link)
		end
	else
		GameTooltip:SetText(Gear.SlotLabel(row.slot))
	end
	GameTooltip:Show()
end

local function onItemClick(self)
	local item = state.gear and state.gear.slots[self.row.slot]
	if item and item.link then
		HandleModifiedItemClick(item.link)
	end
end

local function showGemTooltip(self)
	local gem = self.gem
	if not gem then
		return
	end
	GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
	if gem.link then
		GameTooltip:SetHyperlink(gem.link)
	else
		GameTooltip:SetText(gem.name or gem.text or EMPTY, 1, 1, 1)
		if gem.empty then
			GameTooltip:AddLine(L["Empty socket"], RED[1], RED[2], RED[3])
		end
	end
	GameTooltip:Show()
end

local function onGemClick(self)
	if self.gem and self.gem.link then
		HandleModifiedItemClick(self.gem.link)
	end
end

local function createItemRow(parent, slot, side, textWidth)
	local row = CreateFrame("Frame", nil, parent)
	row:SetSize(ICON_SIZE + ROW_GAP + textWidth, ICON_SIZE)
	row.slot = slot
	row.side = side

	local button = ns.CreateIconSlot(row, ICON_SIZE, "slot")
	button:SetPoint(side == "right" and "RIGHT" or "LEFT")
	button.row = row
	button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	button:SetScript("OnEnter", showItemTooltip)
	button:SetScript("OnLeave", GameTooltip_Hide)
	button:SetScript("OnClick", onItemClick)
	row.button = button

	local glow = button:CreateTexture(nil, "OVERLAY")
	glow:SetTexture(GLOW_TEXTURE)
	glow:SetBlendMode("ADD")
	glow:SetSize(ICON_SIZE * GLOW_SCALE, ICON_SIZE * GLOW_SCALE)
	glow:SetPoint("CENTER")
	glow:SetAlpha(0.8)
	glow:Hide()
	row.glow = glow

	local level = button:CreateFontString(nil, "OVERLAY")
	level:SetPoint("BOTTOM", 0, 1)
	local font = ns.Config.equipment.slotFont
	ns.SetFont(level, font.size, font.outline)
	row.level = level

	local _, texture = GetInventorySlotInfo(Gear.SLOT_NAMES[slot])
	row.emptyTexture = texture

	local justify = side == "right" and "RIGHT" or "LEFT"
	local anchor = side == "right" and "TOPRIGHT" or "TOPLEFT"
	local x = side == "right" and -(ICON_SIZE + ROW_GAP) or ICON_SIZE + ROW_GAP

	local name = row:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
	name:SetPoint(anchor, x, -1)
	name:SetWidth(textWidth)
	name:SetHeight(12)
	name:SetJustifyH(justify)
	row.name = name

	local enchant = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	enchant:SetPoint(anchor, x, -13)
	enchant:SetWidth(textWidth)
	enchant:SetHeight(12)
	enchant:SetJustifyH(justify)
	row.enchant = enchant

	row.gems = {}
	for i = 1, 4 do
		local gem = CreateFrame("Button", nil, row)
		gem:SetSize(GEM_SIZE, GEM_SIZE)
		if i == 1 then
			gem:SetPoint(anchor, x, -25)
		elseif side == "right" then
			gem:SetPoint("RIGHT", row.gems[i - 1], "LEFT", -2, 0)
		else
			gem:SetPoint("LEFT", row.gems[i - 1], "RIGHT", 2, 0)
		end
		gem.icon = gem:CreateTexture(nil, "ARTWORK")
		gem.icon:SetAllPoints()
		gem:SetScript("OnEnter", showGemTooltip)
		gem:SetScript("OnLeave", GameTooltip_Hide)
		gem:SetScript("OnClick", onGemClick)
		gem:Hide()
		row.gems[i] = gem
	end

	local note = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	note:SetPoint(side == "right" and "RIGHT" or "LEFT", row.gems[1], side == "right" and "LEFT" or "RIGHT", 0, 0)
	row.note = note
	return row
end

local function setRowGems(row, item)
	local shown = 0
	for i = 1, 4 do
		local gem = row.gems[i]
		local data = item and item.gems[i]
		if data then
			gem.gem = data
			gem.icon:SetTexture(data.icon or data.empty or "Interface\\Icons\\INV_Misc_QuestionMark")
			if data.empty then
				gem.icon:SetTexCoord(0, 1, 0, 1)
			else
				gem.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
			end
			gem.icon:SetDesaturated(data.inactive or false)
			gem:Show()
			shown = i
		else
			gem.gem = nil
			gem:Hide()
		end
	end
	local anchor = row.gems[max(shown, 1)]
	local side = row.side
	row.note:ClearAllPoints()
	if shown > 0 then
		row.note:SetPoint(
			side == "right" and "RIGHT" or "LEFT",
			anchor,
			side == "right" and "LEFT" or "RIGHT",
			side == "right" and -4 or 4,
			0
		)
	else
		row.note:SetPoint(side == "right" and "RIGHT" or "LEFT", anchor, side == "right" and "RIGHT" or "LEFT", 0, 0)
	end
	local notes = {}
	if item and item.missingBuckle then
		notes[#notes + 1] = hex(RED) .. L["No belt buckle"] .. "|r"
	end
	if item and item.socketBonus and not item.emptySockets then
		local color = item.socketBonusActive and GREEN or { 0.5, 0.5, 0.5 }
		notes[#notes + 1] = hex(color) .. item.socketBonus .. "|r"
	end
	row.note:SetText(table.concat(notes, " "))
end

local function updateRow(row)
	local gear = state.gear
	local item = gear and gear.slots[row.slot]
	local button = row.button
	if item and item.icon then
		button.icon:SetTexture(item.icon)
		button.icon:SetDesaturated(false)
		local quality = item.quality and ITEM_QUALITY_COLORS[item.quality]
		if quality and item.quality > 1 then
			row.glow:SetVertexColor(quality.r, quality.g, quality.b)
			row.glow:Show()
		else
			row.glow:Hide()
		end
		if item.itemLevel and ns.Config.equipment.showItemLevels then
			row.level:SetText(item.itemLevel)
			row.level:SetTextColor(itemLevelColor(item.itemLevel - (gear.average or 0)))
		else
			row.level:SetText("")
		end
		row.name:SetText((quality and quality.hex or "|cffffffff") .. (item.name or "") .. "|r")
		if item.enchant then
			row.enchant:SetText(item.enchant)
			row.enchant:SetTextColor(GREEN[1], GREEN[2], GREEN[3])
		elseif item.missingEnchant then
			row.enchant:SetText(L["No enchant"])
			row.enchant:SetTextColor(RED[1], RED[2], RED[3])
		else
			row.enchant:SetText("")
		end
		setRowGems(row, item)
	else
		button.icon:SetTexture(row.emptyTexture)
		button.icon:SetDesaturated(gear ~= nil)
		row.glow:Hide()
		row.level:SetText("")
		row.name:SetText(gear and GREY .. Gear.SlotLabel(row.slot) .. "|r" or "")
		row.enchant:SetText("")
		setRowGems(row, nil)
	end
end

local function statValue(stat, value, percent)
	local text = value > 0 and formatNumber(value) or ""
	if stat.resilience then
		percent = state.level == Gear.MAX_LEVEL and value / stat.rating or nil
	end
	if not stat.rating or not percent then
		return text
	end
	if stat.points then
		return ("%s %s(%d)|r"):format(text, GREY, percent)
	end
	return ("%s %s%.2f%%|r"):format(text, GREY, percent)
end

local function isCaster(stats)
	if CASTER_CLASSES[state.class] then
		return true
	end
	if HYBRID_CLASSES[state.class] then
		return (stats.ITEM_MOD_SPELL_POWER_SHORT or 0) > (stats.ITEM_MOD_ATTACK_POWER_SHORT or 0)
	end
	return false
end

local function showStatTooltip(self)
	if not self.stat then
		return
	end
	GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
	GameTooltip:SetText(_G[self.stat.key] or self.stat.key, 1, 1, 1)
	if self.stat.resilience and state.level == Gear.MAX_LEVEL then
		local reduction = self.value / self.stat.rating
		GameTooltip:AddLine(
			RESILIENCE_TOOLTIP:format(reduction, reduction * 2.2, reduction * 2),
			NORMAL_FONT_COLOR.r,
			NORMAL_FONT_COLOR.g,
			NORMAL_FONT_COLOR.b,
			true
		)
	end
	local totals = state.totals
	if self.stat.resilience and totals then
		for _, entry in ipairs(CRIT_TAKEN) do
			local value = totals.critTaken[entry[1]]
			if value then
				GameTooltip:AddDoubleLine(
					L["Chance to be critically hit"] .. " (" .. entry[2] .. ")",
					("-%d%%"):format(value),
					1,
					1,
					1,
					GREEN[1],
					GREEN[2],
					GREEN[3]
				)
			end
		end
	end
	local schoolCrit = totals and self.stat.key == "ITEM_MOD_CRIT_RATING_SHORT" and totals.schoolCrit
	if schoolCrit then
		local color = NORMAL_FONT_COLOR
		for school = 2, 7 do
			GameTooltip:AddDoubleLine(
				_G["DAMAGE_SCHOOL" .. school],
				("%.2f%%"):format(schoolCrit[school]),
				color.r,
				color.g,
				color.b,
				color.r,
				color.g,
				color.b
			)
			GameTooltip:AddTexture("Interface\\PaperDollInfoFrame\\SpellSchoolIcon" .. school)
		end
	end
	local sources = totals and totals.sources[self.stat.key]
	if sources then
		GameTooltip:AddLine(" ")
		for _, source in ipairs(sources) do
			GameTooltip:AddDoubleLine(source.name or "", source.text, 1, 1, 1, GREEN[1], GREEN[2], GREEN[3])
		end
	end
	GameTooltip:AddLine(" ")
	GameTooltip:AddLine(
		totals and totals.full and L["Base stats, gear, talents, racial traits and the selected form. Buffs not included."]
			or L["From gear, gems, enchants, socket and set bonuses and talents of the active spec. Base stats and buffs not included."],
		0.6,
		0.6,
		0.6,
		true
	)
	GameTooltip:Show()
end

local function activeTalents()
	local spec = state.specs and state.specs[state.activeGroup]
	return spec and spec.talents
end

local function availableForms()
	local forms = StatData.FORMS[state.class]
	if not forms or state.level ~= StatData.LEVEL then
		return nil
	end
	local known = {}
	for _, talent in ipairs(activeTalents() or {}) do
		known[talent.id] = true
	end
	local list = {}
	for _, form in ipairs(forms) do
		if not form.talent or known[form.talent] then
			list[#list + 1] = form
		end
	end
	return list
end

local function selectedForm(list)
	local id = state.form or state.detectedForm
	for _, form in ipairs(list) do
		if form.id == id then
			return form
		end
	end
	return list[1]
end

local function detectForm()
	state.detectedForm = nil
	if not unitValid() then
		return
	end
	for i = 1, 40 do
		local name, _, _, _, _, _, _, _, _, _, spellId = UnitBuff(state.unit, i)
		if not name then
			break
		end
		if StatData.FORM_AURAS[spellId] then
			state.detectedForm = StatData.FORM_AURAS[spellId]
			return
		end
	end
	local index = state.isSelf and GetShapeshiftForm() or 0
	if index > 0 then
		local _, name = GetShapeshiftFormInfo(index)
		for _, form in ipairs(StatData.FORMS[state.class] or {}) do
			if form.spell and GetSpellInfo(form.spell) == name then
				state.detectedForm = form.id
				return
			end
		end
	end
end

local function formName(form)
	return form.spell and GetSpellInfo(form.spell) or L["No form"]
end

local function formIcon(form)
	if form.spell then
		return (select(3, GetSpellInfo(form.spell)))
	end
	return "Interface\\Icons\\Ability_Hunter_Pet_Bear"
end

local function updateFormButtons(list, current)
	local buttons = frame.formButtons
	local count = list and #list or 0
	for i, button in ipairs(buttons) do
		local form = list and list[i]
		button.form = form
		if form then
			button:SetPoint("BOTTOMRIGHT", frame.statsInset, "TOPRIGHT", -4 - (count - i) * (FORM_SIZE + 3), 2)
			button.icon:SetTexture(formIcon(form))
			local selected = form == current
			button.icon:SetDesaturated(not selected)
			button:SetAlpha(selected and 1 or 0.55)
			if selected then
				button.border:Show()
			else
				button.border:Hide()
			end
			if form.id == state.detectedForm then
				button.detected:Show()
			else
				button.detected:Hide()
			end
			button:Show()
		else
			button:Hide()
		end
	end
end

local statByKey

local function offenseTitle(caster)
	if caster == nil then
		return ""
	elseif caster then
		return L["Spell"]
	end
	return state.class == "HUNTER" and L["Ranged"] or L["Melee"]
end

local function updateStats()
	if not statByKey then
		statByKey = {}
		for _, stat in ipairs(Gear.STATS) do
			statByKey[stat.key] = stat
		end
	end
	local gear = state.gear
	local totals, caster
	state.totals = nil
	detectForm()
	local forms = availableForms()
	local form = forms and selectedForm(forms)
	updateFormButtons(gear and forms, form)
	if gear then
		caster = isCaster(gear.stats)
		if form and form.feral then
			caster = false
		elseif form and form.caster then
			caster = true
		end
		totals = Gear.Compute(gear, activeTalents(), {
			class = state.class,
			race = state.raceFile,
			level = state.level,
			form = form and form.id,
			formData = form,
			caster = caster,
		})
		state.totals = totals
	end
	for index, group in ipairs(frame.statGroups) do
		local rows = group.rows
		local shown = 0
		if index == 2 then
			group.title:SetText(offenseTitle(caster))
		end
		if totals then
			for _, key in ipairs(STAT_GROUPS[index].keys) do
				if totals.visible[key] and shown < #rows then
					shown = shown + 1
					local stat, value = statByKey[key], totals.values[key] or 0
					local row = rows[shown]
					row.stat, row.value = stat, value
					row.label:SetText(L[STAT_LABELS[key] or key])
					row.valueText:SetText(statValue(stat, value, totals.percent[key]))
					row:Show()
				end
			end
		end
		for i = shown + 1, #rows do
			rows[i].stat = nil
			rows[i]:Hide()
		end
	end
end

local function showFormTooltip(self)
	if not self.form then
		return
	end
	GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
	if self.form.spell then
		GameTooltip:SetHyperlink("spell:" .. self.form.spell)
		GameTooltip:AddLine(" ")
	else
		GameTooltip:SetText(formName(self.form), 1, 1, 1)
	end
	if self.form.id == state.detectedForm then
		GameTooltip:AddLine(L["Current form of the player"], GREEN[1], GREEN[2], GREEN[3])
	end
	GameTooltip:AddLine(L["Click to show the stats in this form."], 0.6, 0.6, 0.6, true)
	GameTooltip:Show()
end

local function onFormClick(self)
	if self.form then
		state.form = self.form.id
		updateStats()
		showFormTooltip(self)
	end
end

local function showIssuesTooltip(self)
	local issues = state.gear and state.gear.issues
	if not issues then
		return
	end
	GameTooltip:SetOwner(self, "ANCHOR_BOTTOMLEFT")
	GameTooltip:SetText(L["Gear check"], 1, 1, 1)
	if #issues == 0 then
		GameTooltip:AddLine(L["Fully enchanted and gemmed"], GREEN[1], GREEN[2], GREEN[3])
	end
	for _, issue in ipairs(issues) do
		local color = issue.severity == "error" and RED or YELLOW
		GameTooltip:AddLine(issue.text, color[1], color[2], color[3])
	end
	GameTooltip:Show()
end

local function updateIssues()
	local button = frame.issues
	local gear = state.gear
	if not gear or state.level ~= Gear.MAX_LEVEL then
		button:Hide()
		return
	end
	local errors = 0
	for _, issue in ipairs(gear.issues) do
		if issue.severity == "error" then
			errors = errors + 1
		end
	end
	local count = #gear.issues
	local color = errors > 0 and RED or count > 0 and YELLOW or GREEN
	ns.SetGlyph(button.glyph, count > 0 and "triangle-exclamation" or "circle-check")
	button.glyph:SetTextColor(color[1], color[2], color[3])
	button.text:SetText(count > 0 and count or "")
	button.text:SetTextColor(color[1], color[2], color[3])
	button:SetWidth(button.glyph:GetStringWidth() + (count > 0 and button.text:GetStringWidth() + 4 or 0) + 4)
	button:Show()
	if GameTooltip:IsOwned(button) then
		showIssuesTooltip(button)
	end
end

local function updateGear()
	for _, row in ipairs(frame.itemRows) do
		updateRow(row)
	end
	updateStats()
	updateIssues()
	frame.gearStatus:SetText(state.gear and "" or state.status or "")
end

local scanGear

local function retryGear(token)
	if token == gearToken and frame:IsShown() then
		scanGear()
	end
end

function scanGear()
	if not dataLoaded() then
		return
	end
	local gear = Gear.Scan(state.unit, true, state.class, state.level)
	state.gear = gear
	setStatus(nil)
	updateGear()
	updateHeader()
	if gear.pending and gearRetries < GEAR_RETRIES then
		gearRetries = gearRetries + 1
		gearToken = gearToken + 1
		ns.After(GEAR_RETRY_DELAY, retryGear, gearToken)
	end
end

local function updateSideTabs()
	local show = pages[2]:IsShown() and state.specs and state.numGroups > 1
	for group, tab in ipairs(frame.specTabs) do
		local spec = state.specs and state.specs[group]
		if show and spec then
			tab:GetNormalTexture():SetTexture(specIcon(spec))
			tab:SetChecked(group == state.group)
			tab:Show()
		else
			tab:Hide()
		end
	end
end

local function updateTalents()
	local page = pages[2]
	if not state.specs then
		for _, pane in ipairs(panes) do
			pane:Hide()
		end
		page.status:SetText(state.status or L["Talents not loaded"])
		updateSideTabs()
		return
	end
	page.status:SetText("")
	talentView.group = state.group or state.activeGroup or 1
	talentView.inspect = not state.isSelf
	local context = { preview = false, editable = false, desaturated = false, unspent = 0, perTier = Tree.PER_TIER }
	local numTabs = min(GetNumTalentTabs(talentView.inspect) or 0, 3)
	for tab, pane in ipairs(panes) do
		if tab <= numTabs then
			Tree.UpdatePane(pane, tab, context)
			pane:Show()
		else
			pane:Hide()
		end
	end
	updateSideTabs()
end

local function statistic(id)
	if not state.achievementsReady then
		return nil
	end
	local value = state.isSelf and GetStatistic(id) or GetComparisonStatistic(id)
	if not value or value == "" or value == "--" then
		return nil
	end
	return value
end

local function statisticNumber(id)
	local value = statistic(id)
	return value and tonumber((value:gsub("[^%d]", ""))) or nil
end

local function rateText(won, played)
	if not won or not played or played == 0 then
		return "-"
	end
	return ("%.0f%%"):format(won / played * 100)
end

local function updateTeam(card, size)
	local index
	for i = 1, MAX_ARENA_TEAMS do
		local _, teamSize = arenaTeamData(i)
		if teamSize == size then
			index = i
		end
	end
	card.banner:SetTexture(BANNER:format(size))
	if not index or not state.honorReady then
		card:SetAlpha(0.5)
		card.banner:SetVertexColor(0.3, 0.3, 0.3)
		card.border:Hide()
		card.emblem:Hide()
		card.name:SetText(GREY .. (state.honorReady and L["No team"] or L["Not loaded"]) .. "|r")
		card.rating:SetText("")
		for _, line in ipairs(card.lines) do
			line:SetText("")
		end
		return
	end
	local name, _, rating, played, wins, playerPlayed, playerRating, bgR, bgG, bgB, emblem, emR, emG, emB, border, bR, bG, bB =
		arenaTeamData(index)
	card:SetAlpha(1)
	card.banner:SetVertexColor(bgR, bgG, bgB)
	if border and border ~= -1 then
		card.border:SetTexture(BANNER_BORDER:format(size, border))
		card.border:SetVertexColor(bR, bG, bB)
		card.border:Show()
	else
		card.border:Hide()
	end
	if emblem and emblem ~= -1 then
		card.emblem:SetTexture(BANNER_EMBLEM:format(emblem))
		card.emblem:SetVertexColor(emR, emG, emB)
		card.emblem:Show()
	else
		card.emblem:Hide()
	end
	card.name:SetText(name)
	card.rating:SetText(rating)
	local lost = (played or 0) - (wins or 0)
	card.lines[1]:SetFormattedText(
		L["Games %s%d|r  won %s%d|r  lost %s%d|r"],
		"|cffffffff",
		played or 0,
		"|cff40ff40",
		wins or 0,
		"|cffff4040",
		lost
	)
	card.lines[2]:SetFormattedText(L["Win rate %s%s|r"], "|cffffffff", rateText(wins, played))
	card.lines[3]:SetFormattedText(
		L["Played %s%d|r (%s)"],
		"|cffffffff",
		playerPlayed or 0,
		rateText(playerPlayed, played)
	)
	card.lines[4]:SetFormattedText(L["Personal rating %s%d|r"], "|cffffffff", playerRating or 0)
end

local function setPair(row, label, value)
	row.label:SetText(label)
	row.valueText:SetText(value or "-")
end

local function updateHonor()
	local rows = frame.honorRows
	if state.honorReady then
		local todayHK, todayHonor, yesterdayHK, yesterdayHonor, lifetimeHK = honorData()
		setPair(rows[1], L["Kills / honor today"], ("%d %s/|r %d"):format(todayHK or 0, GREY, todayHonor or 0))
		setPair(
			rows[2],
			L["Kills / honor yesterday"],
			("%d %s/|r %d"):format(yesterdayHK or 0, GREY, yesterdayHonor or 0)
		)
		setPair(rows[3], L["Lifetime kills"], formatNumber(lifetimeHK or 0))
	else
		setPair(rows[1], L["Kills / honor today"], nil)
		setPair(rows[2], L["Kills / honor yesterday"], nil)
		setPair(rows[3], L["Lifetime kills"], nil)
	end
	setPair(rows[4], L["Killing blows"], statistic(STAT_KILLING_BLOWS))
	local bgWon, bgPlayed = statisticNumber(STAT_BG_WON), statisticNumber(STAT_BG_PLAYED)
	setPair(
		rows[5],
		L["Battlegrounds won"],
		bgPlayed and ("%d / %d %s(%s)|r"):format(bgWon or 0, bgPlayed, GREY, rateText(bgWon, bgPlayed)) or nil
	)
	local duelsWon, duelsLost = statisticNumber(STAT_DUELS_WON), statisticNumber(STAT_DUELS_LOST)
	setPair(
		rows[6],
		L["Duels won / lost"],
		(duelsWon or duelsLost) and ("%d / %d"):format(duelsWon or 0, duelsLost or 0) or nil
	)
	setPair(rows[7], L["Deaths from players"], statistic(STAT_PLAYER_DEATHS))
end

local function updateArenaStats()
	local grid = frame.arenaGrid
	for r, entry in ipairs(ARENA_STATISTICS) do
		local cells = grid[r]
		for c = 1, 3 do
			cells[c]:SetText(statistic(entry.ids[c]) or GREY .. "-|r")
		end
	end
	frame.arenaStatus:SetText(state.achievementsReady and "" or GREY .. L["Statistics not loaded"] .. "|r")
end

local function resolveAchievement(entry)
	if type(entry) == "number" then
		return entry
	end
	if entry.chain then
		local best = entry.chain[1]
		for _, id in ipairs(entry.chain) do
			if state.achievementsReady and achievementDate(id) then
				best = id
			end
		end
		return best
	end
	return entry[state.faction or "Alliance"] or entry.Alliance
end

local function showAchievementTooltip(self)
	local id = self.achievement
	if not id then
		return
	end
	local _, name, points, _, _, _, _, description = GetAchievementInfo(id)
	GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
	GameTooltip:SetText(name or "", 1, 1, 1)
	if description and description ~= "" then
		GameTooltip:AddLine(description, NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b, true)
	end
	if not state.achievementsReady then
		GameTooltip:AddLine(L["Not loaded"], 0.6, 0.6, 0.6)
	elseif self.completed then
		GameTooltip:AddLine(
			L["Completed %s"]:format(SHORTDATE:format(self.day, self.month, self.year)),
			GREEN[1],
			GREEN[2],
			GREEN[3]
		)
	else
		GameTooltip:AddLine(INCOMPLETE, RED[1], RED[2], RED[3])
	end
	if points and points > 0 then
		GameTooltip:AddLine(TINY_SHIELD .. " " .. points, 1, 1, 1)
	end
	GameTooltip:Show()
end

local function onAchievementClick(self)
	if self.achievement and IsModifiedClick("CHATLINK") then
		local link = GetAchievementLink(self.achievement)
		if link then
			ChatEdit_InsertLink(link)
		end
	end
end

local function updateAchievements()
	for r, row in ipairs(frame.achievementRows) do
		local earned = 0
		for i, entry in ipairs(ACHIEVEMENT_ROWS[r].ids) do
			local button = row.buttons[i]
			local id = resolveAchievement(entry)
			local _, _, _, _, _, _, _, _, _, icon = GetAchievementInfo(id)
			local completed, month, day, year
			if state.achievementsReady then
				completed, month, day, year = achievementDate(id)
			end
			button.achievement = id
			button.completed, button.month, button.day, button.year = completed, month, day, year
			button.icon:SetTexture(icon)
			button.icon:SetDesaturated(not completed)
			button.icon:SetAlpha(completed and 1 or 0.45)
			if completed then
				earned = earned + 1
			end
		end
		row.count:SetText(state.achievementsReady and ("%d/%d"):format(earned, #ACHIEVEMENT_ROWS[r].ids) or "")
	end
end

local function updatePvP()
	for i, size in ipairs(ARENA_SIZES) do
		updateTeam(frame.teamCards[i], size)
	end
	updateHonor()
	updateArenaStats()
	updateAchievements()
end

local function refreshAll()
	updateHeader()
	updateGear()
	updateTalents()
	updatePvP()
end

function loadSelf()
	captureIdentity("player")
	readSpecs()
	state.honorReady, state.achievementsReady = true, true
	state.gear = Gear.Scan("player", true, state.class, state.level)
	setStatus(nil)
	refreshAll()
end

local function showPage(index)
	for i, page in ipairs(pages) do
		ns.SetShown(page, i == index)
	end
	updateSideTabs()
end

local function createPairRow(parent, labelWidth, width)
	local row = CreateFrame("Frame", nil, parent)
	row:SetSize(width, LIST_ROW)
	row:EnableMouse(true)
	local label = row:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
	label:SetPoint("LEFT")
	label:SetWidth(labelWidth)
	label:SetJustifyH("LEFT")
	row.label = label
	local value = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	value:SetPoint("RIGHT")
	value:SetJustifyH("RIGHT")
	row.valueText = value
	return row
end

local function createHeader()
	local portrait = frame:CreateTexture(nil, "ARTWORK")
	portrait:SetSize(56, 56)
	portrait:SetPoint("TOPLEFT", INSET.left, -HEADER_TOP + 2)
	frame.portrait = portrait

	local ring = frame:CreateTexture(nil, "OVERLAY")
	ring:SetTexture("Interface\\CharacterFrame\\TotemBorder")
	ring:SetSize(80, 80)
	ring:SetPoint("CENTER", portrait)
	frame.ring = ring

	local name = frame:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
	name:SetPoint("TOPLEFT", portrait, "TOPRIGHT", 12, -2)
	name:SetWidth(260)
	name:SetJustifyH("LEFT")
	frame.nameText = name

	local info = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
	info:SetPoint("TOPLEFT", name, "BOTTOMLEFT", 0, -3)
	info:SetJustifyH("LEFT")
	frame.infoText = info

	local guild = frame:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
	guild:SetPoint("TOPLEFT", info, "BOTTOMLEFT", 0, -3)
	guild:SetWidth(260)
	guild:SetJustifyH("LEFT")
	guild:SetTextColor(GUILD_COLOR[1], GUILD_COLOR[2], GUILD_COLOR[3])
	frame.guildText = guild

	local specIcon = frame:CreateTexture(nil, "ARTWORK")
	specIcon:SetSize(34, 34)
	specIcon:SetPoint("TOPLEFT", INSET.left + 350, -HEADER_TOP - 2)
	specIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	frame.specIcon = specIcon

	local spec = frame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	spec:SetPoint("TOPLEFT", specIcon, "TOPRIGHT", 8, 0)
	spec:SetJustifyH("LEFT")
	frame.specText = spec

	local spec2 = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	spec2:SetPoint("TOPLEFT", spec, "BOTTOMLEFT", 0, -3)
	spec2:SetJustifyH("LEFT")
	frame.specText2 = spec2

	local spec3 = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	spec3:SetPoint("TOPLEFT", spec2, "BOTTOMLEFT", 0, -3)
	spec3:SetJustifyH("LEFT")
	spec3:SetTextColor(RED[1], RED[2], RED[3])
	frame.specText3 = spec3

	local itemLevel = frame:CreateFontString(nil, "ARTWORK")
	ns.SetFont(itemLevel, 22, "OUTLINE", true)
	itemLevel:SetPoint("TOPRIGHT", -INSET.right - 4, -HEADER_TOP - 2)
	frame.itemLevel = itemLevel

	local itemLevelLabel = frame:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
	itemLevelLabel:SetPoint("RIGHT", itemLevel, "LEFT", -6, -1)
	itemLevelLabel:SetText(L["Item level"])
	frame.itemLevelLabel = itemLevelLabel

	local issues = CreateFrame("Frame", nil, frame)
	issues:SetHeight(16)
	issues:SetPoint("TOPRIGHT", itemLevel, "BOTTOMRIGHT", 0, -4)
	issues:EnableMouse(true)
	issues.glyph = ns.CreateGlyph(issues, "circle-check", 12, "ARTWORK")
	issues.glyph:SetPoint("LEFT", 2, 0)
	issues.text = issues:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	issues.text:SetPoint("LEFT", issues.glyph, "RIGHT", 4, 0)
	issues:SetScript("OnEnter", showIssuesTooltip)
	issues:SetScript("OnLeave", GameTooltip_Hide)
	issues:Hide()
	frame.issues = issues

	local status = frame:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
	status:SetPoint("TOPLEFT", INSET.left + 350, -HEADER_TOP - 44)
	frame.status = status

	local refresh = ns.CreateGlyphButton(frame, "rotate", 12, L["Refresh"])
	refresh:SetPoint("TOPRIGHT", -34, -8)
	refresh:SetFrameLevel(frame:GetFrameLevel() + 6)
	refresh:SetScript("OnClick", function()
		state.attempts = 0
		requestInspect()
	end)
	refresh.SetEnabled = function(self, enabled)
		if enabled then
			self:Enable()
		else
			self:Disable()
		end
	end
	frame.refresh = refresh
end

local function createInsetList(parent, x, width, title)
	local inset = ns.CreateInset(parent, "box", title)
	inset:SetPoint("TOPLEFT", x, -PANEL_TOP)
	inset:SetSize(width, PANEL_HEIGHT)
	return inset
end

local function createGearPage()
	local page = CreateFrame("Frame", nil, frame)
	page:SetPoint("TOPLEFT", INSET.left, -CONTENT_TOP)
	page:SetSize(CONTENT_WIDTH, PAGE_HEIGHT)
	pages[1] = page

	frame.itemRows = {}
	for i, slot in ipairs(Gear.LAYOUT.left) do
		local row = createItemRow(page, slot, "left", TEXT_WIDTH)
		row:SetPoint("TOPLEFT", 0, -(i - 1) * ROW_HEIGHT)
		frame.itemRows[#frame.itemRows + 1] = row
	end
	for i, slot in ipairs(Gear.LAYOUT.right) do
		local row = createItemRow(page, slot, "right", TEXT_WIDTH)
		row:SetPoint("TOPRIGHT", 0, -(i - 1) * ROW_HEIGHT)
		frame.itemRows[#frame.itemRows + 1] = row
	end
	local weaponWidth = ICON_SIZE + ROW_GAP + WEAPON_TEXT_WIDTH
	local weaponGap = (CONTENT_WIDTH - 3 * weaponWidth) / 2
	for i, slot in ipairs(Gear.LAYOUT.bottom) do
		local row = createItemRow(page, slot, "left", WEAPON_TEXT_WIDTH)
		row:SetPoint("TOPLEFT", (i - 1) * (weaponWidth + weaponGap), -WEAPON_Y)
		frame.itemRows[#frame.itemRows + 1] = row
	end

	local sideWidth = ICON_SIZE + ROW_GAP + TEXT_WIDTH + 8
	local model = CreateFrame("PlayerModel", nil, page)
	model:SetPoint("TOPLEFT", sideWidth, 0)
	model:SetPoint("BOTTOMRIGHT", page, "TOPRIGHT", -sideWidth, -(ROWS * ROW_HEIGHT - ROW_GAP))
	ns.SetupModelControls(model)
	frame.model = model

	local gearStatus = model:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	gearStatus:SetPoint("CENTER", model)
	gearStatus:SetWidth(180)
	frame.gearStatus = gearStatus

	frame.statGroups = {}
	local rowWidth = STAT_GROUP_WIDTH - 16
	for index, group in ipairs(STAT_GROUPS) do
		local inset = createInsetList(page, (index - 1) * (STAT_GROUP_WIDTH + STAT_GROUP_GAP), STAT_GROUP_WIDTH, " ")
		inset.title:SetText(group.title and L[group.title] or "")
		local rows = {}
		for i = 1, min(#group.keys, LIST_ROWS) do
			local row = createPairRow(inset, rowWidth - 90, rowWidth)
			row:SetPoint("TOPLEFT", 8, -6 - (i - 1) * LIST_ROW)
			row:SetScript("OnEnter", showStatTooltip)
			row:SetScript("OnLeave", GameTooltip_Hide)
			row:Hide()
			rows[i] = row
		end
		frame.statGroups[index] = { title = inset.title, rows = rows }
		frame.statsInset = inset
	end
	local statsInset = frame.statsInset
	frame.formButtons = {}
	for i = 1, FORM_BUTTONS do
		local button = CreateFrame("Button", nil, statsInset)
		button:SetSize(FORM_SIZE, FORM_SIZE)
		button:SetPoint("BOTTOMRIGHT", statsInset, "TOPRIGHT", -4 - (FORM_BUTTONS - i) * (FORM_SIZE + 3), 2)
		button.icon = button:CreateTexture(nil, "ARTWORK")
		button.icon:SetAllPoints()
		button.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
		button.border = button:CreateTexture(nil, "OVERLAY")
		button.border:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
		button.border:SetBlendMode("ADD")
		button.border:SetPoint("CENTER")
		button.border:SetSize(FORM_SIZE * 1.8, FORM_SIZE * 1.8)
		button.detected = button:CreateTexture(nil, "OVERLAY")
		button.detected:SetTexture(0.25, 1, 0.25)
		button.detected:SetPoint("TOPLEFT", button, "BOTTOMLEFT", 2, -1)
		button.detected:SetPoint("TOPRIGHT", button, "BOTTOMRIGHT", -2, -1)
		button.detected:SetHeight(2)
		button:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
		button:SetScript("OnClick", onFormClick)
		button:SetScript("OnEnter", showFormTooltip)
		button:SetScript("OnLeave", GameTooltip_Hide)
		button:Hide()
		frame.formButtons[i] = button
	end
end

local function selectGroup(self)
	state.group = self.group
	PlaySound("igCharacterInfoTab")
	updateTalents()
end

local function showSpecTooltip(self)
	local spec = state.specs and state.specs[self.group]
	if not spec then
		return
	end
	GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
	GameTooltip:AddLine(_G[self.group == 1 and "TALENT_SPEC_PRIMARY" or "TALENT_SPEC_SECONDARY"])
	if self.group == state.activeGroup then
		GameTooltip:AddLine(TALENT_ACTIVE_SPEC_STATUS, GREEN_FONT_COLOR.r, GREEN_FONT_COLOR.g, GREEN_FONT_COLOR.b)
	end
	for tab = 1, 3 do
		if spec.names[tab] then
			local color = spec.primary == tab and GREEN_FONT_COLOR or HIGHLIGHT_FONT_COLOR
			GameTooltip:AddDoubleLine(spec.names[tab], spec.points[tab], 1, 1, 1, color.r, color.g, color.b)
		end
	end
	GameTooltip:Show()
end

local function createTalentPage()
	local page = CreateFrame("Frame", nil, frame)
	page:SetPoint("TOPLEFT", INSET.left, -CONTENT_TOP)
	page:SetSize(CONTENT_WIDTH, PAGE_HEIGHT)
	page:Hide()
	pages[2] = page

	for i = 1, 3 do
		local pane = Tree.CreatePane(page, talentView)
		pane:SetPoint("TOPLEFT", (i - 1) * (Tree.PANE_WIDTH + PANE_GAP), 0)
		pane:SetHeight(PANE_HEIGHT)
		Tree.LayoutArt(pane, PANE_BODY)
		pane:Hide()
		panes[i] = pane
	end

	local status = page:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	status:SetPoint("CENTER")
	page.status = status

	frame.specTabs = {}
	for group = 1, 2 do
		local tab = ns.CreateSideTab(frame, DEFAULT_SPEC_ICON)
		tab.group = group
		tab:SetPoint("TOPLEFT", frame, "TOPRIGHT", SIDE_TAB_X, SIDE_TAB_Y - (group - 1) * SIDE_TAB_STEP)
		tab:SetScript("OnClick", selectGroup)
		tab:SetScript("OnEnter", showSpecTooltip)
		tab:Hide()
		frame.specTabs[group] = tab
	end
end

local function createTeamCard(parent, index)
	local card = ns.CreateInset(parent, "panel")
	card:SetSize(TEAM_WIDTH, TEAM_HEIGHT)
	card:SetPoint("TOPLEFT", (index - 1) * (TEAM_WIDTH + PANE_GAP), -16)

	local size = ARENA_SIZES[index]
	local label = parent:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	label:SetPoint("BOTTOMLEFT", card, "TOPLEFT", 4, 1)
	label:SetFormattedText("%dv%d", size, size)

	local banner = card:CreateTexture(nil, "BORDER")
	banner:SetSize(45, 90)
	banner:SetPoint("TOPLEFT", 10, -10)
	card.banner = banner

	local border = card:CreateTexture(nil, "ARTWORK")
	border:SetSize(45, 90)
	border:SetPoint("CENTER", banner)
	card.border = border

	local emblem = card:CreateTexture(nil, "OVERLAY")
	emblem:SetSize(24, 24)
	emblem:SetPoint("CENTER", border, "CENTER", -5, 17)
	card.emblem = emblem

	local name = card:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	name:SetPoint("TOPLEFT", 64, -10)
	name:SetWidth(TEAM_WIDTH - 72)
	name:SetJustifyH("LEFT")
	card.name = name

	local rating = card:CreateFontString(nil, "ARTWORK", "GameFontHighlightLarge")
	rating:SetPoint("TOPLEFT", name, "BOTTOMLEFT", 0, -4)
	card.rating = rating

	card.lines = {}
	for i = 1, 4 do
		local line = card:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
		line:SetPoint("TOPLEFT", i == 1 and rating or card.lines[i - 1], "BOTTOMLEFT", 0, i == 1 and -6 or -3)
		line:SetWidth(TEAM_WIDTH - 72)
		line:SetJustifyH("LEFT")
		card.lines[i] = line
	end
	return card
end

local function createPvPPage()
	local page = CreateFrame("Frame", nil, frame)
	page:SetPoint("TOPLEFT", INSET.left, -CONTENT_TOP)
	page:SetSize(CONTENT_WIDTH, PAGE_HEIGHT)
	page:Hide()
	pages[3] = page

	frame.teamCards = {}
	for i = 1, #ARENA_SIZES do
		frame.teamCards[i] = createTeamCard(page, i)
	end

	local honor = ns.CreateInset(page, "box", HONOR)
	honor:SetPoint("TOPLEFT", 0, -STATS_TOP - 16)
	honor:SetSize(TEAM_WIDTH, STATS_HEIGHT)
	frame.honorRows = {}
	for i = 1, 7 do
		local row = createPairRow(honor, 110, TEAM_WIDTH - 16)
		row:SetPoint("TOPLEFT", 8, -8 - (i - 1) * 19)
		frame.honorRows[i] = row
	end

	local statsWidth = CONTENT_WIDTH - TEAM_WIDTH - PANE_GAP
	local stats = ns.CreateInset(page, "box", L["Arena statistics"])
	stats:SetPoint("TOPLEFT", TEAM_WIDTH + PANE_GAP, -STATS_TOP - 16)
	stats:SetSize(statsWidth, STATS_HEIGHT)
	local labelWidth = 170
	local cellWidth = (statsWidth - labelWidth - 24) / 3
	for c, size in ipairs(ARENA_SIZES) do
		local head = stats:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
		head:SetPoint("TOPRIGHT", stats, "TOPLEFT", 8 + labelWidth + c * cellWidth, -8)
		head:SetText(("%dv%d"):format(size, size))
	end
	frame.arenaGrid = {}
	for r, entry in ipairs(ARENA_STATISTICS) do
		local y = -8 - r * 17
		local label = stats:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
		label:SetPoint("TOPLEFT", 8, y)
		label:SetWidth(labelWidth)
		label:SetJustifyH("LEFT")
		label:SetText(L[entry.label])
		local cells = {}
		for c = 1, 3 do
			local cell = stats:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
			cell:SetPoint("TOPRIGHT", stats, "TOPLEFT", 8 + labelWidth + c * cellWidth, y)
			cells[c] = cell
		end
		frame.arenaGrid[r] = cells
	end
	local status = stats:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
	status:SetPoint("BOTTOMLEFT", 8, 8)
	frame.arenaStatus = status

	local achievements = ns.CreateInset(page, "box", ACHIEVEMENTS)
	achievements:SetPoint("TOPLEFT", 0, -ACHIEVEMENTS_TOP - 16)
	achievements:SetPoint("BOTTOMRIGHT", page, "BOTTOMRIGHT", 0, 0)
	frame.achievementRows = {}
	for r, def in ipairs(ACHIEVEMENT_ROWS) do
		local row = CreateFrame("Frame", nil, achievements)
		row:SetPoint("TOPLEFT", 8, -8 - (r - 1) * (ACHIEVEMENT_SIZE + 8))
		row:SetSize(CONTENT_WIDTH - 16, ACHIEVEMENT_SIZE)
		local label = row:CreateFontString(nil, "ARTWORK", "GameFontNormal")
		label:SetPoint("TOPLEFT", 0, -2)
		label:SetText(L[def.label])
		local count = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
		count:SetPoint("TOPLEFT", label, "BOTTOMLEFT", 0, -2)
		row.count = count
		row.buttons = {}
		for i = 1, #def.ids do
			local button = CreateFrame("Button", nil, row)
			button:SetSize(ACHIEVEMENT_SIZE, ACHIEVEMENT_SIZE)
			button:SetPoint("LEFT", ACHIEVEMENT_LABEL_WIDTH + (i - 1) * (ACHIEVEMENT_SIZE + ACHIEVEMENT_GAP), 0)
			ns.SkinIconButton(button, false)
			button.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
			button:SetScript("OnEnter", showAchievementTooltip)
			button:SetScript("OnLeave", GameTooltip_Hide)
			button:SetScript("OnClick", onAchievementClick)
			row.buttons[i] = button
		end
		frame.achievementRows[r] = row
	end
end

local function onTick(self, elapsed)
	self.elapsed = (self.elapsed or 0) + elapsed
	if self.elapsed < TICK then
		return
	end
	self.elapsed = 0
	local now = GetTime()
	if state.dirtyAt and now >= state.dirtyAt then
		state.dirtyAt = nil
		state.attempts = 0
		requestInspect()
		return
	end
	local waiting = not state.specs or not state.gear
	if waiting and state.attempts < MAX_ATTEMPTS and now - (state.sent or 0) > RETRY_INTERVAL then
		requestInspect()
	elseif waiting and state.attempts >= MAX_ATTEMPTS and not state.gear then
		setStatus(L["No inspect data"])
	end
end

local function onHide()
	PlaySound("igCharacterInfoClose")
	Inspect:SetHold(false)
	ClearInspectPlayer()
	if state.comparing and comparisonAllowed() then
		ClearAchievementComparisonUnit()
	end
	gearToken = gearToken + 1
	wipe(state)
end

local function createFrame()
	frame = ns.CreateWindow(FRAME_NAME, {
		width = WIDTH,
		height = HEIGHT,
		title = INSPECT,
		background = "dark",
		strata = "MEDIUM",
		movable = false,
		special = false,
	})
	frame.close:SetScript("OnClick", HideParentPanel)
	ns.SetUIPanelLayout(frame, "left", 0)

	local underlay = frame:CreateTexture(nil, "BACKGROUND")
	underlay:SetTexture(0, 0, 0, UNDERLAY_ALPHA)
	underlay:SetPoint("TOPLEFT", 11, -12)
	underlay:SetPoint("BOTTOMRIGHT", -12, 11)

	createHeader()
	createGearPage()
	createTalentPage()
	createPvPPage()

	ns.CreateTabs(frame, { L["Equipment"], TALENTS, PVP }, { onSelect = showPage })

	frame:SetScript("OnHide", onHide)
	frame:SetScript("OnUpdate", onTick)
end

local function open(unit, follow)
	if not unit or not UnitExists(unit) or not UnitIsPlayer(unit) then
		return
	end
	local isSelf = UnitIsUnit(unit, "player")
	if isSelf and not follow then
		ToggleCharacter("PaperDollFrame")
		return
	end
	if not isSelf and not CanInspect(unit, not follow) then
		return
	end
	if not frame then
		createFrame()
	end
	local guid = UnitGUID(unit)
	if frame:IsShown() and state.guid == guid then
		return
	end
	if frame:IsShown() then
		ClearInspectPlayer()
	end
	gearToken = gearToken + 1
	gearRetries = 0
	wipe(state)
	state.followTarget = UnitIsUnit(unit, "target")
	state.isSelf = isSelf
	unit = isSelf and "player" or unit
	state.unit, state.guid, state.attempts = unit, guid, 0
	captureIdentity(unit)

	Inspect:SetHold(not isSelf)
	if not frame:IsShown() then
		PlaySound("igCharacterInfoOpen")
	end
	ShowUIPanel(frame)
	frame.model:SetUnit(unit)
	frame.model:SetFacing(0.61)
	refreshAll()
	requestInspect()
	if not isSelf and Inspect:IsLoaded(guid) then
		scanGear()
	end
end

local function onTalentsReady(_, guid)
	if not frame or not frame:IsShown() or guid ~= state.guid then
		return
	end
	readSpecs()
	updateHeader()
	updateTalents()
	updateStats()
	updateIssues()
	if resolveUnit() then
		RequestInspectHonorData()
	end
end

local function onGearReady(_, guid, unit)
	if not frame or not frame:IsShown() or guid ~= state.guid then
		return
	end
	if unit then
		state.unit = unit
	end
	gearRetries = 0
	if unitValid() then
		captureIdentity(state.unit)
	end
	scanGear()
end

function InspectFrame:Initialize()
	InspectUnit = open

	self:RegisterEvent(ns.INSPECT_TALENTS_READY, onTalentsReady)
	self:RegisterEvent(ns.INSPECT_GEAR_READY, onGearReady)
	self:RegisterEvent("INSPECT_HONOR_UPDATE", function()
		if frame and frame:IsShown() and state.specs and HasInspectHonorData() then
			state.honorReady = true
			updatePvP()
		end
	end)
	self:RegisterEvent("INSPECT_ACHIEVEMENT_READY", function()
		if frame and frame:IsShown() and state.comparing then
			state.achievementsReady = true
			updatePvP()
		end
	end)
	self:RegisterEvent("UNIT_INVENTORY_CHANGED", function(_, unit)
		if frame and frame:IsShown() and unit == state.unit and unitValid() and state.gear then
			state.dirtyAt = GetTime() + REFRESH_DELAY
		end
	end)
	local function onFormChanged()
		local previous = state.detectedForm
		detectForm()
		if state.detectedForm ~= previous then
			updateStats()
		end
	end
	self:RegisterEvent("UNIT_AURA", function(_, unit)
		if frame and frame:IsShown() and unit == state.unit and state.gear and unitValid() then
			onFormChanged()
		end
	end)
	self:RegisterEvent("UPDATE_SHAPESHIFT_FORM", function()
		if frame and frame:IsShown() and state.isSelf and state.gear then
			onFormChanged()
		end
	end)
	self:RegisterEvent("PLAYER_TALENT_UPDATE", function()
		if frame and frame:IsShown() and state.isSelf then
			loadSelf()
		end
	end)
	self:RegisterEvent("UNIT_MODEL_CHANGED", function(_, unit)
		if frame and frame:IsShown() and unit == state.unit and unitValid() then
			frame.model:RefreshUnit()
		end
	end)
	self:RegisterEvent("UNIT_PORTRAIT_UPDATE", function(_, unit)
		if frame and frame:IsShown() and unit == state.unit and unitValid() then
			SetPortraitTexture(frame.portrait, unit)
		end
	end)
	local function onUnitsChanged()
		if frame and frame:IsShown() then
			resolveUnit()
			frame.refresh:SetEnabled(unitValid())
		end
	end
	self:RegisterEvent("PLAYER_TARGET_CHANGED", function()
		if frame and frame:IsShown() and state.followTarget and UnitGUID("target") ~= state.guid then
			open("target", true)
		end
		onUnitsChanged()
	end)
	self:RegisterEvent("PARTY_MEMBERS_CHANGED", onUnitsChanged)
	self:RegisterEvent("PLAYER_FOCUS_CHANGED", onUnitsChanged)
end
