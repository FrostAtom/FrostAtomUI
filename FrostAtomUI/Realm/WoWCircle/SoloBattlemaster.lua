local _, ns = ...

ns.OnRealm("wowcircle", function()
	local ipairs, wipe = ipairs, wipe
	local tinsert, tremove, tsort = table.insert, table.remove, table.sort
	local format = string.format

	local GossipCards = ns.GossipCards

	local NPC_NAME = "Solo Arena Battlemaster"
	local INK = GossipCards.INK
	local DANGER_INK = { 0.5, 0.08, 0.04 }
	local WIN_COLOR = "1e5a14"
	local LOSS_COLOR = "7a1a10"
	local DIM_ALPHA = GossipCards.DIM_ALPHA
	local ICON_TRIM = ns.ClassIcons.TRIM
	local CARD_GAP = 4
	local SECTION_GAP = 12
	local QUEUE_HEIGHT = 64
	local QUEUE_TITLE_SIZE = 16
	local QUEUE_TITLE_Y = -10
	local QUEUE_TOTAL_SIZE = 12
	local QUEUE_TOTAL_X = 10
	local QUEUE_TOTAL_GAP = 4
	local ROLE_ICON_SIZE = 19
	local ROLE_COUNT_SIZE = 15
	local ROLE_SPACING = 70
	local ROLE_BOTTOM = 10
	local ROLE_COUNT_GAP = 5
	local ACTION_PADDING = 12
	local ACTION_TEXT_X = 38
	local PRIMARY_HEIGHT = 34
	local PRIMARY_TEXT_SIZE = 15
	local PRIMARY_GLYPH_SIZE = 16
	local SECONDARY_HEIGHT = 28
	local SECONDARY_TEXT_SIZE = 13
	local SECONDARY_GLYPH_SIZE = 13
	local STATS_HEADLINE_SIZE = 26
	local STATS_HEADLINE_Y = -12
	local STATS_CAPTION_SIZE = 11
	local STATS_CAPTION_GAP = 2
	local STATS_ROWS_TOP = 68
	local STATS_ROW_HEIGHT = 21
	local STATS_ROW_SIZE = 13
	local STATS_PADDING = 16
	local STATS_BOTTOM = 10
	local QUEUE_PATTERN = "^(.-)\n+%s*Queued Players:%s*(%d+)"
	local ROLE_PATTERN = "Queued (%a+):%s*(%d+)"
	local STATS_PREFIX = "^SoloQ "
	local FALLBACK_GLYPH = "angle-right"

	local ROLE_ICONS = {
		Melees = "Interface\\Icons\\Ability_MeleeDamage",
		Casters = "Interface\\Icons\\Spell_Fire_FlameBolt",
		Healers = "Interface\\Icons\\Spell_Holy_FlashHeal",
	}
	local ROLE_FALLBACK_ICON = "Interface\\Icons\\INV_Misc_QuestionMark"

	local ACTIONS = {
		{ pattern = "^Sign up", glyph = "right-to-bracket", primary = true },
		{ pattern = "stats$", glyph = "chart-simple" },
		{ pattern = "^Create", glyph = "user-plus" },
		{ pattern = "^Disband", glyph = "user-xmark", danger = true },
	}

	local createText = GossipCards.CreateText

	local function trim(text)
		return text:match("^%s*(.-)%s*$")
	end

	local function findAction(text)
		for _, action in ipairs(ACTIONS) do
			if text:find(action.pattern) then
				return action
			end
		end
	end

	local function createQueue(queue)
		queue.title = createText(queue, QUEUE_TITLE_SIZE)
		queue.title:SetPoint("TOP", 0, QUEUE_TITLE_Y)
		queue.totalGlyph = ns.CreateGlyph(queue, "user", QUEUE_TOTAL_SIZE)
		queue.totalGlyph:SetTextColor(INK[1], INK[2], INK[3])
		queue.totalGlyph:SetAlpha(DIM_ALPHA)
		queue.totalGlyph:SetPoint("LEFT", queue.title, "RIGHT", QUEUE_TOTAL_X, 0)
		queue.total = createText(queue, QUEUE_TOTAL_SIZE, DIM_ALPHA)
		queue.total:SetPoint("LEFT", queue.totalGlyph, "RIGHT", QUEUE_TOTAL_GAP, 0)
		queue.roles = {}
	end

	local function getRole(queue, index)
		local role = queue.roles[index]
		if not role then
			role = {}
			role.icon = queue:CreateTexture(nil, "ARTWORK")
			role.icon:SetSize(ROLE_ICON_SIZE, ROLE_ICON_SIZE)
			role.icon:SetTexCoord(ICON_TRIM, 1 - ICON_TRIM, ICON_TRIM, 1 - ICON_TRIM)
			role.count = createText(queue, ROLE_COUNT_SIZE)
			role.count:SetPoint("LEFT", role.icon, "RIGHT", ROLE_COUNT_GAP, 0)
			queue.roles[index] = role
		end
		return role
	end

	local roles = {}

	local function showQueue(button, gap, title, total, text)
		local queue = GossipCards.ShowCard(button, createQueue, QUEUE_HEIGHT, gap, true)
		queue.title:SetText(title)
		queue.total:SetText(total)

		wipe(roles)
		for name, count in text:gmatch(ROLE_PATTERN) do
			if name ~= "Players" then
				tinsert(roles, name)
				tinsert(roles, count)
			end
		end
		local shown = #roles / 2
		for i = 1, shown do
			local role = getRole(queue, i)
			local name, count = roles[i * 2 - 1], roles[i * 2]
			local empty = count == "0"
			role.icon:SetTexture(ROLE_ICONS[name] or ROLE_FALLBACK_ICON)
			role.icon:SetDesaturated(empty)
			role.icon:SetAlpha(empty and DIM_ALPHA or 1)
			role.icon:ClearAllPoints()
			role.icon:SetPoint("BOTTOMRIGHT", queue, "BOTTOM", (i - (shown + 1) / 2) * ROLE_SPACING, ROLE_BOTTOM)
			role.icon:Show()
			role.count:SetText(count)
			role.count:SetAlpha(empty and DIM_ALPHA or 1)
			role.count:Show()
		end
		for i = shown + 1, #queue.roles do
			queue.roles[i].icon:Hide()
			queue.roles[i].count:Hide()
		end
	end

	local function createAction(action)
		action.glyph = action:CreateFontString(nil, "OVERLAY")
		action.glyph:SetPoint("CENTER", action, "LEFT", ACTION_PADDING + PRIMARY_GLYPH_SIZE / 2, 0)
		action.label = createText(action, PRIMARY_TEXT_SIZE)
		action.label:SetPoint("LEFT", ACTION_TEXT_X, 0)
		action.label:SetPoint("RIGHT", -ACTION_PADDING, 0)
		action.label:SetJustifyH("LEFT")
	end

	local function showAction(button, gap, text, info)
		local primary = info and info.primary
		local height = primary and PRIMARY_HEIGHT or SECONDARY_HEIGHT
		local action = GossipCards.ShowCard(button, createAction, height, gap)
		local ink = info and info.danger and DANGER_INK or INK
		ns.SetGlyph(
			action.glyph,
			info and info.glyph or FALLBACK_GLYPH,
			primary and PRIMARY_GLYPH_SIZE or SECONDARY_GLYPH_SIZE
		)
		action.glyph:SetTextColor(ink[1], ink[2], ink[3])
		action.label:SetFont(STANDARD_TEXT_FONT, primary and PRIMARY_TEXT_SIZE or SECONDARY_TEXT_SIZE)
		action.label:SetTextColor(ink[1], ink[2], ink[3])
		action.label:SetText(text)
	end

	local entries = {}

	local function parseStats(text)
		wipe(entries)
		for line in text:gmatch("[^\n]+") do
			for part in line:gmatch("[^/]+") do
				local key, value = part:match("^%s*(.-):%s*(.-)%s*$")
				if key then
					tinsert(entries, { key = key:gsub(STATS_PREFIX, ""), value = value })
				end
			end
		end
		local i = 1
		while entries[i] do
			local prefix = entries[i].key:match("^(.-)%s*Wins$")
			local losses = entries[i + 1]
			if prefix and losses and losses.key == prefix .. " Losses" then
				entries[i].key = prefix
				entries[i].value =
					format("|cff%s%s|r / |cff%s%s|r", WIN_COLOR, entries[i].value, LOSS_COLOR, losses.value)
				tremove(entries, i + 1)
			end
			i = i + 1
		end
		return #entries > 0
	end

	local function createStats(stats)
		stats.headline = createText(stats, STATS_HEADLINE_SIZE)
		stats.headline:SetPoint("TOP", 0, STATS_HEADLINE_Y)
		stats.caption = createText(stats, STATS_CAPTION_SIZE, DIM_ALPHA)
		stats.caption:SetPoint("TOP", stats.headline, "BOTTOM", 0, -STATS_CAPTION_GAP)
		stats.rows = {}
	end

	local function getStatsRow(stats, index)
		local row = stats.rows[index]
		if not row then
			row = {}
			local y = -STATS_ROWS_TOP - (index - 1) * STATS_ROW_HEIGHT
			row.label = createText(stats, STATS_ROW_SIZE)
			row.label:SetPoint("TOPLEFT", STATS_PADDING, y)
			row.value = createText(stats, STATS_ROW_SIZE)
			row.value:SetPoint("TOPRIGHT", -STATS_PADDING, y)
			stats.rows[index] = row
		end
		return row
	end

	local function showStats(button, gap)
		local count = #entries - 1
		local height = STATS_ROWS_TOP + count * STATS_ROW_HEIGHT + STATS_BOTTOM
		local stats = GossipCards.ShowCard(button, createStats, height, gap, true)
		stats.headline:SetText(entries[1].value)
		stats.caption:SetText(entries[1].key)
		for i = 1, count do
			local row = getStatsRow(stats, i)
			row.label:SetText(entries[i + 1].key)
			row.value:SetText(entries[i + 1].value)
			row.label:Show()
			row.value:Show()
		end
		for i = count + 1, #stats.rows do
			stats.rows[i].label:Hide()
			stats.rows[i].value:Hide()
		end
	end

	local rows = {}

	local function compareRows(a, b)
		if a.rank ~= b.rank then
			return a.rank < b.rank
		end
		return a.index < b.index
	end

	GossipCards.Register(NPC_NAME, function(buttons)
		wipe(rows)
		for index, button in ipairs(buttons) do
			local row = { button = button, index = index, rank = 4 }
			if button.type == "Gossip" then
				local text = trim(button:GetText() or "")
				local title, total = text:match(QUEUE_PATTERN)
				row.text = text
				if title then
					row.kind, row.title, row.total, row.rank = "queue", title, total, 0
				elseif text:find(STATS_PREFIX) and parseStats(text) then
					row.kind, row.rank = "stats", 0
				else
					row.kind, row.action = "action", findAction(text)
					row.rank = text:find("3v3") and 1 or 2
				end
			end
			tinsert(rows, row)
		end
		tsort(rows, compareRows)

		for i, row in ipairs(rows) do
			local nextRow = rows[i + 1]
			local gap = nextRow and (nextRow.rank > 1) ~= (row.rank > 1) and SECTION_GAP or CARD_GAP
			local button = row.button
			if row.kind == "queue" then
				showQueue(button, gap, row.title, row.total, row.text)
				GossipCards.AddNav(button, REFRESH, 2, true)
			elseif row.kind == "stats" then
				showStats(button, gap)
				GossipCards.AddNav(button, BACK, 1, true)
			elseif row.kind == "action" then
				showAction(button, gap, row.text, row.action)
			end
			rows[i] = button
		end
		return rows
	end)
end)
