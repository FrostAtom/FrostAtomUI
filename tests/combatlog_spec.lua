return function(ns, env, R)
	local test, expect = R.test, R.expect
	local CombatLog = ns.CombatLog

	local function log(subevent, ...)
		env.event("COMBAT_LOG_EVENT_UNFILTERED", 0, subevent, ...)
	end

	test("CombatLog: handlers get only their subevents, ALL gets everything", function()
		local seen, all = {}, {}
		local owner = {}
		local function onInterrupt(self, _, subevent, source)
			seen[#seen + 1] = { self, subevent, source }
		end
		local function onAny(_, _, subevent)
			all[#all + 1] = subevent
		end
		CombatLog.Register(owner, { "SPELL_INTERRUPT" }, onInterrupt)
		CombatLog.Register(owner, CombatLog.ALL, onAny)
		log("SPELL_INTERRUPT", "guid-1")
		log("SPELL_DAMAGE", "guid-2")
		CombatLog.Unregister(owner)
		log("SPELL_INTERRUPT", "guid-3")
		expect.eq(#seen, 1)
		expect.eq(seen[1][1], owner, "the owner is passed first")
		expect.eq(seen[1][3], "guid-1")
		expect.eq(#all, 2)
		expect.eq(CombatLog.IsRegistered(owner), false)
	end)

	test("CombatLog: a set of subevents, re-registering replaces, removal during dispatch", function()
		local owner, other = {}, {}
		local calls = 0
		local function second()
			calls = calls + 1
		end
		local function first()
			CombatLog.Unregister(other, second)
		end
		CombatLog.Register(owner, { SPELL_AURA_APPLIED = true, SPELL_AURA_REMOVED = true }, first)
		CombatLog.Register(other, { "SPELL_AURA_APPLIED" }, second)
		CombatLog.Register(other, { "SPELL_AURA_APPLIED" }, second)
		expect.eq(CombatLog.Subscribers().SPELL_AURA_APPLIED, 2, "the same handler is kept once")
		log("SPELL_AURA_APPLIED")
		expect.eq(calls, 0, "a handler removed earlier in the same event is not called")
		CombatLog.Unregister(owner)
		expect.eq(next(CombatLog.Subscribers()), nil)
	end)

	test("Demand: the first Acquire starts a service, the last Release stops it", function()
		local service = ns.Mixin({ starts = 0, stops = 0 }, ns.Demand)
		function service:OnDemandStart()
			self.starts = self.starts + 1
		end
		function service:OnDemandStop()
			self.stops = self.stops + 1
		end
		service:Acquire("frames")
		service:Acquire("plates")
		service:Acquire("frames")
		expect.eq(service.starts, 1)
		expect.eq(service:IsActive(), true)
		service:Release("frames")
		expect.eq(service.stops, 0, "still wanted by plates")
		service:SetDemand("plates", false)
		service:Release("plates")
		expect.eq(service.stops, 1)
		expect.eq(service:IsActive(), false)
	end)
end
