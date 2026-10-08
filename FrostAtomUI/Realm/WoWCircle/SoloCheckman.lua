local _, ns = ...

ns.OnRealm("wowcircle", function()
	local UnitName = UnitName
	local ipairs, wipe = ipairs, wipe
	local tinsert = table.insert

	local GossipCards = ns.GossipCards

	local NPC_NAME = "Solo Arena Checkman"
	local INK = GossipCards.INK
	local DIM_ALPHA = GossipCards.DIM_ALPHA
	local BRACKET_HEIGHT = 44
	local BRACKET_GAP = 8
	local BRACKET_LABEL_SIZE = 17
	local BRACKET_GLYPH = "ranking-star"
	local BRACKET_GLYPH_SIZE = 15
	local BRACKET_GLYPH_GAP = 8
	local ROW_HEIGHT = 24
	local ROW_GAP = 0
	local RANK_SIZE = 12
	local TOP_RANK_SIZE = 15
	local TOP_PLACES = 3
	local RANK_RIGHT = 26
	local ICON_SIZE = 17
	local ICON_LEFT = 34
	local NAME_SIZE = 13
	local NAME_GAP = 6
	local WINRATE_SIZE = 12
	local WINRATE_RIGHT = -56
	local RATING_SIZE = 14
	local RATING_RIGHT = -10
	local BRACKET_PATTERN = "^Show%s+(.-)%s+stats$"
	local CLASS_ROW_PATTERN = "^(%d+)%s*%-%s*(.-)%s*%[(.-)%]%s*(%d+)%%$"
	local ROW_PATTERN = "^(%d+)%s*%-%s*(.-)%s+(%d+)%%$"

	local createText = GossipCards.CreateText

	local function trim(text)
		return text:match("^%s*(.-)%s*$")
	end

	local function capitalize(space, letter)
		return space .. letter:upper()
	end

	local function parseBracket(text)
		local bracket = text:match(BRACKET_PATTERN)
		return bracket and (bracket:gsub("(%s)(%l)", capitalize))
	end

	local function parseRow(text)
		local rating, name, className, winrate = text:match(CLASS_ROW_PATTERN)
		if rating then
			local class = className:upper():gsub("%s", "")
			return rating, name, RAID_CLASS_COLORS[class] and class, winrate
		end
		rating, name, winrate = text:match(ROW_PATTERN)
		return rating, name, nil, winrate
	end

	local function createBracket(bracket)
		bracket.label = createText(bracket, BRACKET_LABEL_SIZE)
		bracket.label:SetPoint("CENTER", (BRACKET_GLYPH_SIZE + BRACKET_GLYPH_GAP) / 2, 0)
		bracket.glyph = ns.CreateGlyph(bracket, BRACKET_GLYPH, BRACKET_GLYPH_SIZE)
		bracket.glyph:SetTextColor(INK[1], INK[2], INK[3])
		bracket.glyph:SetPoint("RIGHT", bracket.label, "LEFT", -BRACKET_GLYPH_GAP, 0)
	end

	local function createRow(row)
		row.rank = createText(row, RANK_SIZE)
		row.rank:SetPoint("RIGHT", row, "LEFT", RANK_RIGHT, 0)
		row.icon = row:CreateTexture(nil, "ARTWORK")
		row.icon:SetSize(ICON_SIZE, ICON_SIZE)
		row.icon:SetPoint("LEFT", ICON_LEFT, 0)
		row.name = createText(row, NAME_SIZE)
		row.rating = createText(row, RATING_SIZE)
		row.rating:SetPoint("RIGHT", RATING_RIGHT, 0)
		row.winrate = createText(row, WINRATE_SIZE, DIM_ALPHA)
		row.winrate:SetPoint("RIGHT", WINRATE_RIGHT, 0)
		row.name:SetJustifyH("LEFT")
	end

	local function showRow(button, place, rating, name, class, winrate)
		local row = GossipCards.ShowCard(button, createRow, ROW_HEIGHT, ROW_GAP, true, name == UnitName("player"))
		local top = place <= TOP_PLACES
		row.rank:SetFont(STANDARD_TEXT_FONT, top and TOP_RANK_SIZE or RANK_SIZE)
		row.rank:SetText(place)
		row.rank:SetAlpha(top and 1 or DIM_ALPHA)
		row.name:ClearAllPoints()
		if class and ns.ClassIcons.SetClassTexture(row.icon, class) then
			row.icon:Show()
			row.name:SetPoint("LEFT", row.icon, "RIGHT", NAME_GAP, 0)
		else
			row.icon:Hide()
			row.name:SetPoint("LEFT", ICON_LEFT, 0)
		end
		row.name:SetPoint("RIGHT", row.winrate, "LEFT", -NAME_GAP, 0)
		row.name:SetText(name)
		row.winrate:SetText(winrate .. "%")
		row.rating:SetText(rating)
	end

	local function showBracket(button, label)
		local bracket = GossipCards.ShowCard(button, createBracket, BRACKET_HEIGHT, BRACKET_GAP)
		bracket.label:SetText(label)
	end

	local brackets = {}
	local lastBracket

	hooksecurefunc("SelectGossipOption", function(index)
		if UnitName("npc") == NPC_NAME then
			lastBracket = brackets[index] or lastBracket
		end
	end)

	local rows = {}

	GossipCards.Register(NPC_NAME, function(buttons)
		wipe(rows)
		wipe(brackets)
		local place = 0
		for _, button in ipairs(buttons) do
			tinsert(rows, button)
			if button.type == "Gossip" then
				local text = trim(button:GetText() or "")
				local rating, name, class, winrate = parseRow(text)
				if rating then
					place = place + 1
					showRow(button, place, rating, name, class, winrate)
				else
					local bracket = parseBracket(text)
					brackets[button:GetID()] = bracket
					showBracket(button, bracket or text)
				end
			end
		end
		if place > 0 and lastBracket then
			GossipCards.SetTitle(lastBracket)
		end
		return rows
	end)
end)
