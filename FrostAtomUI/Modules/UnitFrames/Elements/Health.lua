local _, ns = ...
local UF = ns:GetModule("UnitFrames")

local UnitIsConnected = UnitIsConnected
local UnitIsDeadOrGhost = UnitIsDeadOrGhost
local UnitHealth, UnitHealthMax = UnitHealth, UnitHealthMax
local UnitGUID = UnitGUID
local UnitIsPlayer = UnitIsPlayer
local UnitClass = UnitClass

local ColorGradient = ns.ColorGradient
local classColors = UF.classBarColors
local config = ns.Config.unitFrames

local GRADIENT = { 0.8, 0.2, 0.2, 0.65, 0.63, 0.35, 0.33, 0.59, 0.33 }
local DEAD_BG_R, DEAD_BG_G, DEAD_BG_B = GRADIENT[1] * 0.3, GRADIENT[2] * 0.3, GRADIENT[3] * 0.3

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

local function setColor(health, r, g, b)
	health:SetStatusBarColor(r, g, b)
	health.bg:SetVertexColor(r * 0.3, g * 0.3, b * 0.3)
end

local function setDead(health, setValue)
	health:SetMinMaxValues(0, 1)
	setValue(health, 0)
	health.colorClass = nil
	health.bg:SetVertexColor(DEAD_BG_R, DEAD_BG_G, DEAD_BG_B)
	health.text:SetText("RIP")
	health.lastCurrent = nil
end

local function setAlive(health, setValue, current, max, class)
	health:SetMinMaxValues(0, max)
	setValue(health, current)

	if config.healthCutaway and health.lastCurrent and current < health.lastCurrent then
		showCutaway(health, health.lastCurrent, current, max)
	end
	health.lastCurrent = current

	local classColor = class and config.classColorHealth and classColors[class]
	if classColor then
		if health.colorClass ~= class then
			health.colorClass = class
			setColor(health, classColor[1], classColor[2], classColor[3])
		end
	else
		health.colorClass = nil
		setColor(health, ColorGradient(current / max, unpack(GRADIENT)))
	end
	local frame = health:GetParent()
	UF.UpdateText(frame, health.text, "right")
	if frame.name and UF.TagsUse(UF.TextTemplate(frame, frame.name, "left"), "health") then
		UF.UpdateText(frame, frame.name, "left")
	end
	if frame.power and UF.TagsUse(UF.TextTemplate(frame, frame.power.text, "power"), "health") then
		UF.UpdateText(frame, frame.power.text, "power")
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
		health:SetMinMaxValues(0, 1)
		setValue(health, 0)
		health.colorClass = nil
		health.bg:SetVertexColor(frame:GetBackdropColor())
		health.text:SetText("offline")
		health.lastCurrent = nil
	elseif UnitIsDeadOrGhost(unit) then
		setDead(health, setValue)
	else
		local _, class = UnitClass(unit)
		setAlive(health, setValue, UnitHealth(unit), UnitHealthMax(unit), UnitIsPlayer(unit) and class)
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
	end
end

local function onUpdate(health, elapsed)
	local current = UnitHealth(health.unit)
	if current ~= health.lastValue then
		health.lastValue = current
		update(health:GetParent())
	end

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

	health.text = health:CreateFontString(nil, "OVERLAY")
	ns.SetFont(health.text, config.textFont.size, config.textFont.outline)
	health.text:SetTextColor(unpack(UF.textColor))

	health:SetScript("OnUpdate", onUpdate)
	frame:RegisterUnitEvent("UNIT_MAXHEALTH", update)

	return health
end

UF:RegisterElement("health", create, update, test)
