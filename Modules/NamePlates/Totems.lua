local _, ns = ...
local NamePlates = ns:GetModule("NamePlates")

local GetSpellInfo = GetSpellInfo
local match = string.match

local RANK_SUFFIXES = { "", " II", " III", " IV", " V", " VI", " VII", " VIII", " IX", " X" }

-- stylua: ignore
local TOTEM_SPELL_IDS = {
	8177, -- Grounding Totem
	10595, 10600, 10601, 25574, 58746, 58749, -- Nature Resistance Totem I-VI
	6495, -- Sentry Totem
	8512, -- Windfury Totem
	3738, -- Wrath of Air Totem
	2062, -- Earth Elemental Totem
	2484, -- Earthbind Totem
	5730, 6390, 6391, 6392, 10427, 10428, 25525, 58580, 58581, 58582, -- Stoneclaw Totem I-X
	8071, 8154, 8155, 10406, 10407, 10408, 25508, 25509, 58751, 58753, -- Stoneskin Totem I-X
	8075, 8160, 8161, 10442, 25361, 25528, 57622, 58643, -- Strength of Earth Totem I-VIII
	8143, -- Tremor Totem
	2894, -- Fire Elemental Totem
	8227, 8249, 10526, 16387, 25557, 58649, 58652, 58656, -- Flametongue Totem I-VIII
	8181, 10478, 10479, 25560, 58741, 58745, -- Frost Resistance Totem I-VI
	8190, 10585, 10586, 10587, 25552, 58731, 58734, -- Magma Totem I-VII
	3599, 6363, 6364, 6365, 10437, 10438, 25533, 58699, 58703, 58704, -- Searing Totem I-X
	30706, 57720, 57721, 57722, -- Totem of Wrath I-IV
	8170, -- Cleansing Totem
	8184, 10537, 10538, 25563, 58737, 58739, -- Fire Resistance Totem I-VI
	5394, 6375, 6377, 10462, 10463, 25567, 58755, 58756, 58757, -- Healing Stream Totem I-IX
	5675, 10495, 10496, 10497, 25570, 58771, 58773, 58774, -- Mana Spring Totem I-VIII
	16190, -- Mana Tide Totem
}

local totemIcons = {}

for i = 1, #TOTEM_SPELL_IDS do
	local spellName, rank, texture = GetSpellInfo(TOTEM_SPELL_IDS[i])
	if spellName then
		local digits = rank and match(rank, "%d+")
		totemIcons[spellName .. (digits and RANK_SUFFIXES[tonumber(digits)] or "")] = texture
	end
end

if GetLocale() == "ruRU" then
	local RU_NAMES = {
		[58745] = "Тотем сопротивления льду", -- Frost Resistance Totem
		[58739] = "Тотем сопротивления огню", -- Fire Resistance Totem
		[58749] = "Тотем сопротивления силам природы", -- Nature Resistance Totem
	}
	for spellId, name in pairs(RU_NAMES) do
		local _, _, texture = GetSpellInfo(spellId)
		for rankNumber = 1, 6 do
			totemIcons[name .. RANK_SUFFIXES[rankNumber]] = texture
		end
	end
end

NamePlates.totemIcons = totemIcons
