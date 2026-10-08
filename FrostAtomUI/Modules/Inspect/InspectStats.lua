local _, ns = ...

local L = ns.L

local Gear = ns.InspectGear
local StatData = ns.InspectStatData

local P = {}
ns.InspectFrameShared = P

local CASTER_CLASSES = { MAGE = true, WARLOCK = true, PRIEST = true }
local HYBRID_CLASSES = { DRUID = true, SHAMAN = true, PALADIN = true }
local CRIT_TAKEN = {
	{ "melee", PLAYERSTAT_MELEE_COMBAT },
	{ "ranged", PLAYERSTAT_RANGED_COMBAT },
	{ "spell", PLAYERSTAT_SPELL_COMBAT },
}

local STAT_LABELS = {
	ITEM_MOD_STAMINA_SHORT = "Stamina",
	ITEM_MOD_RESILIENCE_RATING_SHORT = "Resilience",
	ITEM_MOD_STRENGTH_SHORT = "Strength",
	ITEM_MOD_AGILITY_SHORT = "Agility",
	ITEM_MOD_INTELLECT_SHORT = "Intellect",
	ITEM_MOD_SPIRIT_SHORT = "Spirit",
	ITEM_MOD_ATTACK_POWER_SHORT = "Attack power",
	ITEM_MOD_SPELL_POWER_SHORT = "Spell power",
	ITEM_MOD_CRIT_RATING_SHORT = "Crit",
	ITEM_MOD_HASTE_RATING_SHORT = "Haste",
	ITEM_MOD_HIT_RATING_SHORT = "Hit",
	ITEM_MOD_ARMOR_PENETRATION_RATING_SHORT = "Armor pen.",
	ITEM_MOD_EXPERTISE_RATING_SHORT = "Expertise",
	ITEM_MOD_SPELL_PENETRATION_SHORT = "Spell pen.",
	ITEM_MOD_POWER_REGEN0_SHORT = "MP5",
	ITEM_MOD_DEFENSE_SKILL_RATING_SHORT = "Defense",
	ITEM_MOD_DODGE_RATING_SHORT = "Dodge",
	ITEM_MOD_PARRY_RATING_SHORT = "Parry",
	ITEM_MOD_BLOCK_RATING_SHORT = "Block",
	ITEM_MOD_BLOCK_VALUE_SHORT = "Block value",
	RESISTANCE0_NAME = "Armor",
}

local STAT_GROUPS = {
	{
		title = "Attributes",
		keys = {
			"ITEM_MOD_STAMINA_SHORT",
			"ITEM_MOD_STRENGTH_SHORT",
			"ITEM_MOD_AGILITY_SHORT",
			"ITEM_MOD_INTELLECT_SHORT",
			"ITEM_MOD_SPIRIT_SHORT",
		},
	},
	{
		keys = {
			"ITEM_MOD_ATTACK_POWER_SHORT",
			"ITEM_MOD_SPELL_POWER_SHORT",
			"ITEM_MOD_CRIT_RATING_SHORT",
			"ITEM_MOD_HASTE_RATING_SHORT",
			"ITEM_MOD_HIT_RATING_SHORT",
			"ITEM_MOD_EXPERTISE_RATING_SHORT",
			"ITEM_MOD_ARMOR_PENETRATION_RATING_SHORT",
			"ITEM_MOD_SPELL_PENETRATION_SHORT",
			"ITEM_MOD_POWER_REGEN0_SHORT",
		},
	},
	{
		title = "Defenses",
		keys = {
			"ITEM_MOD_RESILIENCE_RATING_SHORT",
			"RESISTANCE0_NAME",
			"ITEM_MOD_DEFENSE_SKILL_RATING_SHORT",
			"ITEM_MOD_DODGE_RATING_SHORT",
			"ITEM_MOD_PARRY_RATING_SHORT",
			"ITEM_MOD_BLOCK_RATING_SHORT",
			"ITEM_MOD_BLOCK_VALUE_SHORT",
		},
	},
}

local function statValue(stat, value, percent)
	local text = value > 0 and P.formatNumber(value) or ""
	if stat.resilience then
		percent = P.state.level == Gear.MAX_LEVEL and value / stat.rating or nil
	end
	if not stat.rating or not percent then
		return text
	end
	if stat.points then
		return ("%s %s(%d)|r"):format(text, P.GREY, percent)
	end
	return ("%s %s%.2f%%|r"):format(text, P.GREY, percent)
end

local function classCaster(class, stats)
	if CASTER_CLASSES[class] then
		return true
	end
	if HYBRID_CLASSES[class] then
		return (stats.ITEM_MOD_SPELL_POWER_SHORT or 0) > (stats.ITEM_MOD_ATTACK_POWER_SHORT or 0)
	end
	return false
end

local function isCaster(stats)
	return classCaster(P.state.class, stats)
end

local function showStatTooltip(self)
	if not self.stat then
		return
	end
	GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
	GameTooltip:SetText(_G[self.stat.key] or self.stat.key, 1, 1, 1)
	if self.stat.resilience and P.state.level == Gear.MAX_LEVEL then
		local reduction = self.value / self.stat.rating
		GameTooltip:AddLine(
			RESILIENCE_TOOLTIP:format(reduction, reduction * 2.2, reduction * 2),
			NORMAL_FONT_COLOR.r,
			NORMAL_FONT_COLOR.g,
			NORMAL_FONT_COLOR.b,
			true
		)
	end
	local totals = P.state.totals
	if self.stat.resilience and totals then
		for _, entry in ipairs(CRIT_TAKEN) do
			local value = totals.critTaken[entry[1]]
			if value then
				GameTooltip:AddDoubleLine(
					L["Chance to be critically hit"] .. " (" .. entry[2] .. ")",
					("-%d%%"):format(value),
					1,
					1,
					1,
					P.COLOR.GREEN[1],
					P.COLOR.GREEN[2],
					P.COLOR.GREEN[3]
				)
			end
		end
	end
	local schoolCrit = totals and self.stat.key == "ITEM_MOD_CRIT_RATING_SHORT" and totals.schoolCrit
	if schoolCrit then
		local color = NORMAL_FONT_COLOR
		for school = 2, 7 do
			GameTooltip:AddDoubleLine(
				_G["DAMAGE_SCHOOL" .. school],
				("%.2f%%"):format(schoolCrit[school]),
				color.r,
				color.g,
				color.b,
				color.r,
				color.g,
				color.b
			)
			GameTooltip:AddTexture("Interface\\PaperDollInfoFrame\\SpellSchoolIcon" .. school)
		end
	end
	local sources = totals and totals.sources[self.stat.key]
	if sources then
		GameTooltip:AddLine(" ")
		for _, source in ipairs(sources) do
			GameTooltip:AddDoubleLine(
				Gear.SourceIcon(source) .. (source.name or ""),
				source.text,
				1,
				1,
				1,
				P.COLOR.GREEN[1],
				P.COLOR.GREEN[2],
				P.COLOR.GREEN[3]
			)
		end
	end
	if not (totals and totals.full) then
		GameTooltip:AddLine(" ")
		GameTooltip:AddLine(
			L["From gear, gems, enchants, socket and set bonuses and talents of the active spec. Base stats and buffs not included."],
			0.6,
			0.6,
			0.6,
			true
		)
	end
	GameTooltip:Show()
end

local function activeTalents()
	local spec = P.state.specs and P.state.specs[P.state.activeGroup]
	return spec and spec.talents
end

local function availableForms()
	local forms = StatData.FORMS[P.state.class]
	if not forms or P.state.level ~= StatData.LEVEL then
		return nil
	end
	local known = {}
	for _, talent in ipairs(activeTalents() or {}) do
		known[talent.id] = true
	end
	local list = {}
	for _, form in ipairs(forms) do
		if not form.talent or known[form.talent] then
			list[#list + 1] = form
		end
	end
	return list
end

local function selectedForm(list)
	local id = P.state.form or P.state.detectedForm
	for _, form in ipairs(list) do
		if form.id == id then
			return form
		end
	end
	return list[1]
end

local function unitForm(unit, class, isSelf)
	for i = 1, 40 do
		local name, _, _, _, _, _, _, _, _, _, spellId = UnitBuff(unit, i)
		if not name then
			break
		end
		if StatData.FORM_AURAS[spellId] then
			return StatData.FORM_AURAS[spellId]
		end
	end
	local index = isSelf and GetShapeshiftForm() or 0
	if index > 0 then
		local _, name = GetShapeshiftFormInfo(index)
		for _, form in ipairs(StatData.FORMS[class] or {}) do
			if form.spell and GetSpellInfo(form.spell) == name then
				return form.id
			end
		end
	end
end

local function detectForm()
	P.state.detectedForm = P.unitValid() and unitForm(P.state.unit, P.state.class, P.state.isSelf) or nil
end

local function formName(form)
	return form.spell and GetSpellInfo(form.spell) or L["No form"]
end

local function formIcon(form)
	if form.spell then
		return (select(3, GetSpellInfo(form.spell)))
	end
	return "Interface\\Icons\\Ability_Hunter_Pet_Bear"
end

local function updateFormButtons(list, current)
	local buttons = P.frame.formButtons
	local count = list and #list or 0
	for i, button in ipairs(buttons) do
		local form = list and list[i]
		button.form = form
		if form then
			button:SetPoint("BOTTOMRIGHT", P.frame.statsInset, "TOPRIGHT", -4 - (count - i) * (P.FORM_SIZE + 3), 2)
			button.icon:SetTexture(formIcon(form))
			local selected = form == current
			button.icon:SetDesaturated(not selected)
			button:SetAlpha(selected and 1 or 0.55)
			ns.SetShown(button.border, selected)
			ns.SetShown(button.detected, form.id == P.state.detectedForm)
			button:Show()
		else
			button:Hide()
		end
	end
end

local statByKey = {}
for _, stat in ipairs(Gear.STATS) do
	statByKey[stat.key] = stat
end

local function offenseTitle(caster)
	if caster == nil then
		return ""
	elseif caster then
		return L["Spell"]
	end
	return P.state.class == "HUNTER" and L["Ranged"] or L["Melee"]
end

local function updateStats()
	local gear = P.state.gear
	local totals, caster
	P.state.totals = nil
	detectForm()
	local forms = availableForms()
	local form = forms and selectedForm(forms)
	updateFormButtons(gear and forms, form)
	if gear then
		caster = isCaster(gear.stats)
		if form and form.feral then
			caster = false
		elseif form and form.caster then
			caster = true
		end
		totals = Gear.Compute(gear, activeTalents(), {
			class = P.state.class,
			race = P.state.raceFile,
			level = P.state.level,
			form = form and form.id,
			formData = form,
			caster = caster,
		})
		P.state.totals = totals
	end
	for index, group in ipairs(P.frame.statGroups) do
		local rows = group.rows
		local shown = 0
		if index == 2 then
			group.title:SetText(offenseTitle(caster))
		end
		if totals then
			for _, key in ipairs(STAT_GROUPS[index].keys) do
				if totals.visible[key] and shown < #rows then
					shown = shown + 1
					local stat, value = statByKey[key], totals.values[key] or 0
					local row = rows[shown]
					row.stat, row.value = stat, value
					row.label:SetText(L[STAT_LABELS[key] or key])
					row.valueText:SetText(statValue(stat, value, totals.percent[key]))
					row:Show()
				end
			end
		end
		for i = shown + 1, #rows do
			rows[i].stat = nil
			rows[i]:Hide()
		end
	end
end

local function showFormTooltip(self)
	if not self.form then
		return
	end
	GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
	if self.form.spell then
		GameTooltip:SetHyperlink("spell:" .. self.form.spell)
		GameTooltip:AddLine(" ")
	else
		GameTooltip:SetText(formName(self.form), 1, 1, 1)
	end
	if self.form.id == P.state.detectedForm then
		GameTooltip:AddLine(L["Current form of the player"], P.COLOR.GREEN[1], P.COLOR.GREEN[2], P.COLOR.GREEN[3])
	end
	GameTooltip:AddLine(L["Click to show the stats in this form."], 0.6, 0.6, 0.6, true)
	GameTooltip:Show()
end

local function onFormClick(self)
	if self.form then
		P.state.form = self.form.id
		updateStats()
		showFormTooltip(self)
	end
end

P.STAT_GROUPS = STAT_GROUPS
P.STAT_LABELS = STAT_LABELS
P.CRIT_TAKEN = CRIT_TAKEN
P.classCaster = classCaster
P.unitForm = unitForm
P.showStatTooltip = showStatTooltip
P.detectForm = detectForm
P.updateStats = updateStats
P.showFormTooltip = showFormTooltip
P.onFormClick = onFormClick
