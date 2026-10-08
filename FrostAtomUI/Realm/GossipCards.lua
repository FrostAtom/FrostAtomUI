local _, ns = ...

ns.OnRealm({ "wowcircle", "warmane" }, function()
	local UnitName = UnitName
	local ipairs, pairs, wipe = ipairs, pairs, wipe
	local tinsert, tsort = table.insert, table.sort

	local GossipCards = {}
	ns.GossipCards = GossipCards

	local LIST_TOP = 10
	local ROW_GAP = 3
	local PANEL_GAP = 8
	local TITLE_SIZE = 17
	local TITLE_GAP = 10
	local TITLE_NOTE_SIZE = 12
	local TITLE_NOTE_X = 8
	local SECTION_SIZE = 12
	local SECTION_TOP = 8
	local SECTION_GAP = 5
	local NAV_WIDTH = 78
	local NAV_HEIGHT = 22
	local NAV_LEFT = 21
	local NAV_BOTTOM = 73
	local NAV_GAP = 2
	local CARD_LEFT = 4
	local CARD_RIGHT = -6
	local CARD_BACKDROP = {
		bgFile = ns.Media.blank,
		edgeFile = ns.Media.blank,
		edgeSize = 1,
	}
	local CARD_FILL = { 0.35, 0.22, 0.08, 0.16 }
	local CARD_FILL_HOVER = { 0.55, 0.35, 0.08, 0.38 }
	local CARD_EDGE = { 0.3, 0.18, 0.06, 0.45 }
	local CARD_EDGE_HOVER = { 0.35, 0.2, 0.04, 1 }

	GossipCards.INK = { 0.22, 0.13, 0.04 }
	GossipCards.DIM_ALPHA = 0.45

	local INK = GossipCards.INK
	local BUTTON_WIDTH = GossipTitleButton1:GetWidth()

	local function onCardClick(card)
		SelectGossipOption(card:GetParent():GetID())
	end

	local function paintCard(card, hovered)
		hovered = hovered or card.highlighted
		local fill = hovered and CARD_FILL_HOVER or CARD_FILL
		local edge = hovered and CARD_EDGE_HOVER or CARD_EDGE
		card:SetBackdropColor(fill[1], fill[2], fill[3], fill[4])
		card:SetBackdropBorderColor(edge[1], edge[2], edge[3], edge[4])
	end

	local function onCardEnter(card)
		paintCard(card, true)
	end

	local function onCardLeave(card)
		paintCard(card, false)
	end

	local function pressCard(card, x, y)
		local content = card.content
		content:ClearAllPoints()
		content:SetPoint("TOPLEFT", x, y)
		content:SetPoint("BOTTOMRIGHT", x, y)
	end

	local function onCardMouseDown(card)
		pressCard(card, 1, -1)
	end

	local function onCardMouseUp(card)
		pressCard(card, 0, 0)
	end

	function GossipCards.CreateText(parent, size, alpha)
		local text = parent:CreateFontString(nil, "OVERLAY")
		text:SetFont(STANDARD_TEXT_FONT, size)
		text:SetTextColor(INK[1], INK[2], INK[3])
		text:SetAlpha(alpha or 1)
		return text
	end

	local function createCard(button)
		local card = CreateFrame("Button", nil, button)
		card:SetPoint("TOPLEFT", CARD_LEFT, 0)
		card:SetPoint("TOPRIGHT", CARD_RIGHT, 0)
		card:SetBackdrop(CARD_BACKDROP)
		card:SetScript("OnClick", onCardClick)
		card:SetScript("OnEnter", onCardEnter)
		card:SetScript("OnLeave", onCardLeave)
		card:SetScript("OnMouseDown", onCardMouseDown)
		card:SetScript("OnMouseUp", onCardMouseUp)
		card.content = CreateFrame("Frame", nil, card)
		pressCard(card, 0, 0)
		card.views = {}
		button.gossipCard = card
		return card
	end

	function GossipCards.ShowCard(button, create, height, gap, static, highlighted)
		local card = button.gossipCard or createCard(button)
		local view = card.views[create]
		if not view then
			view = CreateFrame("Frame", nil, card.content)
			view:SetAllPoints()
			create(view)
			card.views[create] = view
		end
		for _, other in pairs(card.views) do
			ns.SetShown(other, other == view)
		end
		card:SetHeight(height)
		card:EnableMouse(not static)
		card.highlighted = highlighted
		pressCard(card, 0, 0)
		paintCard(card, not static and card:IsMouseOver())
		_G[button:GetName() .. "GossipIcon"]:Hide()
		button:EnableMouse(false)
		button:SetText("")
		button:SetHeight(height + gap)
		card:Show()
		return view
	end

	local function resetButton(button)
		if button.gossipCard then
			button.gossipCard:Hide()
		end
		_G[button:GetName() .. "GossipIcon"]:Show()
		button:EnableMouse(true)
		button:SetWidth(BUTTON_WIDTH)
	end

	local function onNavClick(self)
		SelectGossipOption(self:GetID())
	end

	local navButtons = {}
	local navs = {}

	local function getNavButton(index)
		local nav = navButtons[index]
		if not nav then
			nav = CreateFrame("Button", nil, GossipFrameGreetingPanel, "UIPanelButtonTemplate")
			ns.SkinPanelButton(nav)
			nav:SetSize(NAV_WIDTH, NAV_HEIGHT)
			nav:SetScript("OnClick", onNavClick)
			if index == 1 then
				nav:SetPoint("BOTTOMLEFT", GossipFrame, "BOTTOMLEFT", NAV_LEFT, NAV_BOTTOM)
			else
				nav:SetPoint("LEFT", navButtons[index - 1], "RIGHT", NAV_GAP, 0)
			end
			navButtons[index] = nav
		end
		return nav
	end

	local function compareNavs(a, b)
		return a.order < b.order
	end

	function GossipCards.AddNav(button, label, order, keep)
		tinsert(navs, { id = button:GetID(), label = label, order = order or #navs + 1 })
		if not keep then
			button:Hide()
		end
	end

	local function showNavs()
		tsort(navs, compareNavs)
		for i, entry in ipairs(navs) do
			local nav = getNavButton(i)
			nav:SetID(entry.id)
			nav:SetText(entry.label)
			nav:Show()
		end
	end

	local function hideNavs()
		for _, nav in ipairs(navButtons) do
			nav:Hide()
		end
		wipe(navs)
	end

	local skins = {}

	function GossipCards.Register(npc, skin)
		skins[npc] = skin
	end

	local title = GossipCards.CreateText(GossipGreetingScrollChildFrame, TITLE_SIZE)
	title:SetPoint("TOPLEFT", CARD_LEFT, -LIST_TOP)
	title:SetPoint("TOPRIGHT", GossipGreetingScrollChildFrame, "TOPRIGHT", CARD_RIGHT, -LIST_TOP)
	title:Hide()
	local titleNote = GossipCards.CreateText(GossipGreetingScrollChildFrame, TITLE_NOTE_SIZE, GossipCards.DIM_ALPHA)
	titleNote:SetPoint("RIGHT", title, "RIGHT", -TITLE_NOTE_X, 0)
	titleNote:Hide()

	function GossipCards.SetTitle(text, note)
		title:SetText(text)
		title:Show()
		titleNote:SetText(note or "")
		ns.SetShown(titleNote, note)
	end

	local sections = {}
	local sectionTexts = {}
	local spans = {}

	function GossipCards.SetSection(button, text)
		sections[button] = text
	end

	function GossipCards.SetColumns(button, columns)
		spans[button] = columns
	end

	local function getSectionText(index)
		local text = sectionTexts[index]
		if not text then
			text = GossipCards.CreateText(GossipGreetingScrollChildFrame, SECTION_SIZE, GossipCards.DIM_ALPHA)
			text:SetJustifyH("LEFT")
			sectionTexts[index] = text
		end
		return text
	end

	local function hideSections()
		for _, text in ipairs(sectionTexts) do
			text:Hide()
		end
		wipe(sections)
		wipe(spans)
	end

	function GossipCards.CreatePanel()
		local panel = CreateFrame("Frame", nil, GossipGreetingScrollChildFrame)
		panel:SetBackdrop(CARD_BACKDROP)
		paintCard(panel, false)
		panel:Hide()
		return panel
	end

	local applied
	local visible = {}
	local footer

	local function hideFooter()
		if footer then
			footer:Hide()
			footer = nil
		end
	end

	local function hideTitle()
		title:Hide()
		titleNote:Hide()
	end

	local function restore()
		applied = false
		GossipGreetingText:Show()
		hideTitle()
		hideSections()
		hideFooter()
		hideNavs()
		for i = 1, NUMGOSSIPBUTTONS do
			local button = _G["GossipTitleButton" .. i]
			button:ClearAllPoints()
			if i == 1 then
				button:SetPoint("TOPLEFT", GossipGreetingText, "BOTTOMLEFT", -10, -20)
			else
				button:SetPoint("TOPLEFT", _G["GossipTitleButton" .. (i - 1)], "BOTTOMLEFT", 0, -ROW_GAP)
			end
			resetButton(button)
		end
	end

	local function anchorRow(region, rowStart, x, gap)
		if rowStart then
			region:SetPoint("TOPLEFT", rowStart, "BOTTOMLEFT", x, -gap)
		elseif title:IsShown() then
			region:SetPoint("TOPLEFT", title, "BOTTOMLEFT", x - CARD_LEFT, -TITLE_GAP)
		else
			region:SetPoint("TOPLEFT", GossipGreetingScrollChildFrame, "TOPLEFT", x, -LIST_TOP)
		end
	end

	local function layout(rows, columns, panel, panelHeight)
		columns = columns or 1
		local rowStart, previous
		local column, rowColumns, sectionCount = 0, 0, 0
		for _, button in ipairs(rows) do
			local span = spans[button] or columns
			local section = sections[button]
			button:ClearAllPoints()
			if span > 1 then
				button:SetWidth(BUTTON_WIDTH / span)
			end
			if column > 0 and column < rowColumns and span == rowColumns and not section then
				button:SetPoint("TOPLEFT", previous, "TOPRIGHT")
				column = column + 1
			else
				if section then
					sectionCount = sectionCount + 1
					local text = getSectionText(sectionCount)
					text:SetText(section)
					text:ClearAllPoints()
					anchorRow(text, rowStart, CARD_LEFT, rowStart and ROW_GAP + SECTION_TOP or ROW_GAP)
					text:Show()
					button:SetPoint("TOPLEFT", text, "BOTTOMLEFT", -CARD_LEFT, -SECTION_GAP)
				else
					anchorRow(button, rowStart, 0, ROW_GAP)
				end
				rowStart = button
				column, rowColumns = 1, span
			end
			previous = button
		end
		if panel and rowStart then
			panel:ClearAllPoints()
			panel:SetPoint("TOPLEFT", rowStart, "BOTTOMLEFT", CARD_LEFT, -PANEL_GAP)
			panel:SetPoint("RIGHT", GossipGreetingScrollChildFrame, "LEFT", BUTTON_WIDTH + CARD_RIGHT, 0)
			panel:SetHeight(panelHeight)
			panel:Show()
			footer = panel
		end
		local last = footer or rowStart
		if last then
			GossipSpacerFrame:SetPoint("TOP", last, "BOTTOM", 0, 0)
			GossipSpacerFrame:Show()
		else
			GossipSpacerFrame:Hide()
		end
	end

	hooksecurefunc("GossipFrameUpdate", function()
		local skin = skins[UnitName("npc")]
		if not skin then
			if applied then
				restore()
			end
			return
		end
		applied = true
		GossipGreetingText:Hide()
		hideTitle()
		hideSections()
		hideFooter()
		hideNavs()
		wipe(visible)
		for i = 1, NUMGOSSIPBUTTONS do
			local button = _G["GossipTitleButton" .. i]
			resetButton(button)
			if button:IsShown() then
				tinsert(visible, button)
			end
		end
		layout(skin(visible))
		showNavs()
	end)
end)
