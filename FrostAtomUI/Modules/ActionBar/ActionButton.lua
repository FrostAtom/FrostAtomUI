local ADDON_NAME, ns = ...

local CooldownFrame_SetTimer = CooldownFrame_SetTimer
local GetActionTexture = GetActionTexture
local GetActionCooldown = GetActionCooldown
local GetActionCount = GetActionCount
local GetActionText = GetActionText
local GetBindingKey = GetBindingKey
local HasAction = HasAction
local IsActionInRange = IsActionInRange
local IsUsableAction = IsUsableAction
local IsEquippedAction = IsEquippedAction
local IsCurrentAction = IsCurrentAction
local IsAutoRepeatAction = IsAutoRepeatAction
local IsConsumableAction = IsConsumableAction
local IsStackableAction = IsStackableAction
local InCombatLockdown = InCombatLockdown
local PickupAction = PickupAction
local GetActionInfo = GetActionInfo
local GetMacroSpell = GetMacroSpell
local GetSpellInfo = GetSpellInfo
local UnitGUID = UnitGUID
local UnitExists = UnitExists
local GetTime = GetTime
local GameTooltip = GameTooltip
local max = math.max
local band = bit.band

local Media = ns.Media
local Auras = ns.Auras
local ActionBar = ns:GetModule("ActionBar")
local CooldownTimer = ns:GetModule("CooldownTimer")

local config = ns.Config.actionBar
local WHITE = { 1, 1, 1 }
local BUTTON_NAME = ADDON_NAME .. "ActionButton%d"
local BINDING_NAME = "CLICK " .. BUTTON_NAME .. ":LeftButton"
local SLOT_NAME = ADDON_NAME .. "ActionSlot%d"
ActionBar.BINDING_NAME = BINDING_NAME
local RANGE_CHECK_INTERVAL = 0.1
local GCD_DURATION = 1.5
local MAX_INTERRUPT_LOCKOUT = 8
local INTERRUPT_TOLERANCE = 0.5
local RECEIVE_DRAG_SNIPPET = [[
	if not kind then
		return false
	end
	return "action", self:GetAttribute("action")
]]
local SLOT_VISIBILITY_SNIPPET = [[
	local button = self:GetFrameRef("button")
	if self:IsShown() and button:GetAttribute("slotactive") then
		button:Show()
	else
		button:Hide()
	end
]]

local STUN, FEAR, CONFUSE, BANISH, POSSESS, PACIFY_SILENCE, SILENCE = 1, 2, 3, 4, 5, 6, 7
local PREVENTION_NONE, PREVENTION_SILENCE, PREVENTION_PACIFY = 0, 1, 2

local MECHANIC_CHARM = 1
local MECHANIC_DISORIENTED = 2
local MECHANIC_FEAR = 5
local MECHANIC_SLEEP = 10
local MECHANIC_STUN = 12
local MECHANIC_FREEZE = 13
local MECHANIC_KNOCKOUT = 14
local MECHANIC_POLYMORPH = 17
local MECHANIC_TURN = 20
local MECHANIC_HORROR = 24
local MECHANIC_SAPPED = 30

local SCHOOL_PHYSICAL, SCHOOL_HOLY, SCHOOL_FIRE, SCHOOL_NATURE, SCHOOL_FROST, SCHOOL_SHADOW, SCHOOL_ARCANE =
	1, 2, 4, 8, 16, 32, 64
local SCHOOL_ALL = 127

local DISPEL_MAGIC, DISPEL_CURSE, DISPEL_DISEASE, DISPEL_POISON = 1, 2, 3, 4

local CONTROL_SPELLS = {
	[47481] = { STUN, MECHANIC_STUN, SCHOOL_PHYSICAL }, -- Gnaw
	[51209] = { STUN, MECHANIC_FREEZE, SCHOOL_FROST, DISPEL_MAGIC }, -- Hungering Cold
	[5211] = { STUN, MECHANIC_STUN, SCHOOL_PHYSICAL }, -- Bash
	[33786] = { BANISH }, -- Cyclone
	[2637] = { STUN, MECHANIC_SLEEP, SCHOOL_NATURE, DISPEL_MAGIC }, -- Hibernate
	[22570] = { STUN, MECHANIC_STUN, SCHOOL_PHYSICAL }, -- Maim
	[9005] = { STUN, MECHANIC_STUN, SCHOOL_PHYSICAL }, -- Pounce
	[60210] = { STUN, MECHANIC_FREEZE, SCHOOL_FROST, DISPEL_MAGIC }, -- Freezing Arrow Effect
	[3355] = { STUN, MECHANIC_FREEZE, SCHOOL_FROST, DISPEL_MAGIC }, -- Freezing Trap Effect
	[24394] = { STUN, MECHANIC_STUN, SCHOOL_PHYSICAL }, -- Intimidation
	[1513] = { FEAR, MECHANIC_FEAR, SCHOOL_NATURE, DISPEL_MAGIC }, -- Scare Beast
	[19503] = { CONFUSE, MECHANIC_DISORIENTED, SCHOOL_PHYSICAL }, -- Scatter Shot
	[19386] = { STUN, MECHANIC_SLEEP, SCHOOL_NATURE, DISPEL_POISON }, -- Wyvern Sting
	[50519] = { STUN, MECHANIC_STUN, SCHOOL_NATURE }, -- Sonic Blast
	[50518] = { STUN, MECHANIC_STUN, SCHOOL_PHYSICAL }, -- Ravage
	[44572] = { STUN, MECHANIC_STUN, SCHOOL_FROST, DISPEL_MAGIC }, -- Deep Freeze
	[31661] = { CONFUSE, MECHANIC_DISORIENTED, SCHOOL_FIRE, DISPEL_MAGIC }, -- Dragon's Breath
	[12355] = { STUN, MECHANIC_STUN, SCHOOL_FIRE }, -- Impact
	[118] = { CONFUSE, MECHANIC_POLYMORPH, SCHOOL_ARCANE, DISPEL_MAGIC }, -- Polymorph
	[853] = { STUN, MECHANIC_STUN, SCHOOL_HOLY, DISPEL_MAGIC }, -- Hammer of Justice
	[2812] = { STUN, MECHANIC_STUN, SCHOOL_HOLY, DISPEL_MAGIC }, -- Holy Wrath
	[20066] = { STUN, MECHANIC_KNOCKOUT, SCHOOL_HOLY, DISPEL_MAGIC }, -- Repentance
	[20170] = { STUN, MECHANIC_STUN, SCHOOL_HOLY }, -- Stun
	[10326] = { FEAR, MECHANIC_TURN, SCHOOL_HOLY, DISPEL_MAGIC }, -- Turn Evil
	[605] = { POSSESS }, -- Mind Control
	[64044] = { STUN, MECHANIC_HORROR, SCHOOL_SHADOW, DISPEL_MAGIC }, -- Psychic Horror
	[8122] = { FEAR, MECHANIC_FEAR, SCHOOL_SHADOW, DISPEL_MAGIC }, -- Psychic Scream
	[9484] = { STUN, MECHANIC_TURN, SCHOOL_HOLY, DISPEL_MAGIC }, -- Shackle Undead
	[2094] = { CONFUSE, MECHANIC_DISORIENTED, SCHOOL_PHYSICAL }, -- Blind
	[1833] = { STUN, MECHANIC_STUN, SCHOOL_PHYSICAL }, -- Cheap Shot
	[1776] = { STUN, MECHANIC_KNOCKOUT, SCHOOL_PHYSICAL }, -- Gouge
	[408] = { STUN, MECHANIC_STUN, SCHOOL_PHYSICAL }, -- Kidney Shot
	[6770] = { STUN, MECHANIC_SAPPED, SCHOOL_PHYSICAL }, -- Sap
	[39796] = { STUN, MECHANIC_STUN, SCHOOL_PHYSICAL, DISPEL_MAGIC }, -- Stoneclaw Stun
	[51514] = { PACIFY_SILENCE, MECHANIC_POLYMORPH, SCHOOL_NATURE, DISPEL_CURSE }, -- Hex
	[710] = { BANISH }, -- Banish
	[6789] = { FEAR, MECHANIC_HORROR, SCHOOL_SHADOW, DISPEL_MAGIC }, -- Death Coil
	[5782] = { FEAR, MECHANIC_FEAR, SCHOOL_SHADOW, DISPEL_MAGIC }, -- Fear
	[5484] = { FEAR, MECHANIC_FEAR, SCHOOL_SHADOW, DISPEL_MAGIC }, -- Howl of Terror
	[6358] = { STUN, MECHANIC_CHARM, SCHOOL_SHADOW, DISPEL_MAGIC }, -- Seduction
	[30283] = { STUN, MECHANIC_STUN, SCHOOL_SHADOW, DISPEL_MAGIC }, -- Shadowfury
	[22703] = { STUN, MECHANIC_STUN, SCHOOL_FIRE }, -- Inferno Effect
	[7922] = { STUN, MECHANIC_STUN, SCHOOL_PHYSICAL }, -- Charge Stun
	[12809] = { STUN, MECHANIC_STUN, SCHOOL_PHYSICAL }, -- Concussion Blow
	[20253] = { STUN, MECHANIC_STUN, SCHOOL_PHYSICAL }, -- Intercept
	[5246] = { FEAR, MECHANIC_FEAR, SCHOOL_PHYSICAL }, -- Intimidating Shout
	[12798] = { STUN, MECHANIC_STUN, SCHOOL_PHYSICAL }, -- Revenge Stun
	[46968] = { STUN, MECHANIC_STUN, SCHOOL_PHYSICAL }, -- Shockwave
	[20549] = { STUN, MECHANIC_STUN, SCHOOL_PHYSICAL }, -- War Stomp
	[30217] = { STUN, MECHANIC_KNOCKOUT, SCHOOL_FIRE }, -- Adamantite Grenade
	[67769] = { STUN, MECHANIC_KNOCKOUT, SCHOOL_FIRE }, -- Cobalt Frag Bomb
	[30216] = { STUN, MECHANIC_KNOCKOUT, SCHOOL_FIRE }, -- Fel Iron Bomb
}

local SILENCE_SPELLS = {
	47476, -- Strangulate
	34490, -- Silencing Shot
	18469, -- Silenced - Improved Counterspell
	63529, -- Silenced - Shield of the Templar
	15487, -- Silence
	1330, -- Garrote - Silence
	18425, -- Silenced - Improved Kick
	24259, -- Spell Lock
	18498, -- Silenced - Gag Order
	25046, -- Arcane Torrent
}

local SILENCE_CONTROL = { SILENCE }

local ID_CONTROLS = {
	[31117] = SILENCE_CONTROL, -- Unstable Affliction
	[64058] = false, -- Psychic Horror
}

local CONTROL_BREAKERS = {
	[59752] = { any = true }, -- Every Man for Himself
	[7744] = { mechanics = { MECHANIC_FEAR, MECHANIC_SLEEP, MECHANIC_CHARM } }, -- Will of the Forsaken
	[18499] = { mechanics = { MECHANIC_FEAR, MECHANIC_KNOCKOUT, MECHANIC_SAPPED } }, -- Berserker Rage
	[49039] = { -- Lichborne
		mechanics = { MECHANIC_STUN, MECHANIC_FEAR, MECHANIC_DISORIENTED, MECHANIC_CHARM, MECHANIC_SLEEP },
	},
	[19574] = { mechanics = { MECHANIC_STUN, MECHANIC_FEAR, MECHANIC_DISORIENTED } }, -- Bestial Wrath
	[22812] = { -- Barkskin
		mechanics = {
			MECHANIC_STUN,
			MECHANIC_FREEZE,
			MECHANIC_KNOCKOUT,
			MECHANIC_SLEEP,
			MECHANIC_FEAR,
			MECHANIC_HORROR,
		},
	},
	[33206] = { mechanics = { MECHANIC_STUN } }, -- Pain Suppression
	[47585] = { mechanics = { MECHANIC_STUN, MECHANIC_FEAR } }, -- Dispersion
	[30823] = { mechanics = { MECHANIC_STUN } }, -- Shamanistic Rage
	[51490] = { mechanics = { MECHANIC_STUN } }, -- Thunderstorm
	[50334] = { mechanics = { MECHANIC_FEAR } }, -- Berserk
	[1044] = { mechanics = { MECHANIC_STUN } }, -- Hand of Freedom
	[1953] = { mechanics = { MECHANIC_STUN } }, -- Blink
	[48792] = { mechanics = { MECHANIC_STUN } }, -- Icebound Fortitude
	[10278] = { school = SCHOOL_PHYSICAL }, -- Hand of Protection
	[642] = { school = SCHOOL_ALL }, -- Divine Shield
	[45438] = { school = SCHOOL_ALL }, -- Ice Block
	[20594] = { dispels = { DISPEL_DISEASE, DISPEL_POISON } }, -- Stoneform
	[768] = { mechanics = { MECHANIC_POLYMORPH } }, -- Cat Form
	[5487] = { mechanics = { MECHANIC_POLYMORPH } }, -- Bear Form
	[9634] = { mechanics = { MECHANIC_POLYMORPH } }, -- Dire Bear Form
	[783] = { mechanics = { MECHANIC_POLYMORPH } }, -- Travel Form
	[1066] = { mechanics = { MECHANIC_POLYMORPH } }, -- Aquatic Form
	[33943] = { mechanics = { MECHANIC_POLYMORPH } }, -- Flight Form
	[40120] = { mechanics = { MECHANIC_POLYMORPH } }, -- Swift Flight Form
	[24858] = { mechanics = { MECHANIC_POLYMORPH } }, -- Moonkin Form
	[33891] = { mechanics = { MECHANIC_POLYMORPH } }, -- Tree of Life
	[53563] = { ignore = true }, -- Beacon of Light
	[5171] = { ignore = true }, -- Slice and Dice
	[36554] = { ignore = true }, -- Shadowstep
	[51662] = { ignore = true }, -- Hunger For Blood
	[1130] = { ignore = true }, -- Hunter's Mark
	[49376] = { ignore = true }, -- Feral Charge - Cat
	[2096] = { ignore = true }, -- Mind Vision
}

local NO_PREVENTION_SPELLS = {
	48778, -- Acherus Deathcharger
	13750, -- Adrenaline Rush
	1066, -- Aquatic Form
	31821, -- Aura Mastery
	5487, -- Bear Form
	1462, -- Beast Lore
	50334, -- Berserk
	18499, -- Berserker Rage
	19574, -- Bestial Wrath
	13877, -- Blade Flurry
	883, -- Call Pet
	62757, -- Call Stabled Pet
	66843, -- Call of the Ancestors
	66842, -- Call of the Elements
	66844, -- Call of the Spirits
	768, -- Cat Form
	23214, -- Charger
	8170, -- Cleansing Totem
	14177, -- Cold Blood
	29886, -- Create Soulwell
	1850, -- Dash
	12292, -- Death Wish
	71, -- Defensive Stance
	9634, -- Dire Bear Form
	1842, -- Disarm Trap
	781, -- Disengage
	2641, -- Dismiss Pet
	47585, -- Dispersion
	19752, -- Divine Intervention
	64205, -- Divine Sacrifice
	23161, -- Dreadsteed
	2062, -- Earth Elemental Totem
	2484, -- Earthbind Totem
	5229, -- Enrage
	55694, -- Enraged Regeneration
	59752, -- Every Man for Himself
	57532, -- Eye of Acherus
	6991, -- Feed Pet
	5384, -- Feign Death
	5784, -- Felsteed
	2481, -- Find Treasure
	2894, -- Fire Elemental Totem
	8184, -- Fire Resistance Totem
	8227, -- Flametongue Totem
	33943, -- Flight Form
	8181, -- Frost Resistance Totem
	8177, -- Grounding Totem
	5394, -- Healing Stream Totem
	51662, -- Hunger For Blood
	1130, -- Hunter's Mark
	51690, -- Killing Spree
	49039, -- Lichborne
	8190, -- Magma Totem
	5675, -- Mana Spring Totem
	16190, -- Mana Tide Totem
	49005, -- Mark of Blood
	53271, -- Master's Call
	47241, -- Metamorphosis
	24858, -- Moonkin Form
	10595, -- Nature Resistance Totem
	3714, -- Path of Frost
	14183, -- Premeditation
	14185, -- Preparation
	5215, -- Prowl
	3045, -- Rapid Fire
	23989, -- Readiness
	3599, -- Searing Totem
	5500, -- Sense Demons
	5502, -- Sense Undead
	6495, -- Sentry Totem
	51713, -- Shadow Dance
	15473, -- Shadowform
	64382, -- Shattering Throw
	2565, -- Shield Block
	1784, -- Stealth
	5730, -- Stoneclaw Totem
	8071, -- Stoneskin Totem
	8075, -- Strength of Earth Totem
	34767, -- Summon Charger
	34769, -- Summon Warhorse
	61336, -- Survival Instincts
	40120, -- Swift Flight Form
	1515, -- Tame Beast
	55198, -- Tidal Force
	5217, -- Tiger's Fury
	30706, -- Totem of Wrath
	1494, -- Track Beasts
	19878, -- Track Demons
	19879, -- Track Dragonkin
	19880, -- Track Elementals
	19882, -- Track Giants
	19885, -- Track Hidden
	5225, -- Track Humanoids
	19884, -- Track Undead
	783, -- Travel Form
	33891, -- Tree of Life
	8143, -- Tremor Totem
	57933, -- Tricks of the Trade
	51271, -- Unbreakable Armor
	55233, -- Vampiric Blood
	13819, -- Warhorse
	7744, -- Will of the Forsaken
	8512, -- Windfury Totem
	3738, -- Wrath of Air Totem
}

local SILENCE_PREVENTION_SPELLS = {
	2048, -- Battle Shout
	59671, -- Challenging Howl
	5209, -- Challenging Roar
	1161, -- Challenging Shout
	469, -- Commanding Shout
	56222, -- Dark Command
	99, -- Demoralizing Roar
	1160, -- Demoralizing Shout
	1725, -- Distract
	16857, -- Faerie Fire (Feral)
	6795, -- Growl
	5246, -- Intimidating Shout
	12323, -- Piercing Howl
	355, -- Taunt
	6343, -- Thunder Clap
	28730, -- Arcane Torrent
}

local PACIFY_PREVENTION_SPELLS = {
	19434, -- Aimed Shot
	3044, -- Arcane Shot
	75, -- Auto Shot
	3674, -- Black Arrow
	20572, -- Blood Fury
	48266, -- Blood Presence
	45902, -- Blood Strike
	45529, -- Blood Tap
	2687, -- Bloodrage
	20577, -- Cannibalize
	53209, -- Chimera Shot
	31224, -- Cloak of Shadows
	5116, -- Concussive Shot
	19306, -- Counterattack
	35395, -- Crusader Strike
	49998, -- Death Strike
	54785, -- Demon Charge
	19263, -- Deterrence
	20736, -- Distracting Shot
	53385, -- Divine Storm
	20589, -- Escape Artist
	53301, -- Explosive Shot
	48263, -- Frost Presence
	49143, -- Frost Strike
	53595, -- Hammer of the Righteous
	55050, -- Heart Strike
	53351, -- Kill Shot
	12975, -- Last Stand
	60103, -- Lava Lash
	34477, -- Misdirection
	1495, -- Mongoose Bite
	2643, -- Multi-Shot
	49020, -- Obliterate
	45462, -- Plague Strike
	2973, -- Raptor Strike
	56815, -- Rune Strike
	19503, -- Scatter Shot
	3043, -- Scorpid Sting
	55090, -- Scourge Strike
	1978, -- Serpent Sting
	50581, -- Shadow Cleave
	58984, -- Shadowmeld
	34490, -- Silencing Shot
	56641, -- Steady Shot
	20594, -- Stoneform
	17364, -- Stormstrike
	19801, -- Tranquilizing Shot
	48265, -- Unholy Presence
	50720, -- Vigilance
	3034, -- Viper Sting
	1510, -- Volley
	20549, -- War Stomp
	2974, -- Wing Clip
	19386, -- Wyvern Sting
}

local PHYSICAL_POWER_TYPES = {
	[1] = true,
	[3] = true,
}

local function mapSpellNames(target, spells, value)
	for i = 1, #spells do
		local name = GetSpellInfo(spells[i])
		if name then
			target[name] = value
		end
	end
end

local function toSet(values)
	local set = {}
	if values then
		for i = 1, #values do
			set[values[i]] = true
		end
	end
	return set
end

local NAME_CONTROLS = {}
for id, control in pairs(CONTROL_SPELLS) do
	local name = GetSpellInfo(id)
	if name then
		NAME_CONTROLS[name] = control
	end
end
mapSpellNames(NAME_CONTROLS, SILENCE_SPELLS, SILENCE_CONTROL)

local BREAKER_NAMES = {}
for id, breaker in pairs(CONTROL_BREAKERS) do
	local name = GetSpellInfo(id)
	if name then
		BREAKER_NAMES[name] = {
			any = breaker.any,
			ignore = breaker.ignore,
			school = breaker.school or 0,
			mechanics = toSet(breaker.mechanics),
			dispels = toSet(breaker.dispels),
		}
	end
end

local PREVENTION_NAMES = {}
mapSpellNames(PREVENTION_NAMES, NO_PREVENTION_SPELLS, PREVENTION_NONE)
mapSpellNames(PREVENTION_NAMES, SILENCE_PREVENTION_SPELLS, PREVENTION_SILENCE)
mapSpellNames(PREVENTION_NAMES, PACIFY_PREVENTION_SPELLS, PREVENTION_PACIFY)

local function isBlocked(prevention, breaker, control)
	local kind = control[1]
	if kind == SILENCE then
		return prevention == PREVENTION_SILENCE
	elseif kind == POSSESS then
		return true
	elseif kind == PACIFY_SILENCE and prevention == PREVENTION_NONE then
		return false
	elseif not breaker then
		return true
	elseif breaker.ignore then
		return false
	elseif kind == BANISH then
		return true
	elseif breaker.any and kind ~= PACIFY_SILENCE then
		return false
	end
	return not (
		breaker.mechanics[control[2]]
		or band(breaker.school, control[3]) ~= 0
		or (control[4] and breaker.dispels[control[4]])
	)
end

local activeControls = {}
local interruptedAt = -math.huge
local actionButtons = {}
local hasTarget = false

local DRAG_MODIFIERS = {
	shift = IsShiftKeyDown,
	ctrl = IsControlKeyDown,
	alt = IsAltKeyDown,
}

local ACTION_EVENTS = {
	UPDATE_SHAPESHIFT_FORM = "Update",
	UPDATE_MACROS = "Update",
	ACTIONBAR_UPDATE_USABLE = "UpdateUsable",
	ACTIONBAR_UPDATE_COOLDOWN = "UpdateCooldown",
	ACTIONBAR_UPDATE_STATE = "UpdateState",
	PLAYER_EQUIPMENT_CHANGED = "UpdateEquipped",
	UNIT_ENTERED_VEHICLE = "UpdateStateForUnit",
	UNIT_EXITED_VEHICLE = "UpdateStateForUnit",
	TRADE_SKILL_SHOW = "UpdateState",
	TRADE_SKILL_CLOSE = "UpdateState",
	COMPANION_UPDATE = "UpdateStateForCompanion",
	BAG_UPDATE = "UpdateName",
	SPELL_UPDATE_USABLE = "UpdateUsable",
}

local KEY_ABBREVIATIONS = {
	{ "BUTTON", "B" },
	{ "ALT%-", "A" },
	{ "CTRL%-", "C" },
	{ "SHIFT%-", "S" },
	{ "MOUSEWHEELUP", "WU" },
	{ "MOUSEWHEELDOWN", "WD" },
	{ "CAPSLOCK", "Caps\nLock" },
}

local function abbreviateKey(key)
	for i = 1, #KEY_ABBREVIATIONS do
		local pair = KEY_ABBREVIATIONS[i]
		key = key:gsub(pair[1], pair[2])
	end
	return key
end
local function updateHotkey(button)
	local key = GetBindingKey(button.bindingName)
	if not key and button.blizzardBinding then
		key = GetBindingKey(button.blizzardBinding)
	end
	if key then
		button.hotkey:SetText(abbreviateKey(key))
		button.hotkey:Show()
	else
		button.hotkey:Hide()
	end
end
ActionBar.UpdateHotkey = updateHotkey

local ActionButtonMixin = {}

local function applyColors(button, r, g, b)
	button.icon:SetVertexColor(r, g, b)
	button:GetNormalTexture():SetVertexColor(r, g, b)
end

function ActionButtonMixin:UpdateColors()
	local color
	if self.notEnoughMana then
		color = config.manaColor
	elseif self.outOfRange and config.rangeIconTint then
		color = config.rangeColor
	elseif self.usable then
		color = WHITE
	else
		color = config.unusableColor
	end
	applyColors(self, color[1], color[2], color[3])

	color = self.outOfRange and config.rangeHotkey and config.rangeColor or WHITE
	self.hotkey:SetTextColor(color[1], color[2], color[3])
end

function ActionButtonMixin:UpdateUsable()
	self.usable, self.notEnoughMana = IsUsableAction(self.action)
	self:UpdateColors()
end

function ActionButtonMixin:UpdateEquipped()
	ActionBar:SetButtonEquipped(self, IsEquippedAction(self.action))
end

function ActionButtonMixin:UpdateState()
	ActionBar:SetButtonChecked(self, IsCurrentAction(self.action) or IsAutoRepeatAction(self.action))
end

function ActionButtonMixin:UpdateStateForUnit(unit)
	if unit == "player" then
		self:UpdateState()
	end
end

function ActionButtonMixin:UpdateStateForCompanion(companionType)
	if companionType == "MOUNT" then
		self:UpdateState()
	end
end

function ActionButtonMixin:UpdateBindings()
	updateHotkey(self)
end

function ActionButtonMixin:UpdateName()
	local action = self.action
	if IsConsumableAction(action) or IsStackableAction(action) then
		local count = GetActionCount(action)
		self.count:SetText(count > 999 and "*" or count)
		self.name:SetText("")
	else
		self.count:SetText("")
		self.name:SetText(GetActionText(action))
	end
end

function ActionButtonMixin:UpdateGrid()
	if InCombatLockdown() then
		return
	end
	local slot = self.slot
	local extra = (config.hideEmptyButtons and 0 or 1) + (ActionBar:IsBindMode() and 1 or 0)
	local grid = max(slot:GetAttribute("showgrid") - self.gridExtra + extra, 0)
	self.gridExtra = extra
	slot:SetAttribute("showgrid", grid)
	if grid > 0 then
		ActionButton_ShowGrid(slot)
	else
		ActionButton_HideGrid(slot)
	end
	ns.SetShown(self, self:GetAttribute("slotactive") and slot:IsShown())
end

function ActionButtonMixin:UpdateIcon()
	local texture = GetActionTexture(self.action)
	if not texture then
		texture = Media.emptySlot
	elseif texture == "" then
		texture = Media.questionMark
	end
	self.icon:SetTexture(texture)
end

local function actionSpellName(action)
	local actionType, id, _, spellId = GetActionInfo(action)
	if actionType == "spell" then
		return spellId and GetSpellInfo(spellId)
	elseif actionType == "macro" then
		return GetMacroSpell(id)
	end
end

function ActionButtonMixin:UpdateSpellFlags()
	local name = actionSpellName(self.action)
	self.spellName = name
	if not name then
		return
	end
	local prevention = PREVENTION_NAMES[name]
	if not prevention then
		local _, _, _, _, _, powerType = GetSpellInfo(name)
		prevention = PHYSICAL_POWER_TYPES[powerType] and PREVENTION_PACIFY or PREVENTION_SILENCE
	end
	self.prevention = prevention
	self.controlBreaker = BREAKER_NAMES[name]
end

function ActionButtonMixin:UpdateLockout(now)
	local start, duration, endTime = 0, 0, 0
	if self.hasAction then
		if self.spellName then
			for i = 1, #activeControls do
				local active = activeControls[i]
				if active.expires > endTime and isBlocked(self.prevention, self.controlBreaker, active.control) then
					start, duration, endTime = active.expires - active.duration, active.duration, active.expires
				end
			end
		end
		if self.schoolLocked and self.cooldownEnd > endTime then
			start, duration, endTime = self.cooldownEnd - self.cooldownDuration, self.cooldownDuration, self.cooldownEnd
		end
	end

	local lockout = self.lockout
	if endTime > now and endTime >= self.cooldownEnd then
		if not lockout then
			lockout = CreateFrame("Cooldown", nil, self)
			lockout:SetAllPoints()
			lockout:SetFrameLevel(self.cooldown:GetFrameLevel() + 1)
			lockout.tint = lockout:CreateTexture(nil, "BACKGROUND")
			lockout.tint:SetAllPoints()
			lockout.tint:SetTexture(Media.blank)
			self.lockout = lockout
		end
		local color = config.lossOfControlColor
		lockout.tint:SetVertexColor(color[1], color[2], color[3], color[4])
		if not lockout:IsShown() then
			lockout:Show()
			self.cooldown:SetAlpha(0)
		end
		if start ~= lockout.start or duration ~= lockout.duration then
			lockout.start, lockout.duration = start, duration
			lockout:SetCooldown(start, duration)
		end
		self.lockoutEnd = endTime
	elseif lockout and lockout:IsShown() then
		lockout.start = nil
		lockout:Hide()
		self.cooldown:SetAlpha(1)
		self.lockoutEnd = nil
	end
end

function ActionButtonMixin:UpdateCooldown()
	local start, duration, enable = GetActionCooldown(self.action)
	CooldownFrame_SetTimer(self.cooldown, start, duration, enable)

	local now = GetTime()
	local endTime = start + duration
	if enable == 1 and duration > GCD_DURATION and endTime > now then
		self.cooldownEnd, self.cooldownDuration = endTime, duration
		self.schoolLocked = config.interruptLockout
			and duration <= MAX_INTERRUPT_LOCKOUT
			and start > interruptedAt - INTERRUPT_TOLERANCE
			and start < interruptedAt + INTERRUPT_TOLERANCE
	else
		self.cooldownEnd, self.cooldownDuration = 0, 0
		self.schoolLocked = false
	end

	local desaturated = config.desaturateOnCooldown and self.cooldownEnd > 0 or false
	if desaturated ~= self.desaturated then
		self.desaturated = desaturated
		self.icon:SetDesaturated(desaturated)
	end

	self:UpdateLockout(now)

	local expiry = self.lockoutEnd
	if desaturated and (not expiry or self.cooldownEnd < expiry) then
		expiry = self.cooldownEnd
	end
	self.expiry = expiry
end

function ActionButtonMixin:Update()
	local action = self.action

	if HasAction(action) then
		for event, method in pairs(ACTION_EVENTS) do
			self:RegisterEvent(event, method)
		end

		self.usable, self.notEnoughMana = IsUsableAction(action)
		self.outOfRange = hasTarget and IsActionInRange(action) == 0
		self.hasAction = true
	elseif self.hasAction then
		for event, method in pairs(ACTION_EVENTS) do
			self:UnregisterEvent(event, method)
		end

		self.usable = true
		self.notEnoughMana, self.outOfRange = nil, nil
		self.hasAction = false
	end

	self:UpdateGrid()
	self:UpdateColors()
	self:UpdateEquipped()
	self:UpdateState()
	self:UpdateBindings()
	self:UpdateIcon()
	self:UpdateSpellFlags()
	self:UpdateCooldown()
	self:UpdateName()
end

function ActionButtonMixin:UpdateRange()
	local outOfRange = hasTarget and IsActionInRange(self.action) == 0
	if outOfRange ~= self.outOfRange then
		self.outOfRange = outOfRange
		self:UpdateColors()
	end
end

local nextRangeCheck = 0

local rangeTicker = CreateFrame("Frame")
rangeTicker:Hide()
rangeTicker:SetScript("OnUpdate", function()
	local now = GetTime()
	if now < nextRangeCheck then
		return
	end
	nextRangeCheck = now + RANGE_CHECK_INTERVAL

	for i = 1, #actionButtons do
		local button = actionButtons[i]
		if button.hasAction then
			local expiry = button.expiry
			if expiry and now >= expiry then
				button:UpdateCooldown()
			end
			if hasTarget and button:IsVisible() then
				button:UpdateRange()
			end
		end
	end
end)

function ActionBar:UpdateGrid()
	for i = 1, #actionButtons do
		actionButtons[i]:UpdateGrid()
	end
end

local function onTargetChanged()
	hasTarget = UnitExists("target") and true or false
	for i = 1, #actionButtons do
		local button = actionButtons[i]
		if button.hasAction then
			button:UpdateRange()
		end
	end
end

function ActionButtonMixin:OnAttributeChanged(attribute, value)
	if attribute == "action" then
		self.action = value
		self:Update()
	end
end

function ActionButtonMixin:OnDragStart()
	local modifier = DRAG_MODIFIERS[config.dragModifier]
	if (not modifier or modifier()) and not InCombatLockdown() then
		PickupAction(self.action)
	end
end

function ActionButtonMixin:ACTIONBAR_SLOT_CHANGED(slot)
	if slot == 0 or slot == self.action then
		self:Update()
	end
end

function ActionButtonMixin:SetTooltip()
	if HasAction(self.action) then
		GameTooltip:SetAction(self.action)
	else
		GameTooltip:Hide()
	end
end

function ActionBar:CreateActionButton(action, parent)
	local button = CreateFrame("Button", BUTTON_NAME:format(action), parent, "SecureActionButtonTemplate")
	ns.Mixin(button, ns.EventMixin, ActionButtonMixin)

	button:SetAttribute("checkselfcast", true)
	button:SetAttribute("type", "action")
	button:SetAttribute("action", action)
	button:SetAttribute("slotactive", true)
	button.action = action
	button.bindingName = BINDING_NAME:format(action)

	self:StyleButton(button)

	button.cooldown = CreateFrame("Cooldown", nil, button)
	button.cooldown:SetAllPoints()
	CooldownTimer:Attach(button.cooldown, config.cooldownFont.size)

	button.icon = button:CreateTexture(nil, "BORDER")
	button.icon:SetAllPoints()

	button.hotkey = button:CreateFontString(nil, "ARTWORK")
	button.hotkey:SetPoint("TOPRIGHT")
	button.hotkey:SetJustifyH("LEFT")
	button.hotkey:SetJustifyV("BOTTOM")
	self:StyleHotkey(button.hotkey)

	button.name = button:CreateFontString(nil, "ARTWORK")
	button.name:SetPoint("BOTTOM", 0, 2)
	ns.SetFont(button.name, config.nameFont.size, config.nameFont.outline)

	button.count = button:CreateFontString(nil, "ARTWORK")
	button.count:SetPoint("BOTTOMRIGHT", -2, 2)
	ns.SetFont(button.count, config.countFont.size, config.countFont.outline)

	button:RegisterForClicks("LeftButtonDown")
	button:RegisterForDrag(config.dragButton)
	button:SetScript("OnDragStart", button.OnDragStart)
	button:SetScript("OnAttributeChanged", button.OnAttributeChanged)
	parent:WrapScript(button, "OnReceiveDrag", RECEIVE_DRAG_SNIPPET)
	button:RegisterEvent("ACTIONBAR_SLOT_CHANGED")
	button:RegisterEvent("PLAYER_ENTERING_WORLD", "Update")
	button:RegisterEvent("UPDATE_BINDINGS", "UpdateBindings")
	self:AttachTooltip(button, button.SetTooltip)

	local slot = CreateFrame("CheckButton", SLOT_NAME:format(action), nil, "ActionBarButtonTemplate")
	slot:SetAlpha(0)
	slot:EnableMouse(false)
	slot:SetScript("OnUpdate", nil)
	slot:SetAttribute("action", action)
	SecureHandlerSetFrameRef(slot, "button", button)
	SecureHandlerSetFrameRef(button, "slot", slot)
	parent:WrapScript(slot, "OnShow", SLOT_VISIBILITY_SNIPPET)
	parent:WrapScript(slot, "OnHide", SLOT_VISIBILITY_SNIPPET)
	button.slot = slot
	button.gridExtra = 0

	button.usable = true
	button.cooldownEnd = 0
	button:Update()

	if #actionButtons == 0 then
		self:RegisterEvent("PLAYER_TARGET_CHANGED", onTargetChanged)
		self:RegisterEvent("PLAYER_ENTERING_WORLD", onTargetChanged)
		rangeTicker:Show()
	end
	actionButtons[#actionButtons + 1] = button
	return button
end

local function updateCooldowns()
	for i = 1, #actionButtons do
		local button = actionButtons[i]
		if button.hasAction then
			button:UpdateCooldown()
		end
	end
end

local function scanLossOfControl()
	local count, changed = 0, false
	if config.lossOfControl then
		local auras, auraCount = Auras.Get("player", "HARMFUL")
		for i = 1, auraCount do
			local aura = auras[i]
			local control = ID_CONTROLS[aura.spellId]
			if control == nil then
				control = NAME_CONTROLS[aura.name]
			end
			local duration, expires = aura.duration, aura.expires
			if control and duration and duration > 0 then
				count = count + 1
				local active = activeControls[count]
				if not active then
					active = {}
					activeControls[count] = active
				end
				if active.control ~= control or active.expires ~= expires or active.duration ~= duration then
					active.control, active.expires, active.duration = control, expires, duration
					changed = true
				end
			end
		end
	end

	for i = #activeControls, count + 1, -1 do
		activeControls[i] = nil
		changed = true
	end
	if changed then
		updateCooldowns()
	end
end

local playerGUID

local function onCombatLog(_, _, event, _, _, _, destGUID)
	if event ~= "SPELL_INTERRUPT" then
		return
	end
	playerGUID = playerGUID or UnitGUID("player")
	if destGUID == playerGUID then
		interruptedAt = GetTime()
		updateCooldowns()
	end
end

function ActionBar:UpdateLockoutTracking()
	if config.lossOfControl then
		self:RegisterUnitEvent("UNIT_AURA", "player", scanLossOfControl)
	else
		self:UnregisterUnitEvent("UNIT_AURA", "player", scanLossOfControl)
	end
	if config.interruptLockout then
		self:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED", onCombatLog)
	else
		self:UnregisterEvent("COMBAT_LOG_EVENT_UNFILTERED", onCombatLog)
	end
	scanLossOfControl()
	updateCooldowns()
end
