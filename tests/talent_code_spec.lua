return function(ns, env, R)
	local test, expect = R.test, R.expect

	local TREES = {
		{ { 2, 1, 3 }, { 1, 2, 5 }, { 1, 1, 2 }, { 3, 2, 1 } },
		{ { 1, 1, 5 }, { 1, 3, 3 }, { 2, 2, 2 } },
		{ { 1, 1, 3 }, { 2, 1, 1 } },
	}
	local POINTS_PER_TIER = 5

	local state, message
	local function setup(learned, unspent)
		state = { rank = {}, preview = {}, unspent = unspent or 71 }
		for tab, tree in ipairs(TREES) do
			state.rank[tab], state.preview[tab] = {}, {}
			for i = 1, #tree do
				local rank = learned and learned[tab] and learned[tab][i] or 0
				state.rank[tab][i], state.preview[tab][i] = rank, rank
			end
		end
		message = nil
	end

	local function pointsBelow(tab, tier)
		local sum = 0
		for i, talent in ipairs(TREES[tab]) do
			if talent[1] < tier then
				sum = sum + state.preview[tab][i]
			end
		end
		return sum
	end

	local function previewSpent()
		local spent = 0
		for tab = 1, #TREES do
			for i = 1, #TREES[tab] do
				spent = spent + state.preview[tab][i] - state.rank[tab][i]
			end
		end
		return spent
	end

	local box = env.sandbox({
		StaticPopupDialogs = {},
		GetNumTalentTabs = function()
			return #TREES
		end,
		GetNumTalents = function(tab)
			return #TREES[tab]
		end,
		GetTalentInfo = function(tab, i)
			local talent = TREES[tab][i]
			return "T" .. tab .. i,
				"icon",
				talent[1],
				talent[2],
				state.rank[tab][i],
				talent[3],
				nil,
				true,
				state.preview[tab][i]
		end,
		GetUnspentTalentPoints = function()
			return state.unspent
		end,
		GetActiveTalentGroup = function()
			return 1
		end,
		ResetGroupPreviewTalentPoints = function()
			for tab = 1, #TREES do
				for i = 1, #TREES[tab] do
					state.preview[tab][i] = state.rank[tab][i]
				end
			end
		end,
		AddPreviewTalentPoints = function(tab, i, points)
			local talent = TREES[tab][i]
			if pointsBelow(tab, talent[1]) < (talent[1] - 1) * POINTS_PER_TIER then
				return
			end
			points = math.min(points, talent[3] - state.preview[tab][i], state.unspent - previewSpent())
			state.preview[tab][i] = state.preview[tab][i] + math.max(points, 0)
		end,
		SetCVar = function() end,
		UIErrorsFrame = {
			AddMessage = function(_, text)
				message = text
			end,
		},
	})

	local Tree
	local function load()
		if not Tree then
			env.loadFile("Modules/Books/TalentFrame.lua", ns, box)
			Tree = ns.TalentTree
		end
	end

	local function import(code)
		load()
		box.ImportPopupWideEditBox = {
			GetText = function()
				return code
			end,
		}
		local popup = {
			GetName = function()
				return "ImportPopup"
			end,
		}
		local failed = box.StaticPopupDialogs.FROSTATOMUI_TALENT_IMPORT.OnAccept(popup)
		expect.eq(not failed, message == nil, "failure flag matches the message")
		return message
	end

	local function previewCode()
		return Tree.Code(false, false, 1, true)
	end

	test("Talent code: digits follow tier then column order, trees joined by -", function()
		load()
		setup({ { 3, 5, 2, 0 }, nil, { 1 } })
		expect.eq(Tree.Code(false, false, 1, false), "2530-000-10")
		state.preview[2][3] = 2
		expect.eq(previewCode(), "2530-002-10")
		expect.eq(Tree.Code(false, false, 1, false), "2530-000-10")
	end)

	test("Talent code: importing a code places it as a preview", function()
		setup()
		expect.eq(import("2530-1-1"), nil)
		expect.eq(previewCode(), "2530-100-10")
		expect.eq(Tree.Code(false, false, 1, false), "0000-000-00", "nothing learned")
	end)

	test("Talent code: a full exported code round-trips through import", function()
		setup({ { 3, 5, 2, 1 }, { 3, 2, 1 }, { 2, 0 } })
		local code = Tree.Code(false, false, 1, false)
		expect.eq(code, "2531-321-20")
		setup()
		expect.eq(import(code), nil)
		expect.eq(previewCode(), code)
	end)

	test("Talent code: the code is found inside a Wowhead URL", function()
		setup()
		expect.eq(import("https://www.wowhead.com/wotlk/talent-calc/mage/253-03_1a2b"), nil)
		expect.eq(previewCode(), "2530-030-00")
		setup()
		expect.eq(import("  -03\n"), nil)
		expect.eq(previewCode(), "0000-030-00")
	end)

	test("Talent code: invalid codes are rejected without touching the preview", function()
		for _, code in ipairs({ "", "hello", "--", "1-1-1-1", "25301", "6", "0-6", "00-000-000" }) do
			setup()
			expect.eq(import(code), "Invalid talent code", ("%q"):format(code))
			expect.eq(previewCode(), "0000-000-00")
		end
	end)

	test("Talent code: learned ranks above the code need a reset", function()
		setup({ { 0, 0, 2 } })
		expect.eq(import("1"), "The code needs a talent reset")
		setup({ { 0, 0, 2 } })
		expect.eq(import("25"), nil)
		expect.eq(previewCode(), "2500-000-00")
	end)

	test("Talent code: points are counted against the unspent points", function()
		setup(nil, 5)
		expect.eq(import("253"), "Not enough talent points: 10 needed, 5 available")
		setup({ { 0, 5, 2 } }, 3)
		expect.eq(import("253"), nil)
	end)

	test("Talent code: a code the tier rules reject is reported", function()
		setup()
		expect.eq(import("003"), "The talent code could not be fully applied")
	end)
end
