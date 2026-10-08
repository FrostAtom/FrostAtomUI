local _, ns = ...

local L = ns.L

local GetTalentInfo, GetTalentLink = GetTalentInfo, GetTalentLink
local GetNumTalentTabs, GetNumTalents = GetNumTalentTabs, GetNumTalents
local floor, abs = math.floor, math.abs

local Gear = ns.InspectGear
local StatData = ns.InspectStatData
local TalentData = ns.InspectTalentData
local Shared = ns.InspectFrameShared

local CRIT_KEY = "ITEM_MOD_CRIT_RATING_SHORT"

local playerGear
local watcher = ns.Mixin({}, ns.EventMixin)

local function dropPlayerGear()
	playerGear = nil
end

watcher:RegisterEvent("PLAYER_EQUIPMENT_CHANGED", dropPlayerGear)
watcher:RegisterUnitEvent("UNIT_INVENTORY_CHANGED", "player", dropPlayerGear)

local function ownGear(level)
	if not playerGear then
		local gear = Gear.Scan("player", true, ns.PLAYER_CLASS, level)
		if gear.pending then
			return gear
		end
		playerGear = gear
	end
	return playerGear
end

local function context(inspect)
	if not inspect then
		local level = UnitLevel("player")
		return {
			gear = ownGear(level),
			class = ns.PLAYER_CLASS,
			race = select(2, UnitRace("player")),
			level = level,
			form = Shared.unitForm("player", ns.PLAYER_CLASS, true),
		}
	end
	local state = Shared.state
	if not (Shared.frame and Shared.frame:IsShown() and state.gear and not state.isSelf) then
		return nil
	end
	return {
		gear = state.gear,
		class = state.class,
		race = state.raceFile,
		level = state.level,
		form = state.form or state.detectedForm,
		owner = state.name,
	}
end

local function readTalents(inspect, group, preview)
	local list = {}
	for tab = 1, GetNumTalentTabs(inspect) or 0 do
		for index = 1, GetNumTalents(tab, inspect) or 0 do
			local name, icon, _, _, rank, _, _, _, previewRank = GetTalentInfo(tab, index, inspect, false, group)
			rank = preview and previewRank or rank
			local id = rank
				and rank > 0
				and (GetTalentLink(tab, index, inspect, false, group) or ""):match("talent:(%d+)")
			if id then
				list[#list + 1] = { id = tonumber(id), rank = rank, name = name, icon = icon }
			end
		end
	end
	return list
end

local function withRank(talents, talent, rank)
	local list = {}
	for _, entry in ipairs(talents) do
		if entry.id ~= talent.id then
			list[#list + 1] = entry
		end
	end
	if rank > 0 then
		list[#list + 1] = { id = talent.id, rank = rank, name = talent.name, icon = talent.icon }
	end
	return list
end

local function inForm(mask, form)
	return form and form > 0 and mask % (2 ^ form) >= 2 ^ (form - 1)
end

local function formData(class, id)
	for _, form in ipairs(StatData.FORMS[class] or {}) do
		if form.id == id then
			return form
		end
	end
end

-- Stance-bound talents are shown for the first form they work in when the player is in another one
local function chooseForm(effects, ctx)
	local mask
	for _, effect in ipairs(effects) do
		mask = mask or effect.stances
	end
	if not mask or inForm(mask, ctx.form) then
		return ctx.form, false
	end
	for _, form in ipairs(StatData.FORMS[ctx.class] or {}) do
		if inForm(mask, form.id) then
			return form.id, true
		end
	end
	return ctx.form, false
end

local function signed(value, format)
	return (value > 0 and "+" or "") .. format:format(value)
end

local function difference(before, after)
	local lines = {}
	for _, stat in ipairs(Gear.STATS) do
		local key, text = stat.key, nil
		if stat.rating and not stat.resilience then
			local change = (after.percent[key] or 0) - (before.percent[key] or 0)
			if stat.points and abs(change) >= 0.5 then
				text = signed(floor(change + 0.5), "%d")
			elseif not stat.points and abs(change) >= 0.005 then
				text = signed(change, "%.2f%%")
			end
		else
			local change = (after.values[key] or 0) - (before.values[key] or 0)
			if abs(change) >= 0.5 then
				text = signed(floor(change + 0.5), "%d")
			end
		end
		if text then
			lines[#lines + 1] = { L[Shared.STAT_LABELS[key]], text }
		end
	end
	if before.schoolCrit and after.schoolCrit then
		local overall = (after.percent[CRIT_KEY] or 0) - (before.percent[CRIT_KEY] or 0)
		for school = 2, 7 do
			local change = after.schoolCrit[school] - before.schoolCrit[school] - overall
			if abs(change) >= 0.005 then
				lines[#lines + 1] = {
					("%s (%s)"):format(L[Shared.STAT_LABELS[CRIT_KEY]], _G["DAMAGE_SCHOOL" .. school]),
					signed(change, "%.2f%%"),
				}
			end
		end
	end
	for _, entry in ipairs(Shared.CRIT_TAKEN) do
		local change = (after.critTaken[entry[1]] or 0) - (before.critTaken[entry[1]] or 0)
		if change ~= 0 then
			lines[#lines + 1] = {
				("%s (%s)"):format(L["Chance to be critically hit"], entry[2]),
				signed(-change, "%d%%"),
			}
		end
	end
	return lines
end

local function addLines(tooltip, lines)
	local green = Shared.COLOR.GREEN
	for _, line in ipairs(lines) do
		tooltip:AddDoubleLine(line[1], line[2], 1, 1, 1, green[1], green[2], green[3])
	end
end

local function onSetTalent(tooltip, tab, index, inspect, pet, group, preview)
	if pet then
		return
	end
	local link = GetTalentLink(tab, index, inspect, pet, group, preview)
	local id = link and tonumber(link:match("talent:(%d+)"))
	local effects = id and TalentData[id]
	local ctx = effects and context(inspect)
	if not ctx then
		return
	end
	local name, icon, _, _, rank, maxRank, _, _, previewRank = GetTalentInfo(tab, index, inspect, pet, group)
	if preview then
		rank = previewRank
	end
	if not (rank and maxRank) then
		return
	end
	local talent = { id = id, name = name, icon = icon }
	local talents = readTalents(inspect, group, preview)
	local formId, otherForm = chooseForm(effects, ctx)
	local form = formData(ctx.class, formId)
	local caster = Shared.classCaster(ctx.class, ctx.gear.stats)
	if form and form.feral then
		caster = false
	elseif form and form.caster then
		caster = true
	end
	local info = {
		class = ctx.class,
		race = ctx.race,
		level = ctx.level,
		form = formId,
		formData = form,
		caster = caster,
	}
	local function compute(atRank)
		return Gear.Compute(ctx.gear, withRank(talents, talent, atRank), info)
	end

	local current = rank > 0 and difference(compute(0), compute(rank)) or {}
	local nextRank = rank < maxRank and difference(compute(rank), compute(rank + 1)) or {}

	local header = ctx.owner and L["With the gear of %s:"]:format(ctx.owner) or L["With your gear:"]
	if otherForm and form and form.spell then
		header = ("%s (%s)"):format(header, (GetSpellInfo(form.spell)))
	end
	tooltip:AddLine(" ")
	tooltip:AddLine(header, NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b)
	if #current == 0 and #nextRank == 0 then
		tooltip:AddLine(L["No effect with this gear."], 0.6, 0.6, 0.6, true)
	end
	addLines(tooltip, current)
	if #nextRank > 0 then
		if rank > 0 then
			tooltip:AddLine(L["Next rank:"], 0.6, 0.6, 0.6)
		end
		addLines(tooltip, nextRank)
	end
	tooltip:Show()
end

hooksecurefunc(GameTooltip, "SetTalent", onSetTalent)
