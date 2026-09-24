local _, ns = ...
local UF = ns:GetModule("UnitFrames")

local UnitAffectingCombat = UnitAffectingCombat
local UnitIsConnected = UnitIsConnected

local config = ns.Config.unitFrames

local function update(frame)
	local unit = frame.unit
	ns.SetShown(frame.combat, config.showCombatIcon and UnitIsConnected(unit) and UnitAffectingCombat(unit))
end

local function test(frame)
	ns.SetShown(frame.combat, config.showCombatIcon and math.random(2) == 1)
end

local function create(frame)
	local combat = (frame.classicon or frame):CreateTexture(nil, "OVERLAY")
	combat:SetSize(14, 14)
	combat:SetTexture("Interface\\CharacterFrame\\UI-StateIcon")
	combat:SetTexCoord(0.6, 0.9, 0.1, 0.4)
	combat:SetVertexColor(1, 0.9, 0.9)

	frame:RegisterUnitEvent("UNIT_FLAGS", update)

	return combat
end

UF:RegisterElement("combat", create, update, test)

local GLOW_SIZE = 6

local function setGlow(frame, shown)
	local glow = frame.combatglow
	if not (shown and config.combatGlow) then
		glow:Hide()
		return
	end
	local color = config.combatGlowColor
	if not glow:IsShown() or glow.r ~= color[1] or glow.g ~= color[2] or glow.b ~= color[3] then
		UF.StartCastGlow(glow, color)
	end
end

local function updateGlow(frame)
	setGlow(frame, UnitAffectingCombat("player"))
end

local function testGlow(frame)
	setGlow(frame, math.random(2) == 1)
end

local function onCombatStart(frame)
	setGlow(frame, true)
end

local function onCombatEnd(frame)
	setGlow(frame, false)
end

local function createGlow(frame)
	local glow = UF.CreateCastGlow(frame, frame, GLOW_SIZE)
	glow:SetScript("OnUpdate", UF.PulseCastGlow)

	frame:RegisterEvent("PLAYER_REGEN_DISABLED", onCombatStart)
	frame:RegisterEvent("PLAYER_REGEN_ENABLED", onCombatEnd)

	return glow
end

UF:RegisterElement("combatglow", createGlow, updateGlow, testGlow)
