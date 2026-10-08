local function listOf(ns, event)
	local i = 1
	while true do
		local name, value = debug.getupvalue(ns.Fire, i)
		if not name then
			return
		end
		if name == "callbacks" then
			return value[event]
		end
		i = i + 1
	end
end

return function(ns, env, R)
	local test, expect = R.test, R.expect

	local function owner(name)
		return ns.Mixin({ name = name }, ns.EventMixin)
	end

	test("Event profile: a handler's own time leaves out the handlers it fires", function()
		local outer, inner = owner("Outer"), owner("Inner")
		inner:RegisterEvent("TEST_PROFILE_INNER", function()
			local stop = os.clock() + 0.02
			while os.clock() < stop do
			end
		end)
		outer:RegisterEvent("TEST_PROFILE_OUTER", function()
			ns:Fire("TEST_PROFILE_INNER")
		end)
		ns.StartEventProfile()
		ns:Fire("TEST_PROFILE_OUTER")
		local profile = ns.StopEventProfile()
		local innerMs = profile.TEST_PROFILE_INNER[inner].ms
		local outerMs = profile.TEST_PROFILE_OUTER[outer].ms
		expect.truthy(innerMs >= 15, "inner time " .. innerMs)
		expect.truthy(outerMs < innerMs / 2, "outer own time " .. outerMs)
	end)

	test("Fire: an error in one handler does not stop the next handlers", function()
		local a, b, c = owner("A"), owner("B"), owner("C")
		local calls = {}
		a:RegisterEvent("TEST_ISOLATION", function()
			calls[#calls + 1] = "a"
		end)
		b:RegisterEvent("TEST_ISOLATION", function()
			error("b fails")
		end)
		c:RegisterEvent("TEST_ISOLATION", function(_, x)
			calls[#calls + 1] = "c" .. x
		end)
		ns:Fire("TEST_ISOLATION", 7)
		expect.eq(table.concat(calls, ","), "a,c7")
		local errors = env.takeErrors()
		expect.eq(#errors, 1, "reported errors")
		expect.truthy(errors[1]:find("b fails"), "error text")
		expect.eq(listOf(ns, "TEST_ISOLATION").firing, 0, "firing restored")
	end)

	test("Fire: unit events are isolated too", function()
		local a, b = owner("A"), owner("B")
		local called = 0
		a:RegisterUnitEvent("TEST_UNIT_ISOLATION", "player", function()
			error("a fails")
		end)
		b:RegisterUnitEvent("TEST_UNIT_ISOLATION", "player", function(_, unit)
			called = called + (unit == "player" and 1 or 0)
		end)
		ns:Fire("TEST_UNIT_ISOLATION", "player")
		ns:Fire("TEST_UNIT_ISOLATION", "target")
		expect.eq(called, 1)
		expect.eq(#env.takeErrors(), 1)
	end)

	test("Fire: subscribe/unsubscribe cycles after an error keep the list compact", function()
		local a, b = owner("A"), owner("B")
		a:RegisterEvent("TEST_COMPACT", function()
			error("a fails")
		end)
		ns:Fire("TEST_COMPACT")
		local function handler() end
		for _ = 1, 1000 do
			b:RegisterEvent("TEST_COMPACT", handler)
			b:UnregisterEvent("TEST_COMPACT", handler)
		end
		expect.eq(#listOf(ns, "TEST_COMPACT"), 1)
	end)

	test("Fire: a handler unregistering during dispatch is compacted afterwards", function()
		local a, b = owner("A"), owner("B")
		local bCalls = 0
		a:RegisterEvent("TEST_SELF_REMOVE", function(self)
			self:UnregisterEvent("TEST_SELF_REMOVE")
		end)
		b:RegisterEvent("TEST_SELF_REMOVE", function()
			bCalls = bCalls + 1
		end)
		ns:Fire("TEST_SELF_REMOVE")
		ns:Fire("TEST_SELF_REMOVE")
		expect.eq(bCalls, 2)
		expect.eq(#listOf(ns, "TEST_SELF_REMOVE"), 1)
	end)

	test("Fire: nested Fire of the same event from a handler", function()
		local a = owner("A")
		local depth, seen = 0, {}
		a:RegisterEvent("TEST_NESTED", function(_, n)
			seen[#seen + 1] = n
			if n < 3 then
				depth = depth + 1
				ns:Fire("TEST_NESTED", n + 1)
			end
		end)
		ns:Fire("TEST_NESTED", 1)
		expect.eq(table.concat(seen, ","), "1,2,3")
		expect.eq(listOf(ns, "TEST_NESTED").firing, 0)
	end)

	test("game events reach the bus through the event frame and unregister on the last release", function()
		local a = owner("A")
		local got
		a:RegisterEvent("TEST_GAME_EVENT", function(_, x)
			got = x
		end)
		env.event("TEST_GAME_EVENT", 42)
		expect.eq(got, 42)
		a:UnregisterAllEvents()
		got = nil
		env.event("TEST_GAME_EVENT", 43)
		expect.eq(got, nil)
	end)

	test("catalogued addon events stay on the bus and never reach the event frame", function()
		local a = owner("A")
		local got
		a:RegisterEvent(ns.E.DR_UPDATED, function(_, guid)
			got = guid
		end)
		env.event(ns.E.DR_UPDATED, "from frame")
		expect.eq(got, nil)
		ns:Fire(ns.E.DR_UPDATED, "guid")
		expect.eq(got, "guid")
		a:UnregisterAllEvents()
	end)

	test("an addon-prefixed event missing from the catalog is rejected", function()
		local a = owner("A")
		expect.eq((pcall(a.RegisterEvent, a, "FrostAtomUI_TYPO_UPDATED", function() end)), false)
		expect.eq((pcall(a.RegisterUnitEvent, a, "FrostAtomUI_TYPO_UPDATED", "player", function() end)), false)
	end)

	test("OnAddonLoaded: an error in one waiter does not stop the others", function()
		local calls = 0
		ns:OnAddonLoaded("TestAddon", function()
			error("waiter fails")
		end)
		ns:OnAddonLoaded("TestAddon", function()
			calls = calls + 1
		end)
		env.event("ADDON_LOADED", "TestAddon")
		expect.eq(calls, 1)
		expect.eq(#env.takeErrors(), 1)
	end)
end
