local _, ns = ...

local GetSpellInfo = GetSpellInfo
local match, tonumber = string.match, tonumber

local RANK_SUFFIXES = { "", " II", " III", " IV", " V", " VI", " VII", " VIII", " IX", " X" }

-- stylua: ignore
local TOTEMS = {
	{ 1, 300, 8227, 5950, 8249, 6012, 10526, 7423, 16387, 10557, 25557, 15485, 58649, 31132, 58652, 31158, 58656, 31133 }, -- Flametongue Totem I-VIII
	{ 1, 300, 8181, 5926, 10478, 7412, 10479, 7413, 25560, 15486, 58741, 31171, 58745, 31172 }, -- Frost Resistance Totem I-VI
	{ 1, 21, 8190, 5929, 10585, 7464, 10586, 7465, 10587, 7466, 25552, 15484, 58731, 31166, 58734, 31167 }, -- Magma Totem I-VII
	{ 1, 30, 3599, 2523 }, -- Searing Totem
	{ 1, 35, 6363, 3902 }, -- Searing Totem II
	{ 1, 40, 6364, 3903 }, -- Searing Totem III
	{ 1, 45, 6365, 3904 }, -- Searing Totem IV
	{ 1, 50, 10437, 7400 }, -- Searing Totem V
	{ 1, 55, 10438, 7402 }, -- Searing Totem VI
	{ 1, 60, 25533, 15480, 58699, 31162, 58703, 31164, 58704, 31165 }, -- Searing Totem VII-X
	{ 1, 300, 30706, 17539, 57720, 30652, 57721, 30653, 57722, 30654 }, -- Totem of Wrath I-IV
	{ 1, 120, 2894, 15439 }, -- Fire Elemental Totem
	{ 2, 120, 2062, 15430 }, -- Earth Elemental Totem
	{ 2, 45, 2484, 2630 }, -- Earthbind Totem
	{ 2, 15, 5730, 3579, 6390, 3911, 6391, 3912, 6392, 3913, 10427, 7398, 10428, 7399, 25525, 15478, 58580, 31120, 58581, 31121, 58582, 31122 }, -- Stoneclaw Totem I-X
	{ 2, 300, 8071, 5873, 8154, 5919, 8155, 5920, 10406, 7366, 10407, 7367, 10408, 7368, 25508, 15470, 25509, 15474, 58751, 31175, 58753, 31176 }, -- Stoneskin Totem I-X
	{ 2, 300, 8075, 5874, 8160, 5921, 8161, 5922, 10442, 7403, 25361, 15464, 25528, 15479, 57622, 30647, 58643, 31129 }, -- Strength of Earth Totem I-VIII
	{ 2, 300, 8143, 5913 }, -- Tremor Totem
	{ 3, 300, 8170, 5924 }, -- Cleansing Totem
	{ 3, 300, 8184, 5927, 10537, 7424, 10538, 7425, 25563, 15487, 58737, 31169, 58739, 31170 }, -- Fire Resistance Totem I-VI
	{ 3, 300, 5394, 3527, 6375, 3906, 6377, 3907, 10462, 3908, 10463, 3909, 25567, 15488, 58755, 31181, 58756, 31182, 58757, 31185 }, -- Healing Stream Totem I-IX
	{ 3, 300, 5675, 3573, 10495, 7414, 10496, 7415, 10497, 7416, 25570, 15489, 58771, 31186, 58773, 31189, 58774, 31190 }, -- Mana Spring Totem I-VIII
	{ 3, 13, 16190, 10467 }, -- Mana Tide Totem
	{ 4, 45, 8177, 5925 }, -- Grounding Totem
	{ 4, 300, 10595, 7467, 10600, 7468, 10601, 7469, 25574, 15490, 58746, 31173, 58749, 31174 }, -- Nature Resistance Totem I-VI
	{ 4, 300, 6495, 3968 }, -- Sentry Totem
	{ 4, 300, 8512, 6112 }, -- Windfury Totem
	{ 4, 300, 3738, 15447 }, -- Wrath of Air Totem
}

-- stylua: ignore
local PULSES = {
	[8190] = { 2, 8187, 10579, 10580, 10581, 25550, 58732, 58735 }, -- Magma Totem
	[2484] = { 3, 3600 }, -- Earthbind
	[5730] = { 2, 5729, 6393, 6394, 6395, 10423, 10424, 25512 }, -- Stoneclaw Totem
	[8143] = { 3, 8146 }, -- Tremor Totem
	[8170] = { 3, 8171 }, -- Cleansing Totem
	[5394] = { 2, 52041, 52046, 52047, 52048, 52049, 52050, 58759, 58760, 58761, 52042 }, -- Healing Stream, Healing Stream Totem
	[16190] = { 3, 39610, 39609 }, -- Mana Tide Totem
}

local TotemData = {
	TICK_EVENTS = {
		SPELL_CAST_SUCCESS = true,
		SPELL_DAMAGE = true,
		SPELL_MISSED = true,
		SPELL_HEAL = true,
		SPELL_ENERGIZE = true,
		SPELL_AURA_APPLIED = true,
		SPELL_AURA_REFRESH = true,
		SPELL_DISPEL = true,
	},
	spells = {},
	byEntry = {},
	byName = {},
	tickSpells = {},
}
ns.TotemData = TotemData

local spells, byEntry, byName, tickSpells = TotemData.spells, TotemData.byEntry, TotemData.byName, TotemData.tickSpells

for i = 1, #TOTEMS do
	local row = TOTEMS[i]
	local pulseRow = PULSES[row[3]]
	local pulse
	if pulseRow then
		pulse = { period = pulseRow[1], ticks = {} }
		for j = 2, #pulseRow do
			pulse.ticks[pulseRow[j]] = true
			tickSpells[pulseRow[j]] = true
		end
	end
	for j = 3, #row, 2 do
		local spellId, entry = row[j], row[j + 1]
		local name, rank, icon = GetSpellInfo(spellId)
		if name then
			spells[spellId] = { slot = row[1], duration = row[2], icon = icon, pulse = pulse }
			byEntry[entry] = spellId
			local digits = rank and match(rank, "%d+")
			byName[name .. (digits and RANK_SUFFIXES[tonumber(digits)] or "")] = spellId
		end
	end
end

if GetLocale() == "ruRU" then
	-- stylua: ignore
	local RU_NAMES = {
		["Тотем сопротивления льду"] = { 8181, 10478, 10479, 25560, 58741, 58745 }, -- Frost Resistance Totem I-VI
		["Тотем сопротивления огню"] = { 8184, 10537, 10538, 25563, 58737, 58739 }, -- Fire Resistance Totem I-VI
		["Тотем сопротивления силам природы"] = { 10595, 10600, 10601, 25574, 58746, 58749 }, -- Nature Resistance Totem I-VI
	}
	for name, ranks in pairs(RU_NAMES) do
		for rank = 1, #ranks do
			byName[name .. RANK_SUFFIXES[rank]] = ranks[rank]
		end
	end
end
