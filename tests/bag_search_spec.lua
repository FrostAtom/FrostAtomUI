return function(ns, env, R)
	local test, expect = R.test, R.expect

	local catalog = {
		[100] = { "Furious Gladiator's Silk Robe", 4, 245, "Armor", "Cloth", "INVTYPE_ROBE" },
		[101] = { "Relentless Gladiator's Plate Helm", 4, 258, "Armor", "Plate", "INVTYPE_HEAD" },
		[102] = { "Runic Mana Potion", 1, 70, "Consumable", "Potion", "" },
		[103] = { "Frozen Orb", 3, 80, "Trade Goods", "Elemental", "" },
		[104] = { "Battered Hilt", 4, 80, "Quest", "Quest", "" },
		[106] = { "Wrathful Gladiator's Frost Staff", 4, 264, "Weapon", "Staves", "INVTYPE_2HWEAPON" },
	}
	local tooltips = {
		[100] = { "Furious Gladiator's Silk Robe", "Soulbound", "Chest", "+50 Resilience Rating" },
		[101] = { "Relentless Gladiator's Plate Helm", "Binds when picked up", "Head" },
		[103] = { "Frozen Orb", "Binds when picked up" },
		[104] = { "Battered Hilt", "Quest Item", "Use: Starts a quest" },
		[106] = { "Wrathful Gladiator's Frost Staff", "Binds when equipped", "Two-Hand" },
	}
	local QUALITY = { "Poor", "Common", "Uncommon", "Rare", "Epic", "Legendary", "Artifact", "Heirloom" }

	local box
	local function fontString(text)
		return {
			GetText = function()
				return text
			end,
			IsShown = function()
				return true
			end,
			GetTextColor = function()
				return 1, 1, 1
			end,
		}
	end
	local function scanTooltip(_, name)
		local lines = {}
		return {
			GetName = function()
				return name
			end,
			SetOwner = function() end,
			Hide = function() end,
			SetHyperlink = function(_, link)
				lines = tooltips[tonumber(link:match("^item:(%d+)$"))] or {}
				for i, text in ipairs(lines) do
					box[name .. "TextLeft" .. i] = fontString(text)
				end
			end,
			NumLines = function()
				return #lines
			end,
		}
	end

	box = env.sandbox({
		CreateFrame = scanTooltip,
		GetItemInfo = function(id)
			local item = catalog[id]
			if item then
				return item[1], "link", item[2], item[3], 1, item[4], item[5], 1, item[6]
			end
		end,
		UnitLevel = function()
			return 80
		end,
		GetAuctionItemClasses = function()
			return "Weapon",
				"Armor",
				"Container",
				"Consumable",
				"Glyph",
				"Trade Goods",
				"Projectile",
				"Quiver",
				"Recipe",
				"Gem",
				"Miscellaneous",
				"Quest"
		end,
		GetAuctionItemSubClasses = function(class)
			if class == 2 then
				return "Miscellaneous", "Cloth", "Leather", "Mail", "Plate"
			end
			return "One-Handed Axes", "Two-Handed Axes"
		end,
		GetNumEquipmentSets = function()
			return 2
		end,
		GetEquipmentSetInfo = function(i)
			return ({ "Arena PvP", "Healing" })[i]
		end,
		GetEquipmentSetItemIDs = function(name)
			if name == "Arena PvP" then
				return { 100, 0, 1, 106 }
			end
		end,
		INVTYPE_ROBE = "Chest",
		INVTYPE_HEAD = "Head",
		INVTYPE_2HWEAPON = "Two-Hand",
		ITEM_BIND_ON_EQUIP = "Binds when equipped",
		ITEM_BIND_ON_PICKUP = "Binds when picked up",
		ITEM_SOULBOUND = "Soulbound",
		ITEM_BIND_TO_ACCOUNT = "Binds to account",
		ITEM_BIND_QUEST = "Quest Item",
		RED_FONT_COLOR_CODE = "|cffff2020",
	}, function(key)
		return key == "" or key:find("^INVTYPE_") or key:find("BagScanTooltipText")
	end)
	for i, name in ipairs(QUALITY) do
		box["ITEM_QUALITY" .. (i - 1) .. "_DESC"] = name
	end
	env.loadFile("Modules/BagItems.lua", ns, box)
	local BagItems = ns.BagItems

	local function matching(text)
		local query = BagItems.CompileSearch(text)
		local ids = {}
		for id in pairs(catalog) do
			if BagItems.Matches(query, id) then
				ids[#ids + 1] = id
			end
		end
		table.sort(ids)
		return table.concat(ids, ",")
	end

	local function term(text)
		local query = BagItems.CompileSearch(text)
		expect.truthy(query and #query == 1 and #query[1] == 1, text .. " -> one term")
		local t = query[1][1]
		return table.concat(
			{ tostring(t.kind), tostring(t.op), tostring(t.value), tostring(t.number), tostring(t.negate) },
			" "
		)
	end

	test("Bag search: Cyrillic names match in any letter case", function()
		catalog[107] = { "Ледяной Меч", 3, 200, "Weapon", "Staves", "" }
		local result = matching(ns.Lower("МЕЧ"))
		catalog[107] = nil
		expect.eq(result, "107")
	end)

	test("Bag search: empty queries compile to nil", function()
		for _, text in ipairs({ "", "   ", "|", " | | ", "!", "& &", "q:nothing", "! | lvl>abc" }) do
			expect.eq(BagItems.CompileSearch(text), nil, ("%q"):format(text))
		end
	end)

	test("Bag search: spaces and & are AND, | is OR, ! negates", function()
		local query = BagItems.CompileSearch("a b&c | !d")
		expect.eq(#query, 2)
		expect.eq(#query[1], 3)
		expect.deepEq({ query[1][3].value, query[2][1].value, query[2][1].negate }, { "c", "d", true })
		expect.eq(#BagItems.CompileSearch("a||b"), 2)
	end)

	test("Bag search: keyed terms, operators and quality names", function()
		expect.eq(term("q:epic"), "quality : epic 4 false")
		expect.eq(term("q>=3"), "quality >= 3 3 false")
		expect.eq(term("quality<rare"), "quality < rare 3 false")
		expect.eq(term("q:e"), "quality : e 4 false")
		expect.eq(term("q:leg"), "quality : leg 5 false")
		expect.eq(term("q=poor"), "quality = poor 0 false")
		expect.eq(term("!ilvl>=251"), "level >= 251 251 true")
		expect.eq(term("lvl<200"), "level < 200 200 false")
		expect.eq(term("l:80"), "level : 80 80 false")
		expect.eq(term("t:cloth"), "type : cloth nil false")
		expect.eq(term("n:frost"), "name : frost nil false")
		expect.eq(term("tt:resil"), "tooltip : resil nil false")
		expect.eq(term("boe"), "bind nil boe nil false")
		expect.eq(term("foo:bar"), "text nil foo:bar nil false")
		expect.eq(term("name:"), "text nil name: nil false")
		expect.eq(term("!!x"), "text nil !x nil true")
	end)

	test("Bag search: plain text matches name, type, subtype and slot", function()
		expect.eq(matching("gladiator"), "100,101,106")
		expect.eq(matching("chest"), "100")
		expect.eq(matching("staves"), "106")
		expect.eq(matching("potion"), "102")
		expect.eq(matching("gladiator's frost"), "106")
		expect.eq(matching("gladiator !plate"), "100,106")
		expect.eq(matching("potion | orb"), "102,103")
		expect.eq(matching("n:cloth"), "")
		expect.eq(matching("t:cloth"), "100")
		expect.eq(matching("t:two-hand"), "106")
	end)

	test("Bag search: quality and item level comparisons", function()
		expect.eq(matching("q:epic"), "100,101,104,106")
		expect.eq(matching("q<3"), "102")
		expect.eq(matching("q>=rare ilvl>250"), "101,106")
		expect.eq(matching("ilvl<=80"), "102,103,104")
		expect.eq(matching("!q:epic"), "102,103")
	end)

	test("Bag search: equipment sets ignore empty and skipped slots", function()
		expect.eq(matching("s:arena"), "100,106")
		expect.eq(matching("s:heal"), "")
		expect.eq(matching("s:nothing"), "")
		expect.eq(matching("s:a"), "100,106")
	end)

	test("Bag search: binding and tooltip terms read the tooltip", function()
		expect.eq(matching("boe"), "106")
		expect.eq(matching("bop"), "100,101,103")
		expect.eq(matching("quest"), "104")
		expect.eq(matching("tt:resilience"), "100")
		expect.eq(matching("tt:starts a quest | boe"), "104,106")
	end)

	test("Bag search: Matches reports uncertainty for uncached items and missing tooltips", function()
		expect.deepEq({ BagItems.Matches(BagItems.CompileSearch("gladiator"), 105) }, { false, true })
		expect.deepEq({ BagItems.Matches(BagItems.CompileSearch("boe"), 102) }, { false, true })
		expect.deepEq({ BagItems.Matches(BagItems.CompileSearch("!boe"), 102) }, { true, true })
		expect.deepEq({ BagItems.Matches(BagItems.CompileSearch("q:common"), 102) }, { true, false })
		expect.deepEq({ BagItems.Matches(BagItems.CompileSearch("potion | boe"), 102) }, { true, false })
	end)

	test("Bag search: LinkQuality reads the link color", function()
		expect.eq(ns.LinkQuality("|cffa335ee|Hitem:1:0|h[Robe]|h|r"), 4)
		expect.eq(ns.LinkQuality("|cFFFF8000|Hitem:2:0|h[Sword]|h|r"), 5)
		expect.eq(ns.LinkQuality("|cff123456|Hitem:3:0|h[Odd]|h|r"), nil)
		expect.eq(ns.LinkQuality("item:4"), nil)
	end)
end
