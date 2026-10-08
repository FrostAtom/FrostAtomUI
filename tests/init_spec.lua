return function(ns, env, R)
	local test, expect = R.test, R.expect

	test("SafeCall passes every argument, including nils and long lists", function()
		local got
		ns.SafeCall(function(...)
			got = { n = select("#", ...), ... }
		end, nil, 2, nil)
		expect.eq(got.n, 3)
		expect.eq(got[2], 2)
		local sum = 0
		ns.SafeCall(function(...)
			for i = 1, select("#", ...) do
				sum = sum + select(i, ...)
			end
		end, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20)
		expect.eq(sum, 210)
	end)

	test("SafeCall reports an error and returns false", function()
		expect.eq(
			ns.SafeCall(function()
				error("safe call fails")
			end),
			false
		)
		expect.eq(ns.SafeCall(function() end), true)
		local errors = env.takeErrors()
		expect.eq(#errors, 1)
		expect.truthy(errors[1]:find("safe call fails"))
	end)

	test("SafeCall is reentrant for the same arity", function()
		local seen = {}
		ns.SafeCall(function(a)
			ns.SafeCall(function(b)
				seen[#seen + 1] = b
			end, "inner")
			seen[#seen + 1] = a
		end, "outer")
		expect.eq(table.concat(seen, ","), "inner,outer")
	end)
end
