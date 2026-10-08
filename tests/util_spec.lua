return function(ns, _, R)
	local test, expect = R.test, R.expect

	test("FormatClock: minutes and zero-padded seconds, fractions dropped", function()
		expect.eq(ns.FormatClock(0), "0:00")
		expect.eq(ns.FormatClock(9.9), "0:09")
		expect.eq(ns.FormatClock(61), "1:01")
		expect.eq(ns.FormatClock(754.5), "12:34")
	end)

	test("L: a numbered label uses the format translation of its pattern", function()
		rawset(ns.L, "Spec member %d castbar", "Полоса участника %d")
		expect.eq(ns.L["Spec member 3 castbar"], "Полоса участника 3")
		expect.eq(ns.L["Spec member 4 pet"], "Spec member 4 pet")
	end)

	test("Lower: Cyrillic and Latin letters, other bytes unchanged", function()
		expect.eq(ns.Lower("ЛЕДЯНОЙ Меч"), "ледяной меч")
		expect.eq(ns.Lower("Ёлка"), "ёлка")
		expect.eq(ns.Lower("Frost 2"), "frost 2")
	end)
end
