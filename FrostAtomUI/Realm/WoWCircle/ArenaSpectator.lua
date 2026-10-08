local _, ns = ...

ns.OnRealm("wowcircle", function()
	local ipairs, pairs, tonumber, wipe = ipairs, pairs, tonumber, wipe
	local tinsert, tsort = table.insert, table.sort

	local GossipCards = ns.GossipCards

	local NPC_NAME = "Arena Spectator"
	local ICON_SIZE = 17
	local ICON_GAP = 1
	local VS_GAP = 6
	local DIM_ALPHA = GossipCards.DIM_ALPHA
	local BRACKET_HEIGHT = 44
	local BRACKET_GAP = 8
	local BRACKET_LABEL_SIZE = 17
	local BRACKET_COUNT_SIZE = 12
	local BRACKET_COUNT_X = 8
	local BRACKET_COUNT_Y = 6
	local MATCH_HEIGHT = 27
	local MATCH_GAP = 4
	local MATCH_PADDING = 8
	local MATCH_RATING_SIZE = 14
	local MATCH_VS_SIZE = 11
	local BRACKET_PATTERN = "^%s*(.-)%s*%-%s*Spectators count:%s*(%d+)%s*$"
	local NAV_ORDER = { Back = 1, Refresh = 2 }
	local ICON_TRIM = ns.ClassIcons.TRIM

	local CLASS_SUFFIXES = {
		warrior = "WARRIOR",
		paladin = "PALADIN",
		pala = "PALADIN",
		hunter = "HUNTER",
		hunt = "HUNTER",
		rogue = "ROGUE",
		priest = "PRIEST",
		deathknight = "DEATHKNIGHT",
		dk = "DEATHKNIGHT",
		shaman = "SHAMAN",
		mage = "MAGE",
		warlock = "WARLOCK",
		lock = "WARLOCK",
		druid = "DRUID",
	}

	local SPEC_NAMES = {
		DEATHKNIGHT = { "blood", "frost", "unholy" },
		DRUID = { "balance", "feral", "restoration" },
		HUNTER = { "beastmastery", "marksmanship", "survival" },
		MAGE = { "arcane", "fire", "frost" },
		PALADIN = { "holy", "protection", "retribution" },
		PRIEST = { "discipline", "holy", "shadow" },
		ROGUE = { "assassination", "combat", "subtlety" },
		SHAMAN = { "elemental", "enhancement", "restoration" },
		WARLOCK = { "affliction", "demonology", "destruction" },
		WARRIOR = { "arms", "fury", "protection" },
	}

	local SPEC_ALIASES = {
		HUNTER = { bm = 1, mm = 2, sv = 3 },
	}

	local HEALER_SPECS = {
		DRUID = { [3] = true },
		PALADIN = { [1] = true },
		PRIEST = { [1] = true, [2] = true },
		SHAMAN = { [3] = true },
	}

	local suffixes = {}
	for suffix in pairs(CLASS_SUFFIXES) do
		tinsert(suffixes, suffix)
	end
	tsort(suffixes, function(a, b)
		return #a > #b
	end)

	local function parseSpec(class, prefix)
		if prefix == "" then
			return nil
		end
		local aliases = SPEC_ALIASES[class]
		if aliases and aliases[prefix] then
			return aliases[prefix]
		end
		for index, name in ipairs(SPEC_NAMES[class]) do
			if name:sub(1, #prefix) == prefix then
				return index
			end
		end
	end

	local function parsePlayer(token)
		local lower = token:lower()
		for _, suffix in ipairs(suffixes) do
			if #lower > #suffix and lower:sub(-#suffix) == suffix or lower == suffix then
				local class = CLASS_SUFFIXES[suffix]
				local spec = parseSpec(class, lower:sub(1, -#suffix - 1))
				local healers = HEALER_SPECS[class]
				return {
					class = class,
					spec = spec,
					specName = spec and SPEC_NAMES[class][spec],
					healer = spec and healers and healers[spec] or false,
				}
			end
		end
	end

	local function comparePlayers(a, b)
		if a.healer ~= b.healer then
			return b.healer
		end
		if a.class ~= b.class then
			return a.class < b.class
		end
		if not a.specName or not b.specName then
			return a.specName ~= nil and b.specName == nil
		end
		return a.specName < b.specName
	end

	local function parseTeam(text)
		local team = {}
		for token in text:gmatch("%S+") do
			local player = parsePlayer(token)
			if not player then
				return nil
			end
			tinsert(team, player)
		end
		if #team == 0 then
			return nil
		end
		tsort(team, comparePlayers)
		return team
	end

	local function parseMatch(text)
		local players1, rating1, players2, rating2 = text:match("^%s*(.-)%s*%[(%d+)%]%s*%-%s*(.-)%s*%[(%d+)%]%s*$")
		if not players1 then
			return nil
		end
		local team1, team2 = parseTeam(players1), parseTeam(players2)
		if team1 and team2 then
			rating1, rating2 = tonumber(rating1), tonumber(rating2)
			if rating2 > rating1 then
				return team2, rating2, team1, rating1
			end
			return team1, rating1, team2, rating2
		end
	end

	local function compareMatches(a, b)
		if a.spectatorRating ~= b.spectatorRating then
			return a.spectatorRating > b.spectatorRating
		end
		if a.spectatorRatingLow ~= b.spectatorRatingLow then
			return a.spectatorRatingLow > b.spectatorRatingLow
		end
		return a:GetID() < b:GetID()
	end

	local createText = GossipCards.CreateText

	local function createBracket(bracket)
		bracket.label = createText(bracket, BRACKET_LABEL_SIZE)
		bracket.label:SetPoint("CENTER")
		bracket.count = createText(bracket, BRACKET_COUNT_SIZE, DIM_ALPHA)
		bracket.count:SetPoint("BOTTOMRIGHT", -BRACKET_COUNT_X, BRACKET_COUNT_Y)
	end

	local function createMatch(match)
		match.left = createText(match, MATCH_RATING_SIZE)
		match.left:SetPoint("LEFT", MATCH_PADDING, 0)
		match.right = createText(match, MATCH_RATING_SIZE)
		match.right:SetPoint("RIGHT", -MATCH_PADDING, 0)
		match.vs = createText(match, MATCH_VS_SIZE, DIM_ALPHA)
		match.vs:SetPoint("CENTER")
		match.vs:SetText("vs")
		match.icons = {}
	end

	local function getIcon(match, index)
		local icon = match.icons[index]
		if not icon then
			icon = match:CreateTexture(nil, "ARTWORK")
			icon:SetSize(ICON_SIZE, ICON_SIZE)
			match.icons[index] = icon
		end
		return icon
	end

	local function setIcon(icon, player)
		ns.ClassIcons.SetClassTexture(icon, player.class, player.spec)
		if player.spec then
			icon:SetTexCoord(ICON_TRIM, 1 - ICON_TRIM, ICON_TRIM, 1 - ICON_TRIM)
		end
		icon:Show()
	end

	local function layoutTeam(match, team, first, point, relativePoint, direction)
		local anchor = match.vs
		local count = #team
		for i = 1, count do
			local icon = getIcon(match, first + i - 1)
			setIcon(icon, team[direction > 0 and i or count - i + 1])
			icon:ClearAllPoints()
			icon:SetPoint(point, anchor, relativePoint, direction * (i == 1 and VS_GAP or ICON_GAP), 0)
			anchor = icon
		end
	end

	local function showMatch(button, team1, rating1, team2, rating2)
		local match = GossipCards.ShowCard(button, createMatch, MATCH_HEIGHT, MATCH_GAP)
		match.left:SetText(rating1)
		match.right:SetText(rating2)
		layoutTeam(match, team1, 1, "RIGHT", "LEFT", -1)
		layoutTeam(match, team2, #team1 + 1, "LEFT", "RIGHT", 1)
		for i = #team1 + #team2 + 1, #match.icons do
			match.icons[i]:Hide()
		end
	end

	local function showBracket(button, name, count)
		local bracket = GossipCards.ShowCard(button, createBracket, BRACKET_HEIGHT, BRACKET_GAP)
		bracket.label:SetText(name)
		bracket.count:SetText(count)
	end

	local rows, matchRows, matchSlots = {}, {}, {}

	GossipCards.Register(NPC_NAME, function(buttons)
		wipe(rows)
		wipe(matchRows)
		wipe(matchSlots)
		for _, button in ipairs(buttons) do
			local text = button.type == "Gossip" and button:GetText() or ""
			if NAV_ORDER[text] then
				GossipCards.AddNav(button, text, NAV_ORDER[text])
			else
				tinsert(rows, button)
				local bracket, count = text:match(BRACKET_PATTERN)
				if bracket then
					showBracket(button, bracket, count)
				else
					local team1, rating1, team2, rating2 = parseMatch(text)
					if team1 then
						showMatch(button, team1, rating1, team2, rating2)
						button.spectatorRating = rating1
						button.spectatorRatingLow = rating2
						tinsert(matchRows, button)
						tinsert(matchSlots, #rows)
					end
				end
			end
		end

		tsort(matchRows, compareMatches)
		for i, slot in ipairs(matchSlots) do
			rows[slot] = matchRows[i]
		end
		return rows
	end)
end)
