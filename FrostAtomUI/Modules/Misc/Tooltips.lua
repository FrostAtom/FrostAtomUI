local _, ns = ...

local L = ns.L

local GetSpellInfo = GetSpellInfo
local GetItemInfo = GetItemInfo
local GetItemIcon = GetItemIcon
local GetItemCount = GetItemCount
local UnitAura = UnitAura
local UnitName = UnitName
local UnitPVPName = UnitPVPName
local UnitIsPlayer = UnitIsPlayer
local UnitClass = UnitClass
local UnitRace = UnitRace
local UnitLevel = UnitLevel
local UnitClassification = UnitClassification
local UnitCreatureType = UnitCreatureType
local UnitCreatureFamily = UnitCreatureFamily
local UnitExists = UnitExists
local UnitIsUnit = UnitIsUnit
local UnitGUID = UnitGUID
local UnitReaction = UnitReaction
local UnitCanAttack = UnitCanAttack
local UnitHealth = UnitHealth
local UnitIsDeadOrGhost = UnitIsDeadOrGhost
local UnitIsCorpse = UnitIsCorpse
local UnitIsConnected = UnitIsConnected
local UnitIsAFK = UnitIsAFK
local UnitIsDND = UnitIsDND
local UnitIsTapped = UnitIsTapped
local UnitIsTappedByPlayer = UnitIsTappedByPlayer
local GetRaidTargetIndex = GetRaidTargetIndex
local GetQuestDifficultyColor = GetQuestDifficultyColor
local GetGuildInfo = GetGuildInfo
local GetMouseFocus = GetMouseFocus
local GetCursorPosition = GetCursorPosition
local GetNumRaidMembers = GetNumRaidMembers
local GetNumPartyMembers = GetNumPartyMembers
local InCombatLockdown = InCombatLockdown
local IsShiftKeyDown = IsShiftKeyDown
local GetTime = GetTime
local tconcat, sort = table.concat, table.sort
local floor, ceil, max = math.floor, math.ceil, math.max

local Misc = ns:GetModule("Misc")
local Talents = ns:GetModule("Talents")
local Inspect = ns:GetModule("Inspect")
local UF = ns:GetModule("UnitFrames")
local Skin = ns.TooltipSkin
local config = ns.Config.tooltip
local classColors = UF.classColors
local ccSpellNames = UF.ccSpellNames

local TOOLTIPS = {
	ItemRefTooltip,
	GameTooltip,
	ShoppingTooltip1,
	ShoppingTooltip2,
	ShoppingTooltip3,
	ItemRefShoppingTooltip1,
	ItemRefShoppingTooltip2,
	ItemRefShoppingTooltip3,
}
local TITLE_ICON = "|T%s:20:20:0:0:64:64:5:59:5:59:20|t %s"
local RAID_ICON = "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_%d:14:14|t "
local LEVEL_LINE_PATTERN = "^" .. LEVEL .. " "
local GUILD_HEX = "|cff00ff10"
local OWN_GUILD_HEX = "|cffe066ff"
local GREY_HEX = "|cff999999"
local STATUS_HEX = "|cffff9900"
local DEAD_R, DEAD_G, DEAD_B = 0.5, 0.5, 0.5
local CLUTTER_LINES = { [PVP] = true, [PVP_ENABLED] = true, [FACTION_ALLIANCE] = true, [FACTION_HORDE] = true }
local CLASSIFICATIONS = {
	worldboss = "|cffff2020" .. BOSS .. "|r",
	rareelite = "|cffc0c0ff" .. ITEM_QUALITY3_DESC .. " " .. ELITE .. "|r",
	elite = "|cffffcc00" .. ELITE .. "|r",
	rare = "|cffc0c0ff" .. ITEM_QUALITY3_DESC .. "|r",
}
local TREE_NAMES = {
	DEATHKNIGHT = { "Blood", "Frost", "Unholy" },
	DRUID = { "Balance", "Feral Combat", "Restoration" },
	HUNTER = { "Beast Mastery", "Marksmanship", "Survival" },
	MAGE = { "Arcane", "Fire", "Frost" },
	PALADIN = { "Holy", "Protection", "Retribution" },
	PRIEST = { "Discipline", "Holy", "Shadow" },
	ROGUE = { "Assassination", "Combat", "Subtlety" },
	SHAMAN = { "Elemental", "Enhancement", "Restoration" },
	WARLOCK = { "Affliction", "Demonology", "Destruction" },
	WARRIOR = { "Arms", "Fury", "Protection" },
}

local CLASS_ICONS = {}
for class, coords in pairs(CLASS_ICON_TCOORDS) do
	CLASS_ICONS[class] = ("|T%s:14:14:0:0:256:256:%d:%d:%d:%d|t "):format(
		UF.CLASS_ICONS,
		coords[1] * 256,
		coords[2] * 256,
		coords[3] * 256,
		coords[4] * 256
	)
end

local PARTY, PARTY_TARGETS, RAID, RAID_TARGETS = {}, {}, {}, {}
for i = 1, MAX_PARTY_MEMBERS do
	PARTY[i] = "party" .. i
	PARTY_TARGETS[i] = PARTY[i] .. "target"
end
for i = 1, MAX_RAID_MEMBERS do
	RAID[i] = "raid" .. i
	RAID_TARGETS[i] = RAID[i] .. "target"
end

local labelHex

local function applyLabelColor()
	local color = config.labelColor
	labelHex = ("|cff%02x%02x%02x"):format(color[1] * 255, color[2] * 255, color[3] * 255)
end

applyLabelColor()
Misc:WatchConfig("tooltip.labelColor", applyLabelColor)

local function labeled(label, value)
	return ("%s%s|r: |cffffffff%d|r"):format(labelHex, label, value)
end

local function hex(r, g, b, text)
	return ("|cff%02x%02x%02x%s|r"):format(r * 255, g * 255, b * 255, text)
end

local function lineCache(side)
	return setmetatable({}, {
		__index = function(cache, tooltip)
			local lines = setmetatable({}, {
				__index = function(self, index)
					local line = _G[tooltip:GetName() .. side .. index]
					if line then
						self[index] = line
					end
					return line
				end,
			})
			cache[tooltip] = lines
			return lines
		end,
	})
end

local leftLines = lineCache("TextLeft")
local rightLines = lineCache("TextRight")

local function leftLine(tooltip, index)
	return leftLines[tooltip][index or 1]
end

local function setRightText(tooltip, index, text)
	local right = rightLines[tooltip][index]
	if right then
		right:SetText(text)
		right:SetTextColor(0.6, 0.6, 0.6)
		right:Show()
	end
end

local function findLine(tooltip, pattern)
	for i = 2, tooltip:NumLines() do
		local text = leftLine(tooltip, i):GetText()
		if text and text:find(pattern) then
			return i
		end
	end
end

local function onTooltipSetSpell(tooltip)
	local _, _, spellId = tooltip:GetSpell()
	if not spellId or not config.enabled then
		return
	end
	local spellName, _, texture = GetSpellInfo(spellId)
	if not spellName then
		return
	end

	local title = leftLine(tooltip)
	if title and not Skin.ShowIcon(tooltip, texture) then
		title:SetFormattedText(TITLE_ICON, texture, title:GetText())
	end

	if config.showIds then
		tooltip:AddLine(labeled(L["ID"], spellId))
	end
	tooltip:Show()
end

local itemDone = {}

local function onTooltipSetItem(tooltip)
	local itemName, link = tooltip:GetItem()
	if not link or not config.enabled or itemDone[tooltip] then
		return
	end
	local knownName, _, quality, itemLevel, _, _, _, _, equipLoc = GetItemInfo(link)
	if not knownName then
		return
	end
	itemDone[tooltip] = true

	local texture = GetItemIcon(link)
	local sideIcon = Skin.ShowIcon(tooltip, texture)
	for i = 1, 2 do
		local title = leftLine(tooltip, i)
		local text = title and title:GetText()
		if text and text:find(itemName, 1, true) then
			if not sideIcon then
				title:SetFormattedText(TITLE_ICON, texture, text)
			end
			if config.showItemLevel and equipLoc ~= "" and itemLevel then
				local color = quality and ITEM_QUALITY_COLORS[quality]
				setRightText(tooltip, i, L["ilvl %s%d|r"]:format(color and color.hex or "|cffffffff", itemLevel))
			end
			break
		end
	end

	if config.colorBorder and quality and quality >= 2 then
		local color = ITEM_QUALITY_COLORS[quality]
		Skin.SetBorder(tooltip, color.r, color.g, color.b)
		if sideIcon and tooltip == GameTooltip then
			Skin.SetIconBorder(color.r, color.g, color.b)
		end
	end

	if config.showItemCount and equipLoc == "" then
		local inBags = GetItemCount(link)
		local inBank = GetItemCount(link, true) - inBags
		if inBank > 0 then
			tooltip:AddLine(labeled(L["Bags"], inBags) .. "  " .. labeled(L["Bank"], inBank))
		elseif inBags > 0 then
			tooltip:AddLine(labeled(L["Bags"], inBags))
		end
	end

	if config.showIds then
		tooltip:AddLine(labeled(L["ID"], link:match("|Hitem:(%d+):")))
	end

	tooltip:Show()
end

local function onSetHyperlink(tooltip, link)
	if not config.enabled or not config.showIds or type(link) ~= "string" then
		return
	end
	local kind, id, level = link:match("(%a+):(%d+):?(%-?%d*)")
	if kind == "quest" then
		level = tonumber(level)
		if level and level > 0 then
			tooltip:AddLine(labeled(L["Level"], level))
		end
	elseif kind ~= "achievement" then
		return
	end
	tooltip:AddLine(labeled(L["ID"], id))
	tooltip:Show()
end

local hideAuras, stopWatching

local function onTooltipCleared(tooltip)
	itemDone[tooltip] = nil
	Skin.Clear(tooltip)
	if tooltip == GameTooltip then
		Skin.HideIcon()
		hideAuras()
		stopWatching()
	end
end

for _, tooltip in ipairs(TOOLTIPS) do
	tooltip:HookScript("OnTooltipSetSpell", onTooltipSetSpell)
	tooltip:HookScript("OnTooltipSetItem", onTooltipSetItem)
	tooltip:HookScript("OnTooltipCleared", onTooltipCleared)
end
hooksecurefunc(GameTooltip, "SetHyperlink", onSetHyperlink)
hooksecurefunc(ItemRefTooltip, "SetHyperlink", onSetHyperlink)

local function applyScale()
	local scale = config.enabled and config.scale or 1
	for _, tooltip in ipairs(TOOLTIPS) do
		tooltip:SetScale(scale)
	end
end

applyScale()
Misc:WatchConfig("tooltip.scale", applyScale)
Misc:WatchConfig("tooltip.enabled", applyScale)

local anchor = CreateFrame("Frame", nil, UIParent)
anchor:SetSize(220, 120)
Misc:AnchorToConfig(anchor, "tooltip.point", "Tooltip")

local function screenHalves(frame)
	local x, y = frame:GetCenter()
	if not x then
		return false, false
	end
	local scale = frame:GetEffectiveScale() / UIParent:GetEffectiveScale()
	return y * scale > UIParent:GetHeight() / 2, x * scale < UIParent:GetWidth() / 2
end

local follower = CreateFrame("Frame")
follower:Hide()

local function moveToCursor(tooltip)
	local x, y = GetCursorPosition()
	local scale = tooltip:GetEffectiveScale()
	tooltip:SetPoint(
		"BOTTOMLEFT",
		UIParent,
		"BOTTOMLEFT",
		x / scale + config.cursorOffsetX,
		y / scale + config.cursorOffsetY
	)
end

follower:SetScript("OnUpdate", function(self)
	local tooltip = self.tooltip
	if not tooltip:IsShown() or tooltip:GetOwner() ~= self.owner then
		self:Hide()
		return
	end
	moveToCursor(tooltip)
end)

local function followCursor(tooltip, parent)
	tooltip:SetOwner(parent, "ANCHOR_NONE")
	tooltip:ClearAllPoints()
	moveToCursor(tooltip)
	follower.tooltip, follower.owner = tooltip, parent
	follower:Show()
end

local function anchorToOwner(tooltip, parent)
	local top, left = screenHalves(parent)
	local side = left and "LEFT" or "RIGHT"
	tooltip:SetOwner(parent, "ANCHOR_NONE")
	tooltip:ClearAllPoints()
	if top then
		tooltip:SetPoint("TOP" .. side, parent, "BOTTOM" .. side, 0, -4)
	else
		tooltip:SetPoint("BOTTOM" .. side, parent, "TOP" .. side, 0, 4)
	end
end

hooksecurefunc("GameTooltip_SetDefaultAnchor", function(tooltip, parent)
	if follower.tooltip == tooltip then
		follower:Hide()
	end
	if not config.enabled then
		return
	end
	if parent ~= UIParent and config.frameAnchor == "owner" then
		anchorToOwner(tooltip, parent)
	elseif config.anchorCursor then
		if config.cursorOffsetX == 0 and config.cursorOffsetY == 0 then
			tooltip:SetOwner(parent, "ANCHOR_CURSOR")
		else
			followCursor(tooltip, parent)
		end
	else
		local top, left = screenHalves(anchor)
		local corner = (top and "TOP" or "BOTTOM") .. (left and "LEFT" or "RIGHT")
		tooltip:SetOwner(parent, "ANCHOR_NONE")
		tooltip:ClearAllPoints()
		tooltip:SetPoint(corner, anchor, corner)
	end
end)

local function isDead(unit)
	return UnitHealth(unit) <= 0 and (UnitIsDeadOrGhost(unit) or UnitIsCorpse(unit))
end

local function unitColor(unit)
	local isPlayer = UnitIsPlayer(unit)
	if
		isDead(unit)
		or (isPlayer and not UnitIsConnected(unit))
		or (UnitIsTapped(unit) and not UnitIsTappedByPlayer(unit))
	then
		return DEAD_R, DEAD_G, DEAD_B
	end
	if isPlayer then
		local _, class = UnitClass(unit)
		local color = classColors[class] or UF.textColor
		return color[1], color[2], color[3]
	end
	local color = FACTION_BAR_COLORS[UnitReaction(unit, "player") or 4]
	return color.r, color.g, color.b
end

local function reactionTint(unit)
	if isDead(unit) or not UnitIsConnected(unit) then
		return DEAD_R, DEAD_G, DEAD_B
	elseif UnitCanAttack("player", unit) then
		return 1, 0.1, 0.1
	end
	return 0.2, 0.4, 1
end

local function colorize(unit, text)
	local r, g, b = unitColor(unit)
	return hex(r, g, b, text)
end

local function classHex(class, text)
	local color = classColors[class]
	return color and hex(color[1], color[2], color[3], text) or text
end

local nameParts = {}

local function styleName(tooltip, unit, isPlayer)
	local title = leftLine(tooltip)
	if not title then
		return
	end
	local name
	if isPlayer then
		local realm
		name, realm = UnitName(unit)
		if config.showTitle then
			name = UnitPVPName(unit) or name
		end
		if realm and realm ~= "" then
			name = IsShiftKeyDown() and name .. "-" .. realm or name .. FOREIGN_SERVER_LABEL
		end
	else
		name = title:GetText() or UnitName(unit)
	end

	wipe(nameParts)
	local raidIcon = config.showRaidIcon and GetRaidTargetIndex(unit)
	if raidIcon then
		nameParts[#nameParts + 1] = RAID_ICON:format(raidIcon)
	end
	if isPlayer and config.showClassIcon then
		local _, class = UnitClass(unit)
		nameParts[#nameParts + 1] = CLASS_ICONS[class]
	end
	nameParts[#nameParts + 1] = colorize(unit, name)
	if isPlayer then
		if not UnitIsConnected(unit) then
			nameParts[#nameParts + 1] = " " .. GREY_HEX .. "<" .. PLAYER_OFFLINE .. ">|r"
		elseif isDead(unit) then
			nameParts[#nameParts + 1] = " " .. GREY_HEX .. "<" .. DEAD .. ">|r"
		elseif config.showStatus and UnitIsAFK(unit) then
			nameParts[#nameParts + 1] = " " .. STATUS_HEX .. CHAT_FLAG_AFK .. "|r"
		elseif config.showStatus and UnitIsDND(unit) then
			nameParts[#nameParts + 1] = " " .. STATUS_HEX .. CHAT_FLAG_DND .. "|r"
		end
	end
	title:SetText(tconcat(nameParts))
end

local function styleGuild(tooltip, unit)
	local guild, rank = GetGuildInfo(unit)
	local line = guild and leftLine(tooltip, 2)
	local text = line and line:GetText()
	if not (text and text:find(guild, 1, true)) then
		return
	end
	local color = guild == GetGuildInfo("player") and OWN_GUILD_HEX or GUILD_HEX
	if config.showGuildRank and rank then
		line:SetFormattedText("<%s%s|r> %s%s|r", color, guild, GREY_HEX, rank)
	else
		line:SetFormattedText("<%s%s|r>", color, guild)
	end
end

local function levelText(unit)
	local level = UnitLevel(unit)
	if level <= 0 then
		return "|cffff2020??|r"
	end
	local color = GetQuestDifficultyColor(level)
	return hex(color.r, color.g, color.b, level)
end

local levelParts = {}
local numLevelParts = 0

local function addLevelPart(part)
	if part and part ~= "" then
		numLevelParts = numLevelParts + 1
		levelParts[numLevelParts] = part
	end
end

local function styleLevel(tooltip, unit, isPlayer)
	local index = findLine(tooltip, LEVEL_LINE_PATTERN)
	if not index then
		return
	end
	numLevelParts = 0
	addLevelPart(LEVEL)
	addLevelPart(levelText(unit))
	if isPlayer then
		local className, class = UnitClass(unit)
		addLevelPart(UnitRace(unit))
		addLevelPart(classHex(class, className))
	else
		addLevelPart(CLASSIFICATIONS[UnitClassification(unit)])
		addLevelPart(UnitCreatureFamily(unit) or UnitCreatureType(unit))
		if isDead(unit) then
			addLevelPart(GREY_HEX .. "(" .. CORPSE .. ")|r")
		end
	end
	local line = leftLine(tooltip, index)
	line:SetText(tconcat(levelParts, " ", 1, numLevelParts))
	line:SetTextColor(1, 1, 1)
end

local function hideClutter(tooltip)
	for i = 2, tooltip:NumLines() do
		local line = leftLine(tooltip, i)
		local text = line:GetText()
		if text and CLUTTER_LINES[text] then
			line:SetText(nil)
		end
	end
end

local function addSpec(tooltip, unit, guid)
	local spec = Talents:GetSpec(guid)
	local _, class = UnitClass(unit)
	local trees = TREE_NAMES[class]
	local tree = spec and trees and trees[spec]
	if not tree then
		return
	end
	local text = classHex(class, L[tree])
	local points = Talents:GetPoints(guid)
	if points then
		text = text .. " " .. GREY_HEX .. points .. "|r"
	end
	tooltip:AddDoubleLine(L["Spec"], text)
end

local function groupUnits()
	local numRaid = GetNumRaidMembers()
	if numRaid > 0 then
		return RAID, RAID_TARGETS, numRaid
	end
	return PARTY, PARTY_TARGETS, GetNumPartyMembers()
end

local function targeting(unit)
	local members, targets, count = groupUnits()
	local found, sum = 0, 0
	for i = 1, count do
		if not UnitIsUnit(members[i], "player") and UnitIsUnit(targets[i], unit) then
			found, sum = found + 1, sum + i
		end
	end
	return found, sum
end

local targetedBy = {}

local function addTargetedBy(tooltip, unit)
	local members, targets, count = groupUnits()
	wipe(targetedBy)
	for i = 1, count do
		local member = members[i]
		if not UnitIsUnit(member, "player") and UnitIsUnit(targets[i], unit) then
			targetedBy[#targetedBy + 1] = colorize(member, UnitName(member))
		end
	end
	local numTargeting = #targetedBy
	if numTargeting > 0 then
		tooltip:AddLine(L["Targeted by (%d): %s"]:format(numTargeting, tconcat(targetedBy, ", ")), 1, 1, 1, true)
	end
end

local ILVL_CACHE_TIME = 120

local itemLevels = {}

local function addItemLevel(tooltip, average)
	local _, _, _, color = ns.AverageItemLevelColor(average)
	local text = L["ilvl %s%.1f|r"]:format(color, average)
	local line = findLine(tooltip, LEVEL_LINE_PATTERN)
	if line then
		setRightText(tooltip, line, text)
	else
		tooltip:AddLine(text, 0.6, 0.6, 0.6)
	end
end

local function refreshUnit(guid)
	if not GameTooltip:IsShown() then
		return
	end
	local _, unit = GameTooltip:GetUnit()
	if unit and UnitGUID(unit) == guid then
		GameTooltip:SetUnit(unit)
	end
end

Misc:RegisterEvent(ns.INSPECT_GEAR_READY, function(_, guid, unit)
	if not (config.enabled and config.showItemLevel) then
		return
	end
	local average, count = ns.UnitAverageItemLevel(unit)
	if count == 0 then
		return
	end
	local cached = itemLevels[guid]
	if cached then
		cached.level, cached.time = average, GetTime()
	else
		itemLevels[guid] = { level = average, time = GetTime() }
	end
	refreshUnit(guid)
end)

Misc:RegisterEvent(ns.TALENTS_UPDATED, function(_, guid)
	if config.enabled and config.showSpec then
		refreshUnit(guid)
	end
end)

local function unitItemLevel(tooltip, unit, guid)
	if UnitIsUnit(unit, "player") then
		local average, count = ns.UnitAverageItemLevel("player")
		if count > 0 then
			addItemLevel(tooltip, average)
		end
		return
	end

	local cached = itemLevels[guid]
	if cached then
		addItemLevel(tooltip, cached.level)
	end
	if not cached or GetTime() - cached.time > ILVL_CACHE_TIME then
		Inspect:Request(unit, ILVL_CACHE_TIME, true)
	end
end

local TEAMS_CACHE_TIME = 600

local arenaTeams = {}

local function sortBySize(a, b)
	return a.size < b.size
end

Misc:RegisterEvent(ns.INSPECT_TEAMS_READY, function(_, guid, teams)
	sort(teams, sortBySize)
	arenaTeams[guid] = { teams = teams, time = GetTime() }
	if config.enabled and config.showArenaTeams then
		refreshUnit(guid)
	end
end)

local function applyArenaTeams()
	if config.enabled and config.showArenaTeams then
		Inspect:WantTeams()
	end
end

applyArenaTeams()
Misc:WatchConfig("tooltip.showArenaTeams", applyArenaTeams)
Misc:WatchConfig("tooltip.enabled", applyArenaTeams)

local teamParts = {}

local function addArenaTeams(tooltip, unit, guid)
	local cached = arenaTeams[guid]
	if not cached or GetTime() - cached.time > TEAMS_CACHE_TIME then
		arenaTeams[guid] = { teams = cached and cached.teams, time = GetTime() }
		Inspect:Request(unit, nil, true)
	end
	local teams = cached and cached.teams
	if not teams or #teams == 0 then
		return
	end
	wipe(teamParts)
	for i = 1, #teams do
		local team = teams[i]
		local text = GREY_HEX .. team.size .. "v" .. team.size .. "|r " .. team.rating
		if team.personal ~= team.rating then
			text = text .. " " .. GREY_HEX .. "(" .. team.personal .. ")|r"
		end
		teamParts[i] = text
	end
	tooltip:AddDoubleLine(L["Arena"], tconcat(teamParts, "  "), nil, nil, nil, 1, 1, 1)
end

local AURA_SPACING = 2
local AURA_BAR_GAP = 12
local MAX_AURAS = 40

local auraAnchor = CreateFrame("Frame", nil, GameTooltip)
auraAnchor:SetHeight(1)
local auraIcons = {}
local shownAuras = 0

local function auraIcon(index)
	local icon = auraIcons[index]
	if icon then
		return icon
	end
	icon = CreateFrame("Frame", nil, auraAnchor)
	icon.texture = icon:CreateTexture(nil, "BORDER")
	icon.texture:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	UF.SkinIcon(icon, icon.texture)
	icon.cooldown = CreateFrame("Cooldown", nil, icon, "CooldownFrameTemplate")
	icon.cooldown:SetAllPoints()
	icon.cooldown:SetReverse(true)
	local overlay = CreateFrame("Frame", nil, icon)
	overlay:SetAllPoints()
	overlay:SetFrameLevel(icon.cooldown:GetFrameLevel() + 1)
	icon.count = overlay:CreateFontString(nil, "OVERLAY")
	ns.SetFont(icon.count, 10, "OUTLINE")
	icon.count:SetPoint("BOTTOMRIGHT", 1, 0)
	auraIcons[index] = icon
	return icon
end

function hideAuras()
	for i = 1, shownAuras do
		auraIcons[i]:Hide()
	end
	shownAuras = 0
end

local function showAura(icon, texture, count, duration, expires, isDebuff, r, g, b)
	icon.texture:SetTexture(texture)
	icon.count:SetText(count and count > 1 and count or nil)
	Skin.StyleAuraBorder(icon.border, isDebuff, r, g, b)
	if duration and duration > 0 then
		local start = expires - duration
		if icon.start ~= start or icon.duration ~= duration then
			icon.start, icon.duration = start, duration
			icon.cooldown:SetCooldown(start, duration)
		end
	else
		icon.start = nil
		icon.cooldown:Hide()
	end
	icon:Show()
end

local function placeAura(icon, size, step, right, row, col, up)
	if icon.size ~= size then
		icon.size = size
		icon:SetSize(size, size)
	end
	local point = (up and "BOTTOM" or "TOP") .. (right and "RIGHT" or "LEFT")
	icon:ClearAllPoints()
	icon:SetPoint(point, auraAnchor, point, right and -col * step or col * step, up and row * step or -row * step)
end

local function layoutAuras(unit, filter, perRow, maxRows, firstRow, size, step, up)
	local onlyCC = config.auras == "important"
	local isDebuff = filter == "HARMFUL"
	local placed = 0
	for i = 1, MAX_AURAS do
		local name, _, texture, count, debuffType, duration, expires = UnitAura(unit, i, filter)
		if not name then
			break
		end
		if not onlyCC or ccSpellNames[name] then
			local row = floor(placed / perRow)
			if row >= maxRows then
				break
			end
			shownAuras = shownAuras + 1
			local icon = auraIcon(shownAuras)
			local r, g, b = 1, 1, 1
			if isDebuff then
				local color = DebuffTypeColor[debuffType or "none"] or DebuffTypeColor.none
				r, g, b = color.r, color.g, color.b
			end
			showAura(icon, texture, count, duration, expires, isDebuff, r, g, b)
			placeAura(icon, size, step, isDebuff, firstRow + row, placed % perRow, up)
			placed = placed + 1
		end
	end
	return placed > 0 and ceil(placed / perRow) or 0
end

local function showAuras(tooltip, unit)
	hideAuras()
	if config.auras == "none" then
		return
	end
	local size = config.auraSize
	local step = size + AURA_SPACING
	local perRow = max(1, floor((tooltip:GetWidth() + AURA_SPACING) / step))
	local rows = config.auraRows

	local tooltipScale = tooltip:GetEffectiveScale()
	local screenTop = UIParent:GetTop() * UIParent:GetEffectiveScale() / tooltipScale
	local up = (tooltip:GetTop() or 0) + rows * 2 * step + AURA_SPACING <= screenTop

	auraAnchor:ClearAllPoints()
	if up then
		auraAnchor:SetPoint("BOTTOMLEFT", tooltip, "TOPLEFT", 0, AURA_SPACING)
		auraAnchor:SetPoint("BOTTOMRIGHT", tooltip, "TOPRIGHT", 0, AURA_SPACING)
	else
		auraAnchor:SetPoint("TOPLEFT", tooltip, "BOTTOMLEFT", 0, -AURA_BAR_GAP)
		auraAnchor:SetPoint("TOPRIGHT", tooltip, "BOTTOMRIGHT", 0, -AURA_BAR_GAP)
	end

	local debuffRows = layoutAuras(unit, "HARMFUL", perRow, rows, 0, size, step, up)
	layoutAuras(unit, "HELPFUL", perRow, rows, debuffRows, size, step, up)
end

local REFRESH_INTERVAL = 0.25

local watcher = CreateFrame("Frame")
watcher:Hide()

function stopWatching()
	watcher:Hide()
end

watcher:SetScript("OnUpdate", function(self, elapsed)
	local unit = self.unit
	if unit == "mouseover" and config.anchorCursor and not UnitExists("mouseover") then
		GameTooltip:Hide()
		return
	end
	self.elapsed = self.elapsed + elapsed
	if self.elapsed < REFRESH_INTERVAL then
		return
	end
	self.elapsed = 0
	if not self.live or UnitGUID(unit) ~= self.guid then
		return
	end
	local count, sum = 0, 0
	if config.showTargetedBy then
		count, sum = targeting(unit)
	end
	if UnitGUID(self.targetUnit) ~= self.target or count ~= self.count or sum ~= self.sum then
		GameTooltip:SetUnit(unit)
	end
end)

local function watch(tooltip, unit, guid)
	if tooltip ~= GameTooltip then
		return
	end
	local owner = tooltip:GetOwner()
	watcher.unit, watcher.guid = unit, guid
	watcher.targetUnit = unit .. "target"
	watcher.target = UnitGUID(watcher.targetUnit)
	watcher.count, watcher.sum = 0, 0
	if config.showTargetedBy then
		watcher.count, watcher.sum = targeting(unit)
	end
	watcher.live = (config.showTarget or config.showTargetedBy) and not (owner and owner.UpdateTooltip)
	watcher.elapsed = 0
	watcher:Show()
end

local suppressedOwner, suppressedUnit

local function hiddenByCombat(tooltip)
	if not InCombatLockdown() or IsShiftKeyDown() then
		return false
	end
	if tooltip:GetOwner() == UIParent then
		return config.hideInCombatWorld
	end
	return config.hideInCombat
end

local function tooltipUnit(tooltip)
	local name, unit = tooltip:GetUnit()
	if unit then
		return unit
	end
	local focus = GetMouseFocus()
	unit = focus and focus.GetAttribute and focus:GetAttribute("unit")
	if unit then
		return unit
	end
	if name and UnitName("mouseover") == name then
		return "mouseover"
	end
end

local function onTooltipSetUnit(tooltip)
	local unit = tooltipUnit(tooltip)
	if not (unit and UnitExists(unit) and config.enabled) then
		return
	end

	if hiddenByCombat(tooltip) then
		suppressedOwner, suppressedUnit = tooltip:GetOwner(), unit
		tooltip:Hide()
		return
	end
	suppressedOwner, suppressedUnit = nil, nil

	local guid = UnitGUID(unit)
	local isPlayer = UnitIsPlayer(unit)
	styleName(tooltip, unit, isPlayer)
	styleLevel(tooltip, unit, isPlayer)
	if config.hidePvPLines then
		hideClutter(tooltip)
	end

	if isPlayer then
		styleGuild(tooltip, unit)
		if config.showItemLevel then
			unitItemLevel(tooltip, unit, guid)
		end
		if config.showSpec then
			addSpec(tooltip, unit, guid)
		end
		if config.showArenaTeams and not UnitIsUnit(unit, "player") and not UnitCanAttack("player", unit) then
			addArenaTeams(tooltip, unit, guid)
		end
		local Version = ns.Version
		local userVersion, userBuild = Version.GetUser(UnitName(unit))
		if userVersion then
			tooltip:AddDoubleLine(
				"|cff177cbfFrostAtom UI|r",
				Version.Label(userVersion, userBuild),
				nil,
				nil,
				nil,
				1,
				1,
				1
			)
		else
			Version.Probe(unit)
		end
	end

	local target = unit .. "target"
	if config.showTarget and unit ~= "player" and UnitExists(target) then
		local name = UnitIsUnit(target, "player") and L["|cffff0000<YOU>|r"] or colorize(target, UnitName(target))
		tooltip:AddDoubleLine(L["Target"], name)
	end

	if config.showTargetedBy then
		addTargetedBy(tooltip, unit)
	end

	if not isPlayer and config.showIds then
		local npcId = guid and tonumber(guid:sub(7, 12), 16)
		if npcId and npcId > 0 then
			tooltip:AddLine(labeled(L["NPC ID"], npcId))
		end
	end

	if config.colorBorder then
		Skin.SetBorder(tooltip, unitColor(unit))
	end
	if config.reactionBackground and isPlayer then
		Skin.SetTint(tooltip, reactionTint(unit))
	end
	Skin.PrepareUnit(tooltip)

	tooltip:Show()
	if tooltip == GameTooltip then
		showAuras(tooltip, unit)
	end
	watch(tooltip, unit, guid)
end

GameTooltip:HookScript("OnTooltipSetUnit", onTooltipSetUnit)
GameTooltip:HookScript("OnHide", function()
	Skin.HideIcon()
	hideAuras()
	stopWatching()
end)

Misc:RegisterEvent("MODIFIER_STATE_CHANGED", function(_, key, down)
	if (key ~= "LSHIFT" and key ~= "RSHIFT") or not config.enabled then
		return
	end
	if GameTooltip:IsShown() then
		local _, unit = GameTooltip:GetUnit()
		if unit and UnitExists(unit) then
			GameTooltip:SetUnit(unit)
		end
		return
	end
	local owner, unit = suppressedOwner, suppressedUnit
	if down ~= 1 or not owner or not UnitExists(unit) then
		return
	end
	local hovered = owner == UIParent and unit == "mouseover" or GetMouseFocus() == owner
	if hovered then
		GameTooltip_SetDefaultAnchor(GameTooltip, owner)
		GameTooltip:SetUnit(unit)
	end
end)

local healthBar = GameTooltipStatusBar
local blizzardHealthUpdate = healthBar:GetScript("OnValueChanged")
local healthText = healthBar:CreateFontString(nil, "OVERLAY", "SystemFont_Outline_Small")
healthText:SetPoint("CENTER")

healthBar:SetScript("OnValueChanged", function(bar, value)
	local _, unit = GameTooltip:GetUnit()
	if config.enabled and config.classColorHealth and unit and UnitExists(unit) then
		bar:SetStatusBarColor(unitColor(unit))
	elseif blizzardHealthUpdate then
		blizzardHealthUpdate(bar, value)
	end

	local _, maxValue = bar:GetMinMaxValues()
	if
		not value
		or maxValue == 0
		or not config.enabled
		or not config.showHealthText
		or Skin.HealthBarMode() == "thin"
	then
		healthText:SetText("")
	elseif value == 0 and unit and UnitIsDeadOrGhost(unit) then
		healthText:SetText(DEAD)
	elseif maxValue == 1 then
		healthText:SetFormattedText("%d%%", value * 100)
	else
		healthText:SetFormattedText("%s / %s", ns.FormatValue(value), ns.FormatValue(maxValue))
	end
end)

local function onSetUnitAura(tooltip, unit, index, filter)
	local _, _, _, _, _, _, _, caster, _, _, spellId = UnitAura(unit, index, filter)
	if not spellId or not config.enabled then
		return
	end
	local showCaster = caster and config.showAuraCaster
	if not config.showIds and not showCaster then
		return
	end

	local idText = config.showIds and labeled(L["ID"], spellId) or labelHex .. L["Cast by"] .. "|r"
	if showCaster then
		local r, g, b = 1, 0.9, 0.8
		if UnitIsPlayer(caster) then
			local _, class = UnitClass(caster)
			local color = classColors[class]
			if color then
				r, g, b = color[1], color[2], color[3]
			end
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
