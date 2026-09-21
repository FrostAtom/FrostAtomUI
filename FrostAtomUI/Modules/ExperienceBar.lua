local _, ns = ...

local CreateFrame = CreateFrame
local UnitLevel = UnitLevel
local UnitXP, UnitXPMax = UnitXP, UnitXPMax
local GetXPExhaustion = GetXPExhaustion
local GetWatchedFactionInfo = GetWatchedFactionInfo
local GameTooltip = GameTooltip
local min = math.min
local MAX_PLAYER_LEVEL = MAX_PLAYER_LEVEL or 80

local ExperienceBar = ns:NewModule("ExperienceBar")

local FACTION_COLORS = FACTION_BAR_COLORS

local holder, bar, rested, bg

local function showExperience()
	local current, max = UnitXP("player"), UnitXPMax("player")
	bar:SetMinMaxValues(0, max)
	bar:SetValue(current)
	bar:SetStatusBarColor(unpack(ns.Config.experienceBar.xpColor))

	local exhaustion = GetXPExhaustion()
	if exhaustion and exhaustion > 0 then
		rested:SetMinMaxValues(0, max)
		rested:SetValue(min(current + exhaustion, max))
		rested:Show()
	else
		rested:Hide()
	end

	holder.mode = "xp"
	holder:Show()
end

local function showReputation()
	local name, standing, min, max, value = GetWatchedFactionInfo()
	if not name then
		holder:Hide()
		return
	end

	bar:SetMinMaxValues(0, max - min)
	bar:SetValue(value - min)
	local color = FACTION_COLORS[standing]
	bar:SetStatusBarColor(color.r, color.g, color.b)
	rested:Hide()

	holder.mode = "reputation"
	holder.factionName = name
	holder:Show()
end

function ExperienceBar:Update()
	local config = ns.Config.experienceBar
	if not config.enabled then
		holder:Hide()
	elseif UnitLevel("player") < MAX_PLAYER_LEVEL then
		showExperience()
	elseif config.showReputation then
		showReputation()
	else
		holder:Hide()
	end
end

local function onEnter(self)
	GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")

	if self.mode == "xp" then
		local current, max = UnitXP("player"), UnitXPMax("player")
		GameTooltip:AddDoubleLine("Experience", ("%d / %d (%d%%)"):format(current, max, current / max * 100))
		local exhaustion = GetXPExhaustion()
		if exhaustion and exhaustion > 0 then
			GameTooltip:AddDoubleLine("Rested", ("+%d (%d%%)"):format(exhaustion, exhaustion / max * 100), 0, 0.6, 1)
		end
	else
		local _, standing, min, max, value = GetWatchedFactionInfo()
		local standingText = _G["FACTION_STANDING_LABEL" .. standing] or ""
		GameTooltip:AddDoubleLine(self.factionName, standingText)
		GameTooltip:AddDoubleLine("Reputation", ("%d / %d"):format(value - min, max - min))
	end

	GameTooltip:Show()
end

local function onLeave()
	GameTooltip:Hide()
end

local function applyConfig(self)
	local config = ns.Config.experienceBar
	holder:SetSize(config.width, config.height)
	holder:ClearAllPoints()
	holder:SetPoint(unpack(config.point))
	bg:SetTexture(0, 0, 0, config.backgroundAlpha)
	rested:SetStatusBarColor(unpack(config.restedColor))
	self:Update()
end

function ExperienceBar:Initialize()
	holder = CreateFrame("Frame", nil, UIParent)
	holder:Hide()
	holder:SetFrameStrata("LOW")
	holder:EnableMouse(true)
	holder:SetScript("OnEnter", onEnter)
	holder:SetScript("OnLeave", onLeave)

	bg = holder:CreateTexture(nil, "BACKGROUND")
	bg:SetAllPoints()

	rested = CreateFrame("StatusBar", nil, holder)
	rested:Hide()
	rested:SetAllPoints()
	rested:SetFrameLevel(holder:GetFrameLevel() + 1)
	rested:SetStatusBarTexture(ns.Media.blank)

	bar = CreateFrame("StatusBar", nil, holder)
	bar:SetAllPoints()
	bar:SetFrameLevel(holder:GetFrameLevel() + 2)
	bar:SetStatusBarTexture(ns.Media.blank)

	applyConfig(self)
	self:WatchConfig("experienceBar", applyConfig)

	for _, event in ipairs({
		"PLAYER_ENTERING_WORLD",
		"PLAYER_XP_UPDATE",
		"PLAYER_LEVEL_UP",
		"UPDATE_EXHAUSTION",
		"UPDATE_FACTION",
	}) do
		self:RegisterEvent(event, "Update")
	end
end
