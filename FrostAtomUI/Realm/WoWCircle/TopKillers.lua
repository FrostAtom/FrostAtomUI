local _, ns = ...

ns.OnRealm("wowcircle", function()
	local UnitName = UnitName
	local GetTime = GetTime
	local ipairs, wipe = ipairs, wipe
	local tinsert = table.insert

	local TopKillers = ns:NewModule("TopKillers")
	local GossipCards = ns.GossipCards

	local NPC_NAME = "Top Killers"
	local DIM_ALPHA = GossipCards.DIM_ALPHA
	local COLUMNS = 2
	local CLASS_HEIGHT = 26
	local CLASS_GAP = 0
	local CLASS_ICON_SIZE = 18
	local CLASS_ICON_LEFT = 7
	local CLASS_TEXT_SIZE = 13
	local CLASS_TEXT_GAP = 7
	local PANEL_TITLE_SIZE = 16
	local PANEL_TITLE_Y = -10
	local PANEL_ICON_SIZE = 20
	local PANEL_ICON_GAP = 7
	local PANEL_CAPTION_SIZE = 11
	local PANEL_ROWS = 5
	local PANEL_ROWS_TOP = 40
	local PANEL_ROW_HEIGHT = 20
	local PANEL_BOTTOM = 8
	local PANEL_HEIGHT = PANEL_ROWS_TOP + PANEL_ROWS * PANEL_ROW_HEIGHT + PANEL_BOTTOM
	local PANEL_PADDING = 12
	local RANK_SIZE = 12
	local TOP_RANK_SIZE = 15
	local TOP_PLACES = 3
	local RANK_RIGHT = 26
	local NAME_LEFT = 36
	local NAME_SIZE = 13
	local KILLS_SIZE = 14
	local REPLY_WINDOW = 5
	local OPTION_PATTERN = "^Top%s+%d+%s+(.-)s$"
	local HEADER_PATTERN = "^Top%s+%d+%s+.+$"
	local ENTRY_PATTERN = "^[^:]+:%s*(.-),%s*[^:]+:%s*(%d+)%s*$"

	local createText = GossipCards.CreateText

	local function trim(text)
		return text:match("^%s*(.-)%s*$")
	end

	local function stripColors(text)
		return (text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""))
	end

	local function parseClass(text)
		local name = text:match(OPTION_PATTERN)
		local class = name and name:upper():gsub("%s", "")
		return class and RAID_CLASS_COLORS[class] and class
	end

	local function formatKills(kills)
		return (kills:reverse():gsub("(%d%d%d)", "%1 "):reverse():gsub("^ ", ""))
	end

	local selected
	local awaitingUntil = 0
	local entries = {}
	local classes = {}

	local panel = GossipCards.CreatePanel()
	panel.icon = panel:CreateTexture(nil, "ARTWORK")
	panel.icon:SetSize(PANEL_ICON_SIZE, PANEL_ICON_SIZE)
	panel.title = createText(panel, PANEL_TITLE_SIZE)
	panel.title:SetPoint("TOP", (PANEL_ICON_SIZE + PANEL_ICON_GAP) / 2, PANEL_TITLE_Y)
	panel.icon:SetPoint("RIGHT", panel.title, "LEFT", -PANEL_ICON_GAP, 0)
	panel.caption = createText(panel, PANEL_CAPTION_SIZE, DIM_ALPHA)
	panel.caption:SetPoint("BOTTOMRIGHT", panel, "TOPRIGHT", -PANEL_PADDING, -PANEL_ROWS_TOP + 2)
	panel.caption:SetText(KILLS)
	panel.rows = {}
	for i = 1, PANEL_ROWS do
		local y = -PANEL_ROWS_TOP - (i - 0.5) * PANEL_ROW_HEIGHT
		local row = {}
		row.rank = createText(panel, i <= TOP_PLACES and TOP_RANK_SIZE or RANK_SIZE, i <= TOP_PLACES and 1 or DIM_ALPHA)
		row.rank:SetPoint("RIGHT", panel, "TOPLEFT", RANK_RIGHT, y)
		row.rank:SetText(i)
		row.kills = createText(panel, KILLS_SIZE)
		row.kills:SetPoint("RIGHT", panel, "TOPRIGHT", -PANEL_PADDING, y)
		row.name = createText(panel, NAME_SIZE)
		row.name:SetPoint("LEFT", panel, "TOPLEFT", NAME_LEFT, y)
		row.name:SetPoint("RIGHT", row.kills, "LEFT", -PANEL_PADDING, 0)
		row.name:SetJustifyH("LEFT")
		panel.rows[i] = row
	end

	local function updatePanel()
		if not selected then
			return
		end
		ns.ClassIcons.SetClassTexture(panel.icon, selected)
		panel.title:SetText(LOCALIZED_CLASS_NAMES_MALE[selected])
		ns.SetShown(panel.caption, entries[1])
		for i, row in ipairs(panel.rows) do
			local entry = entries[i]
			ns.SetShown(row.rank, entry)
			row.name:SetText(entry and entry.name or "")
			row.kills:SetText(entry and formatKills(entry.kills) or "")
		end
	end

	local function createClass(view)
		view.icon = view:CreateTexture(nil, "ARTWORK")
		view.icon:SetSize(CLASS_ICON_SIZE, CLASS_ICON_SIZE)
		view.icon:SetPoint("LEFT", CLASS_ICON_LEFT, 0)
		view.label = createText(view, CLASS_TEXT_SIZE)
		view.label:SetPoint("LEFT", view.icon, "RIGHT", CLASS_TEXT_GAP, 0)
	end

	local function showClass(button, class)
		local view = GossipCards.ShowCard(button, createClass, CLASS_HEIGHT, CLASS_GAP, false, class == selected)
		ns.ClassIcons.SetClassTexture(view.icon, class)
		view.label:SetText(LOCALIZED_CLASS_NAMES_MALE[class])
	end

	local function isReply(message)
		if GetTime() > awaitingUntil then
			return false
		end
		message = stripColors(message)
		return message:find(HEADER_PATTERN) or message:find(ENTRY_PATTERN)
	end

	hooksecurefunc("SelectGossipOption", function(index)
		if UnitName("npc") == NPC_NAME and classes[index] then
			selected = classes[index]
			awaitingUntil = GetTime() + REPLY_WINDOW
			wipe(entries)
			updatePanel()
		end
	end)

	ChatFrame_AddMessageEventFilter("CHAT_MSG_SYSTEM", function(_, _, message)
		if isReply(message) then
			return true
		end
	end)

	TopKillers:RegisterEvent("CHAT_MSG_SYSTEM", function(_, message)
		if GetTime() > awaitingUntil then
			return
		end
		message = stripColors(message)
		if message:find(HEADER_PATTERN) then
			wipe(entries)
		else
			local name, kills = message:match(ENTRY_PATTERN)
			if name and #entries < PANEL_ROWS then
				tinsert(entries, { name = name, kills = kills })
			end
		end
		updatePanel()
	end)

	TopKillers:RegisterEvent("GOSSIP_CLOSED", function()
		selected = nil
		awaitingUntil = 0
		wipe(entries)
	end)

	local rows = {}

	GossipCards.Register(NPC_NAME, function(buttons)
		wipe(rows)
		wipe(classes)
		for _, button in ipairs(buttons) do
			tinsert(rows, button)
			if button.type == "Gossip" then
				local class = parseClass(trim(button:GetText() or ""))
				if class then
					classes[button:GetID()] = class
					showClass(button, class)
				end
			end
		end
		if selected then
			updatePanel()
			return rows, COLUMNS, panel, PANEL_HEIGHT
		end
		return rows, COLUMNS
	end)
end)
