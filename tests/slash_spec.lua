return function(ns, env, R)
	local test, expect = R.test, R.expect

	local stubMeta = {}
	local function stub()
		return setmetatable({}, stubMeta)
	end
	stubMeta.__index = function()
		return stub()
	end
	stubMeta.__call = function()
		return stub()
	end
	stubMeta.__add = function()
		return 0
	end
	stubMeta.__sub = stubMeta.__add

	local calls = {}
	local function record(name)
		return function()
			calls[#calls + 1] = name
		end
	end

	local addon = setmetatable({
		L = setmetatable({}, {
			__index = function(_, key)
				return key
			end,
		}),
		Lower = ns.Lower,
		OnLocaleReady = function() end,
		Print = function() end,
		Movers = { Unlock = record("unlock"), Lock = record("lock"), ConfirmResetPositions = record("reset") },
		ConfirmRestoreBackup = record("restore"),
		ShowDebugReport = record("debug"),
		TogglePerf = record("perf"),
	}, {
		__index = function()
			return stub()
		end,
	})

	local LUA = {
		ipairs = ipairs,
		pairs = pairs,
		type = type,
		tostring = tostring,
		tonumber = tonumber,
		select = select,
		next = next,
		unpack = unpack,
		string = string,
		table = table,
		math = math,
		setmetatable = setmetatable,
		strtrim = strtrim,
		print = function() end,
	}
	local box = { SlashCmdList = {}, SLASH_RELOAD1 = "/reload", LoadAddOn = record("load") }
	box._G = box
	setmetatable(box, {
		__index = function(_, key)
			if LUA[key] ~= nil then
				return LUA[key]
			elseif type(key) == "string" and key:find("^SLASH_") then
				return nil
			end
			return stub()
		end,
	})
	local chunk = assert(loadfile(env.root .. "/FrostAtomUI/Modules/Interface/Tweaks.lua"))
	setfenv(chunk, box)
	chunk("FrostAtomUI", addon)

	test("Russian layout: Latin commands typed on the ЙЦУКЕН layout convert back", function()
		expect.eq(addon.FromRussianLayout("рудз"), "help")
		expect.eq(addon.FromRussianLayout("ГТДЩСЛ"), "unlock")
		expect.eq(addon.FromRussianLayout("ыуегз"), "setup")
		expect.eq(addon.FromRussianLayout("сфыеифк"), "castbar")
		expect.eq(addon.FromRussianLayout("Ёж"), "`;")
		expect.eq(addon.FromRussianLayout("abc 12"), "abc 12")
	end)

	test("/fui subcommands: English, Russian aliases and the Russian layout", function()
		local parse = addon.ParseConfigCommand
		expect.eq(parse("unlock"), "unlock")
		expect.eq(parse("  LOCK "), "lock")
		expect.eq(parse("move"), "move")
		expect.eq(parse("двигать"), "unlock")
		expect.eq(parse("Справка"), "help")
		expect.eq(parse("помощь"), "help")
		expect.eq(parse("копии"), "restore")
		expect.eq(parse("отчёт"), "debug")
		expect.eq(parse("ОТЧЕТ"), "debug")
		expect.eq(parse("рудз"), "help")
		expect.eq(parse("гтдщсл"), "unlock")
		expect.eq(parse("здуфыу"), nil)
		expect.eq(select(2, parse("Тринкет")), "тринкет")
		expect.eq(select(2, parse("castbar width")), "castbar width")
		expect.eq(select(2, parse(nil)), "")
	end)

	test("/fui runs the subcommand and does not load the settings addon", function()
		for i = #calls, 1, -1 do
			calls[i] = nil
		end
		box.SlashCmdList.FROSTATOMUI_CONFIG("отчёт")
		box.SlashCmdList.FROSTATOMUI_CONFIG("гтдщсл")
		expect.deepEq(calls, { "debug", "unlock" })
	end)

	test("Slash aliases: /агш and /гш open the settings, /кд reloads, existing aliases kept", function()
		local config = {}
		for i = 1, 20 do
			config[#config + 1] = box["SLASH_FROSTATOMUI_CONFIG" .. i]
		end
		local set = {}
		for _, alias in ipairs(config) do
			set[alias] = true
		end
		for _, alias in ipairs({ "/fui", "/ui", "/faui", "/frostatomui", "/агш", "/гш", "/АГШ", "/ГШ" }) do
			expect.truthy(set[alias], alias)
		end
		expect.eq(box.SLASH_RELOAD1, "/reload")
		expect.eq(box.SLASH_RELOAD2, "/rl")
		expect.eq(box.SLASH_RELOAD3, "/кд")
		expect.eq(box.SLASH_RELOAD4, "/КД")
	end)
end
