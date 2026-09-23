local _, ns = ...
local UF = ns:GetModule("UnitFrames")

local UnitCanAssist = UnitCanAssist
local random = math.random

local Auras = ns.Auras
local config = ns.Config
local debuffColors = UF.debuffColors

local DISPEL_TYPES = {
	PRIEST = { Magic = true, Disease = true },
	PALADIN = { Magic = true, Poison = true, Disease = true },
	SHAMAN = { Poison = true, Disease = true, Curse = true },
	DRUID = { Curse = true, Poison = true },
	MAGE = { Curse = true },
	WARLOCK = { Magic = true },
}

local canDispel = DISPEL_TYPES[ns.PLAYER_CLASS]
UF.canDispel = canDispel

local function firstDispellable(unit)
	local auras, count = Auras.Get(unit, "HARMFUL")
	for i = 1, count do
		local debuffType = auras[i].debuffType
		if debuffType and canDispel[debuffType] then
			return debuffType
		end
	end
end

local function setType(overlay, debuffType)
	if debuffType then
		local color = debuffColors[debuffType]
		overlay:SetVertexColor(color[1], color[2], color[3], config.dispelHighlightAlpha)
		overlay:Show()
	else
		overlay:Hide()
	end
end

local function update(frame)
	local unit = frame.unit
	setType(frame.dispel, canDispel and UnitCanAssist("player", unit) and firstDispellable(unit))
end

local TEST_TYPES = { "Magic", "Curse", "Poison", "Disease" }

local function test(frame)
	setType(frame.dispel, random(4) == 1 and TEST_TYPES[random(#TEST_TYPES)])
end

local function create(frame)
	local overlay = frame.health:CreateTexture(nil, "OVERLAY", nil, -1)
	overlay:SetAllPoints()
	overlay:SetTexture(ns.Media.blank)
	overlay:Hide()

	if canDispel then
		frame:RegisterUnitEvent("UNIT_AURA", update)
	end

	return overlay
end

UF:RegisterElement("dispel", create, update, test)
