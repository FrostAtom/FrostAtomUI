local _, ns = ...
local L = ns.L

local GetNumSpellTabs, GetSpellTabInfo, GetSpellName, GetSpellTexture =
	GetNumSpellTabs, GetSpellTabInfo, GetSpellName, GetSpellTexture
local IsPassiveSpell, GetSpellCooldown, IsSelectedSpell, GetSpellAutocast =
	IsPassiveSpell, GetSpellCooldown, IsSelectedSpell, GetSpellAutocast
local GetKnownSlotFromHighestRankSlot, HasPetSpells, PickupSpell, GetSpellLink =
	GetKnownSlotFromHighestRankSlot, HasPetSpells, PickupSpell, GetSpellLink
local GetBindingKey, SetOverrideBindingClick, ClearOverrideBindings =
	GetBindingKey, SetOverrideBindingClick, ClearOverrideBindings
local InCombatLockdown, GetCVarBool, CooldownFrame_SetTimer = InCombatLockdown, GetCVarBool, CooldownFrame_SetTimer
local strlower, strfind, strtrim, strjoin, strsplit, floor =
	string.lower, string.find, strtrim, strjoin, strsplit, math.floor

local SpellBook = ns:NewModule("SpellBook")
SpellBook.configKey = "spellBook"

local FRAME_NAME = "FrostAtomUISpellBook"
local ART = "Interface\\Spellbook\\UI-SpellbookPanel-"
local SLICE_X = 100
local SLICE_Y = 178
local WIDTH = 384 + 2 * (256 - SLICE_X)
local HEIGHT = 512 + 2 * (256 - SLICE_Y)
local COLUMNS = 4
local CELL_WIDTH = 149
local CELL_HEIGHT = 48
local BUTTON_SIZE = 37
local SECTION_HEIGHT = 34
local SECTION_TEXT_WIDTH = 380
local HEADER_ORNAMENT = "Interface\\QuestFrame\\UI-HorizontalBreak"
local HEADER_ORNAMENT_HEIGHT = 24
local HEADER_ORNAMENT_COLOR = { r = 0.55, g = 0.38, b = 0.2 }
local HEADER_CURL_WIDTH = 42
local HEADER_ICON_SIZE = 20
local SECTION_GAP = 6
local LIST_LEFT = 30
local LIST_TOP = 82
local LIST_BOTTOM = 90
local VIEW_HEIGHT = HEIGHT - LIST_TOP - LIST_BOTTOM
local POOL_SIZE = COLUMNS * floor(VIEW_HEIGHT / CELL_HEIGHT)
local SCROLLBAR_RIGHT = 48
local SCROLL_LINES = 2
local HIGHLIGHT_SQUARE = "Interface\\Buttons\\ButtonHilight-Square"
local HIGHLIGHT_PASSIVE = "Interface\\Buttons\\UI-PassiveHighlight"
local TOGGLE_ACTIONS = { "TOGGLESPELLBOOK", "TOGGLEPETBOOK" }

local SETUP_SNIPPET = [[
	BOOK = self
	LIST = self:GetFrameRef("list")
	UP = self:GetFrameRef("up")
	DOWN = self:GetFrameRef("down")
	BUTTONS = newtable()
	for i = 1, %d do
		BUTTONS[i] = self:GetFrameRef("button" .. i)
	end
	LINE_HEIGHT = newtable()
	LINE_SECTION = newtable()
	LINE_ENTRIES = newtable()
	NUM_LINES = 0
	OFFSET = 0
	MAX_OFFSET = 0
]]

local FILTER_SNIPPET = [[
	local hidePassive = self:GetAttribute("hidepassive")
	wipe(LINE_HEIGHT)
	wipe(LINE_SECTION)
	wipe(LINE_ENTRIES)
	local lines, section, column = 0, nil, %d
	for i = 1, self:GetAttribute("entries") or 0 do
		local entrySection, passive = strsplit("\t", self:GetAttribute("entry" .. i))
		if not hidePassive or passive ~= "1" then
			if entrySection ~= section then
				if lines > 0 then
					LINE_HEIGHT[lines] = LINE_HEIGHT[lines] + %d
				end
				section = entrySection
				lines = lines + 1
				LINE_HEIGHT[lines] = %d
				LINE_SECTION[lines] = section
				column = %d
			end
			if column == %d then
				lines = lines + 1
				LINE_HEIGHT[lines] = %d
				LINE_ENTRIES[lines] = newtable()
				column = 0
			end
			column = column + 1
			LINE_ENTRIES[lines][column] = i
		end
	end
	NUM_LINES = lines
	local first, height = lines + 1, 0
	while first > 1 and height + LINE_HEIGHT[first - 1] <= %d do
		first = first - 1
		height = height + LINE_HEIGHT[first]
	end
	MAX_OFFSET = first - 1
	OFFSET = min(OFFSET, MAX_OFFSET)
	control:RunAttribute("render")
]]

local RENDER_SNIPPET = [[
	local y, used, headers, line = 0, 0, 0, OFFSET + 1
	while line <= NUM_LINES do
		local entries = LINE_ENTRIES[line]
		if y + (entries and %d or %d) > %d then
			break
		end
		if entries then
			for column = 1, %d do
				local index = entries[column]
				if not index then
					break
				end
				used = used + 1
				local button = BUTTONS[used]
				local _, _, type1, spell, type2, macro = strsplit("\t", self:GetAttribute("entry" .. index))
				button:SetAttribute("type1", type1 ~= "" and type1 or nil)
				button:SetAttribute("spell", spell)
				button:SetAttribute("type2", type2 ~= "" and type2 or nil)
				button:SetAttribute("macrotext2", macro ~= "" and macro or nil)
				button:SetAttribute("entry", index)
				button:ClearAllPoints()
				button:SetPoint("TOPLEFT", "$parent", "TOPLEFT", (column - 1) * %d + 4, -(y + 2))
				button:Show()
			end
		else
			headers = headers + 1
			self:SetAttribute("header" .. headers, LINE_SECTION[line] .. "\t" .. y)
		end
		y = y + LINE_HEIGHT[line]
		line = line + 1
	end
	for i = used + 1, %d do
		BUTTONS[i]:Hide()
		BUTTONS[i]:SetAttribute("entry", nil)
	end
	self:SetAttribute("headers", headers)
	self:SetAttribute("offset", OFFSET)
	self:SetAttribute("maxoffset", MAX_OFFSET)
	if OFFSET > 0 then
		UP:Enable()
	else
		UP:Disable()
	end
	if OFFSET < MAX_OFFSET then
		DOWN:Enable()
	else
		DOWN:Disable()
	end
	control:CallMethod("OnRender")
]]

local SCROLL_SNIPPET = [[
	local offset = max(0, min(MAX_OFFSET, OFFSET + ...))
	if offset ~= OFFSET then
		OFFSET = offset
		control:RunAttribute("render")
	end
]]

local TOGGLE_SNIPPET = [[
	if BOOK:IsShown() then
		BOOK:Hide()
	else
		BOOK:Show()
	end
]]

local HIDE_PASSIVE_SNIPPET = [[
	BOOK:SetAttribute("hidepassive", not BOOK:GetAttribute("hidepassive"))
	control:RunAttribute("filter")
]]

local frame, list, toggleButton, panel
local buttons = {}
local headers = {}
local sections = {}
local collected = {}
local entries = {}
local query = ""
local appliedQuery = ""
local dirty = true
local rendering = false
local boundKeys = ""
local displaced = false
local muted = false

local function collectSection(name, texture, book, first, last, highestRank)
	local section = { name = name, texture = texture }
	local count = 0
	for i = first, last do
		local slot = highestRank and GetKnownSlotFromHighestRankSlot(i) or i
		local spellName, rank = GetSpellName(slot, book)
		if spellName then
			count = count + 1
			collected[#collected + 1] = {
				section = section,
				slot = slot,
				book = book,
				name = spellName,
				rank = rank or "",
				passive = IsPassiveSpell(slot, book) and true or false,
				search = strlower(spellName),
			}
		end
	end
	if count > 0 then
		sections[#sections + 1] = section
		section.index = #sections
	end
end

local function collect()
	wipe(sections)
	collected = {}
	local allRanks = GetCVarBool("ShowAllSpellRanks")
	for tab = 1, GetNumSpellTabs() do
		local name, texture, offset, numSpells, highestOffset, highestNumSpells = GetSpellTabInfo(tab)
		if allRanks then
			collectSection(name, texture, BOOKTYPE_SPELL, offset + 1, offset + numSpells, false)
		else
			collectSection(name, texture, BOOKTYPE_SPELL, highestOffset + 1, highestOffset + highestNumSpells, true)
		end
	end
	local numPetSpells, petToken = HasPetSpells()
	if numPetSpells and numPetSpells > 0 then
		collectSection(_G["PET_TYPE_" .. tostring(petToken)] or PET, nil, BOOKTYPE_PET, 1, numPetSpells, false)
	end
end

local function isCurrent(entry)
	return GetSpellName(entry.slot, entry.book) == entry.name
end

local function insertLink(self)
	local entry = self.entry
	if not entry then
		return
	end
	local spellLink, tradeSkillLink
	if isCurrent(entry) then
		spellLink, tradeSkillLink = GetSpellLink(entry.slot, entry.book)
	else
		spellLink = GetSpellLink(entry.name)
	end
	local link = tradeSkillLink or spellLink
	if link then
		ChatEdit_InsertLink(link)
	end
end

local function showTooltip(self)
	local entry = self.entry
	GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
	self.UpdateTooltip = nil
	if not entry then
		return
	end
	if not isCurrent(entry) then
		GameTooltip:SetText(entry.name)
	elseif GameTooltip:SetSpell(entry.slot, entry.book) then
		self.UpdateTooltip = showTooltip
	end
end

local function pickup(self)
	local entry = self.entry
	if entry and isCurrent(entry) then
		PickupSpell(entry.slot, entry.book)
	end
end

local function updateButton(button)
	local entry = button.entry
	local slot, book = entry.slot, entry.book
	local current = isCurrent(entry)
	local texture = current and GetSpellTexture(slot, book) or entry.texture
	entry.texture = texture
	button.icon:SetTexture(texture or ns.Media.questionMark)

	local start, duration, enable = 0, 0, 0
	if current then
		start, duration, enable = GetSpellCooldown(slot, book)
	end
	CooldownFrame_SetTimer(button.cooldown, start or 0, duration or 0, enable or 0)
	if enable == 0 then
		button.icon:SetVertexColor(0.4, 0.4, 0.4)
	else
		button.icon:SetVertexColor(1, 1, 1)
	end

	ns.SetShown(button.checked, current and IsSelectedSpell(slot, book) and true or false)

	local autoCastAllowed, autoCastEnabled
	if current and book == BOOKTYPE_PET then
		autoCastAllowed, autoCastEnabled = GetSpellAutocast(slot, book)
	end
	ns.SetShown(button.autoCastable, autoCastAllowed and true or false)
	if autoCastEnabled then
		button.shine:Show()
		AutoCastShine_AutoCastStart(button.shine)
	else
		AutoCastShine_AutoCastStop(button.shine)
		button.shine:Hide()
	end
end

local function updateButtons()
	for i = 1, #buttons do
		local button = buttons[i]
		if button.entry then
			updateButton(button)
		end
	end
end

local function matches(entry, text)
	return text == "" or strfind(entry.search, text, 1, true) ~= nil
end

local function assignButton(button, entry)
	button.entry = entry
	local color = entry.passive and PASSIVE_SPELL_FONT_COLOR or NORMAL_FONT_COLOR
	local ring = entry.passive and 0 or 1
	button.text:SetTextColor(color.r, color.g, color.b)
	button.normal:SetVertexColor(ring, ring, ring)
	button.highlight:SetTexture(entry.passive and HIGHLIGHT_PASSIVE or HIGHLIGHT_SQUARE)
	button.text:SetText(entry.name)
	button.subText:SetText(entry.rank)
	button.text:SetPoint("LEFT", button, "RIGHT", 4, entry.rank ~= "" and 4 or 2)
	updateButton(button)
end

local function updateDimming()
	local pending = query ~= appliedQuery
	for i = 1, #buttons do
		local button = buttons[i]
		local alpha = 1
		if pending and button.entry and not matches(button.entry, query) then
			alpha = 0.25
		end
		button.icon:SetAlpha(alpha)
		button.normal:SetAlpha(alpha)
		button.text:SetAlpha(alpha)
		button.subText:SetAlpha(alpha)
	end
	ns.SetShown(frame.combatNote, pending)
end

local function createButton(index)
	local name = FRAME_NAME .. "Spell" .. index
	local button = CreateFrame("Button", name, list, "SecureActionButtonTemplate")
	button:Hide()
	button:SetSize(BUTTON_SIZE, BUTTON_SIZE)
	button:SetHitRectInsets(0, BUTTON_SIZE - CELL_WIDTH + 8, 0, 0)
	button:RegisterForClicks("AnyUp")
	button:RegisterForDrag("LeftButton")
	button:SetAttribute("shift-type*", "link")
	button:SetAttribute("alt-unit*", "player")
	button.link = insertLink

	ns.SkinIconButton(button, "spell")
	local normal = button:GetNormalTexture()
	normal:ClearAllPoints()
	normal:SetPoint("CENTER")
	button.normal = normal
	button.highlight = button:GetHighlightTexture()

	local checked = button:CreateTexture(nil, "OVERLAY")
	checked:SetTexture("Interface\\Buttons\\CheckButtonHilight")
	checked:SetBlendMode("ADD")
	checked:SetAllPoints()
	checked:Hide()
	button.checked = checked

	local autoCastable = button:CreateTexture(nil, "OVERLAY")
	autoCastable:SetTexture("Interface\\Buttons\\UI-AutoCastableOverlay")
	autoCastable:SetSize(60, 60)
	autoCastable:SetPoint("CENTER")
	autoCastable:Hide()
	button.autoCastable = autoCastable

	local shine = CreateFrame("Frame", name .. "Shine", button, "SpellBookShineTemplate")
	shine:SetPoint("CENTER")
	shine:Hide()
	button.shine = shine

	button.cooldown = CreateFrame("Cooldown", nil, button, "CooldownFrameTemplate")
	button.cooldown:SetAllPoints()

	local text = button:CreateFontString(nil, "BORDER", "GameFontNormal")
	text:SetWidth(103)
	text:SetJustifyH("LEFT")
	text:SetPoint("LEFT", button, "RIGHT", 4, 0)
	button.text = text

	local subText = button:CreateFontString(nil, "BORDER", "SubSpellFont")
	subText:SetSize(79, 18)
	subText:SetJustifyH("LEFT")
	subText:SetPoint("TOPLEFT", text, "BOTTOMLEFT", 0, 4)
	button.subText = subText

	button:SetScript("OnEnter", showTooltip)
	button:SetScript("OnLeave", GameTooltip_Hide)
	button:SetScript("OnDragStart", pickup)

	buttons[index] = button
	return button
end

local function createHeader(index)
	local header = CreateFrame("Frame", nil, list)
	header:SetSize(COLUMNS * CELL_WIDTH, SECTION_HEIGHT)

	local text = header:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
	text:SetHeight(20)
	text:SetPoint("CENTER", 14, 0)
	header.text = text

	local icon = header:CreateTexture(nil, "ARTWORK")
	icon:SetSize(HEADER_ICON_SIZE, HEADER_ICON_SIZE)
	icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	icon:SetPoint("RIGHT", text, "LEFT", -7, 0)
	header.icon = icon

	local border = header:CreateTexture(nil, "BORDER")
	border:SetTexture(0.18, 0.1, 0.04)
	border:SetPoint("TOPLEFT", icon, -1, 1)
	border:SetPoint("BOTTOMRIGHT", icon, 1, -1)

	local function ornament(left, right)
		local texture = header:CreateTexture(nil, "ARTWORK")
		texture:SetTexture(HEADER_ORNAMENT)
		texture:SetTexCoord(left, right, 0, 1)
		texture:SetHeight(HEADER_ORNAMENT_HEIGHT)
		texture:SetVertexColor(HEADER_ORNAMENT_COLOR.r, HEADER_ORNAMENT_COLOR.g, HEADER_ORNAMENT_COLOR.b)
		return texture
	end

	local leftCurl = ornament(0, 0.22)
	leftCurl:SetWidth(HEADER_CURL_WIDTH)
	leftCurl:SetPoint("LEFT", 4, 0)
	local leftLine = ornament(0.22, 0.34)
	leftLine:SetPoint("LEFT", leftCurl, "RIGHT")
	leftLine:SetPoint("RIGHT", border, "LEFT", -8, 0)

	local rightCurl = ornament(0.78, 1)
	rightCurl:SetWidth(HEADER_CURL_WIDTH)
	rightCurl:SetPoint("RIGHT", -4, 0)
	local rightLine = ornament(0.66, 0.78)
	rightLine:SetPoint("RIGHT", rightCurl, "LEFT")
	rightLine:SetPoint("LEFT", text, "RIGHT", 8, 0)

	headers[index] = header
	return header
end

local function onRender(self)
	local shown = 0
	for i = 1, #buttons do
		local button = buttons[i]
		local entry = entries[button:GetAttribute("entry") or 0]
		if entry then
			shown = shown + 1
			assignButton(button, entry)
			if GameTooltip:IsOwned(button) then
				showTooltip(button)
			end
		else
			button.entry = nil
		end
	end

	local count = self:GetAttribute("headers") or 0
	for i = 1, count do
		local sectionIndex, y = strsplit("\t", self:GetAttribute("header" .. i))
		local section = sections[tonumber(sectionIndex)]
		local header = headers[i] or createHeader(i)
		header:ClearAllPoints()
		header:SetPoint("TOPLEFT", 0, -tonumber(y))
		header.text:SetWidth(0)
		header.text:SetText(section.name)
		if header.text:GetStringWidth() > SECTION_TEXT_WIDTH then
			header.text:SetWidth(SECTION_TEXT_WIDTH)
		end
		local texture = section.texture
		if not texture then
			for e = 1, #entries do
				if entries[e].section == section then
					texture = entries[e].texture or GetSpellTexture(entries[e].slot, entries[e].book)
					break
				end
			end
		end
		header.icon:SetTexture(texture)
		header:Show()
	end
	for i = count + 1, #headers do
		headers[i]:Hide()
	end

	rendering = true
	frame.scrollBar:SetMinMaxValues(0, self:GetAttribute("maxoffset") or 0)
	frame.scrollBar:SetValue(self:GetAttribute("offset") or 0)
	rendering = false

	frame.hidePassive:SetChecked(self:GetAttribute("hidepassive"))
	if (self:GetAttribute("hidepassive") and true or false) ~= ns.Config.spellBook.hidePassive then
		ns:SetConfig("spellBook.hidePassive", self:GetAttribute("hidepassive") and true or false)
	end
	ns.SetShown(frame.empty, shown == 0)
	updateDimming()
end

local function layout()
	if InCombatLockdown() then
		dirty = true
		updateDimming()
		return
	end
	dirty = false
	local resetScroll = query ~= appliedQuery
	appliedQuery = query
	collect()

	local allRanks = GetCVarBool("ShowAllSpellRanks")
	wipe(entries)
	for _, entry in ipairs(collected) do
		if matches(entry, query) then
			entries[#entries + 1] = entry
			local spell = entry.name
			if allRanks and entry.book == BOOKTYPE_SPELL and strfind(entry.rank, "%d") then
				spell = spell .. "(" .. entry.rank .. ")"
			end
			local type1 = not entry.passive and "spell" or ""
			local type2, macro = type1, ""
			if entry.book == BOOKTYPE_PET and GetSpellAutocast(entry.slot, entry.book) then
				type2, macro = "macro", "/petautocasttoggle " .. entry.name
			end
			frame:SetAttribute(
				"entry" .. #entries,
				strjoin("\t", entry.section.index, entry.passive and 1 or 0, type1, spell, type2, macro)
			)
		end
	end

	frame:SetAttribute("entries", #entries)
	frame:SetAttribute("hidepassive", ns.Config.spellBook.hidePassive)
	frame:Execute(resetScroll and [[OFFSET = 0 control:RunAttribute("filter")]] or [[control:RunAttribute("filter")]])
end

local function onCombatChanged(inCombat)
	if not frame then
		return
	end
	frame.scrollBar:EnableMouse(not inCombat)
	if InCombatLockdown() then
		return
	end
	if inCombat then
		if dirty then
			layout()
		end
		if frame:IsShown() then
			SetOverrideBindingClick(frame.escape, true, "ESCAPE", frame.close:GetName())
		end
		return
	end
	ClearOverrideBindings(frame.escape)
	if frame:IsShown() and not panel:IsShown() then
		if not displaced then
			ShowUIPanel(panel)
		end
		if not panel:IsShown() then
			frame:Hide()
		end
	end
end

local function syncPosition()
	if InCombatLockdown() then
		return
	end
	local point, _, relativePoint, x, y = panel:GetPoint()
	if point then
		frame:ClearAllPoints()
		frame:SetPoint(point, UIParent, relativePoint, x, y)
	end
end

local function updateBindings()
	if InCombatLockdown() then
		return
	end
	local keys = ""
	for _, action in ipairs(TOGGLE_ACTIONS) do
		keys = keys .. strjoin(",", "", GetBindingKey(action))
	end
	if keys == boundKeys then
		return
	end
	boundKeys = keys
	ClearOverrideBindings(toggleButton)
	for _, action in ipairs(TOGGLE_ACTIONS) do
		for _, key in ipairs({ GetBindingKey(action) }) do
			SetOverrideBindingClick(toggleButton, false, key, toggleButton:GetName())
		end
	end
end

local function toggle()
	if InCombatLockdown() then
		UIErrorsFrame:AddMessage(ERR_NOT_IN_COMBAT, 1, 0.1, 0.1)
		return
	end
	ns.SetShown(frame, not frame:IsShown())
end

local function setMicroButtonState()
	if frame:IsShown() then
		SpellbookMicroButton:SetButtonState("PUSHED", 1)
	else
		SpellbookMicroButton:SetButtonState("NORMAL")
	end
end

local function onScrollValue(_, value)
	if rendering or InCombatLockdown() then
		return
	end
	value = floor(value + 0.5)
	if value ~= frame:GetAttribute("offset") then
		frame:Execute(string.format([[OFFSET = %d control:RunAttribute("render")]], value))
	end
end

local function playScrollSound()
	PlaySound("UChatScrollButton")
end

local function createScrollButton(suffix, template, point, y, lines)
	local button = CreateFrame("Button", FRAME_NAME .. suffix, frame, "SecureFrameTemplate," .. template)
	button:SetPoint(point, frame, point == "TOP" and "TOPRIGHT" or "BOTTOMRIGHT", -SCROLLBAR_RIGHT - 8, y)
	button:SetScript("PostClick", playScrollSound)
	frame:WrapScript(button, "OnClick", string.format([[control:RunAttribute("scroll", %d)]], lines))
	return button
end

local function createScrollBar()
	local up = createScrollButton("ScrollUp", "UIPanelScrollUpButtonTemplate", "TOP", -LIST_TOP, -SCROLL_LINES)
	local down =
		createScrollButton("ScrollDown", "UIPanelScrollDownButtonTemplate", "BOTTOM", LIST_BOTTOM, SCROLL_LINES)
	frame:SetFrameRef("up", up)
	frame:SetFrameRef("down", down)

	local scrollBar = CreateFrame("Slider", FRAME_NAME .. "ScrollBar", frame)
	scrollBar:SetWidth(16)
	scrollBar:SetPoint("TOP", up, "BOTTOM")
	scrollBar:SetPoint("BOTTOM", down, "TOP")
	scrollBar:SetOrientation("VERTICAL")
	scrollBar:SetThumbTexture("Interface\\Buttons\\UI-ScrollBar-Knob")
	local thumb = scrollBar:GetThumbTexture()
	thumb:SetSize(18, 24)
	thumb:SetTexCoord(0.2, 0.8, 0.125, 0.875)
	scrollBar:SetValueStep(1)
	scrollBar:SetMinMaxValues(0, 0)
	scrollBar:SetValue(0)
	scrollBar:SetScript("OnValueChanged", onScrollValue)
	local track = scrollBar:CreateTexture(nil, "BACKGROUND")
	track:SetTexture(0, 0, 0, 0.3)
	track:SetWidth(12)
	track:SetPoint("TOP", up, "BOTTOM", 0, 2)
	track:SetPoint("BOTTOM", down, "TOP", 0, -2)
	frame.scrollBar = scrollBar
end

local function createToolbar()
	local passive = CreateFrame("CheckButton", FRAME_NAME .. "HidePassive", frame, "OptionsSmallCheckButtonTemplate")
	passive:SetSize(26, 26)
	passive:SetPoint("TOPLEFT", 74, -38)
	passive:SetHitRectInsets(0, 0, 0, 0)
	passive:EnableMouse(false)
	local label = _G[passive:GetName() .. "Text"]
	label:SetFontObject(GameFontNormalSmall)
	label:SetText(L["Hide passive abilities"])
	passive:SetChecked(ns.Config.spellBook.hidePassive)
	frame.hidePassive = passive

	local passiveClick = CreateFrame("Button", FRAME_NAME .. "HidePassiveClick", passive, "SecureFrameTemplate")
	passiveClick:SetPoint("TOPLEFT")
	passiveClick:SetPoint("BOTTOMLEFT")
	passiveClick:SetPoint("RIGHT", label, "RIGHT")
	passiveClick:SetScript("OnEnter", function()
		passive:LockHighlight()
	end)
	passiveClick:SetScript("OnLeave", function()
		passive:UnlockHighlight()
	end)
	passiveClick:SetScript("PostClick", function()
		PlaySound(frame:GetAttribute("hidepassive") and "igMainMenuOptionCheckBoxOn" or "igMainMenuOptionCheckBoxOff")
	end)
	frame:WrapScript(passiveClick, "OnClick", HIDE_PASSIVE_SNIPPET)

	local search = ns.CreateEditBox(frame, 140, 20, FRAME_NAME .. "Search", L["Search"])
	search:SetPoint("TOPRIGHT", -76, -40)
	search.placeholder:SetFontObject(GameFontDisableSmall)
	search:HookScript("OnTextChanged", function(self)
		local text = strlower(strtrim(self:GetText()))
		if text ~= query then
			query = text
			layout()
		end
	end)
	search:SetScript("OnEscapePressed", function(self)
		self:SetText("")
		self:ClearFocus()
	end)
	search:SetScript("OnEnterPressed", search.ClearFocus)
	frame.search = search

	local combatNote = frame:CreateFontString(nil, "OVERLAY", "GameFontRedSmall")
	combatNote:SetPoint("TOPLEFT", 80, -66)
	combatNote:SetText(L["Search applies after combat"])
	combatNote:Hide()
	frame.combatNote = combatNote
end

local function artSpans(slice, lastSize)
	return {
		{ 1, 0, 256, 256 },
		{ 1, 256, slice, 256 - slice },
		{ 1, slice, 256, 256 - slice },
		{ 2, 0, lastSize, lastSize },
	}
end

local function createArt()
	local portrait = frame:CreateTexture(nil, "BACKGROUND")
	portrait:SetTexture("Interface\\Spellbook\\Spellbook-Icon")
	portrait:SetSize(58, 58)
	portrait:SetPoint("TOPLEFT", 10, -8)

	local files = { { "TopLeft", "TopRight" }, { "BotLeft", "BotRight" } }
	local y = 0
	for _, row in ipairs(artSpans(SLICE_Y, 256)) do
		local x = 0
		for _, column in ipairs(artSpans(SLICE_X, 128)) do
			local texture = frame:CreateTexture(nil, "ARTWORK")
			texture:SetTexture(ART .. files[row[1]][column[1]])
			local width = column[1] == 1 and 256 or 128
			texture:SetTexCoord(column[2] / width, column[3] / width, row[2] / 256, row[3] / 256)
			texture:SetSize(column[4], row[4])
			texture:SetPoint("TOPLEFT", x, -y)
			x = x + column[4]
		end
		y = y + row[4]
	end
end

local function createMicroButtonClick()
	local click = CreateFrame("Button", FRAME_NAME .. "MicroButton", SpellbookMicroButton, "SecureFrameTemplate")
	click:SetAllPoints()
	click:SetScript("OnEnter", function()
		SpellbookMicroButton:LockHighlight()
		local onEnter = SpellbookMicroButton:GetScript("OnEnter")
		if onEnter then
			onEnter(SpellbookMicroButton)
		end
	end)
	click:SetScript("OnLeave", function()
		SpellbookMicroButton:UnlockHighlight()
		local onLeave = SpellbookMicroButton:GetScript("OnLeave")
		if onLeave then
			onLeave(SpellbookMicroButton)
		end
	end)
	click:SetScript("OnMouseDown", function()
		SpellbookMicroButton:SetButtonState("PUSHED")
	end)
	click:SetScript("OnMouseUp", setMicroButtonState)
	frame:WrapScript(click, "OnClick", TOGGLE_SNIPPET)
end

local function createFrame()
	frame = CreateFrame("Frame", FRAME_NAME, UIParent, "SecureHandlerMouseWheelTemplate")
	frame:Hide()
	frame:SetSize(WIDTH, HEIGHT)
	frame:SetToplevel(true)
	frame:EnableMouse(true)
	frame:SetHitRectInsets(0, 30, 0, 70)
	frame:SetPoint(
		"TOPLEFT",
		UIParent,
		"TOPLEFT",
		UIParent:GetAttribute("LEFT_OFFSET"),
		UIParent:GetAttribute("TOP_OFFSET")
	)
	createArt()

	panel = CreateFrame("Frame", FRAME_NAME .. "Panel", UIParent)
	panel:Hide()
	panel:SetSize(WIDTH, HEIGHT)
	ns.SetUIPanelLayout(panel, "left", 0)
	hooksecurefunc(panel, "SetPoint", syncPosition)
	panel:SetScript("OnShow", function()
		syncPosition()
		if not frame:IsShown() and not InCombatLockdown() then
			frame:Show()
		end
	end)
	panel:SetScript("OnHide", function()
		if not frame:IsShown() then
			return
		end
		if InCombatLockdown() then
			displaced = true
		else
			frame:Hide()
		end
	end)

	local title = frame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	title:SetPoint("CENTER", frame, "TOPLEFT", WIDTH / 2 + 6, -26)
	title:SetText(SPELLBOOK)

	local close = CreateFrame("Button", FRAME_NAME .. "Close", frame, "SecureHandlerClickTemplate")
	close:SetSize(32, 32)
	close:SetPoint("CENTER", frame, "TOPRIGHT", -44, -25)
	close:SetNormalTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Up")
	close:SetPushedTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Down")
	close:SetHighlightTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Highlight")
	close:GetHighlightTexture():SetBlendMode("ADD")
	close:SetFrameRef("window", frame)
	close:SetAttribute("_onclick", [[self:GetFrameRef("window"):Hide()]])
	frame.close = close

	local escape = CreateFrame("Frame", nil, frame, "SecureHandlerShowHideTemplate")
	escape:SetAttribute(
		"_onshow",
		string.format([[if PlayerInCombat() then self:SetBindingClick(true, "ESCAPE", "%s") end]], close:GetName())
	)
	escape:SetAttribute("_onhide", [[self:ClearBindings()]])
	frame.escape = escape

	list = CreateFrame("Frame", nil, frame)
	list:SetPoint("TOPLEFT", LIST_LEFT, -LIST_TOP)
	list:SetSize(COLUMNS * CELL_WIDTH, VIEW_HEIGHT)
	frame:SetFrameRef("list", list)
	for i = 1, POOL_SIZE do
		frame:SetFrameRef("button" .. i, createButton(i))
	end

	createToolbar()
	createScrollBar()

	local empty = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	empty:SetPoint("CENTER", list)
	empty:SetText(L["Nothing found"])
	empty:Hide()
	frame.empty = empty

	frame.OnRender = onRender
	frame:SetAttribute(
		"filter",
		FILTER_SNIPPET:format(COLUMNS, SECTION_GAP, SECTION_HEIGHT, COLUMNS, COLUMNS, CELL_HEIGHT, VIEW_HEIGHT)
	)
	frame:SetAttribute(
		"render",
		RENDER_SNIPPET:format(CELL_HEIGHT, SECTION_HEIGHT + CELL_HEIGHT, VIEW_HEIGHT, COLUMNS, CELL_WIDTH, POOL_SIZE)
	)
	frame:SetAttribute("scroll", SCROLL_SNIPPET)
	frame:SetAttribute("_onmousewheel", string.format([[control:RunAttribute("scroll", -delta * %d)]], SCROLL_LINES))
	frame:Execute(SETUP_SNIPPET:format(POOL_SIZE))

	frame:SetScript("OnShow", function()
		if not panel:IsShown() then
			ShowUIPanel(panel)
			if not panel:IsShown() and not InCombatLockdown() then
				muted = true
				frame:Hide()
				muted = false
				return
			end
		end
		PlaySound("igSpellBookOpen")
		setMicroButtonState()
		if dirty then
			layout()
		end
		updateButtons()
	end)
	frame:SetScript("OnHide", function()
		displaced = false
		HideUIPanel(panel)
		if not muted then
			PlaySound("igSpellBookClose")
		end
		setMicroButtonState()
		frame.search:ClearFocus()
	end)

	toggleButton = CreateFrame("Button", FRAME_NAME .. "Toggle", UIParent, "SecureHandlerClickTemplate")
	toggleButton:SetFrameRef("window", frame)
	toggleButton:SetAttribute(
		"_onclick",
		[[
		local window = self:GetFrameRef("window")
		if window:IsShown() then
			window:Hide()
		else
			window:Show()
		end
	]]
	)

	createMicroButtonClick()
end

local function onSpellsChanged()
	dirty = true
	if frame:IsShown() then
		layout()
	end
end

local function onButtonEvent()
	if frame:IsShown() then
		updateButtons()
	end
end

function SpellBook:Initialize()
	createFrame()

	ToggleSpellBook = toggle
	SpellbookMicroButton:SetScript("OnClick", toggle)
	hooksecurefunc("UpdateMicroButtons", setMicroButtonState)

	self:RegisterEvent("SPELLS_CHANGED", onSpellsChanged)
	self:RegisterEvent("LEARNED_SPELL_IN_TAB", onSpellsChanged)
	for _, event in ipairs({
		"SPELL_UPDATE_COOLDOWN",
		"CURRENT_SPELL_CAST_CHANGED",
		"UPDATE_SHAPESHIFT_FORM",
		"PET_BAR_UPDATE",
		"TRADE_SKILL_SHOW",
		"TRADE_SKILL_CLOSE",
	}) do
		self:RegisterEvent(event, onButtonEvent)
	end
	self:RegisterEvent("UPDATE_BINDINGS", updateBindings)
	self:RegisterEvent("PLAYER_REGEN_DISABLED", function()
		onCombatChanged(true)
	end)
	self:RegisterEvent("PLAYER_REGEN_ENABLED", function()
		onCombatChanged(false)
		updateBindings()
		if dirty or query ~= appliedQuery then
			layout()
		end
	end)
	self:WatchConfig("spellBook.hidePassive", function()
		frame.hidePassive:SetChecked(ns.Config.spellBook.hidePassive)
		if (frame:GetAttribute("hidepassive") and true or false) ~= ns.Config.spellBook.hidePassive then
			frame:SetAttribute("hidepassive", ns.Config.spellBook.hidePassive)
			frame:Execute([[control:RunAttribute("filter")]])
		end
	end, true)

	updateBindings()
	layout()
	onCombatChanged(InCombatLockdown() and true or false)
end
