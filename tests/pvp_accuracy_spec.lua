return function(_, env, R)
	local test, expect = R.test, R.expect

	local HOSTILE_PLAYER = 0x548
	local FRIENDLY_PLAYER = 0x511

	local function band(a, b)
		local result, bitValue = 0, 1
		while a > 0 and b > 0 do
			if a % 2 == 1 and b % 2 == 1 then
				result = result + bitValue
			end
			a, b, bitValue = math.floor(a / 2), math.floor(b / 2), bitValue * 2
		end
		return result
	end

	local function newNs()
		local ns = { modules = {}, E = setmetatable({}, {
			__index = function(_, key)
				return key
			end,
		}) }
		ns.API = { RegisterAction = function() end, RegisterPreview = function() end, PreviewChanged = function() end }
		function ns:NewModule(name)
			local module = { events = {} }
			function module:RegisterEvent(event, handler)
				self.events[event] = handler or event
			end
			function module:UnregisterEvent(event)
				self.events[event] = nil
			end
			function module.WatchConfig() end
			self.modules[name] = module
			return module
		end
		function ns:GetModule(name)
			return self.modules[name]
		end
		function ns.Fire() end
		function ns.After() end
		ns.Mixin = function(target, source)
			for key, value in pairs(source) do
				target[key] = value
			end
			return target
		end
		env.loadFile("Core/Demand.lua", ns)
		ns.CombatLog = { ALL = "*" }
		function ns.CombatLog.Register(owner, _, handler)
			owner.events = owner.events or {}
			owner.events.COMBAT_LOG_EVENT_UNFILTERED = handler
		end
		function ns.CombatLog.Unregister(owner)
			if owner.events then
				owner.events.COMBAT_LOG_EVENT_UNFILTERED = nil
			end
		end
		function ns.tContains(list, value)
			for i = 1, #list do
				if list[i] == value then
					return true
				end
			end
			return false
		end
		return ns
	end

	local function dispatch(module, event, ...)
		local handler = module.events[event]
		if type(handler) == "string" then
			handler = module[handler]
		end
		if handler then
			handler(module, ...)
		end
	end

	local function newBox(globals)
		globals.bit = { band = band }
		globals.COMBATLOG_OBJECT_TYPE_PLAYER = 0x400
		globals.COMBATLOG_OBJECT_TYPE_PET = 0x1000
		globals.COMBATLOG_OBJECT_REACTION_HOSTILE = 0x40
		globals.SlashCmdList = {}
		return env.sandbox(globals, function(key)
			return rawget(_G, key) == nil
		end)
	end

	local function spellName(names)
		return function(id)
			return names[id] or ("Spell" .. id), nil, "icon"
		end
	end

	do
		local units, classes, played, zone = {}, {}, {}, "arena"
		local box = newBox({
			GetSpellInfo = spellName({ [57073] = "Drink" }),
			PlaySoundFile = function(path)
				played[#played + 1] = path:match("([^\\]+)%.wav$")
			end,
			UnitGUID = function(unit)
				return units[unit]
			end,
			UnitIsUnit = function(a, b)
				return units[a] ~= nil and units[a] == units[b]
			end,
			UnitIsPlayer = function()
				return true
			end,
			UnitIsEnemy = function()
				return true
			end,
			GetPlayerInfoByGUID = function(guid)
				return nil, classes[guid]
			end,
			IsInInstance = function()
				return true, zone
			end,
		})
		local ns = newNs()
		local timers = {}
		function ns.After(delay, fn)
			timers[#timers + 1] = { at = env.clock + delay, fn = fn }
		end
		local function runTimers()
			local i = 1
			while i <= #timers do
				local timer = timers[i]
				if timer.at <= env.clock then
					table.remove(timers, i)
					timer.fn()
					i = 1
				else
					i = i + 1
				end
			end
		end
		local function advance(seconds)
			for _ = 1, seconds * 10 do
				env.clock = env.clock + 0.1
				runTimers()
			end
		end
		env.loadFile("Modules/SpellAlertData.lua", ns, box)
		ns.Config = {
			spellAlerts = {
				enabled = true,
				zones = { arena = true, battleground = true, world = true },
				targetOnly = true,
				controlOnYou = false,
				urgentWhenTargeted = false,
				defensiveEnd = true,
				controlEnd = true,
				interrupted = true,
				spells = {},
			},
		}
		ns.ExplainOnce = ns.ExplainOnce or function() end
		env.loadFile("Modules/Alerts/SpellAlerts.lua", ns, box)
		local SpellAlerts = ns.modules.SpellAlerts
		local config = ns.Config.spellAlerts

		local MAGE, PRIEST, PLAYER, ALLY = "0xMAGE", "0xPRIEST", "0xPLAYER", "0xALLY"

		local function reset(options)
			for key in pairs(units) do
				units[key] = nil
			end
			units.player, units.party1, units.arena1, units.arena2 = PLAYER, ALLY, MAGE, PRIEST
			classes[MAGE], classes[PRIEST] = "MAGE", "PRIEST"
			zone = options and options.zone or "arena"
			config.controlOnYou = options and options.controlOnYou or false
			config.urgentWhenTargeted = options and options.urgentWhenTargeted or false
			advance(10)
			SpellAlerts:Initialize()
			dispatch(SpellAlerts, "PLAYER_ENTERING_WORLD")
			for i = #played, 1, -1 do
				played[i] = nil
			end
		end

		local function log(event, source, sourceFlags, dest, destFlags, spellId)
			dispatch(
				SpellAlerts,
				"COMBAT_LOG_EVENT_UNFILTERED",
				0,
				event,
				source,
				"",
				sourceFlags,
				dest,
				"",
				destFlags,
				spellId,
				""
			)
		end

		local function count(sound)
			local n = 0
			for i = 1, #played do
				if played[i] == sound then
					n = n + 1
				end
			end
			return n
		end

		test("Spell alerts: Polymorph cast by a mage targeting you plays the plain clip, not ... on you", function()
			reset()
			units.arena1target = PLAYER
			log("SPELL_CAST_START", MAGE, HOSTILE_PLAYER, nil, 0, 118)
			expect.eq(table.concat(played, ","), "polymorph")
		end)

		test("Spell alerts: CLEU repeats without control landing on you never play ... on you", function()
			reset({ controlOnYou = true, urgentWhenTargeted = true })
			units.arena1target = PLAYER
			for i = 1, 4 do
				log("SPELL_CAST_START", MAGE, HOSTILE_PLAYER, nil, 0, 118)
				log("SPELL_CAST_START", MAGE, HOSTILE_PLAYER, nil, 0, 118)
				log("SPELL_AURA_APPLIED", MAGE, HOSTILE_PLAYER, ALLY, FRIENDLY_PLAYER, 118)
				log("SPELL_AURA_REMOVED", MAGE, HOSTILE_PLAYER, ALLY, FRIENDLY_PLAYER, 118)
				log("SPELL_CAST_START", PRIEST, HOSTILE_PLAYER, nil, 0, 605)
				log("SPELL_AURA_APPLIED", PRIEST, HOSTILE_PLAYER, ALLY, FRIENDLY_PLAYER, 8122)
				advance(i % 2 == 0 and 4 or 1)
			end
			advance(5)
			for i = 1, #played do
				expect.truthy(not played[i]:find("You$"), "played " .. played[i])
			end
			expect.truthy(count("polymorph") > 0, "the cast is still announced")
			expect.truthy(count("psychicScream") > 0, "control on an ally is still announced")
		end)

		test("Spell alerts: control landing on you plays ... on you only with Crowd control on you", function()
			reset()
			log("SPELL_AURA_APPLIED", MAGE, HOSTILE_PLAYER, PLAYER, FRIENDLY_PLAYER, 118)
			log("SPELL_AURA_APPLIED", MAGE, HOSTILE_PLAYER, PLAYER, FRIENDLY_PLAYER, 44572)
			expect.eq(#played, 0)
			reset({ controlOnYou = true })
			log("SPELL_AURA_APPLIED", MAGE, HOSTILE_PLAYER, PLAYER, FRIENDLY_PLAYER, 118)
			expect.eq(table.concat(played, ","), "polymorphYou")
		end)

		test("Spell alerts: the targeted cast waits in the queue unless Urgent when targeted is on", function()
			reset()
			units.arena1target = PLAYER
			log("SPELL_CAST_SUCCESS", PRIEST, HOSTILE_PLAYER, nil, 0, 42292)
			log("SPELL_CAST_START", MAGE, HOSTILE_PLAYER, nil, 0, 118)
			expect.eq(table.concat(played, ","), "trinketPriest")
			reset({ urgentWhenTargeted = true })
			units.arena1target = PLAYER
			log("SPELL_CAST_SUCCESS", PRIEST, HOSTILE_PLAYER, nil, 0, 42292)
			log("SPELL_CAST_START", MAGE, HOSTILE_PLAYER, nil, 0, 118)
			expect.eq(table.concat(played, ","), "trinketPriest,polymorph")
		end)

		test("Spell alerts: outside arenas a cast at you is announced from an unwatched caster", function()
			reset({ zone = "pvp" })
			units.arena1target = PLAYER
			log("SPELL_CAST_START", MAGE, HOSTILE_PLAYER, nil, 0, 118)
			log("SPELL_CAST_START", PRIEST, HOSTILE_PLAYER, nil, 0, 605)
			expect.eq(table.concat(played, ","), "polymorph")
		end)
	end

	do
		local units, classes, races = {}, {}, {}
		local box = newBox({
			GetSpellInfo = spellName({}),
			UnitGUID = function(unit)
				return units[unit]
			end,
			UnitClass = function(unit)
				return nil, classes[units[unit]]
			end,
			UnitRace = function(unit)
				return nil, races[units[unit]]
			end,
		})
		local ns = newNs()
		env.loadFile("Data/Abilities.lua", ns, box)
		local Talents = ns:NewModule("Talents")
		function Talents.Get() end
		function Talents.Has() end
		function Talents.Observe() end
		function Talents.Invalidate() end
		function Talents.GetProven()
			return 0
		end
		function Talents.IsExcluded()
			return false
		end
		function Talents.GetReachableRanks()
			return 0
		end
		env.loadFile("Modules/CooldownTracker.lua", ns, box)
		local Tracker = ns.modules.CooldownTracker
		Tracker:Acquire("test")

		local function cast(guid, spellId)
			dispatch(
				Tracker,
				"COMBAT_LOG_EVENT_UNFILTERED",
				0,
				"SPELL_CAST_SUCCESS",
				guid,
				"",
				HOSTILE_PLAYER,
				nil,
				"",
				0,
				spellId
			)
		end

		local function remaining(guid, spellId)
			local start, duration = Tracker:GetCooldown(guid, spellId)
			return start and start + duration - env.clock or 0
		end

		test("Cooldowns: unknown glyphs give the shortest plausible cooldown, marked as assumed", function()
			Tracker:Reset()
			local PRIEST = "0xPRIEST"
			classes[PRIEST], races[PRIEST] = "PRIEST", "Human"
			cast(PRIEST, 47585)
			expect.eq(remaining(PRIEST, 47585), 75, "Dispersion with its glyph")
			local duration, assumed, longest = Tracker:GetDuration(PRIEST, 47585)
			expect.eq(duration, 75)
			expect.eq(assumed, true)
			expect.eq(longest, 120, "without the glyph")
			expect.eq(Tracker:GetMaybeReady(PRIEST, 47585), nil, "still on cooldown")
			env.clock = env.clock + 80
			expect.eq(
				Tracker:GetMaybeReady(PRIEST, 47585),
				env.clock + 40,
				"may be ready until the unglyphed cooldown ends"
			)
			env.clock = env.clock + 41
			expect.eq(Tracker:GetMaybeReady(PRIEST, 47585), nil, "surely ready")
		end)

		test("Cooldowns: Readiness resets hunter abilities but not the trinket, racials or Bestial Wrath", function()
			Tracker:Reset()
			local HUNTER = "0xHUNTER"
			classes[HUNTER], races[HUNTER] = "HUNTER", "Dwarf"
			cast(HUNTER, 42292)
			cast(HUNTER, 20594)
			cast(HUNTER, 19263)
			cast(HUNTER, 19574)
			cast(HUNTER, 34490)
			cast(HUNTER, 14311)
			env.clock = env.clock + 5
			cast(HUNTER, 23989)
			expect.eq(remaining(HUNTER, 42292), 115, "PvP Trinket")
			expect.eq(remaining(HUNTER, 20594), 115, "Stoneform")
			expect.eq(remaining(HUNTER, 19574), 95, "Bestial Wrath, glyph assumed while talents are unknown")
			expect.eq(remaining(HUNTER, 19263), 0, "Deterrence")
			expect.eq(remaining(HUNTER, 34490), 0, "Silencing Shot")
			expect.eq(remaining(HUNTER, 1499), 0, "Freezing Trap")
			expect.eq(remaining(HUNTER, 13809), 0, "Frost Trap")
			expect.eq(remaining(HUNTER, 23989), 180, "Readiness")
		end)

		test("Cooldowns: Cold Snap resets Frost Ward but not Fire Ward", function()
			Tracker:Reset()
			local MAGE = "0xMAGE"
			classes[MAGE] = "MAGE"
			cast(MAGE, 43010)
			cast(MAGE, 43012)
			cast(MAGE, 45438)
			cast(MAGE, 11958)
			expect.eq(remaining(MAGE, 543), 30, "Fire Ward")
			expect.eq(remaining(MAGE, 6143), 0, "Frost Ward")
			expect.eq(remaining(MAGE, 45438), 0, "Ice Block")
		end)

		test("Cooldowns: Will of the Forsaken puts the trinket on max(remaining, 45)", function()
			Tracker:Reset()
			local UNDEAD = "0xUNDEAD"
			cast(UNDEAD, 7744)
			expect.eq(remaining(UNDEAD, 42292), 45)
			env.clock = env.clock + 50
			cast(UNDEAD, 42292)
			env.clock = env.clock + 10
			expect.eq(remaining(UNDEAD, 7744), 60)
			expect.eq(remaining(UNDEAD, 42292), 110)
		end)
	end

	do
		local classes = {}
		local box = newBox({
			GetSpellInfo = spellName({}),
			GetPlayerInfoByGUID = function(guid)
				return nil, classes[guid]
			end,
		})
		local ns = newNs()
		env.loadFile("Data/Abilities.lua", ns, box)
		ns:NewModule("Inspect")
		env.loadFile("Modules/Talents.lua", ns, box)
		local Talents = ns.modules.Talents
		local HINTS = ns.CooldownData.SPEC_HINTS

		local guidCount = 0
		local function mage(...)
			guidCount = guidCount + 1
			local guid = "0xMAGE" .. guidCount
			classes[guid] = "MAGE"
			for i = 1, select("#", ...) do
				Talents:Observe(guid, HINTS[select(i, ...)])
			end
			return Talents:GetSpec(guid)
		end

		test("Talents: no spec from a shallow talent in any tree", function()
			expect.eq(mage(), nil, "nothing seen")
			expect.eq(mage(12472), nil, "Icy Veins, 11 points in Frost")
			expect.eq(mage(12472, 12043), nil, "Icy Veins and Presence of Mind")
			expect.eq(mage(11958), nil, "Cold Snap, 21 points in Frost")
		end)

		test("Talents: spec from 31 points deep or a share of at least 0.8", function()
			expect.eq(mage(57529), 1, "Arcane Potency, 26 points: share 0.83")
			expect.eq(mage(12042), 1, "Arcane Power, 31 points")
			expect.eq(mage(12472, 11426), 3, "Ice Barrier, 31 points in Frost")
			expect.eq(mage(12472, 44572), 3, "Deep Freeze, 51 points in Frost")
		end)
	end

	do
		local units, zone = {}, "arena"
		local NAMES = {
			[118] = "Polymorph",
			[2061] = "Flash Heal",
			[47540] = "Penance",
			[5484] = "Howl of Terror",
			[2006] = "Resurrection",
		}
		local box = newBox({
			GetSpellInfo = spellName(NAMES),
			FAILED = "Failed",
			INTERRUPTED = "Interrupted",
			UnitName = function(unit)
				local info = units[unit]
				return info and info.name
			end,
			UnitIsUnit = function(a, b)
				return units[a] ~= nil and units[a] == units[b]
			end,
			UnitCanAttack = function(a, b)
				return units[a] ~= nil and units[b] ~= nil and units[a].side ~= units[b].side
			end,
			UnitIsFriend = function(a, b)
				return units[a] ~= nil and units[b] ~= nil and units[a].side == units[b].side
			end,
			IsInInstance = function()
				return true, zone
			end,
		})
		local UF = { RegisterElement = function() end }
		local ns = newNs()
		ns.modules.UnitFrames = UF
		ns.L = setmetatable({}, {
			__index = function(_, key)
				return key
			end,
		})
		ns.OnLocaleReady = function() end
		ns.DRData = { SPELLS = {} }
		ns.Config = { theme = { textColor = { 1, 1, 1 } }, castbar = { targetName = true } }
		ns.EventMixin = { RegisterEvent = function() end }
		ns.Mixin = function(target, source)
			for key, value in pairs(source) do
				target[key] = value
			end
			return target
		end
		ns.Colors = { class = {} }
		env.loadFile("Modules/CastShared.lua", ns, box)

		local PRIEST = { name = "Priest", side = "enemy" }
		local MAGE = { name = "Mage", side = "enemy" }
		local ROGUE = { name = "Rogue", side = "us" }

		local function target(caster, casterTarget, spell, inZone)
			units.arena1, units.arena1target = caster, casterTarget
			zone = inZone or "arena"
			local name, uncertain = ns.Cast.CastTarget("arena1", "arena1target", spell)
			return name and (name .. (uncertain and "?" or "")) or "-"
		end

		test("Cast target: a heal of an enemy priest who targets your ally shows no target", function()
			expect.eq(target(PRIEST, ROGUE, "Flash Heal"), "-")
			expect.eq(target(PRIEST, MAGE, "Flash Heal"), "Mage")
			expect.eq(target(PRIEST, ROGUE, "Resurrection"), "-")
		end)

		test("Cast target: control shows a hostile target, dimmed with ? at arena", function()
			expect.eq(target(MAGE, ROGUE, "Polymorph"), "Rogue?")
			expect.eq(target(MAGE, ROGUE, "Polymorph", "pvp"), "Rogue")
			expect.eq(target(MAGE, PRIEST, "Polymorph"), "-")
		end)

		test("Cast target: other casts need a hostile target; self and area casts show none", function()
			expect.eq(target(MAGE, ROGUE, "Spell42842"), "Rogue")
			expect.eq(target(MAGE, PRIEST, "Spell42842"), "-")
			expect.eq(target(PRIEST, ROGUE, "Penance"), "Rogue")
			expect.eq(target(PRIEST, MAGE, "Penance"), "Mage")
			expect.eq(target(MAGE, ROGUE, "Howl of Terror"), "-")
			expect.eq(target(MAGE, MAGE, "Spell42842"), "-")
			ns.Config.castbar.targetName = false
			expect.eq(target(MAGE, ROGUE, "Polymorph"), "-")
			ns.Config.castbar.targetName = true
		end)
	end

	do
		local box = newBox({ GetSpellInfo = spellName({}) })
		local ns = newNs()
		env.loadFile("Data/Effects.lua", ns, box)
		env.loadFile("Core/SpellDB.lua", ns, box)
		env.loadFile("Modules/DRData.lua", ns, box)
		env.loadFile("Modules/LoseControlData.lua", ns, box)
		local DR = ns.DRData.SPELLS

		test("DR: no rank of a control spell is missing when its other ranks are there", function()
			local missing = {}
			for _, spells in pairs(ns.LoseControlData.SPELLS) do
				for _, group in ipairs(spells) do
					local known
					for i = 1, #group do
						known = known or DR[group[i]] ~= nil
					end
					for i = 1, #group do
						if known and not DR[group[i]] then
							missing[#missing + 1] = group[i]
						end
					end
				end
			end
			table.sort(missing)
			expect.eq(table.concat(missing, ", "), "")
			expect.eq(DR[47476], "silence", "Strangulate")
			expect.eq(DR[49916], nil, "Strangulate ranks 2-5 are not learnable in 3.3.5")
			expect.eq(DR[74347], "silence", "Gag Order")
		end)
	end
end
