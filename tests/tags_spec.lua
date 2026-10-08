return function(ns, env, R)
	local test, expect = R.test, R.expect

	local UF = ns:NewModule("UnitFrames")
	UF.classColors = { MAGE = { 0.2, 0.4, 1 } }

	local unit = {}
	local box = env.sandbox({
		UnitName = function()
			return unit.name
		end,
		UnitClass = function()
			return unit.className, unit.class
		end,
		UnitRace = function()
			return "Human"
		end,
		UnitLevel = function()
			return unit.level
		end,
		UnitHealth = function()
			return unit.health
		end,
		UnitHealthMax = function()
			return unit.healthMax
		end,
		UnitPower = function(_, powerType)
			return powerType == 0 and unit.mana or unit.power
		end,
		UnitPowerMax = function(_, powerType)
			return powerType == 0 and unit.manaMax or unit.powerMax
		end,
		UnitPowerType = function()
			return unit.powerType
		end,
		UnitIsAFK = function()
			return unit.afk
		end,
		UnitIsDND = function()
			return false
		end,
		UnitIsConnected = function()
			return not unit.offline
		end,
		UnitIsDeadOrGhost = function()
			return unit.dead
		end,
		UnitIsPlayer = function()
			return unit.class ~= nil
		end,
		UnitReaction = function()
			return unit.reaction
		end,
		GetGuildInfo = function()
			return unit.guild
		end,
		DEAD = "Dead",
		AFK = "AFK",
		DND = "DND",
		FRIENDS_LIST_OFFLINE = "Offline",
		MAX_PLAYER_LEVEL = 80,
	})
	env.loadFile("Modules/UnitFrames/Tags.lua", ns, box)
	local render = UF.RenderTags

	local function data(fields)
		local d = { name = "Bob", class = "MAGE", health = 50, healthMax = 200, power = 30, powerMax = 100 }
		for k, v in pairs(fields or {}) do
			d[k] = v
		end
		return d
	end

	test("Tags: plain text, known tags and percentages", function()
		expect.eq(render("[name] [perhp]% [curpp]/[maxpp]", nil, data()), "Bob 25% 30/100")
		expect.eq(render("no tags", nil, data()), "no tags")
		expect.eq(render("", nil, data()), "")
		expect.eq(render("[perhp]", nil, data({ healthMax = 0 })), "0")
		expect.eq(render("[misshp]", nil, data()), "150")
		expect.eq(render("[level] [class]", nil, data()), "80 MAGE")
	end)

	test("Tags: large values are shortened unless :raw", function()
		local d = data({ health = 12345, healthMax = 2500000 })
		expect.eq(render("[curhp] [maxhp]", nil, d), "12.3k 2.5m")
		expect.eq(render("[curhp:raw] [maxhp:raw]", nil, d), "12345 2500000")
	end)

	test("Tags: dead test units show zero health and the dead status", function()
		local d = data({ dead = true })
		expect.eq(render("[curhp] [perhp] [curpp] [status]", nil, d), "0 0 0 Dead")
		expect.eq(render("[status]", nil, data()), "")
	end)

	test("Tags: unknown and malformed tags stay literal", function()
		expect.eq(render("[foo] [name]", nil, data()), "[foo] Bob")
		expect.eq(render("[] [name", nil, data()), "[] [name")
		expect.eq(render("[[name]]", nil, data()), "[Bob]")
		expect.eq(render("[:name]", nil, data()), "Bob")
		expect.eq(render("[name:bogus]", nil, data()), "Bob")
	end)

	test("Tags: length truncates by UTF-8 characters", function()
		expect.eq(render("[name:3]", nil, data({ name = "Привет" })), "При")
		expect.eq(render("[name:10]", nil, data({ name = "Привет" })), "Привет")
		expect.eq(render("[name:2]", nil, data({ name = "ab😀c" })), "ab")
		expect.eq(render("[name:3]", nil, data({ name = "ab😀c" })), "ab😀")
	end)

	test("Tags: color options", function()
		local d = data()
		expect.eq(render("[name:ff00AA]", nil, d), "|cffff00aaBob|r")
		expect.eq(render("[name:class]", nil, d), "|cff3366ffBob|r")
		expect.eq(render("[name:class]", nil, data({ class = "ROGUE" })), "|cffffffffBob|r")
		expect.eq(render("[perhp:hp]", nil, data({ health = 200 })), "|cff4cff4c100|r")
		expect.eq(render("[perhp:hp]", nil, data({ health = 0 })), "|cffff33330|r")
		expect.eq(render("[curpp:power]", nil, data({ powerType = 0 })), "|cff0000ff30|r")
		expect.eq(render("[curpp:power]", nil, data({ powerType = 99 })), "|cffffffff30|r")
		expect.eq(render("[name:reaction]", nil, d), "|cffffffffBob|r")
		expect.eq(render("[name:3:class]", nil, data({ name = "Roberta" })), "|cff3366ffRob|r")
	end)

	test("Tags: hex colors made only of digits are colors, not lengths", function()
		expect.eq(render("[name:808080]", nil, data()), "|cff808080Bob|r")
		expect.eq(render("[name:000000]", nil, data()), "|cff000000Bob|r")
	end)

	test("Tags: live units read the unit API", function()
		unit = {
			name = "Alice",
			class = "MAGE",
			className = "Mage",
			level = -1,
			health = 30,
			healthMax = 60,
			powerType = 1,
			power = 40,
			powerMax = 100,
			mana = 500,
			manaMax = 1000,
			reaction = 2,
			guild = "Frost",
		}
		expect.eq(
			render("[name] [level] [class] [race] [guild] [perhp]", "target", nil),
			"Alice ?? Mage Human Frost 50"
		)
		expect.eq(render("[druidmana]", "target", nil), "500")
		expect.eq(render("[name:reaction]", "target", nil), "|cffff4c4cAlice|r")
		unit.reaction = 5
		expect.eq(render("[name:reaction]", "target", nil), "|cff4cff4cAlice|r")
		unit.powerType = 0
		expect.eq(render("[druidmana]", "target", nil), "")
		unit.afk = true
		expect.eq(render("[status][afk]", "target", nil), "AFKAFK")
		unit.dead = true
		expect.eq(render("[status]", "target", nil), "Dead")
		unit.offline = true
		expect.eq(render("[status]", "target", nil), "Offline")
		unit = { level = 80 }
		expect.eq(render("[name] [class] [name:class]", "target", nil), "UNKNOWN  |cffffffffUNKNOWN|r")
	end)

	test("Tags: TemplateUses reports health and power dependencies", function()
		expect.eq(UF.TemplateUses("[name]", "health"), false)
		expect.eq(UF.TemplateUses("[name] [curhp]", "health"), true)
		expect.eq(UF.TemplateUses("[name] [curhp]", "power"), false)
		expect.eq(UF.TemplateUses("[status] [perpp]", "power"), true)
		expect.eq(UF.TemplateUses("[status]", "health"), true)
		expect.eq(UF.TemplateUses("[curhp", "health"), false)
	end)

	local renderHealth = ns.Tags.RenderHealth

	test("Tags: health tags from current and maximum values", function()
		expect.eq(renderHealth("[perhp:floor]%", 999, 1000), "99%")
		expect.eq(renderHealth("[perhp]%", 999, 1000), "100%")
		expect.eq(renderHealth("[curhp]", 523, 1000), "523")
		expect.eq(renderHealth("[curhp] | [perhp:floor]%", 12345, 20000), "12.3k | 61%")
		expect.eq(renderHealth("[curhp:raw]/[maxhp:raw]", 12345, 20000), "12345/20000")
		expect.eq(renderHealth("[misshp:neg]", 70, 100), "-30")
		expect.eq(renderHealth("[misshp:neg]", 100, 100), "")
		expect.eq(renderHealth("[perhp:nofull]", 100, 100), "")
		expect.eq(renderHealth("[smarthp]", 500, 1000, true), "50%")
		expect.eq(renderHealth("[smarthp]", 500, 1000, false), "500")
		expect.eq(renderHealth("[status]", 0, 100), "Dead")
		expect.eq(renderHealth("[status]", 1, 100), "")
		expect.eq(renderHealth("[perhp:hp]", 100, 100), "|cff4cff4c100|r")
		expect.eq(renderHealth("[perhp:ff0000]", 50, 100), "|cffff000050|r")
	end)

	test("Tags: tags that need a unit render empty from values", function()
		expect.eq(renderHealth("[name][class][level][curpp:nofull][druidmana] [perhp]", 50, 100), " 50")
		expect.eq(renderHealth("[perhp:class]", 100, 100), "100")
		expect.eq(renderHealth("[perhp:reaction]|[perhp:power]", 100, 100), "100|100")
	end)

	test("Tags: the health presets render what the old fixed formats did", function()
		local formatValue = ns.FormatValue
		for _, max in ipairs({ 1, 3, 7, 100, 137, 23456, 1234567 }) do
			local step = math.max(1, math.floor(max / 300))
			for current = 0, max, step do
				local d = data({ health = current, healthMax = max })
				local percent = ("%d%%"):format(math.floor(current / max * 100 + 0.5))
				expect.eq(render("[perhp]%", nil, d), percent, "raid percent")
				local deficit = current < max and ("-%s"):format(formatValue(max - current)) or ""
				expect.eq(render("[misshp:neg]", nil, d), deficit, "raid missing health")
				local floored = math.floor(current / max * 100)
				expect.eq(renderHealth("[perhp:floor]%", current, max), ("%d%%"):format(floored), "nameplate percent")
				local value = current < 1e3 and ("%d"):format(current) or formatValue(current)
				expect.eq(renderHealth("[curhp]", current, max), value, "nameplate value")
				expect.eq(
					renderHealth("[curhp] | [perhp:floor]%", current, max),
					("%s | %d%%"):format(value, floored),
					"nameplate value and percent"
				)
				expect.eq(
					render("[perhp:floor]%", nil, d),
					("%d%%"):format(current / max * 100),
					"player plate percent"
				)
			end
		end
	end)

	test("Tags: CheckTag validates a tag body", function()
		expect.eq(UF.CheckTag("name"), nil)
		expect.eq(UF.CheckTag("name:3:class:raw:00ff00"), nil)
		expect.eq(UF.CheckTag("perhp:hp"), nil)
		expect.eq(UF.CheckTag("perhp:floor"), nil)
		expect.eq(UF.CheckTag("nope"), "nope")
		expect.deepEq({ UF.CheckTag("name:bogus") }, { "bogus", true })
		expect.deepEq({ UF.CheckTag("name:fffff") }, { "fffff", true })
		expect.eq(UF.CheckTag(""), "")
		expect.eq(UF.CheckTag(":"), ":")
	end)
end
