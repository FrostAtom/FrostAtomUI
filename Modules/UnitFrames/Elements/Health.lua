local _, ns = ...
local UF = ns:GetModule("UnitFrames")

local CreateFrame = CreateFrame
local UnitIsConnected = UnitIsConnected
local UnitIsDeadOrGhost = UnitIsDeadOrGhost
local UnitHealth, UnitHealthMax = UnitHealth, UnitHealthMax
local UnitGUID = UnitGUID
local UnitIsPlayer = UnitIsPlayer
local UnitClass = UnitClass
local unpack = unpack

local FormatValue = ns.FormatValue
local ColorGradient = ns.ColorGradient
local classColors = UF.classBarColors

local GRADIENT = { 0.8, 0.2, 0.2, 0.65, 0.63, 0.35, 0.33, 0.59, 0.33 }

local CUTAWAY_FADE_SPEED = 2.5

local function showCutaway(health, from, to, max)
	local width = health:GetWidth()
	if max <= 0 or width <= 0 then
		return
	end

	local cutaway = health.cutaway
	cutaway:ClearAllPoints()
	cutaway:SetPoint("TOPLEFT", health, "TOPLEFT", width * to / max, 0)
	cutaway:SetPoint("BOTTOMRIGHT", health, "BOTTOMLEFT", width * from / max, 0)
	cutaway:SetAlpha(1)
	cutaway:Show()
end

local function update(frame)
	local unit = frame.unit
	local health = frame.health

	local guid = UnitGUID(unit)
	local setValue = health.SetValue
	if guid ~= health.guid then
		health.guid = guid
		health.lastCurrent = nil
		setValue = health.SnapValue
		health.cutaway:Hide()
	end

	if not UnitIsConnected(unit) then
		health:SetMinMaxValues(0, 1)
		setValue(health, 0)
		health.bg:SetVertexColor(frame:GetBackdropColor())
		health.text:SetText("offline")
		health.lastCurrent = nil
	elseif UnitIsDeadOrGhost(unit) then
		health:SetMinMaxValues(0, 1)
		setValue(health, 0)

		local r, g, b = ColorGradient(0, unpack(GRADIENT))
		health.bg:SetVertexColor(r * 0.3, g * 0.3, b * 0.3)
		health.text:SetText("RIP")
		health.lastCurrent = nil
	else
		local current, max = UnitHealth(unit), UnitHealthMax(unit)
		health:SetMinMaxValues(0, max)
		setValue(health, current)

		if health.lastCurrent and current < health.lastCurrent then
			showCutaway(health, health.lastCurrent, current, max)
		end
		health.lastCurrent = current

		local r, g, b
		local _, class = UnitClass(unit)
		if UnitIsPlayer(unit) and classColors[class] then
			r, g, b = unpack(classColors[class])
		else
			r, g, b = ColorGradient(current / max, unpack(GRADIENT))
		end
		health:SetStatusBarColor(r, g, b)
		health.bg:SetVertexColor(r * 0.3, g * 0.3, b * 0.3)
		health.text:SetText(FormatValue(current))
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
	health:SetStatusBarTexture(ns.Media.blank)
	health.unit = frame.unit
	ns.SmoothBar(health)

	health.bg = health:CreateTexture(nil, "BORDER")
	health.bg:SetAllPoints()
	health.bg:SetTexture(ns.Media.blank)

	health.cutaway = health:CreateTexture(nil, "ARTWORK", nil, 1)
	health.cutaway:SetTexture(ns.Media.blank)
	health.cutaway:SetVertexColor(1, 0.9, 0.8, 0.6)
	health.cutaway:Hide()

	health.text = health:CreateFontString(nil, "OVERLAY", "SystemFont_Outline_Small")
	health.text:SetTextColor(unpack(UF.textColor))

	health:SetScript("OnUpdate", onUpdate)
	frame:RegisterUnitEvent("UNIT_MAXHEALTH", update)

	return health
end

UF:RegisterElement("health", create, update)
