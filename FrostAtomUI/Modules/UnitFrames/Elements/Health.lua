local _, ns = ...
local UF = ns:GetModule("UnitFrames")
local L = ns.L

local UnitIsConnected = UnitIsConnected
local UnitIsDeadOrGhost = UnitIsDeadOrGhost
local UnitHealth, UnitHealthMax = UnitHealth, UnitHealthMax
local UnitGUID = UnitGUID
local UnitIsPlayer = UnitIsPlayer
local UnitClass = UnitClass

local HealthColor = ns.HealthColor
local Prediction = ns.HealPrediction
local setColor = UF.SetBarColor
local classColors = UF.classBarColors
local config = ns.Config.unitFrames

local BG_DIM = UF.BAR_BACKGROUND_DIM
local DEAD_R, DEAD_G, DEAD_B = HealthColor(0)
local DEAD_BG_R, DEAD_BG_G, DEAD_BG_B = DEAD_R * BG_DIM, DEAD_G * BG_DIM, DEAD_B * BG_DIM
local OFFLINE_R, OFFLINE_G, OFFLINE_B = 0.5, 0.5, 0.5

local CUTAWAY_FADE_SPEED = 2.5

local function showCutaway(health, from, to, max)
	local width = health:GetWidth()
	if max <= 0 or width <= 0 then
		return
	end

	local cutaway = health.cutaway
	cutaway:SetPoint("TOPLEFT", health, "TOPLEFT", width * to / max, 0)
	cutaway:SetPoint("BOTTOMRIGHT", health, "BOTTOMLEFT", width * from / max, 0)
	cutaway:SetVertexColor(unpack(config.healthCutawayColor))
	cutaway:SetAlpha(1)
	cutaway:Show()
end

local function setEmpty(health, setValue, text, ...)
	health:SetMinMaxValues(0, 1)
	setValue(health, 0)
	health.colorClass = nil
	health.bg:SetVertexColor(...)
	health.text:SetText(text)
	health.lastCurrent = nil
	Prediction.SetValues(health, 0, 0, false)
end

local function setDead(health, setValue)
	setEmpty(health, setValue, L["RIP"], DEAD_BG_R, DEAD_BG_G, DEAD_BG_B)
end

local function setOffline(health, setValue)
	health:SetMinMaxValues(0, 1)
	setValue(health, 1)
	health.colorClass = nil
	setColor(health, OFFLINE_R, OFFLINE_G, OFFLINE_B)
	health.text:SetText(L["offline"])
	health.lastCurrent = nil
	health.cutaway:Hide()
	Prediction.SetValues(health, 0, 0, false)
end

local function setAlive(health, setValue, current, max, class)
	health:SetMinMaxValues(0, max)
	setValue(health, current)

	local last = health.lastCurrent
	if config.healthCutaway and last and current < last and max == health.lastMax and max > 1 then
		showCutaway(health, last < max and last or max, current, max)
	end
	health.lastCurrent = current
	health.lastMax = max

	local classColor = class and config.healthColorMode == "class" and classColors[class]
	if classColor then
		if health.colorClass ~= class then
			health.colorClass = class
			setColor(health, classColor[1], classColor[2], classColor[3])
		end
	else
		health.colorClass = nil
		setColor(health, HealthColor(max > 0 and current / max or 0))
	end
	local frame = health:GetParent()
	UF.UpdateText(frame, health.text, "right")
	if frame.name then
		UF.UpdateTextIfUses(frame, frame.name, "left", "health")
	end
	if frame.power then
		UF.UpdateTextIfUses(frame, frame.power.text, "power", "health")
	end
end

local function update(frame)
	local unit = frame.unit
	local health = frame.health

	local guid = UnitGUID(unit)
	local setValue = health.SetValue
	if guid ~= health.guid then
		health.guid = guid
		health.lastCurrent = nil
		health.colorClass = nil
		setValue = health.SnapValue
		health.cutaway:Hide()
	end

	if not UnitIsConnected(unit) then
		setOffline(health, setValue)
	elseif UnitIsDeadOrGhost(unit) then
		setDead(health, setValue)
	else
		local _, class = UnitClass(unit)
		setAlive(health, setValue, UnitHealth(unit), UnitHealthMax(unit), UnitIsPlayer(unit) and class)
		Prediction.Refresh(health, guid, unit, config.healPrediction, config.absorbs)
	end
end

local function onPredictionChanged(frame, guid)
	local health = frame.health
	if
		guid == health.guid
		and frame:IsShown()
		and UnitIsConnected(frame.unit)
		and not UnitIsDeadOrGhost(frame.unit)
	then
		Prediction.Refresh(health, guid, frame.unit, config.healPrediction, config.absorbs)
	end
end

local function test(frame)
	local health, data = frame.health, frame.test
	health.cutaway:Hide()
	health.lastCurrent = nil
	health.lastValue = UnitHealth(frame.unit)
	if data.dead then
		setDead(health, health.SnapValue)
	else
		setAlive(health, health.SnapValue, data.health, data.healthMax, data.class)
		local absorb = config.absorbs and data.absorb or 0
		local incoming = config.healPrediction and data.incoming or 0
		local own = config.healPredictionSplit and data.incomingOwn or 0
		Prediction.SetValues(health, incoming, absorb, absorb > 0, own)
	end
end

local function onUpdate(health, elapsed)
	local current = UnitHealth(health.unit)
	if current ~= health.lastValue then
		health.lastValue = current
		update(health:GetParent())
	end
	Prediction.Follow(health)

	local cutaway = health.cutaway
	if cutaway:IsShown() then
		local alpha = cutaway:GetAlpha() - elapsed * CUTAWAY_FADE_SPEED
		if alpha > 0 then
			cutaway:SetAlpha(alpha)
		else
			cutaway:Hide()
		end
	end
end

local function create(frame)
	local health = CreateFrame("StatusBar", nil, frame)
	health:SetFrameLevel(frame:GetFrameLevel())
	ns.SkinStatusBar(health)
	health.unit = frame.unit
	ns.SmoothBar(health)

	health.bg = health:CreateTexture(nil, "BORDER")
	health.bg:SetAllPoints()
	health.bg:SetTexture(ns.Media.blank)

	health.cutaway = health:CreateTexture(nil, "ARTWORK", nil, 1)
	health.cutaway:SetTexture(ns.Media.blank)
	health.cutaway:Hide()

	Prediction.CreateBars(health)

	health.text = health:CreateFontString(nil, "OVERLAY")
	ns.SetFont(health.text, config.textFont.size, config.textFont.outline)
	health.text:SetTextColor(unpack(UF.textColor))

	health:SetScript("OnUpdate", onUpdate)
	frame:RegisterUnitEvent("UNIT_MAXHEALTH", update)
	frame:RegisterEvent(Prediction.CHANGED, onPredictionChanged)

	return health
end

UF:RegisterElement("health", create, update, test)
