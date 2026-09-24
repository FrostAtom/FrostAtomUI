local _, ns = ...
local UF = ns:GetModule("UnitFrames")
local L = ns.L

local UnitExists = UnitExists
local UnitGUID = UnitGUID
local UnitName = UnitName
local UnitClass = UnitClass
local UnitIsDeadOrGhost = UnitIsDeadOrGhost
local UnitHealth, UnitHealthMax = UnitHealth, UnitHealthMax
local UnitBuff = UnitBuff
local IsInInstance = IsInInstance
local InCombatLockdown = InCombatLockdown
local GetBattlefieldStatus = GetBattlefieldStatus
local GetNumArenaOpponents = GetNumArenaOpponents
local GetNumPartyMembers = GetNumPartyMembers
local UNKNOWNOBJECT = UNKNOWNOBJECT
local MAX_BATTLEFIELD_QUEUES = MAX_BATTLEFIELD_QUEUES or 2
local min, floor = math.min, math.floor

local Talents = ns:GetModule("Talents")

local STEALTH_ICON = "Interface\\Icons\\Ability_Stealth"
local UNKNOWN_ICON = "Interface\\Icons\\INV_Misc_QuestionMark"
local ARENA_PREPARATION = GetSpellInfo(32727) -- Arena Preparation
local MAX_OPPONENTS = 3
local GREY = 0.5
local TEST_UNIT = "arena3"
local TEST_INFO_KEYS = { "name", "class", "spec", "health", "healthMax", "power", "powerMax", "dead" }

local BORDER_INSET = UF.BORDER_INSET
local CLASS_ICON_INSET = UF.CLASS_ICON_INSET
local ICON_TRIM = UF.ICON_TRIM
local SetContentInset = UF.FrameMixin.SetContentInset
local setBarColor = UF.SetBarColor

local ghosts = {}
local ghostByUnit = {}
local inArena, preparing = false, false
local expected = 0

local watcher = ns.Mixin({}, ns.EventMixin)

local function setGrey(bar)
	setBarColor(bar, GREY, GREY, GREY)
end

local function createBar(ghost)
	local bar = CreateFrame("StatusBar", nil, ghost)
	ns.SkinStatusBar(bar)
	bar.bg = bar:CreateTexture(nil, "BORDER")
	bar.bg:SetAllPoints()
	bar.bg:SetTexture(ns.Media.blank)
	bar.text = bar:CreateFontString(nil, "OVERLAY")
	return bar
end

local function setTrimmedTexture(texture, path)
	texture:SetTexture(path)
	texture:SetTexCoord(ICON_TRIM, 1 - ICON_TRIM, ICON_TRIM, 1 - ICON_TRIM)
end

local function createIcon(parent, texture)
	local icon = CreateFrame("Frame", nil, parent)
	icon.texture = icon:CreateTexture(nil, "BORDER")
	UF.SkinIcon(icon, icon.texture)
	if texture then
		setTrimmedTexture(icon.texture, texture)
	end
	return icon
end

local function layout(ghost)
	local config = ns.Config.unitFrames
	local height = ghost.frame:GetHeight()
	ghost.innerHeight = height - BORDER_INSET * 2

	local size = height - CLASS_ICON_INSET * 2
	local side = ghost.iconSide or "RIGHT"
	local icon = ghost.classicon
	icon:SetSize(size, size)
	icon:ClearAllPoints()
	icon:SetPoint("TOP" .. side, side == "LEFT" and CLASS_ICON_INSET or -CLASS_ICON_INSET, -CLASS_ICON_INSET)
	ns.SetShown(icon, config.showClassIcon)
	SetContentInset(ghost, config.showClassIcon and UF.ClassIconInset(size) or 0)

	ghost.stealth:SetSize(height, height)
	UF.SetBackdropColors(ghost)

	local font = config.textFont
	local texts = ghost.texts
	for i = 1, #texts do
		local text = texts[i]
		ns.SetFont(text, font.size, font.outline)
		text:SetTextColor(unpack(config.textColor))
	end
end

local function setClassIcon(ghost, class, spec)
	local texture = ghost.classicon.texture
	if not UF.SetClassTexture(texture, class, ns.Config.unitFrames.classIconStyle ~= "class" and spec) then
		setTrimmedTexture(texture, UNKNOWN_ICON)
	end
end

local function setBarValue(bar, current, max)
	bar:SetMinMaxValues(0, max)
	bar:SetValue(current)
end

local function renderPrep(ghost, info)
	local health, power = ghost.health, ghost.power
	ghost:SetAlpha(1)
	setBarValue(health, 1, 1)
	local color = info.class and UF.classBarColors[info.class]
	if color then
		setBarColor(health, color[1], color[2], color[3])
	else
		setGrey(health)
	end
	health.text:SetText(nil)
	setBarValue(power, 1, 1)
	setGrey(power)
	ghost.stealth:Hide()
end

local function renderUnseen(ghost, info)
	local health, power = ghost.health, ghost.power
	ghost:SetAlpha(ns.Config.arenaUnseen.alpha)

	local healthMax = info.healthMax or 0
	if info.dead then
		setBarValue(health, 0, 1)
		health.text:SetText(L["RIP"])
	elseif healthMax > 0 then
		local current = min(info.health or healthMax, healthMax)
		setBarValue(health, current, healthMax)
		health.text:SetFormattedText("%d%%", floor(current / healthMax * 100 + 0.5))
	else
		setBarValue(health, 1, 1)
		health.text:SetText(nil)
	end
	setGrey(health)

	local powerMax = info.powerMax or 0
	if powerMax > 0 and not info.dead then
		setBarValue(power, min(info.power or 0, powerMax), powerMax)
	else
		setBarValue(power, 0, 1)
	end
	setGrey(power)
	ghost.stealth:Show()
end

local function render(ghost)
	local state = ghost.state
	if not state then
		ghost:Hide()
		ghost.stealth:Hide()
		return
	end

	local info = ghost.info
	layout(ghost)
	setClassIcon(ghost, info.class, info.spec or (info.guid and Talents:GetSpec(info.guid)))
	ghost.name:SetText(info.name)
	if state == "prep" then
		renderPrep(ghost, info)
	else
		renderUnseen(ghost, info)
	end
	ghost:Show()
end

local function evaluate(ghost)
	if UF.testing then
		return
	end
	local config = ns.Config.arenaUnseen
	local state
	if inArena and ns.Config.unitFrames.showArena and not ghost.frame:IsShown() then
		if preparing then
			if config.prep and ghost.index <= expected then
				state = "prep"
			end
		elseif config.enabled and ghost.info.known then
			state = "unseen"
		end
	end
	ghost.state = state
	render(ghost)
end

local function expectedOpponents()
	local count = GetNumArenaOpponents() or 0
	for i = 1, MAX_BATTLEFIELD_QUEUES do
		local status, _, _, _, _, teamSize = GetBattlefieldStatus(i)
		if status == "active" and teamSize and teamSize > count then
			count = teamSize
		end
	end
	if count == 0 then
		count = GetNumPartyMembers() + 1
	end
	return min(count, MAX_OPPONENTS)
end

local function hasArenaPreparation()
	return ARENA_PREPARATION and UnitBuff("player", ARENA_PREPARATION) and true or false
end

local function refreshAll()
	preparing = inArena and hasArenaPreparation()
	expected = preparing and expectedOpponents() or 0
	for i = 1, #ghosts do
		evaluate(ghosts[i])
	end
end

local function fillInfo(ghost)
	local unit, info = ghost.unit, ghost.info
	local name = UnitName(unit)
	if name and name ~= UNKNOWNOBJECT then
		info.name = name
	end
	local _, class = UnitClass(unit)
	if class then
		info.class = class
	end
	info.guid = UnitGUID(unit) or info.guid
end

local function snapshot(ghost)
	local frame, info = ghost.frame, ghost.info
	local health, power = frame.health, frame.power
	local _, healthMax = health:GetMinMaxValues()
	info.dead = health.text:GetText() == L["RIP"] or UnitIsDeadOrGhost(ghost.unit) and true or false
	if health.lastCurrent then
		info.health = health.lastCurrent
		info.healthMax = healthMax
	end
	local _, powerMax = power:GetMinMaxValues()
	info.power = power.lastValue or power:GetValue()
	info.powerMax = powerMax
end

local function onRealHide(frame)
	local ghost = frame.unseen
	if UF.testing or not ghost then
		return
	end
	if inArena and ghost.info.known then
		snapshot(ghost)
	end
	evaluate(ghost)
end

local function update(frame)
	local ghost = frame.unseen
	if inArena and UnitExists(ghost.unit) then
		ghost.info.known = true
		ghost.info.dead = nil
		fillInfo(ghost)
	end
	if ghost.state then
		ghost.state = nil
		render(ghost)
	end
end

local function test(frame)
	local ghost = frame.unseen
	if frame.unit ~= TEST_UNIT or not ns.Config.arenaUnseen.enabled then
		if ghost.state and frame.unit == TEST_UNIT and not InCombatLockdown() then
			frame:Show()
		end
		ghost.state = nil
		render(ghost)
		return
	end

	local data, info = frame.test, ghost.info
	wipe(info)
	for i = 1, #TEST_INFO_KEYS do
		local key = TEST_INFO_KEYS[i]
		info[key] = data[key]
	end
	ghost.tested = true
	if not InCombatLockdown() then
		frame:Hide()
	end
	ghost.state = "unseen"
	render(ghost)
end

local function create(frame)
	local ghost = CreateFrame("Frame", nil, UIParent)
	ghost:SetFrameStrata(frame:GetFrameStrata())
	ghost:SetFrameLevel(frame:GetFrameLevel())
	ghost:SetAllPoints(frame)
	ghost:SetBackdrop(UF.backdrop)
	ghost:Hide()
	ghost.frame = frame
	ghost.unit = frame.unit
	ghost.index = tonumber(frame.unit:match("%d+$"))
	ghost.iconSide = frame.iconSide
	ghost.info = {}

	local health = createBar(ghost)
	health.text:SetPoint("BOTTOMRIGHT")
	ghost.health = health

	local power = createBar(ghost)
	power:SetPoint("TOPRIGHT", health, "BOTTOMRIGHT")
	power.text:SetPoint("RIGHT")
	ghost.power = power

	ghost.classicon = createIcon(ghost)

	local name = ghost:CreateFontString(nil, "OVERLAY")
	name:SetJustifyH("RIGHT")
	name:SetPoint("BOTTOMLEFT", health)
	ghost.name = name
	ghost.texts = { health.text, power.text, name }

	local stealth = createIcon(UIParent, STEALTH_ICON)
	stealth:SetFrameStrata(frame:GetFrameStrata())
	stealth:SetFrameLevel(frame:GetFrameLevel() + 3)
	stealth:SetPoint("RIGHT", ghost, "LEFT", -BORDER_INSET, 0)
	stealth:Hide()
	ghost.stealth = stealth

	frame:HookScript("OnHide", onRealHide)

	ghosts[#ghosts + 1] = ghost
	ghostByUnit[ghost.unit] = ghost
	return ghost
end

UF:RegisterElement("unseen", create, update, test)

local function onEnteringWorld()
	inArena = select(2, IsInInstance()) == "arena"
	for i = 1, #ghosts do
		local ghost = ghosts[i]
		wipe(ghost.info)
		if inArena and UnitGUID(ghost.unit) then
			ghost.info.known = true
			fillInfo(ghost)
		end
	end
	refreshAll()
end

local function onAura(_, unit)
	if not inArena or unit ~= "player" then
		return
	end
	local wasPreparing = preparing
	preparing = hasArenaPreparation()
	if preparing ~= wasPreparing then
		refreshAll()
	end
end

local function onPrepChanged()
	if preparing then
		refreshAll()
	end
end

local function onOpponentUpdate(_, unit, reason)
	local ghost = ghostByUnit[unit]
	if not ghost or not inArena then
		return
	end
	local info = ghost.info
	if reason == "seen" or reason == "unseen" then
		info.known = true
		fillInfo(ghost)
	elseif reason == "cleared" or (reason == "destroyed" and not UnitGUID(unit)) then
		wipe(info)
	end
	evaluate(ghost)
end

local function onNameUpdate(_, unit)
	local ghost = ghostByUnit[unit]
	if ghost and inArena and ghost.info.known then
		fillInfo(ghost)
		render(ghost)
	end
end

local function onHealth(_, unit)
	local ghost = ghostByUnit[unit]
	if not ghost or ghost.state ~= "unseen" then
		return
	end
	local healthMax = UnitHealthMax(unit)
	if healthMax and healthMax > 0 then
		local info = ghost.info
		info.health = UnitHealth(unit)
		info.healthMax = healthMax
		info.dead = info.health <= 0
		renderUnseen(ghost, info)
	end
end

local function onTalents(_, guid)
	for i = 1, #ghosts do
		local ghost = ghosts[i]
		if ghost.state and ghost.info.guid == guid then
			render(ghost)
		end
	end
end

local function onConfigChanged()
	if not UF.testing then
		refreshAll()
		return
	end
	for i = 1, #ghosts do
		local frame = ghosts[i].frame
		if frame.test then
			test(frame)
		end
	end
end

local function onTestMode()
	if UF.testing then
		return
	end
	for i = 1, #ghosts do
		local ghost = ghosts[i]
		if ghost.tested then
			ghost.tested = nil
			wipe(ghost.info)
		end
		ghost.state = nil
	end
	refreshAll()
end

UF:OnInitialize(function(self)
	for i = 1, #self.frames do
		local frame = self.frames[i]
		if frame.unit:find("^arena%d$") then
			self:AddElement(frame, "unseen")
			watcher:RegisterUnitEvent("UNIT_HEALTH", frame.unit, onHealth)
			watcher:RegisterUnitEvent("UNIT_MAXHEALTH", frame.unit, onHealth)
			watcher:RegisterUnitEvent("UNIT_NAME_UPDATE", frame.unit, onNameUpdate)
		end
	end

	watcher:RegisterEvent("PLAYER_ENTERING_WORLD", onEnteringWorld)
	watcher:RegisterEvent("ARENA_OPPONENT_UPDATE", onOpponentUpdate)
	watcher:RegisterUnitEvent("UNIT_AURA", "player", onAura)
	watcher:RegisterEvent("PARTY_MEMBERS_CHANGED", onPrepChanged)
	watcher:RegisterEvent("UPDATE_BATTLEFIELD_STATUS", onPrepChanged)
	watcher:RegisterEvent(ns.TALENTS_UPDATED, onTalents)
	hooksecurefunc(self, "SetTestMode", onTestMode)

	self:WatchConfig("arenaUnseen", onConfigChanged)
	self:WatchConfig("unitFrames", onConfigChanged)
end)
