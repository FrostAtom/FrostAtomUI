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
local strlower, strfind, strtrim, floor, ceil = string.lower, string.find, strtrim, math.floor, math.ceil

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
local HEADER_PLATE = "Interface\\DialogFrame\\UI-DialogBox-Header"
local SECTION_GAP = 6
local LIST_LEFT = 30
local LIST_TOP = 82
local LIST_BOTTOM = 90
local SCROLLBAR_RIGHT = 48
local SCROLL_STEP = CELL_HEIGHT * 2
local HIGHLIGHT_SQUARE = "Interface\\Buttons\\ButtonHilight-Square"
local HIGHLIGHT_PASSIVE = "Interface\\Buttons\\UI-PassiveHighlight"
local TOGGLE_ACTIONS = { "TOGGLESPELLBOOK", "TOGGLEPETBOOK" }

local frame, content, scroll, toggleButton, panel
local sections = {}
local buttons = {}
local headers = {}
local query = ""
local dirty = true
local boundKeys = ""
local displaced = false
local muted = false

local function collectSection(name, texture, book, first, last, highestRank)
	local entries = {}
	for i = first, last do
		local slot = highestRank and GetKnownSlotFromHighestRankSlot(i) or i
		local spellName, rank = GetSpellName(slot, book)
		if spellName then
			entries[#entries + 1] = {
				slot = slot,
				book = book,
				name = spellName,
				rank = rank or "",
				passive = IsPassiveSpell(slot, book) and true or false,
				search = strlower(spellName),
			}
		end
	end
	if #entries > 0 then
		sections[#sections + 1] = { name = name, texture = texture, entries = entries }
	end
end

local function collect()
	wipe(sections)
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

local function insertLink(self)
	local spellLink, tradeSkillLink = GetSpellLink(self.slot, self.book)
	local link = tradeSkillLink or spellLink
	if link then
		ChatEdit_InsertLink(link)
	end
end

local function showTooltip(self)
	GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
	if GameTooltip:SetSpell(self.slot, self.book) then
		self.UpdateTooltip = showTooltip
	else
		self.UpdateTooltip = nil
	end
end

local function pickup(self)
	PickupSpell(self.slot, self.book)
end

local function updateButton(button)
	local slot, book = button.slot, button.book
	local texture = GetSpellTexture(slot, book)
	button.icon:SetTexture(texture or ns.Media.questionMark)

	local start, duration, enable = GetSpellCooldown(slot, book)
	CooldownFrame_SetTimer(button.cooldown, start or 0, duration or 0, enable or 0)
	if enable == 0 then
		button.icon:SetVertexColor(0.4, 0.4, 0.4)
	else
		button.icon:SetVertexColor(1, 1, 1)
	end

	ns.SetShown(button.checked, IsSelectedSpell(slot, book) and true or false)

	local autoCastAllowed, autoCastEnabled
	if book == BOOKTYPE_PET then
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
		if button:IsShown() then
			updateButton(button)
		end
	end
end

local function createButton(index)
	local name = FRAME_NAME .. "Spell" .. index
	local button = CreateFrame("Button", name, content, "SecureActionButtonTemplate")
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

local function assignButton(button, entry, allRanks)
	button.slot = entry.slot
	button.book = entry.book

	local spell = entry.name
	if allRanks and entry.book == BOOKTYPE_SPELL and strfind(entry.rank, "%d") then
		spell = spell .. "(" .. entry.rank .. ")"
	end
	button:SetAttribute("type1", not entry.passive and "spell" or nil)
	button:SetAttribute("spell", spell)
	if entry.book == BOOKTYPE_PET and GetSpellAutocast(entry.slot, entry.book) then
		button:SetAttribute("type2", "macro")
		button:SetAttribute("macrotext2", "/petautocasttoggle " .. entry.name)
	else
		button:SetAttribute("type2", not entry.passive and "spell" or nil)
		button:SetAttribute("macrotext2", nil)
	end

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

local function createHeader(index)
	local header = CreateFrame("Frame", nil, content)
	header:SetSize(COLUMNS * CELL_WIDTH, SECTION_HEIGHT)

	local text = header:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
	text:SetHeight(20)
	text:SetPoint("CENTER", 13, -1)
	header.text = text

	local icon = header:CreateTexture(nil, "ARTWORK")
	icon:SetSize(22, 22)
	icon:SetPoint("RIGHT", text, "LEFT", -6, 0)
	header.icon = icon

	local middle = header:CreateTexture(nil, "BACKGROUND")
	middle:SetTexture(HEADER_PLATE)
	middle:SetTexCoord(0.28125, 0.71484375, 0, 0.625)
	middle:SetHeight(40)
	middle:SetPoint("TOP", header, "CENTER", 0, 20)
	middle:SetPoint("LEFT", icon, "LEFT", -4, 0)
	middle:SetPoint("RIGHT", text, "RIGHT", 4, 0)

	local left = header:CreateTexture(nil, "BACKGROUND")
	left:SetTexture(HEADER_PLATE)
	left:SetTexCoord(0.2265625, 0.28125, 0, 0.625)
	left:SetSize(14, 40)
	left:SetPoint("RIGHT", middle, "LEFT")

	local right = header:CreateTexture(nil, "BACKGROUND")
	right:SetTexture(HEADER_PLATE)
	right:SetTexCoord(0.71484375, 0.76953125, 0, 0.625)
	right:SetSize(14, 40)
	right:SetPoint("LEFT", middle, "RIGHT")

	for side = 1, 2 do
		local bar = header:CreateTexture(nil, "BACKGROUND")
		bar:SetTexture("Interface\\ClassTrainerFrame\\UI-ClassTrainer-HorizontalBar")
		bar:SetTexCoord(0, 1, 0, 0.25)
		bar:SetHeight(8)
		if side == 1 then
			bar:SetPoint("LEFT", 4, 0)
			bar:SetPoint("RIGHT", left, "LEFT")
		else
			bar:SetPoint("LEFT", right, "RIGHT")
			bar:SetPoint("RIGHT", -4, 0)
		end
	end

	headers[index] = header
	return header
end

local function matches(entry, hidePassive)
	if hidePassive and entry.passive then
		return false
	end
	return query == "" or strfind(entry.search, query, 1, true) ~= nil
end

local function layout()
	if InCombatLockdown() then
		dirty = true
		return
	end
	dirty = false
	collect()

	local hidePassive = ns.Config.spellBook.hidePassive
	local allRanks = GetCVarBool("ShowAllSpellRanks")
	local y, used, sectionCount = 0, 0, 0
	for s = 1, #sections do
		local section = sections[s]
		local shown = 0
		for e = 1, #section.entries do
			local entry = section.entries[e]
			if matches(entry, hidePassive) then
				if shown == 0 then
					sectionCount = sectionCount + 1
					local header = headers[sectionCount] or createHeader(sectionCount)
					header:SetPoint("TOPLEFT", 0, -y)
					header.text:SetWidth(0)
					header.text:SetText(section.name)
					if header.text:GetStringWidth() > SECTION_TEXT_WIDTH then
						header.text:SetWidth(SECTION_TEXT_WIDTH)
					end
					header.icon:SetTexture(section.texture or GetSpellTexture(entry.slot, entry.book))
					header:Show()
					y = y + SECTION_HEIGHT
				end
				used = used + 1
				local button = buttons[used] or createButton(used)
				local column, row = shown % COLUMNS, floor(shown / COLUMNS)
				button:ClearAllPoints()
				button:SetPoint("TOPLEFT", column * CELL_WIDTH + 4, -(y + row * CELL_HEIGHT + 2))
				assignButton(button, entry, allRanks)
				button:Show()
				shown = shown + 1
			end
		end
		if shown > 0 then
			y = y + ceil(shown / COLUMNS) * CELL_HEIGHT + SECTION_GAP
		end
	end
	for i = used + 1, #buttons do
		buttons[i]:Hide()
	end
	for i = sectionCount + 1, #headers do
		headers[i]:Hide()
	end

	content:SetHeight(y > 0 and y or 1)
	ns.SetShown(frame.empty, used == 0)
	scroll:UpdateScrollChildRect()
	local maxScroll = math.max(0, content:GetHeight() - scroll:GetHeight())
	if scroll:GetVerticalScroll() > maxScroll then
		scroll:SetVerticalScroll(maxScroll)
	end
	frame.scrollBar:SetMinMaxValues(0, maxScroll)
	frame.scrollBar:SetValue(scroll:GetVerticalScroll())
end

local function onCombatChanged(inCombat)
	if not frame then
		return
	end
	ns.SetShown(frame.scrollBar, not inCombat)
	ns.SetShown(frame.combatNote, inCombat)
	if InCombatLockdown() then
		return
	end
	if inCombat then
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
	if not InCombatLockdown() then
		scroll:SetVerticalScroll(value)
	end
end

local function onMouseWheel(_, delta)
	if InCombatLockdown() then
		return
	end
	local bar = frame.scrollBar
	local _, maxValue = bar:GetMinMaxValues()
	bar:SetValue(math.max(0, math.min(maxValue, bar:GetValue() - delta * SCROLL_STEP)))
end

local function createToolbar()
	local passive = CreateFrame("CheckButton", FRAME_NAME .. "HidePassive", frame, "OptionsSmallCheckButtonTemplate")
	passive:SetSize(26, 26)
	passive:SetPoint("TOPLEFT", 74, -38)
	passive:SetHitRectInsets(0, 0, 0, 0)
	local label = _G[passive:GetName() .. "Text"]
	label:SetFontObject(GameFontNormalSmall)
	label:SetText(L["Hide passive abilities"])
	passive:SetChecked(ns.Config.spellBook.hidePassive)
	passive:SetScript("OnClick", function(self)
		PlaySound(self:GetChecked() and "igMainMenuOptionCheckBoxOn" or "igMainMenuOptionCheckBoxOff")
		ns:SetConfig("spellBook.hidePassive", self:GetChecked() and true or false)
	end)
	frame.hidePassive = passive

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
	combatNote:SetText(L["Filters apply after combat"])
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

local function createFrame()
	frame = CreateFrame("Frame", FRAME_NAME, UIParent)
	frame:Hide()
	frame:SetSize(WIDTH, HEIGHT)
	frame:SetToplevel(true)
	frame:EnableMouse(true)
	frame:SetHitRectInsets(0, 30, 0, 70)
	frame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", UIParent:GetAttribute("LEFT_OFFSET"), UIParent:GetAttribute("TOP_OFFSET"))
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

	createToolbar()

	scroll = CreateFrame("ScrollFrame", FRAME_NAME .. "Scroll", frame)
	scroll:SetPoint("TOPLEFT", LIST_LEFT, -LIST_TOP)
	scroll:SetPoint("BOTTOMRIGHT", -SCROLLBAR_RIGHT - 22, LIST_BOTTOM)
	frame:EnableMouseWheel(true)
	frame:SetScript("OnMouseWheel", onMouseWheel)

	content = CreateFrame("Frame", nil, scroll)
	content:SetSize(COLUMNS * CELL_WIDTH, 1)
	scroll:SetScrollChild(content)

	local scrollBar = CreateFrame("Slider", FRAME_NAME .. "ScrollScrollBar", frame, "UIPanelScrollBarTemplate")
	scrollBar:SetPoint("TOPRIGHT", -SCROLLBAR_RIGHT, -(LIST_TOP + 16))
	scrollBar:SetPoint("BOTTOMRIGHT", -SCROLLBAR_RIGHT, LIST_BOTTOM + 16)
	scrollBar:SetScript("OnValueChanged", onScrollValue)
	scrollBar:SetValueStep(1)
	scrollBar:SetMinMaxValues(0, 0)
	scrollBar:SetValue(0)
	_G[scrollBar:GetName() .. "ScrollUpButton"]:SetScript("OnClick", function()
		PlaySound("UChatScrollButton")
		onMouseWheel(nil, 1)
	end)
	_G[scrollBar:GetName() .. "ScrollDownButton"]:SetScript("OnClick", function()
		PlaySound("UChatScrollButton")
		onMouseWheel(nil, -1)
	end)
	local track = scrollBar:CreateTexture(nil, "BACKGROUND")
	track:SetTexture(0, 0, 0, 0.3)
	track:SetWidth(12)
	track:SetPoint("TOP", _G[scrollBar:GetName() .. "ScrollUpButton"], "BOTTOM", 0, 2)
	track:SetPoint("BOTTOM", _G[scrollBar:GetName() .. "ScrollDownButton"], "TOP", 0, -2)
	frame.scrollBar = scrollBar

	local empty = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	empty:SetPoint("CENTER", scroll)
	empty:SetText(L["Nothing found"])
	empty:Hide()
	frame.empty = empty

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
		if dirty then
			layout()
		end
	end)
	self:WatchConfig("spellBook.hidePassive", function()
		frame.hidePassive:SetChecked(ns.Config.spellBook.hidePassive)
		layout()
	end)

	updateBindings()
	onCombatChanged(InCombatLockdown() and true or false)
end
