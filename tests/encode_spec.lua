return function(ns, _, R)
	local test, expect = R.test, R.expect

	test("Encode output uses only the Z85 alphabet: no pipes, quotes or whitespace", function()
		local encoded = ns.Encode(ns.Serialize(ns.Defaults) .. "|cffff0000|r\n\t \"'\\")
		expect.eq(encoded:find("[|%s\"'\\,;`~_]"), nil, "unsafe character")
		expect.truthy(encoded:find("^[0-3]"), "pad digit first")
		expect.eq((#encoded - 1) % 5, 0, "whole Z85 groups")
	end)

	test("Encode/Decode round-trip: LZW KwKwK patterns and long runs", function()
		for _, s in ipairs({ "abababababababab", "aaaaaaa", ("\0"):rep(10000), ("xyz"):rep(5000), ("\255"):rep(3) }) do
			expect.eq(ns.Decode(ns.Encode(s)), s)
		end
	end)

	test("Decode ignores whitespace and line breaks inside a pasted string", function()
		local s = ns.Serialize({ minimap = { size = 222 }, name = "Тест" })
		local encoded = ns.Encode(s)
		local wrapped = {}
		for i = 1, #encoded, 7 do
			wrapped[#wrapped + 1] = encoded:sub(i, i + 6)
		end
		expect.eq(ns.Decode("  " .. table.concat(wrapped, "\r\n \t") .. "\n"), s)
	end)

	test("Decode error messages for malformed, overflowing and tampered strings", function()
		local encoded = ns.Encode("hello world")
		expect.eq(select(2, ns.Decode("4" .. encoded:sub(2))), "malformed string", "pad digit > 3")
		expect.eq(select(2, ns.Decode(encoded:sub(1, -2))), "malformed string", "partial group")
		expect.eq(select(2, ns.Decode(encoded .. "#####")), "malformed string", "group above 2^32")
		expect.eq(select(2, ns.Decode("1" .. ("0"):rep(5))), "malformed string", "shorter than the checksum")
		expect.eq(select(2, ns.Decode("0" .. ("0"):rep(5))), "checksum mismatch", "empty body, zero checksum")
		expect.eq(select(2, ns.Decode("x" .. encoded:sub(2))), "malformed string", "pad is not a digit")
		local header, body = encoded:sub(1, 6), encoded:sub(7)
		local flipped = header:sub(1, 5) .. (header:sub(6, 6) == "0" and "1" or "0") .. body
		expect.eq(select(2, ns.Decode(flipped)), "checksum mismatch")
	end)
end
