return function(ns, env, R)
	local test, expect = R.test, R.expect

	local spellbook = { { "Frostbolt", "Rank 16" }, { "Fireball", "Rank 1" }, { "Polymorph", "" } }
	local items = {
		Healthstone = { count = 1 },
		Hearthstone = { count = 0 },
		["Medallion of the Alliance"] = { count = 0, equipped = true },
	}
	local function noop() end

	local box = env.sandbox({
		GetSpellName = function(i, book)
			local spell = book == "spell" and spellbook[i]
			if spell then
				return spell[1], spell[2]
			end
		end,
		GetSpellInfo = function(spell)
			if spell == "Blink" then
				return spell
			end
		end,
		GetNumCompanions = function()
			return 0
		end,
		GetCompanionInfo = noop,
		GetItemInfo = function(name)
			return items[name] and name
		end,
		GetItemCount = function(name)
			return items[name].count
		end,
		IsEquippedItem = function(name)
			return items[name].equipped
		end,
		GetContainerItemLink = function(bag, slot)
			return bag == 0 and slot == 1 and "link" or nil
		end,
		GetInventoryItemLink = function(_, slot)
			return slot == 13 and "link" or nil
		end,
		GetModifiedClick = function(action)
			return action == "SELFCAST" and "ALT" or nil
		end,
		GetEquipmentSetInfoByName = function(name)
			return name == "PvP" and "icon" or nil
		end,
		GetClickFrame = function(name)
			if name == "MyButton" then
				return {
					IsObjectType = function(_, kind)
						return kind == "Button"
					end,
				}
			end
		end,
		GetAuctionItemClasses = function()
			return "Weapon", "Armor"
		end,
		GetAuctionItemSubClasses = function(class)
			if class == 1 then
				return "One-Handed Axes", "Daggers"
			end
			return "Cloth", "Shields"
		end,
		INVTYPE_TRINKET = "Trinket",
		NUM_ACTIONBAR_PAGES = 6,
		ChatTypeInfo = { SAY = {}, PARTY = {} },
		SlashCmdList = {
			SCRIPT = noop,
			DISMOUNT = noop,
			EQUIP_SET = noop,
			USE_TALENT_SPEC = noop,
			RELOAD = noop,
		},
		MAXEMOTEINDEX = 2,
		EMOTE1_TOKEN = "WAVE",
		EMOTE1_CMD1 = "/wave",
		EMOTE2_TOKEN = "BOW",
		EMOTE2_CMD1 = "/bow",
		EMOTE2_CMD2 = "/curtsey",
	}, function(key)
		return key:find("^SLASH_") or key:find("^EMOTE%d") or key:find("^INVTYPE_")
	end)
	for key, slashes in pairs({
		CAST = { "/cast", "/spell" },
		USE = { "/use" },
		CASTSEQUENCE = { "/castsequence" },
		CASTRANDOM = { "/castrandom" },
		TARGET = { "/target" },
		STOPCASTING = { "/stopcasting" },
		EQUIP = { "/equip" },
		EQUIP_TO_SLOT = { "/equipslot" },
		CHANGEACTIONBAR = { "/changeactionbar" },
		SWAPACTIONBAR = { "/swapactionbar" },
		CLICK = { "/click" },
		SAY = { "/say", "/s" },
		PARTY = { "/p" },
		SCRIPT = { "/script", "/run" },
		DISMOUNT = { "/dismount" },
		EQUIP_SET = { "/equipset" },
		USE_TALENT_SPEC = { "/usetalents" },
		RELOAD = { "/reload" },
	}) do
		for i, slash in ipairs(slashes) do
			box["SLASH_" .. key .. i] = slash
		end
	end
	env.loadFile("Modules/Macros/Parser.lua", ns, box)
	local Parser = ns.MacroParser

	local function issues(text, limit)
		local list = {}
		for _, issue in ipairs(Parser.Analyze(text, limit).issues) do
			list[#list + 1] = issue.level .. ":" .. issue.text
		end
		return list
	end

	local function expectIssue(text, level, needle)
		local list = issues(text)
		if not level then
			expect.eq(#list, 0, text .. " -> " .. tostring(list[1]))
			return
		end
		expect.eq(#list, 1, text .. " issue count")
		expect.eq(tonumber(list[1]:match("^(%d+)")), level, text .. " level")
		expect.truthy(list[1]:find(needle, 1, true), text .. " -> " .. list[1])
	end

	local ERROR, WARNING, INFO = Parser.ERROR, Parser.WARNING, Parser.INFO

	test("Macro parser: a valid macro has no issues", function()
		local text = table.concat({
			"#showtooltip",
			"/cast [mod:shift,@focus] Polymorph; [nocombat] Fireball(Rank 1); !Frostbolt",
			"/cast [@focus,exists][harm] [] Polymorph",
			"/use 13",
			"/use [combat] Healthstone",
			"/use 0 1",
			"/castsequence reset=5/target/combat Frostbolt, Fireball",
			"/stopcasting",
			"/CAST Blink",
			"/s hello [world]",
			"/1 lfg",
			"/curtsey",
			"-- comment",
			"/run print(1)",
			"/reload",
		}, "\n")
		expect.eq(#issues(text), 0, tostring(issues(text)[1]))
	end)

	test("Macro parser: condition names are case-sensitive and unknown ones are errors", function()
		expectIssue("/cast [Combat] Frostbolt", ERROR, "write [combat]")
		expectIssue("/cast [nofoo] Frostbolt", ERROR, "unknown condition [foo]")
		expectIssue("/cast [exists,bogus:1] Frostbolt", ERROR, "unknown condition [bogus]")
	end)

	test("Macro parser: condition arguments", function()
		local cases = {
			{ "[combat:1]", WARNING, "takes no arguments" },
			{ "[stance:x]", WARNING, "expects a number" },
			{ "[stance:1/2]" },
			{ "[actionbar:7]", WARNING, "page 1-6" },
			{ "[bar:0]", WARNING, "page 1-6" },
			{ "[spec:3]", WARNING, "talent group 1 or 2" },
			{ "[group:Party]", WARNING, "lowercase" },
			{ "[group:raid]" },
			{ "[cursor:Item]" },
			{ "[cursor:pet]", WARNING, "unknown cursor type" },
			{ "[mod:shift/ctrl]" },
			{ "[mod:LSHIFT]" },
			{ "[mod:SELFCAST]" },
			{ "[mod:meta]", WARNING, "unknown modifier" },
			{ "[equipped:Shields]" },
			{ "[worn:Trinket]" },
			{ "[equipped:invtype_head]" },
			{ "[equipped:Hats]", WARNING, "unknown item type" },
			{ "[nomod: shift , combat]" },
		}
		for _, case in ipairs(cases) do
			expectIssue("/cast " .. case[1] .. " Frostbolt", case[2], case[3])
		end
	end)

	test("Macro parser: unit tokens and player names in @ and target=", function()
		for _, unit in ipairs({
			"focus",
			"party1target",
			"arena5",
			"raidpet40",
			"targettargettarget",
			"mouseovertarget",
			"Player",
			"none",
			"boss4",
		}) do
			expectIssue("/cast [@" .. unit .. "] Frostbolt", nil)
			expectIssue("/cast [target=" .. unit .. "] Frostbolt", nil)
		end
		for _, unit in ipairs({ "party5", "arena0", "raid41", "Bob", "party1pet", "focusfoo" }) do
			expectIssue("/cast [@" .. unit .. "] Frostbolt", INFO, "is not a unit token")
		end
		expectIssue("/cast [@" .. ("x"):rep(32) .. "] Frostbolt", ERROR, "longer than 31")
		expectIssue("/cast [@] Frostbolt", nil)
	end)

	test("Macro parser: option structure", function()
		expectIssue("/cast Frostbolt [combat] Fireball", WARNING, "text before a [condition]")
		expectIssue("/cast [combat Frostbolt", ERROR, "missing ]")
		expectIssue("/cast [combat]", INFO, "empty action")
		expectIssue("/cast [combat]; Frostbolt", INFO, "empty action")
		expectIssue("/cast [combat] Frostbolt; [] Fireball;", nil)
		expectIssue("/cast [combat] Pyroblast; Frostbolt", ERROR, 'unknown spell or item "Pyroblast"')
	end)

	test("Macro parser: lines, commands and line numbers", function()
		expectIssue("cast Frostbolt", WARNING, "does not start with /")
		expectIssue(" /cast Frostbolt", WARNING, "starts with a space")
		expectIssue("/foo bar", ERROR, "unknown command /foo")
		expectIssue("/", ERROR, "unknown command /")
		expectIssue("#showx Frostbolt", nil)
		expectIssue("#show [combat] Pyroblast", ERROR, "Pyroblast")
		local result = Parser.Analyze("/cast Frostbolt\n\n/foo\r/bar")
		expect.eq(#result.issues, 2)
		expect.eq(result.issues[1].line, 3)
		expect.eq(result.issues[2].line, 4)
	end)

	test("Macro parser: castsequence reset words", function()
		expectIssue("/castsequence reset=5/target/combat/shift Frostbolt, Fireball", nil)
		expectIssue("/castsequence reset=5/foo Frostbolt, Fireball", WARNING, 'unknown reset condition "foo"')
		expectIssue("/castsequence [combat] reset=120 Frostbolt, Pyroblast", ERROR, "Pyroblast")
		expectIssue("/castrandom Frostbolt, Fireball, Polymorph", nil)
	end)

	test("Macro parser: items, bag and equipment slots", function()
		expectIssue("/use 0 2", WARNING, "bag slot 0 2 is empty")
		expectIssue("/use 14", WARNING, "equipment slot 14 is empty")
		expectIssue("/use Hearthstone", WARNING, 'item "Hearthstone" is not in your bags')
		expectIssue("/use Medallion of the Alliance", nil)
		expectIssue("/equip Hearthstone", WARNING, "not in your bags")
		expectIssue("/equip Ashbringer", WARNING, 'unknown item "Ashbringer"')
		expectIssue("/equipslot 13 Healthstone", nil)
		expectIssue("/equipslot Healthstone", ERROR, "expected an equipment slot number")
	end)

	test("Macro parser: action bar pages, /click, /equipset, /usetalents", function()
		expectIssue("/changeactionbar 2", nil)
		expectIssue("/changeactionbar x", ERROR, "page numbers 1-6")
		expectIssue("/swapactionbar 1 2", nil)
		expectIssue("/swapactionbar 1", ERROR, "page numbers 1-6")
		expectIssue("/click MyButton LeftButton", nil)
		expectIssue("/click NoSuchButton", WARNING, 'button "NoSuchButton" does not exist')
		expectIssue("/equipset PvP", nil)
		expectIssue("/equipset PvE", WARNING, 'no equipment set named "PvE"')
		expectIssue("/usetalents [combat] 2", nil)
		expectIssue("/usetalents 3", ERROR, "talent group 1 or 2")
	end)

	test("Macro parser: action bar pages outside 1-NUM_ACTIONBAR_PAGES are errors", function()
		expectIssue("/changeactionbar 7", ERROR, "page numbers 1-6")
		expectIssue("/changeactionbar 0", ERROR, "page numbers 1-6")
		expectIssue("/swapactionbar 1 9", ERROR, "page numbers 1-6")
		expectIssue("/swapactionbar [combat] 1 6", nil)
	end)

	test("Macro parser: /run reports Lua syntax errors without the chunk prefix", function()
		expectIssue("/run local x = ", ERROR, "Lua error: ")
		expect.eq(issues("/run local x = ")[1]:find("[string", 1, true), nil)
		expectIssue("/script if x then end", nil)
	end)

	test("Macro parser: macro and line length limits", function()
		local long = "/s " .. ("x"):rep(253)
		expect.eq(#issues(long, 255), 1)
		expect.truthy(issues(long, 255)[1]:find("256 of 255 characters", 1, true))
		expect.eq(#issues(long:sub(1, 255), 255), 0)
		local result = Parser.Analyze(long, 255)
		expect.eq(result.issues[1].line, nil)
		expect.eq(result.bytes, 256)
		expectIssue("/s " .. ("x"):rep(980), nil)
		expectIssue("/s " .. ("x"):rep(981), ERROR, "984 bytes long")
	end)

	test("Macro parser: spans are ordered, disjoint and inside the text", function()
		local samples = {
			"#showtooltip [mod] Frostbolt\n/cast [mod:shift,@focus,nocombat:1] Polymorph; Fireball",
			"/castsequence reset=5/foo Frostbolt, Pyroblast\n/use 0 2\n/s a|b",
			"/cast [Combat Frostbolt\n bad\n/run x(\n/foo",
			"/equipslot 13 Healthstone\n/click MyButton\n-- c\n#x",
		}
		for _, text in ipairs(samples) do
			local last = 0
			for _, span in ipairs(Parser.Analyze(text).spans) do
				expect.truthy(span[1] > last and span[1] <= span[2] and span[2] <= #text, text)
				expect.truthy(span[3]:find("^%x%x%x%x%x%x$"), "color")
				last = span[2]
			end
		end
	end)

	test("Macro parser: Render escapes pipes, Decode restores the text and the cursor", function()
		local samples = {
			"/cast [mod:shift] Frostbolt; Fireball",
			"/s a|b || |cffff0000red|r |",
			"|r|c|cff00ff00x\n/foo |",
			"plain",
			"",
		}
		for _, text in ipairs(samples) do
			local spans = Parser.Analyze(text).spans
			for cursor = 0, #text do
				local rendered, renderedCursor = Parser.Render(text, spans, cursor)
				local decoded, rawCursor = Parser.Decode(rendered, renderedCursor)
				expect.eq(decoded, text)
				expect.eq(rawCursor, cursor, ("%q cursor %d"):format(text, cursor))
			end
		end
	end)

	test("Macro parser: OptionsValid", function()
		for _, text in ipairs({ "Frostbolt", "[combat] A; B", "[@focus,harm,nodead] A", "[nomod:shift/ctrl] A", "[] A" }) do
			expect.eq(Parser.OptionsValid(text), true, text)
		end
		for _, text in ipairs({ "[Combat] A", "[combat] A; [bogus] B", "[combat A", "[target = focus] A" }) do
			expect.eq(Parser.OptionsValid(text), false, text)
		end
	end)

	test("Macro parser: FirstAction", function()
		expect.deepEq({ Parser.FirstAction("#showtooltip Fireball\n/cast Frostbolt") }, { "action", "Fireball" })
		expect.deepEq({ Parser.FirstAction("#showtooltip\n/say hi\n/cast [combat] Frostbolt") }, {
			"action",
			"[combat] Frostbolt",
		})
		expect.deepEq({ Parser.FirstAction("/castsequence reset=5 A, B") }, { "sequence", "reset=5 A, B" })
		expect.deepEq({ Parser.FirstAction("/castrandom A, B") }, { "actions", "A, B" })
		expect.eq(Parser.FirstAction("/target focus\n/stopcasting\n/s hi"), nil)
	end)

	test("Macro parser: InvalidateSpells picks up newly learned spells", function()
		expectIssue("/cast Ice Lance", ERROR, "Ice Lance")
		spellbook[#spellbook + 1] = { "Ice Lance", "Rank 1" }
		expectIssue("/cast Ice Lance", ERROR, "Ice Lance")
		Parser.InvalidateSpells()
		expectIssue("/cast Ice Lance(Rank 1)", nil)
		spellbook[#spellbook] = nil
		Parser.InvalidateSpells()
	end)

	test("Macro parser: slash commands added later are found after the rebuild interval", function()
		box.SlashCmdList.LATECMD = noop
		box.SLASH_LATECMD1 = "/late"
		env.clock = env.clock + 3
		expectIssue("/late", nil)
		box.SlashCmdList.LATERCMD = noop
		box.SLASH_LATERCMD1 = "/later"
		expectIssue("/later", ERROR, "unknown command /later")
		env.clock = env.clock + 3
		expectIssue("/later", nil)
	end)
end
