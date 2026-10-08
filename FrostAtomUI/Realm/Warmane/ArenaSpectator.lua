local _, ns = ...

ns.OnRealm("warmane", function()
	local GetRealmName, UnitName = GetRealmName, UnitName
	local ipairs, tonumber, wipe = ipairs, tonumber, wipe
	local max, min = math.max, math.min
	local format = string.format
	local tinsert, tremove, tsort = table.insert, table.remove, table.sort

	local L = ns.L
	local GossipCards = ns.GossipCards

	local NPC_NAME = "Arena Spectator"
	local INK = GossipCards.INK
	local LIVE_INK = { 0.62, 0.1, 0.05 }
	local DIM_ALPHA = GossipCards.DIM_ALPHA
	local GRID_COLUMNS = 2
	local GRID_HEIGHT = 30
	local GRID_GAP = 6
	local GRID_LABEL_SIZE = 15
	local GRID_DOT_SIZE = 7
	local GRID_DOT_GAP = 7
	local GRID_NOTE_SIZE = 10
	local GRID_NOTE_X = 6
	local GRID_NOTE_Y = 4
	local ACTION_HEIGHT = 26
	local ACTION_GAP = 6
	local ACTION_PADDING = 12
	local ACTION_TEXT_X = 34
	local ACTION_TEXT_SIZE = 13
	local ACTION_GLYPH_SIZE = 13
	local MATCH_GAP = 4
	local MATCH_PADDING = 8
	local MATCH_RATING_SIZE = 14
	local MATCH_REALM_SIZE = 9
	local MATCH_REALM_GAP = 1
	local MATCH_VS_SIZE = 11
	local MATCH_VS_GAP = 12
	local MATCH_NAMES_X = 46
	local MATCH_NAME_SIZE = 11
	local LIVE_LINE_HEIGHT = 13
	local LIVE_PADDING = 7
	local LIVE_MAX_NAMES = 5
	local REPLAY_HEIGHT = 27
	local REPLAY_RATING_SIZE = 13
	local EMPTY_HEIGHT = 44
	local EMPTY_SIZE = 13
	local LIVE_PATTERN = "^%((%d+)%)%s*(.-)%s+%-VS%-%s+(.-)%s*%((%d+)%)$"
	local REPLAY_PATTERN = "^%((%d+)%)%s*'(.*)'%s+VS%s+'(.*)'%s*%((%d+)%)$"
	local LIVE_BRACKET_PATTERN = "^Spectate live (.+)$"
	local TOP_BRACKET_PATTERN = "^Replay top (.-) of the last (%d+) hours$"

	local SECTION_LIVE, SECTION_REPLAYS = 1, 2

	local NAVS = {
		Back = { BACK, 1 },
		["Previous Page"] = { PREV, 2 },
		["Next Page"] = { NEXT, 3 },
	}
	local PAGE_STEPS = { ["Previous Page"] = -1, ["Next Page"] = 1 }

	local ACTIONS = {
		["Spectate live games by Player Name"] = {
			kind = "live",
			byName = true,
			section = SECTION_LIVE,
			order = 1,
			label = L["Find by player name"],
			glyph = "magnifying-glass",
		},
		["Replay list by Player Name"] = {
			kind = "replays",
			byName = true,
			section = SECTION_REPLAYS,
			order = 1,
			label = L["Find by player name"],
			glyph = "magnifying-glass",
		},
		["Replay a Match ID"] = {
			kind = "replay",
			section = SECTION_REPLAYS,
			order = 2,
			label = L["Open by match ID"],
			glyph = "play",
		},
	}

	local BRACKET_LABELS = {
		["2vs2"] = "2v2",
		["3vs3"] = "3v3",
		["5vs5"] = "5v5",
		["Solo Queue"] = "SoloQ",
		["Rated Battlegrounds"] = "RBG",
	}

	local SECTION_TITLES = {
		[SECTION_LIVE] = L["Live games"],
		[SECTION_REPLAYS] = L["Replays"],
	}

	local REALMS = {
		Blackrock = true,
		Frostmourne = true,
		Icecrown = true,
		Lordaeron = true,
		Onyxia = true,
	}
	REALMS[(GetRealmName() or ""):match("^%S+") or ""] = true

	local createText = GossipCards.CreateText

	local function trim(text)
		return text:match("^%s*(.-)%s*$")
	end

	local function bracketLabel(text)
		text = text:gsub("%s+games$", "")
		return BRACKET_LABELS[text] or text
	end

	local function parseOption(text)
		local action = ACTIONS[text]
		if action then
			return action
		end
		local bracket = text:match(LIVE_BRACKET_PATTERN)
		if bracket then
			return { kind = "live", section = SECTION_LIVE, order = 0, label = bracketLabel(bracket), grid = true }
		end
		local hours
		bracket, hours = text:match(TOP_BRACKET_PATTERN)
		if bracket then
			return {
				kind = "top",
				section = SECTION_REPLAYS,
				order = 0,
				label = bracketLabel(bracket),
				hours = tonumber(hours),
				grid = true,
			}
		end
	end

	local function parseSide(text)
		local side = { names = {} }
		for word in text:gmatch("%S+") do
			tinsert(side.names, word)
		end
		if #side.names > 1 and REALMS[side.names[1]] then
			side.realm = tremove(side.names, 1)
		end
		return side
	end

	local function parseLive(text)
		local rating1, side1, side2, rating2 = text:match(LIVE_PATTERN)
		if not rating1 then
			return nil
		end
		side1, side2 = parseSide(side1), parseSide(side2)
		side1.rating, side2.rating = tonumber(rating1), tonumber(rating2)
		if #side1.names == 0 or #side2.names == 0 then
			return nil
		end
		if side2.rating > side1.rating then
			return side2, side1
		end
		return side1, side2
	end

	local function createGrid(grid)
		grid.label = createText(grid, GRID_LABEL_SIZE)
		grid.dot = ns.CreateGlyph(grid, "circle", GRID_DOT_SIZE)
		grid.dot:SetTextColor(LIVE_INK[1], LIVE_INK[2], LIVE_INK[3])
		grid.dot:SetPoint("RIGHT", grid.label, "LEFT", -GRID_DOT_GAP, 0)
		grid.note = createText(grid, GRID_NOTE_SIZE, DIM_ALPHA)
		grid.note:SetPoint("BOTTOMRIGHT", -GRID_NOTE_X, GRID_NOTE_Y)
	end

	local function showGrid(button, option)
		local grid = GossipCards.ShowCard(button, createGrid, GRID_HEIGHT, GRID_GAP)
		local live = option.kind == "live"
		grid.label:SetText(option.label)
		grid.label:ClearAllPoints()
		grid.label:SetPoint("CENTER", live and (GRID_DOT_SIZE + GRID_DOT_GAP) / 2 or 0, 0)
		ns.SetShown(grid.dot, live)
		grid.note:SetText(option.hours and format(L["%d h"], option.hours) or "")
		GossipCards.SetColumns(button, GRID_COLUMNS)
	end

	local function createAction(action)
		action.glyph = ns.CreateGlyph(action, "angle-right", ACTION_GLYPH_SIZE)
		action.glyph:SetTextColor(INK[1], INK[2], INK[3])
		action.glyph:SetPoint("CENTER", action, "LEFT", ACTION_PADDING + ACTION_GLYPH_SIZE / 2, 0)
		action.label = createText(action, ACTION_TEXT_SIZE)
		action.label:SetPoint("LEFT", ACTION_TEXT_X, 0)
		action.label:SetPoint("RIGHT", -ACTION_PADDING, 0)
		action.label:SetJustifyH("LEFT")
		action.label:SetWordWrap(false)
	end

	local function showAction(button, label, glyph, gap)
		local action = GossipCards.ShowCard(button, createAction, ACTION_HEIGHT, gap or ACTION_GAP)
		ns.SetGlyph(action.glyph, glyph or "angle-right")
		action.label:SetText(label)
	end

	local function createSide(view, point, sign)
		local side = { point = point, sign = sign, texts = {} }
		side.rating = createText(view, MATCH_RATING_SIZE)
		side.realm = createText(view, MATCH_REALM_SIZE, DIM_ALPHA)
		side.realm:SetPoint("TOP" .. point, side.rating, "BOTTOM" .. point, 0, -MATCH_REALM_GAP)
		return side
	end

	local function createVs(view)
		view.vs = createText(view, MATCH_VS_SIZE, DIM_ALPHA)
		view.vs:SetPoint("CENTER")
		view.vs:SetText("vs")
	end

	local function createLive(live)
		createVs(live)
		live.sides = { createSide(live, "LEFT", 1), createSide(live, "RIGHT", -1) }
	end

	local function getName(view, side, index)
		local name = side.texts[index]
		if not name then
			name = createText(view, MATCH_NAME_SIZE)
			name:SetJustifyH(side.sign > 0 and "RIGHT" or "LEFT")
			name:SetWordWrap(false)
			side.texts[index] = name
		end
		return name
	end

	local function layoutSide(view, side, data, lines)
		local realm = data.realm
		side.rating:ClearAllPoints()
		side.rating:SetPoint(side.point, MATCH_PADDING * side.sign, realm and (MATCH_REALM_SIZE + MATCH_REALM_GAP) / 2 or 0)
		side.rating:SetText(data.rating > 0 and data.rating or "")
		side.realm:SetText(realm or "")
		ns.SetShown(side.realm, realm)

		local count = #data.names
		local visible = min(count, lines)
		local shown = count > lines and lines - 1 or count
		local inner = side.sign > 0 and "RIGHT" or "LEFT"
		for i = 1, max(visible, #side.texts) do
			local name = getName(view, side, i)
			if i <= visible then
				local y = ((visible + 1) / 2 - i) * LIVE_LINE_HEIGHT
				name:ClearAllPoints()
				name:SetPoint(inner, view, "CENTER", -MATCH_VS_GAP * side.sign, y)
				name:SetPoint(side.point, view, side.point, MATCH_NAMES_X * side.sign, y)
				if i <= shown then
					name:SetText(data.names[i])
					name:SetAlpha(1)
				else
					name:SetText("+" .. (count - shown))
					name:SetAlpha(DIM_ALPHA)
				end
				name:Show()
			else
				name:Hide()
			end
		end
	end

	local function showLive(button, side1, side2)
		local lines = min(max(#side1.names, #side2.names), LIVE_MAX_NAMES)
		local height = lines * LIVE_LINE_HEIGHT + LIVE_PADDING * 2
		local live = GossipCards.ShowCard(button, createLive, height, MATCH_GAP)
		layoutSide(live, live.sides[1], side1, lines)
		layoutSide(live, live.sides[2], side2, lines)
	end

	local function createReplay(replay)
		createVs(replay)
		replay.sides = {}
		for i, point in ipairs({ "LEFT", "RIGHT" }) do
			local sign = i == 1 and 1 or -1
			local side = {}
			side.rating = createText(replay, REPLAY_RATING_SIZE)
			side.rating:SetPoint(point, MATCH_PADDING * sign, 0)
			side.team = createText(replay, MATCH_NAME_SIZE)
			side.team:SetPoint(point, MATCH_NAMES_X * sign, 0)
			side.team:SetPoint(sign > 0 and "RIGHT" or "LEFT", replay, "CENTER", -MATCH_VS_GAP * sign, 0)
			side.team:SetJustifyH(sign > 0 and "RIGHT" or "LEFT")
			side.team:SetWordWrap(false)
			replay.sides[i] = side
		end
	end

	local function showReplay(button, rating1, team1, rating2, team2)
		local replay = GossipCards.ShowCard(button, createReplay, REPLAY_HEIGHT, MATCH_GAP)
		replay.sides[1].rating:SetText(rating1 ~= "0" and rating1 or "")
		replay.sides[1].team:SetText(team1)
		replay.sides[2].rating:SetText(rating2 ~= "0" and rating2 or "")
		replay.sides[2].team:SetText(team2)
	end

	local function createEmpty(empty)
		empty.label = createText(empty, EMPTY_SIZE, DIM_ALPHA)
		empty.label:SetPoint("CENTER")
	end

	local function showEmpty(button, text)
		local empty = GossipCards.ShowCard(button, createEmpty, EMPTY_HEIGHT, MATCH_GAP, true)
		empty.label:SetText(text)
	end

	local options = {}
	local pageSteps = {}
	local context, searched
	local page = 1

	hooksecurefunc("SelectGossipOption", function(index, code)
		if UnitName("npc") ~= NPC_NAME then
			return
		end
		local option = options[index]
		if option then
			context, searched, page = option, code, 1
		elseif pageSteps[index] then
			page = max(1, page + pageSteps[index])
		end
	end)

	local function listTitle()
		if not context then
			return nil
		end
		local kind = context.kind
		if context.byName then
			if not searched or searched == "" then
				return nil
			end
			return format(kind == "live" and L["Live: %s"] or L["Replays: %s"], searched)
		elseif kind == "live" then
			return format(L["Live: %s"], context.label)
		elseif kind == "top" then
			return format(L["Top replays: %s"], context.label)
		end
	end

	local rows, entries, matches, others = {}, {}, {}, {}

	local function compareEntries(a, b)
		if a.option.section ~= b.option.section then
			return a.option.section < b.option.section
		end
		if a.option.order ~= b.option.order then
			return a.option.order < b.option.order
		end
		return a.index < b.index
	end

	local function compareMatches(a, b)
		if a.high ~= b.high then
			return a.high > b.high
		end
		if a.low ~= b.low then
			return a.low > b.low
		end
		return a.button:GetID() < b.button:GetID()
	end

	local function showRoot()
		tsort(entries, compareEntries)
		local section
		for _, entry in ipairs(entries) do
			local option, button = entry.option, entry.button
			if option.grid then
				showGrid(button, option)
			else
				showAction(button, option.label, option.glyph)
			end
			if option.section ~= section then
				section = option.section
				GossipCards.SetSection(button, SECTION_TITLES[section])
			end
			tinsert(rows, button)
		end
		for _, button in ipairs(others) do
			tinsert(rows, button)
		end
	end

	local function showList()
		tsort(matches, compareMatches)
		for _, match in ipairs(matches) do
			tinsert(rows, match.button)
		end
		for _, button in ipairs(others) do
			tinsert(rows, button)
		end
		local title = listTitle()
		if title then
			GossipCards.SetTitle(title, page > 1 and format(L["page %d"], page) or nil)
		end
	end

	GossipCards.Register(NPC_NAME, function(buttons)
		wipe(rows)
		wipe(entries)
		wipe(matches)
		wipe(others)
		wipe(options)
		wipe(pageSteps)
		local back
		for index, button in ipairs(buttons) do
			local text = button.type == "Gossip" and trim(button:GetText() or "") or ""
			local option = parseOption(text)
			if option then
				options[button:GetID()] = option
				tinsert(entries, { option = option, button = button, index = index })
			elseif NAVS[text] then
				pageSteps[button:GetID()] = PAGE_STEPS[text]
				if text == "Back" then
					back = button
				else
					GossipCards.AddNav(button, NAVS[text][1], NAVS[text][2])
				end
			else
				local side1, side2 = parseLive(text)
				if side1 then
					showLive(button, side1, side2)
					tinsert(matches, { button = button, high = side1.rating, low = side2.rating })
				else
					local rating1, team1, team2, rating2 = text:match(REPLAY_PATTERN)
					if rating1 then
						showReplay(button, rating1, team1, rating2, team2)
					else
						showAction(button, text, nil, MATCH_GAP)
					end
					tinsert(others, button)
				end
			end
		end

		if #entries > 0 then
			showRoot()
		else
			showList()
		end

		if back then
			local empty = #rows == 0
			GossipCards.AddNav(back, NAVS.Back[1], NAVS.Back[2], empty)
			if empty then
				showEmpty(back, context and context.kind == "live" and L["No live games right now"] or L["No games found"])
				tinsert(rows, back)
			end
		end
		return rows
	end)
end)
