return function(ns, env, R)
	local test, expect = R.test, R.expect

	local function drain()
		for _ = 1, 5 do
			env.tick(0)
		end
	end

	test("Defer: an error in one task does not stop the rest of the batch", function()
		local ran = {}
		ns.Defer("sched.a", function()
			ran[#ran + 1] = "a"
		end)
		ns.Defer("sched.b", function()
			error("b fails")
		end)
		ns.Defer("sched.c", function(key)
			ran[#ran + 1] = key
		end)
		env.tick(0)
		expect.eq(table.concat(ran, ","), "a,sched.c")
		expect.eq(#env.takeErrors(), 1)
	end)

	test("Defer: keys of a batch with an error can be deferred again", function()
		local ran = {}
		ns.Defer("sched.d", function()
			error("d fails")
		end)
		ns.Defer("sched.e", function()
			ran[#ran + 1] = "e1"
		end)
		env.tick(0)
		ns.Defer("sched.d", function()
			ran[#ran + 1] = "d2"
		end)
		ns.Defer("sched.e", function()
			ran[#ran + 1] = "e2"
		end)
		drain()
		expect.eq(table.concat(ran, ","), "e1,d2,e2")
	end)

	test("Defer: the same key runs once per frame", function()
		local count = 0
		for _ = 1, 3 do
			ns.Defer("sched.once", function()
				count = count + 1
			end)
		end
		drain()
		expect.eq(count, 1)
	end)

	test("Defer: a task deferred from a running task runs on the next frame", function()
		local ran = {}
		ns.Defer("sched.outer", function()
			ran[#ran + 1] = "outer"
			ns.Defer("sched.inner", function()
				ran[#ran + 1] = "inner"
			end)
		end)
		env.tick(0)
		expect.eq(table.concat(ran, ","), "outer")
		env.tick(0)
		expect.eq(table.concat(ran, ","), "outer,inner")
	end)

	test("After: timers fire on time and an error does not stop other timers", function()
		local ran = {}
		ns.After(1, function(arg)
			ran[#ran + 1] = arg
		end, "one")
		ns.After(0.5, function()
			error("timer fails")
		end)
		ns.After(2, function(arg)
			ran[#ran + 1] = arg
		end, "two")
		env.tick(0.6)
		expect.eq(#ran, 0)
		expect.eq(#env.takeErrors(), 1)
		env.tick(0.6)
		expect.eq(table.concat(ran, ","), "one")
		env.tick(1)
		expect.eq(table.concat(ran, ","), "one,two")
	end)

	test("At: one pending timer per key, the earliest time wins", function()
		local key, ran = {}, {}
		local function record(arg)
			expect.eq(arg, key)
			ran[#ran + 1] = GetTime()
		end
		local start = GetTime()
		ns.Scheduler.At(key, start + 2, record)
		ns.Scheduler.At(key, start + 1, record)
		ns.Scheduler.At(key, start + 3, record)
		env.tick(0.5)
		expect.eq(#ran, 0)
		env.tick(0.6)
		expect.eq(#ran, 1)
		env.tick(3)
		expect.eq(#ran, 1)
		ns.Scheduler.At(key, GetTime() + 1, function()
			error("keyed timer fails")
		end)
		env.tick(1.1)
		expect.eq(#env.takeErrors(), 1)
		ns.Scheduler.At(key, GetTime() + 1, record)
		env.tick(1.1)
		expect.eq(#ran, 2)
	end)

	test("AddTicker: a failing ticker keeps ticking and does not stop others", function()
		local good, bad = 0, 0
		ns.Scheduler.AddTicker("sched.badTicker", function()
			bad = bad + 1
			error("ticker fails")
		end, 0.1)
		ns.Scheduler.AddTicker("sched.goodTicker", function(key, now)
			expect.eq(key, "sched.goodTicker")
			expect.truthy(now)
			good = good + 1
		end, 0.1)
		for _ = 1, 3 do
			env.tick(0.2)
		end
		ns.Scheduler.RemoveTicker("sched.badTicker")
		ns.Scheduler.RemoveTicker("sched.goodTicker")
		env.tick(0.2)
		expect.eq(good, 3)
		expect.eq(bad, 3)
		expect.eq(#env.takeErrors(), 3)
	end)
end
