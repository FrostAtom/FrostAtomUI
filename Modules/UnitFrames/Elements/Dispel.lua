local _, ns = ...
local UF = ns:GetModule("UnitFrames")

local UnitAura = UnitAura
local UnitCanAssist = UnitCanAssist

local MAX_AURAS = 40
local HIGHLIGHT_ALPHA = ns.Config.dispelHighlightAlpha
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

local function firstDispellable(unit)
	for i = 1, MAX_AURAS do
		local name, _, _, _, debuffType = UnitAura(unit, i, "HARMFUL")
		if not name then
			return
		end
		if debuffType and canDispel[debuffType] then
			return debuffType
		end
	end
end

local function update(frame)
	local unit = frame.unit
	local overlay = frame.dispel

	local debuffType = UnitCanAssist("player", unit) and firstDispellable(unit)
	if debuffType then
		local color = debuffColors[debuffType]
		overlay:SetVertexColor(color[1], color[2], color[3], HIGHLIGHT_ALPHA)
		overlay:Show()
	else
		overlay:Hide()
	end
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

UF:RegisterElement("dispel", create, canDispel and update or ns.noop)
