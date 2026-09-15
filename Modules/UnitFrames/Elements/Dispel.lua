local _, ns = ...
local UF = ns:GetModule("UnitFrames")

-- Tints the health bar with the debuff type color when a friendly unit has
-- a debuff the player's class can dispel.

local UnitAura = UnitAura
local UnitCanAssist = UnitCanAssist

local MAX_AURAS = 40

-- Debuff types each class can remove (3.3.5, talents included).
local DISPEL_TYPES = {
	PRIEST = { Magic = true, Disease = true },
	PALADIN = { Magic = true, Poison = true, Disease = true },
	SHAMAN = { Poison = true, Disease = true, Curse = true },
	DRUID = { Curse = true, Poison = true },
	MAGE = { Curse = true },
	WARLOCK = { Magic = true }, -- felhunter
}

local canDispel = DISPEL_TYPES[ns.PLAYER_CLASS]

local debuffColors = {}
for debuffType, color in pairs(DebuffTypeColor) do
	debuffColors[debuffType] = { color.r, color.g, color.b }
end

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
		overlay:SetVertexColor(color[1], color[2], color[3], ns.Config.dispelHighlightAlpha)
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

-- Classes without a dispel never show anything.
UF:RegisterElement("dispel", create, canDispel and update or ns.noop)
