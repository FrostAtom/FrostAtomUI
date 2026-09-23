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
