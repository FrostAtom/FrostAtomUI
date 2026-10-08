return function(ns, env, R)
	local test, expect = R.test, R.expect

	local config = {}
	local chunk = assert(loadfile(env.root .. "/FrostAtomUI_Config/Search.lua"))
	setfenv(chunk, env.sandbox({ FrostAtomUI = { Lower = ns.Lower } }))
	chunk("FrostAtomUI_Config", config)
	local Search = config.Search

	local function entry(path, label, extra)
		local e = { path = path, label = label }
		for k, v in pairs(extra or {}) do
			e[k] = v
		end
		return e
	end

	local function results(schema)
		local list = {}
		for _, e in ipairs(schema) do
			if not e.header then
				list[#list + 1] = e
			end
		end
		return list
	end

	local function titles(schema)
		local list = {}
		for _, e in ipairs(schema) do
			if e.header then
				list[#list + 1] = e.header
			end
		end
		return list
	end

	test("Search: is:changed keeps only accepted entries and needs no words", function()
		local changed = entry("a.width", "Width", { changed = true })
		local sources = {
			{ entries = { changed, entry("a.height", "Height") }, title = "A", context = "a", rank = 1 },
		}
		local search = Search.ParseQuery("is:changed")
		search.accept = function(filter, e)
			return filter == "changed" and e.changed == true
		end
		expect.deepEq(search.filters, { "changed" })
		local schema, count = Search.Collect(sources, search)
		expect.eq(count, 1)
		expect.eq(results(schema)[1], changed)
	end)

	test("Search: in:<page> limits the results to pages whose name matches", function()
		local sources = {
			{ entries = { entry("arena.size", "Size") }, title = "Arena", context = "arena", rank = 1 },
			{ entries = { entry("bags.size", "Size") }, title = "Bags", context = "bags", rank = 1 },
		}
		local search = Search.ParseQuery("in:arena size")
		expect.eq(search.scope, "arena")
		local schema, count = Search.Collect(sources, search)
		expect.eq(count, 1)
		expect.deepEq(titles(schema), { "Arena" })
	end)

	test("Search: the shown results stop at the limit, the count stays full", function()
		local list = {}
		for i = 1, 70 do
			list[i] = entry("a.size" .. i, "Size")
		end
		local schema, count, shown =
			Search.Collect({ { entries = list, title = "A", context = "", rank = 1 } }, Search.ParseQuery("size"))
		expect.eq(count, 70)
		expect.eq(shown, 60)
		expect.eq(#results(schema), 60)
	end)
	test("Search: a path shown in a tab and in an element is listed once, under the tab", function()
		local inElement = entry("unitFrames.playerWidth", "Width")
		local inTab = entry("unitFrames.playerWidth", "Width")
		local sources = {
			{ entries = { inElement }, title = "Unit frames / Player", context = "unit frames player", rank = 3 },
			{ entries = { inTab }, title = "Unit frames / Player tab", context = "unit frames player", rank = 1 },
		}
		local schema, count = Search.Collect(sources, Search.ParseQuery("width"))
		expect.eq(count, 1)
		expect.eq(results(schema)[1], inTab)
		expect.deepEq(titles(schema), { "Unit frames / Player tab" })
	end)

	test("Search: one path in several elements and tabs counts once; the first tab wins", function()
		local first = entry("unitFrames.partyWidth", "Width")
		local sources = {
			{ entries = { entry("unitFrames.partyWidth", "Width") }, title = "Party 1", context = "", rank = 3 },
			{ entries = { entry("unitFrames.partyWidth", "Width") }, title = "Party 2", context = "", rank = 3 },
			{ entries = { first }, title = "Party tab", context = "", rank = 1 },
			{ entries = { entry("unitFrames.partyWidth", "Width") }, title = "Party tab 2", context = "", rank = 1 },
			{ entries = { entry("unitFrames.arenaWidth", "Width") }, title = "Arena", context = "", rank = 3 },
		}
		local schema, count = Search.Collect(sources, Search.ParseQuery("width"))
		expect.eq(count, 2)
		local seen = {}
		for _, e in ipairs(results(schema)) do
			expect.eq(seen[e.path], nil, "duplicate " .. e.path)
			seen[e.path] = true
		end
		expect.truthy(seen["unitFrames.arenaWidth"])
		expect.truthy(results(schema)[1] == first or results(schema)[2] == first)
	end)

	test("Search: a hidden tab entry does not hide the visible one elsewhere", function()
		local visible = entry("groupCooldowns.size", "Icon size")
		local sources = {
			{
				entries = { entry("groupCooldowns.size", "Icon size", { hidden = true }) },
				title = "Tab",
				context = "",
				rank = 1,
			},
			{ entries = { visible }, title = "Element", context = "", rank = 3 },
		}
		local schema, count = Search.Collect(sources, Search.ParseQuery("icon size"))
		expect.eq(count, 1)
		expect.eq(results(schema)[1], visible)
	end)

	test("Search: entries without a path are deduplicated by identity only", function()
		local button = { label = "Test frames", type = "execute" }
		local other = { label = "Test frames", type = "execute" }
		local sources = {
			{ entries = { button }, title = "A", context = "", rank = 2 },
			{ entries = { button, other }, title = "B", context = "", rank = 1 },
		}
		local _, count = Search.Collect(sources, Search.ParseQuery("test"))
		expect.eq(count, 2)
	end)

	test("Search: the element fallback is used only when none of its entries matched", function()
		local built = 0
		local function source(entries)
			return {
				entries = entries,
				title = "Unit frames / Arena 1",
				context = "unit frames",
				rank = 3,
				fallback = {
					key = "element:unitFrames.arena",
					name = "arena 1",
					context = "unit frames",
					build = function()
						built = built + 1
						return { label = "Arena 1", type = "execute" }
					end,
				},
			}
		end
		local _, count = Search.Collect({ source({ entry("unitFrames.arenaGap", "Gap") }) }, Search.ParseQuery("arena"))
		expect.eq(count, 1)
		expect.eq(built, 1)
		local tab =
			{ entries = { entry("unitFrames.arenaHeight", "Arena height") }, title = "Tab", context = "", rank = 1 }
		local deduped = source({ entry("unitFrames.arenaHeight", "Arena height") })
		_, count = Search.Collect({ tab, deduped }, Search.ParseQuery("arena"))
		expect.eq(count, 1)
		expect.eq(built, 1)
	end)

	test("Search: results are ranked by score, exact label first", function()
		local exact = entry("a.castbar", "Castbar")
		local prefix = entry("a.castbarHeight", "Castbar height")
		local section = entry("a.other", "Height")
		local sources = {
			{ entries = { { header = "Castbar" }, section }, title = "P", context = "p", rank = 2 },
			{ entries = { prefix, exact }, title = "Q", context = "q", rank = 2 },
		}
		local schema, count = Search.Collect(sources, Search.ParseQuery("castbar"))
		expect.eq(count, 3)
		local list = results(schema)
		expect.eq(list[1], exact)
		expect.eq(list[2], prefix)
		expect.eq(list[3], section)
	end)

	test("Search: Cyrillic labels match lowercase queries", function()
		local sources = { { entries = { entry("x.y", "Ширина") }, title = "T", context = "", rank = 1 } }
		local _, count = Search.Collect(sources, Search.ParseQuery(ns.Lower("ШИРИНА")))
		expect.eq(count, 1)
	end)

	local full = {}
	local sourceTexts = { ["Ширина"] = "Width", ["Арена"] = "Arena" }
	local fullChunk = assert(loadfile(env.root .. "/FrostAtomUI_Config/Search.lua"))
	setfenv(
		fullChunk,
		env.sandbox({
			FrostAtomUI = {
				Lower = ns.Lower,
				SourceText = function(text)
					return sourceTexts[text]
				end,
			},
		})
	)
	assert(loadfile(env.root .. "/FrostAtomUI_Config/SearchSynonyms.lua"))("FrostAtomUI_Config", full)
	fullChunk("FrostAtomUI_Config", full)
	local Full = full.Search

	local function first(sources, query)
		local schema, count = Full.Collect(sources, Full.ParseQuery(query))
		return results(schema)[1], count
	end

	test("Search: ё equals е, punctuation is a space", function()
		local found = entry("a.b", "Ещё раз")
		local sources = { { entries = { found }, title = "T", context = "", rank = 1 } }
		expect.eq((first(sources, "еще")), found)
		local map = entry("a.c", "Мини-карта")
		sources = { { entries = { map }, title = "T", context = "", rank = 1 } }
		expect.eq((first(sources, "мини карта")), map)
	end)

	test("Search: a short token matches whole words and word starts, never the inside of a word", function()
		local dr = entry("dr.target", "DR on target")
		local drag = entry("bar.drag", "Drag modifier")
		local accept = entry("p.accept", "Accept invites")
		local sources = { { entries = { drag, accept, dr }, title = "T", context = "", rank = 1 } }
		local top, count = first(sources, "dr")
		expect.eq(top, dr)
		expect.eq(count, 2, "Accept is not found by dr")
		local _, ccCount = first(sources, "cc")
		expect.eq(ccCount, 0)
	end)

	test("Search: synonyms, English keys and addon names find the setting", function()
		local timers = entry("cooldownTimer.minDuration", "Cooldown timers")
		local trinket = entry("unitFrames.trinket", "Trinket")
		local width = entry("unitFrames.playerWidth", "Ширина")
		local arena = entry("unitFrames.arenaGap", "Gap")
		local stealth = entry("arenaUnseen.enabled", "Не скрывать невидимых противников")
		local sources = {
			{ entries = { timers, trinket, width, stealth }, title = "T", context = "", rank = 1 },
			{ entries = { arena }, title = "Арена", context = "арена arena", rank = 1 },
		}
		expect.eq((first(sources, "кд")), timers)
		expect.eq((first(sources, "тринкет")), trinket)
		expect.eq((first(sources, "width")), width)
		expect.eq((first(sources, "gladius")), arena)
		expect.eq((first(sources, "стелс")), stealth)
	end)
end
