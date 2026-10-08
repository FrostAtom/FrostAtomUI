local _, ns = ...
local UF = ns:GetModule("UnitFrames")

local GetSpellInfo = GetSpellInfo
local GetTime = GetTime
local UnitGUID = UnitGUID
local band = bit.band
local random, huge = math.random, math.huge

local Auras = ns.Auras
local Data = ns.LoseControlData
local CooldownTimer = ns:GetModule("CooldownTimer")
local config = ns.Config.loseControl

local BY_ID = Data.BY_ID
local PRIORITY = Data.PRIORITY
local FILTERS = { "HARMFUL", "HELPFUL" }
local TIMER_FONT_SIZE = 10
local HOSTILE_PLAYER = 0x100
local REACTION_HOSTILE = COMBATLOG_OBJECT_REACTION_HOSTILE
local LOCKOUT_PRIORITY = PRIORITY.silence
local CENTER_SIZE = 0.6

UF.ccSpellNames = Data.CONTROL_NAMES

local widgets = {}
local lockouts = {}

local function isShown(spell)
	return config.spells[spell[1]] ~= false
end

local function isActive(loseControl)
	return config.enabled and config.frames[loseControl.kind]
end

local function layout(loseControl)
	local frame = loseControl:GetParent()
	local icon = frame.classicon
	loseControl:ClearAllPoints()
	local inside = icon and UF.ClassIconShown(frame)
	if inside then
		loseControl:SetAllPoints(icon)
	else
		local size = frame:GetHeight() * CENTER_SIZE
		loseControl:SetSize(size, size)
		loseControl:SetPoint("CENTER", frame)
	end
	local trim = inside and UF.SPELL_TRIM or 0
	loseControl.texture:SetTexCoord(trim, 1 - trim, trim, 1 - trim)
	ns.SetShown(loseControl.border, not inside)
end

local function show(loseControl, texture, start, duration)
	layout(loseControl)
	loseControl.texture:SetTexture(texture)
	if start ~= loseControl.start or duration ~= loseControl.duration then
		loseControl.start, loseControl.duration = start, duration
		loseControl:SetCooldown(start, duration)
	end
	loseControl:Show()
end

local function hide(loseControl)
	loseControl.start = nil
	loseControl:Hide()
end

local function update(frame)
	local loseControl = frame.losecontrol
	if not isActive(loseControl) then
		hide(loseControl)
		return
	end

	local best, bestPriority, bestExpires
	for f = 1, #FILTERS do
		local auras, count = Auras.Get(frame.unit, FILTERS[f])
		for i = 1, count do
			local aura = auras[i]
			local spell = BY_ID[aura.spellId]
			if spell and isShown(spell) then
				local priority = PRIORITY[spell.category]
				local expires = aura.expires == 0 and huge or aura.expires
				if not best or priority > bestPriority or priority == bestPriority and expires > bestExpires then
					best, bestPriority, bestExpires = aura, priority, expires
				end
			end
		end
	end

	local lockout = config.lockouts and lockouts[UnitGUID(frame.unit) or ""]
	if lockout and lockout.expires > GetTime() then
		if
			not best
			or LOCKOUT_PRIORITY > bestPriority
			or LOCKOUT_PRIORITY == bestPriority and lockout.expires > bestExpires
		then
			show(loseControl, lockout.icon, lockout.expires - lockout.duration, lockout.duration)
			return
		end
	end

	if best then
		show(loseControl, best.icon, best.expires - best.duration, best.duration)
	else
		hide(loseControl)
	end
end

local function test(frame)
	local loseControl = frame.losecontrol
	if not isActive(loseControl) or random(3) ~= 1 then
		hide(loseControl)
		return
	end
	local shown = {}
	for _, spells in pairs(Data.SPELLS) do
		for _, spell in ipairs(spells) do
			if isShown(spell) then
				shown[#shown + 1] = spell[1]
			end
		end
	end
	if #shown == 0 then
		hide(loseControl)
		return
	end
	local _, _, texture = GetSpellInfo(shown[random(#shown)])
	local duration = random(4, 10)
	show(loseControl, texture, GetTime() - random(0, duration - 2), duration)
end

local function create(frame)
	local loseControl = CreateFrame("Cooldown", nil, frame)
	loseControl:SetReverse(true)
	loseControl.kind = frame.baseUnit:match("^%a+")
	CooldownTimer:Attach(loseControl, TIMER_FONT_SIZE)

	loseControl.texture = loseControl:CreateTexture(nil, "BORDER")
	UF.SkinIcon(loseControl, loseControl.texture)

	loseControl:SetFrameLevel((frame.classicon or frame):GetFrameLevel() + 3)
	widgets[#widgets + 1] = loseControl

	frame:RegisterUnitEvent("UNIT_AURA", update)

	return loseControl
end

UF:RegisterElement({ name = "losecontrol", Create = create, Update = update, Test = test })

local function refreshGUID(guid)
	for i = 1, #widgets do
		local frame = widgets[i]:GetParent()
		if frame:IsShown() and not frame.test and UnitGUID(frame.unit) == guid then
			update(frame)
		end
	end
end

local function onInterrupt(_, _, _, _, _, _, destGUID, _, destFlags, spellId, _, _, interruptedId)
	if not config.lockouts or band(destFlags, HOSTILE_PLAYER) == 0 or band(destFlags, REACTION_HOSTILE) == 0 then
		return
	end
	local duration = ns.SpellDB.Lockout(spellId)
	if not duration then
		return
	end
	local _, _, icon = GetSpellInfo(interruptedId or spellId)
	local now = GetTime()
	lockouts[destGUID] =
		{ expires = now + duration, duration = duration, icon = icon or select(3, GetSpellInfo(spellId)) }
	refreshGUID(destGUID)
	ns.After(duration + 0.05, function()
		local entry = lockouts[destGUID]
		if entry and entry.expires <= GetTime() then
			lockouts[destGUID] = nil
			refreshGUID(destGUID)
		end
	end)
end

ns.CombatLog.Register(lockouts, { "SPELL_INTERRUPT" }, onInterrupt)

UF:OnInitialize(function(self)
	self:WatchConfig("loseControl", function()
		for i = 1, #widgets do
			local frame = widgets[i]:GetParent()
			if frame.test then
				test(frame)
			elseif frame:IsShown() then
				update(frame)
			end
		end
	end)
end)
