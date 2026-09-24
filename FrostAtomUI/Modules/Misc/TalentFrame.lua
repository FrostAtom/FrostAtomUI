local _, ns = ...

local GetNumTalentTabs, GetTalentTabInfo, GetNumTalents, GetTalentInfo, GetTalentPrereqs =
	GetNumTalentTabs, GetTalentTabInfo, GetNumTalents, GetTalentInfo, GetTalentPrereqs
local GetUnspentTalentPoints, GetGroupPreviewTalentPointsSpent =
	GetUnspentTalentPoints, GetGroupPreviewTalentPointsSpent
local GetActiveTalentGroup, GetNumTalentGroups, SetActiveTalentGroup =
	GetActiveTalentGroup, GetNumTalentGroups, SetActiveTalentGroup
local LearnTalent, AddPreviewTalentPoints, ResetGroupPreviewTalentPoints, GetTalentLink =
	LearnTalent, AddPreviewTalentPoints, ResetGroupPreviewTalentPoints, GetTalentLink
local GetCVarBool, IsModifiedClick, IsCurrentSpell, UnitLevel = GetCVarBool, IsModifiedClick, IsCurrentSpell, UnitLevel
local GetNumGlyphSockets, GetGlyphSocketInfo, GlyphMatchesSocket, PlaceGlyphInSocket, GetGlyphLink =
	GetNumGlyphSockets, GetGlyphSocketInfo, GlyphMatchesSocket, PlaceGlyphInSocket, GetGlyphLink
local GetSpellInfo, IsShiftKeyDown, SetPortraitTexture, UnitName =
	GetSpellInfo, IsShiftKeyDown, SetPortraitTexture, UnitName
local select, min, max, abs = select, math.min, math.max, math.abs

local TalentFrame = ns:NewModule("TalentFrame")
TalentFrame.configKey = "talentFrame"

local FRAME_NAME = "FrostAtomUITalents"
local INSET = ns.WINDOW_INSET
local MAX_TABS = 3
local COLUMNS = 4
local CONTENT_TOP = 40
local STATUS_HEIGHT = 26
local PANE_GAP = 8
local PANE_BORDER = 4
local PANE_HEADER = 26
local BUTTON_SIZE = 32
local SLOT_SIZE = 56
local CELL_X = 52
local CELL_Y = 44
local MARGIN = 18
local BRANCH_SIZE = 32
local ARROW_SIZE = 32
local ARROW_OFFSET = 5
local BAR_HEIGHT = 26
local FOOTER_BOTTOM = 14
local SIDE_TAB_X = -3
local SIDE_TAB_Y = -60
local PANE_WIDTH = MARGIN * 2 + (COLUMNS - 1) * CELL_X + BUTTON_SIZE
local GLYPH_WIDTH = 246
local WIDTH = INSET.left + INSET.right + MAX_TABS * PANE_WIDTH + MAX_TABS * PANE_GAP + GLYPH_WIDTH
local PLAYER_TALENTS_PER_TIER, PET_TALENTS_PER_TIER = 5, 3
local ART_CROP, ART_WIDTH, ART_HEIGHT, ART_LEFT, ART_TOP = 0.19921875, 249, 331, 205, 256
local DEFAULT_SPEC_ICON = "Interface\\Icons\\Ability_Marksmanship"

local BORDERS = "Interface\\Buttons\\UI-Button-Borders2"
local INPUT_BORDER = "Interface\\Common\\Common-Input-Border"
local BRANCH_TEXTURE = "Interface\\TalentFrame\\UI-TalentBranches"
local ARROW_TEXTURE = "Interface\\TalentFrame\\UI-TalentArrows"
local GLYPH_TEXTURE = "Interface\\Spellbook\\UI-GlyphFrame"
local LOCKED_TEXTURE = "Interface\\Spellbook\\UI-GlyphFrame-Locked"
local PARCHMENT_TEXTURE = "Interface\\AchievementFrame\\UI-Achievement-Parchment"

local SLOT_AVAILABLE = { 0.1, 1, 0.1 }
local SLOT_MAXED = { 1, 0.82, 0 }
local PARCHMENT_TITLE_COLOR = { 0.18, 0.12, 0.06 }
local PARCHMENT_TEXT_COLOR = { 0, 0, 0 }
local PARCHMENT_DISABLED_COLOR = { 0.4, 0.26, 0.12 }

local BRANCH_COORDS = {
	down = { [true] = { 0, 0.125, 0, 0.484375 }, [false] = { 0, 0.125, 0.515625, 1 } },
	right = { [true] = { 0.2578125, 0.3828125, 0, 0.5 }, [false] = { 0.2578125, 0.3828125, 0.5, 1 } },
	topright = { [true] = { 0.515625, 0.640625, 0, 0.5 }, [false] = { 0.515625, 0.640625, 0.5, 1 } },
	topleft = { [true] = { 0.640625, 0.515625, 0, 0.5 }, [false] = { 0.640625, 0.515625, 0.5, 1 } },
	bottomright = { [true] = { 0.38671875, 0.51171875, 0, 0.5 }, [false] = { 0.38671875, 0.51171875, 0.5, 1 } },
	bottomleft = { [true] = { 0.51171875, 0.38671875, 0, 0.5 }, [false] = { 0.51171875, 0.38671875, 0.5, 1 } },
}

local ARROW_COORDS = {
	top = { [true] = { 0, 0.5, 0, 0.5 }, [false] = { 0, 0.5, 0.5, 1 } },
	right = { [true] = { 1, 0.5, 0, 0.5 }, [false] = { 1, 0.5, 0.5, 1 } },
	left = { [true] = { 0.5, 1, 0, 0.5 }, [false] = { 0.5, 1, 0.5, 1 } },
}

local GLYPH_CROP_LEFT, GLYPH_CROP_RIGHT, GLYPH_CROP_TOP, GLYPH_CROP_BOTTOM = 18, 330, 42, 420
local GLYPH_SCALE = (GLYPH_WIDTH - PANE_BORDER * 2) / (GLYPH_CROP_RIGHT - GLYPH_CROP_LEFT)
local GLYPH_ART_HEIGHT = (GLYPH_CROP_BOTTOM - GLYPH_CROP_TOP) * GLYPH_SCALE
local GLYPH_NAME_HEIGHT = 16
local GLYPH_TYPES = { 1, 2, 2, 1, 2, 1 }
local GLYPH_LABELS = { "MAJOR_GLYPH", "MINOR_GLYPH" }
local GLYPH_COLORS = { { 1, 0.25, 0 }, { 0, 0.25, 1 } }
local GLYPH_SOCKETS = { { 177, 116 }, { 178, 359 }, { 73, 178 }, { 283, 299 }, { 283, 178 }, { 71, 299 } }
local GLYPH_SLOTS = {
	[0] = { 0.78125, 0.91015625, 0.69921875, 0.828125 },
	{ 0, 0.12890625, 0.87109375, 1 },
	{ 0.130859375, 0.259765625, 0.87109375, 1 },
	{ 0.392578125, 0.521484375, 0.87109375, 1 },
	{ 0.5234375, 0.65234375, 0.87109375, 1 },
	{ 0.26171875, 0.390625, 0.87109375, 1 },
	{ 0.654296875, 0.783203125, 0.87109375, 1 },
}
local GLYPH_STYLES = {
	{
		setting = 108,
		settingCoords = { 0.740234375, 0.953125, 0.484375, 0.697265625 },
		ring = 82,
		ringY = -1,
		ringCoords = { 0.767578125, 0.92578125, 0.32421875, 0.482421875 },
		shineCoords = { 0.9609375, 1, 0.9609375, 1 },
		background = 70,
	},
	{
		setting = 86,
		settingCoords = { 0.765625, 0.927734375, 0.15625, 0.31640625 },
		ring = 62,
		ringY = 1,
		ringCoords = { 0.787109375, 0.908203125, 0.033203125, 0.154296875 },
		shineCoords = { 0.9609375, 1, 0.921875, 0.9609375 },
		background = 64,
	},
}
local GLYPH_HIGHLIGHT_ALPHA = 0.4

local SPECS = {
	{ group = 1, pet = false, unit = "player", name = "TALENT_SPEC_PRIMARY", glyphName = "TALENT_SPEC_PRIMARY_GLYPH" },
	{
		group = 2,
		pet = false,
		unit = "player",
		name = "TALENT_SPEC_SECONDARY",
		glyphName = "TALENT_SPEC_SECONDARY_GLYPH",
	},
	{ group = 1, pet = true, unit = "pet", name = "TALENT_SPEC_PET_PRIMARY" },
}

local frame
local panes = {}
local view = { pet = false, group = 1 }

local function centerX(column)
	return MARGIN + (column - 1) * CELL_X + BUTTON_SIZE / 2
end

local function centerY(tier)
	return MARGIN + (tier - 1) * CELL_Y + BUTTON_SIZE / 2
end

local function isEditable()
	return view.group == GetActiveTalentGroup(false, view.pet)
end

local function setEnabled(button, enabled)
	if enabled then
		button:Enable()
	else
		button:Disable()
	end
end

local function setColor(region, color)
	region:SetVertexColor(color[1], color[2], color[3])
end

local function setFontColor(region, color)
	region:SetTextColor(color.r, color.g, color.b)
end

local function createBar(parent)
	local bar = CreateFrame("Frame", nil, parent)
	bar:SetHeight(BAR_HEIGHT)

	local background = bar:CreateTexture(nil, "BACKGROUND")
	background:SetTexture(BORDERS)
	background:SetTexCoord(0, 0.646484375, 0.2109375, 0.4140625)
	background:SetAllPoints()

	local left = bar:CreateTexture(nil, "BORDER")
	left:SetTexture(BORDERS)
	left:SetTexCoord(0, 0.01171875, 0.421875, 0.5625)
	left:SetWidth(6)
	left:SetPoint("TOPLEFT", 4, -5)
	left:SetPoint("BOTTOMLEFT", 4, 5)

	local right = bar:CreateTexture(nil, "BORDER")
	right:SetTexture(BORDERS)
	right:SetTexCoord(0.3046875, 0.31640625, 0.421875, 0.5625)
	right:SetWidth(6)
	right:SetPoint("TOPRIGHT", -4, -5)
	right:SetPoint("BOTTOMRIGHT", -4, 5)

	local middle = bar:CreateTexture(nil, "BORDER")
	middle:SetTexture(BORDERS)
	middle:SetTexCoord(0.01171875, 0.3046875, 0.421875, 0.5625)
	middle:SetPoint("TOPLEFT", left, "TOPRIGHT")
	middle:SetPoint("BOTTOMRIGHT", right, "BOTTOMLEFT")
	return bar
end

local function acquireBranch(pane, key, met)
	pane.branchCount = pane.branchCount + 1
	local branch = pane.branches[pane.branchCount]
	if not branch then
		branch = pane.body:CreateTexture(nil, "ARTWORK")
		branch:SetTexture(BRANCH_TEXTURE)
		pane.branches[pane.branchCount] = branch
	end
	branch:SetTexCoord(unpack(BRANCH_COORDS[key][met]))
	branch:ClearAllPoints()
	branch:Show()
	return branch
end

local function horizontalBranch(pane, x1, x2, y, met)
	local branch = acquireBranch(pane, "right", met)
	branch:SetPoint("TOPLEFT", pane.body, "TOPLEFT", min(x1, x2), -(y - BRANCH_SIZE / 2))
	branch:SetSize(max(abs(x2 - x1), 1), BRANCH_SIZE)
end

local function verticalBranch(pane, x, y1, y2, met)
	local branch = acquireBranch(pane, "down", met)
	branch:SetPoint("TOPLEFT", pane.body, "TOPLEFT", x - BRANCH_SIZE / 2, -min(y1, y2))
	branch:SetSize(BRANCH_SIZE, max(abs(y2 - y1), 1))
end

local function cornerBranch(pane, key, x, y, met)
	local branch = acquireBranch(pane, key, met)
	branch:SetPoint("CENTER", pane.body, "TOPLEFT", x, -y)
	branch:SetSize(BRANCH_SIZE, BRANCH_SIZE)
end

local function arrow(pane, direction, x, y, met)
	pane.arrowCount = pane.arrowCount + 1
	local texture = pane.arrows[pane.arrowCount]
	if not texture then
		texture = pane.arrowLayer:CreateTexture(nil, "OVERLAY")
		texture:SetTexture(ARROW_TEXTURE)
		texture:SetSize(ARROW_SIZE, ARROW_SIZE)
		pane.arrows[pane.arrowCount] = texture
	end
	texture:SetTexCoord(unpack(ARROW_COORDS[direction][met]))
	texture:ClearAllPoints()
	texture:SetPoint("CENTER", pane.body, "TOPLEFT", x, -y)
	texture:Show()
end

local function rowBlocked(pane, tier, fromColumn, toColumn)
	local step = fromColumn < toColumn and 1 or -1
	for column = fromColumn + step, toColumn, step do
		if pane.occupied[tier * COLUMNS + column] then
			return true
		end
	end
	return false
end

local function drawBranch(pane, fromTier, fromColumn, tier, column, met)
	local reach = BUTTON_SIZE / 2 + ARROW_OFFSET
	local half = BRANCH_SIZE / 2
	local fromX, fromY = centerX(fromColumn), centerY(fromTier)
	local x, y = centerX(column), centerY(tier)
	local step = fromColumn < column and 1 or -1
	local side = fromColumn < column and "left" or "right"

	if fromColumn == column then
		verticalBranch(pane, x, fromY, y, met)
		arrow(pane, "top", x, y - reach, met)
	elseif fromTier == tier then
		horizontalBranch(pane, fromX, x, y, met)
		arrow(pane, side, x - step * reach, y, met)
	elseif not rowBlocked(pane, fromTier, fromColumn, column) then
		horizontalBranch(pane, fromX, x - step * half, fromY, met)
		cornerBranch(pane, step == 1 and "topright" or "topleft", x, fromY, met)
		verticalBranch(pane, x, fromY + half, y, met)
		arrow(pane, "top", x, y - reach, met)
	else
		verticalBranch(pane, fromX, fromY, y - half, met)
		cornerBranch(pane, step == 1 and "bottomleft" or "bottomright", fromX, y, met)
		horizontalBranch(pane, fromX + step * half, x, y, met)
		arrow(pane, side, x - step * reach, y, met)
	end
end

local function drawPrereqs(pane, tier, column, met, preview, ...)
	for i = 1, select("#", ...), 4 do
		local fromTier, fromColumn, isLearnable, isPreviewLearnable = select(i, ...)
		if preview then
			met = met and isPreviewLearnable and true or false
		else
			met = met and isLearnable and true or false
		end
		drawBranch(pane, fromTier, fromColumn, tier, column, met)
	end
	return met
end

local function showTalentTooltip(self)
	GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
	GameTooltip:SetTalent(self.tab, self.index, false, view.pet, view.group, GetCVarBool("previewTalents"))
end

local function onTalentClick(self, mouseButton)
	local preview = GetCVarBool("previewTalents")
	if IsModifiedClick("CHATLINK") then
		local link = GetTalentLink(self.tab, self.index, false, view.pet, view.group, preview)
		if link then
			ChatEdit_InsertLink(link)
		end
		return
	end
	if not isEditable() then
		return
	end
	if preview then
		AddPreviewTalentPoints(self.tab, self.index, mouseButton == "LeftButton" and 1 or -1, view.pet, view.group)
	elseif mouseButton == "LeftButton" then
		LearnTalent(self.tab, self.index, view.pet, view.group)
	end
end

local function createTalentButton(pane, index)
	local button = CreateFrame("Button", nil, pane.body)
	button:SetSize(BUTTON_SIZE, BUTTON_SIZE)
	button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	ns.SkinIconButton(button, false)

	local slot = button:CreateTexture(nil, "BACKGROUND")
	slot:SetTexture("Interface\\Buttons\\UI-EmptySlot-White")
	slot:SetSize(SLOT_SIZE, SLOT_SIZE)
	slot:SetPoint("CENTER")
	button.slot = slot

	local rankBorder = button:CreateTexture(nil, "OVERLAY")
	rankBorder:SetTexture("Interface\\TalentFrame\\TalentFrame-RankBorder")
	rankBorder:SetSize(32, 32)
	rankBorder:SetPoint("CENTER", button, "BOTTOMRIGHT")
	button.rankBorder = rankBorder

	local rank = button:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	rank:SetPoint("CENTER", rankBorder)
	button.rank = rank

	button.index = index
	button:SetScript("OnClick", onTalentClick)
	button:SetScript("OnEnter", showTalentTooltip)
	button:SetScript("OnLeave", GameTooltip_Hide)

	pane.buttons[index] = button
	return button
end

local function updateTalent(button, pane, i, context)
	local name, iconTexture, tier, column, rank, maxRank, _, meetsPrereq, previewRank, meetsPreviewPrereq =
		GetTalentInfo(context.tab, i, false, view.pet, view.group)
	if not name then
		button:Hide()
		return 0
	end

	local displayRank = context.preview and previewRank or rank
	local forceDesaturated = (context.unspent <= 0 or not context.editable) and displayRank == 0
	local tierUnlocked = (tier - 1) * context.perTier <= context.spent
	local met = drawPrereqs(
		pane,
		tier,
		column,
		tierUnlocked and not forceDesaturated,
		context.preview,
		GetTalentPrereqs(context.tab, i, false, view.pet, view.group)
	)

	button.tab = context.tab
	button:SetPoint(
		"TOPLEFT",
		pane.body,
		"TOPLEFT",
		centerX(column) - BUTTON_SIZE / 2,
		-(centerY(tier) - BUTTON_SIZE / 2)
	)
	button.icon:SetTexture(iconTexture)
	button.rank:SetText(displayRank)

	if met and (context.preview and meetsPreviewPrereq or not context.preview and meetsPrereq) then
		button.icon:SetDesaturated(false)
		button.icon:SetVertexColor(1, 1, 1)
		local maxed = displayRank >= maxRank
		setColor(button.slot, maxed and SLOT_MAXED or SLOT_AVAILABLE)
		setFontColor(button.rank, maxed and NORMAL_FONT_COLOR or GREEN_FONT_COLOR)
		button.rankBorder:SetVertexColor(1, 1, 1)
		button.rankBorder:Show()
		button.rank:Show()
	else
		button.icon:SetDesaturated(true)
		button.icon:SetVertexColor(0.65, 0.65, 0.65)
		button.slot:SetVertexColor(0.5, 0.5, 0.5)
		button.rankBorder:SetVertexColor(0.5, 0.5, 0.5)
		setFontColor(button.rank, GRAY_FONT_COLOR)
		ns.SetShown(button.rankBorder, displayRank > 0)
		ns.SetShown(button.rank, displayRank > 0)
	end
	button:Show()
	return tier
end

local function setBackground(pane, background, desaturated)
	local base = "Interface\\TalentFrame\\" .. (background or "MageFire") .. "-"
	for suffix, texture in pairs(pane.art) do
		texture:SetTexture(base .. suffix)
		texture:SetDesaturated(desaturated)
	end
end

local function updatePane(pane, tab, context)
	local name, icon, pointsSpent, background, previewPointsSpent = GetTalentTabInfo(tab, false, view.pet, view.group)
	context.tab = tab
	context.spent = pointsSpent + (previewPointsSpent or 0)

	pane.icon:SetTexture(icon)
	pane.name:SetText(name)
	pane.points:SetText(context.spent)
	setBackground(pane, background, not context.editable)

	pane.branchCount, pane.arrowCount = 0, 0
	wipe(pane.occupied)
	local numTalents = GetNumTalents(tab, false, view.pet)
	for i = 1, numTalents do
		local talentName, _, tier, column = GetTalentInfo(tab, i, false, view.pet, view.group)
		if talentName then
			pane.occupied[tier * COLUMNS + column] = true
		end
	end

	local maxTier = 1
	for i = 1, numTalents do
		local button = pane.buttons[i] or createTalentButton(pane, i)
		maxTier = max(maxTier, updateTalent(button, pane, i, context))
	end
	for i = numTalents + 1, #pane.buttons do
		pane.buttons[i]:Hide()
	end
	for i = pane.branchCount + 1, #pane.branches do
		pane.branches[i]:Hide()
	end
	for i = pane.arrowCount + 1, #pane.arrows do
		pane.arrows[i]:Hide()
	end
	return maxTier
end

local function layoutArt(pane, bodyHeight)
	local sx = (PANE_WIDTH - PANE_BORDER * 2) / ART_WIDTH
	local sy = (bodyHeight - PANE_BORDER) / ART_HEIGHT
	local left, right = ART_LEFT * sx, (ART_WIDTH - ART_LEFT) * sx
	local top, bottom = ART_TOP * sy, (ART_HEIGHT - ART_TOP) * sy
	pane.art.TopLeft:SetSize(left, top)
	pane.art.TopRight:SetSize(right, top)
	pane.art.BottomLeft:SetSize(left, bottom)
	pane.art.BottomRight:SetSize(right, bottom)
end

local function showSpecTooltip(self)
	local spec = self.spec
	GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
	if GetNumTalentGroups(false, true) <= 1 and GetNumTalentGroups(false, false) <= 1 then
		GameTooltip:AddLine(UnitName(spec.unit), NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b)
	else
		GameTooltip:AddLine(_G[spec.name])
		if not spec.pet and spec.group == GetActiveTalentGroup(false, false) then
			GameTooltip:AddLine(TALENT_ACTIVE_SPEC_STATUS, GREEN_FONT_COLOR.r, GREEN_FONT_COLOR.g, GREEN_FONT_COLOR.b)
		end
	end
	local cache = self.cache
	for index = 1, cache.numTabs or 0 do
		local info = cache[index]
		if info and info.name then
			local color = cache.primaryTabIndex == index and GREEN_FONT_COLOR or HIGHLIGHT_FONT_COLOR
			GameTooltip:AddDoubleLine(
				info.name,
				info.pointsSpent,
				HIGHLIGHT_FONT_COLOR.r,
				HIGHLIGHT_FONT_COLOR.g,
				HIGHLIGHT_FONT_COLOR.b,
				color.r,
				color.g,
				color.b,
				1
			)
		end
	end
	GameTooltip:Show()
end

local function updateSpecTabs(numGroups, numPetGroups)
	local showTabs = numGroups > 1 or numPetGroups > 0
	local y
	for _, tab in ipairs(frame.specTabs) do
		local spec = tab.spec
		local available = spec.pet and numPetGroups > 0 or not spec.pet and spec.group <= numGroups
		if available and showTabs then
			local cache = tab.cache
			TalentFrame_UpdateSpecInfoCache(cache, false, spec.pet, spec.group)
			local normal = tab:GetNormalTexture()
			if numGroups <= 1 then
				SetPortraitTexture(normal, spec.unit)
			elseif cache.primaryTabIndex > 0 then
				normal:SetTexture(cache[cache.primaryTabIndex].icon)
			elseif cache.numTabs > 1 and cache.totalPointsSpent > 0 then
				normal:SetTexture(TALENT_HYBRID_ICON)
			elseif spec.pet then
				SetPortraitTexture(normal, spec.unit)
			else
				normal:SetTexture(DEFAULT_SPEC_ICON)
			end

			if y then
				y = y - BUTTON_SIZE - (spec.pet and 39 or 22)
			else
				y = SIDE_TAB_Y
			end
			tab:ClearAllPoints()
			tab:SetPoint("TOPLEFT", frame, "TOPRIGHT", SIDE_TAB_X, y)
			tab:SetChecked(spec.pet == view.pet and (spec.pet or spec.group == view.group))
			tab:Show()
		else
			tab:Hide()
		end
	end
end

local function updateStatus(numGroups)
	local activeGroup = GetActiveTalentGroup(false, false)
	local dual = numGroups > 1 and not view.pet
	ns.SetShown(frame.status, dual and view.group == activeGroup)
	local activate = frame.activate
	if dual and view.group ~= activeGroup then
		activate:Show()
		setEnabled(activate, not (TALENT_ACTIVATION_SPELLS and IsCurrentSpell(TALENT_ACTIVATION_SPELLS[view.group])))
	else
		activate:Hide()
	end
end

local function updateFooter(unspent, preview, editable)
	frame.unspent:SetFormattedText(UNSPENT_TALENT_POINTS, HIGHLIGHT_FONT_COLOR_CODE .. unspent .. FONT_COLOR_CODE_CLOSE)
	local showPreview = preview and editable and GetUnspentTalentPoints(false, view.pet, view.group) > 0
	local bar = frame.pointsBar
	bar:ClearAllPoints()
	bar:SetPoint("BOTTOMLEFT", INSET.left, FOOTER_BOTTOM)
	if showPreview then
		bar:SetPoint("RIGHT", frame.previewBar, "LEFT", -2, 0)
		local spent = GetGroupPreviewTalentPointsSpent(view.pet, view.group) > 0
		setEnabled(frame.learn, spent)
		setEnabled(frame.reset, spent)
		frame.previewBar:Show()
	else
		bar:SetPoint("RIGHT", frame, "RIGHT", -INSET.right, 0)
		frame.previewBar:Hide()
	end
end

local function glyphEditable()
	return not view.pet and view.group == GetActiveTalentGroup(false, false)
end

local function showGlyphTooltip(self)
	if self.background:IsShown() then
		self.highlight:Show()
	end
	GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
	GameTooltip:SetGlyph(self.socket, view.group)
	GameTooltip:Show()
end

local function hideGlyphTooltip(self)
	self.highlight:Hide()
	GameTooltip:Hide()
end

local function onGlyphClick(self, mouseButton)
	local socket = self.socket
	if IsModifiedClick("CHATLINK") then
		local link = GetGlyphLink(socket, view.group)
		if link then
			ChatEdit_InsertLink(link)
		end
		return
	end
	if not glyphEditable() then
		return
	end
	local _, _, glyphSpell = GetGlyphSocketInfo(socket, view.group)
	if mouseButton == "RightButton" then
		if IsShiftKeyDown() and glyphSpell then
			local dialog = StaticPopup_Show("FROSTATOMUI_REMOVE_GLYPH", (GetSpellInfo(glyphSpell)))
			if dialog then
				dialog.data = socket
			end
		end
	elseif glyphSpell and GlyphMatchesSocket(socket) then
		local dialog = StaticPopup_Show("FROSTATOMUI_GLYPH_PLACEMENT")
		if dialog then
			dialog.data = socket
		end
	else
		PlaceGlyphInSocket(socket)
	end
end

local function onGlyphUpdate(self, elapsed)
	local hasGlyph = self.glyph:IsShown()
	if hasGlyph or self.elapsed > 0 then
		self.elapsed = self.elapsed + elapsed
		local t = self.elapsed
		if t >= 6 then
			self.setting:SetAlpha(0.6)
			self.elapsed = 0
		elseif t <= 2 then
			self.setting:SetAlpha(0.6 + 0.4 * t / 2)
		elseif t >= 4 then
			self.setting:SetAlpha(1 - 0.4 * (t - 4) / 2)
		end
	else
		self.setting:SetAlpha(0.6)
	end

	if not hasGlyph and self.editable and self.background:IsShown() and GlyphMatchesSocket(self.socket) then
		self.tintElapsed = self.tintElapsed + elapsed
		self.background:SetTexCoord(unpack(GLYPH_SLOTS[self.socket]))
		local hovered = self:IsMouseOver()
		if not hovered then
			self.highlight:Show()
		end
		local t, alpha = self.tintElapsed
		if t >= 1.6 then
			alpha = 1
			self.tintElapsed = 0
		elseif t <= 0.6 then
			alpha = 1 - 0.6 * t / 0.6
		elseif t >= 0.8 then
			alpha = 0.4 + 0.6 * (t - 0.8) / 0.8
		end
		if alpha then
			self.background:SetAlpha(alpha)
			self.highlight:SetAlpha(hovered and GLYPH_HIGHLIGHT_ALPHA or GLYPH_HIGHLIGHT_ALPHA * alpha)
		end
	elseif not hasGlyph then
		self.background:SetTexCoord(unpack(GLYPH_SLOTS[0]))
		self.background:SetAlpha(1)
		if self.tintElapsed > 0 then
			self.tintElapsed = 0
			self.highlight:SetAlpha(GLYPH_HIGHLIGHT_ALPHA)
			if not self:IsMouseOver() then
				self.highlight:Hide()
			end
		end
	end
end

local function createGlyphTexture(button, layer, size)
	local texture = button:CreateTexture(nil, layer)
	texture:SetTexture(GLYPH_TEXTURE)
	if size then
		texture:SetSize(size * GLYPH_SCALE, size * GLYPH_SCALE)
	end
	texture:SetPoint("CENTER")
	return texture
end

local function createGlyphSocket(panel, socket)
	local center = GLYPH_SOCKETS[socket]
	local button = CreateFrame("Button", nil, panel.art)
	button:SetSize(90 * GLYPH_SCALE, 90 * GLYPH_SCALE)
	button:SetPoint(
		"CENTER",
		panel.art,
		"TOPLEFT",
		(center[1] - GLYPH_CROP_LEFT) * GLYPH_SCALE,
		-(center[2] - GLYPH_CROP_TOP) * GLYPH_SCALE
	)
	button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	button.socket = socket
	button.elapsed, button.tintElapsed = 0, 0

	button.setting = createGlyphTexture(button, "BACKGROUND")
	local highlight = createGlyphTexture(button, "BORDER")
	highlight:SetBlendMode("ADD")
	highlight:SetVertexColor(1, 1, 1, 0.25)
	highlight:SetAlpha(GLYPH_HIGHLIGHT_ALPHA)
	highlight:Hide()
	button.highlight = highlight
	button.background = createGlyphTexture(button, "BORDER")
	button.glyph = createGlyphTexture(button, "ARTWORK", 53)
	button.ring = createGlyphTexture(button, "OVERLAY")
	local shine = createGlyphTexture(button, "OVERLAY", 16)
	shine:ClearAllPoints()
	shine:SetPoint("CENTER", -9 * GLYPH_SCALE, 12 * GLYPH_SCALE)
	button.shine = shine

	button:SetScript("OnClick", onGlyphClick)
	button:SetScript("OnEnter", showGlyphTooltip)
	button:SetScript("OnLeave", hideGlyphTooltip)
	button:SetScript("OnUpdate", onGlyphUpdate)
	panel.sockets[socket] = button
	return button
end

local function setGlyphType(button, glyphType)
	local style = GLYPH_STYLES[glyphType]
	local settingSize = style.setting * GLYPH_SCALE
	button.setting:SetTexture(GLYPH_TEXTURE)
	button.setting:SetSize(settingSize, settingSize)
	button.setting:SetTexCoord(unpack(style.settingCoords))
	button.highlight:SetSize(settingSize, settingSize)
	button.highlight:SetTexCoord(unpack(style.settingCoords))
	button.ring:SetSize(style.ring * GLYPH_SCALE, style.ring * GLYPH_SCALE)
	button.ring:SetPoint("CENTER", 0, style.ringY * GLYPH_SCALE)
	button.ring:SetTexCoord(unpack(style.ringCoords))
	button.shine:SetTexCoord(unpack(style.shineCoords))
	button.background:SetSize(style.background * GLYPH_SCALE, style.background * GLYPH_SCALE)
	setColor(button.glyph, GLYPH_COLORS[glyphType])
end

local function updateGlyphSocket(button, editable)
	local socket = button.socket
	local enabled, glyphType, glyphSpell, iconFile = GetGlyphSocketInfo(socket, view.group)
	setGlyphType(button, glyphType == 2 and 2 or 1)
	button.editable = editable
	button.elapsed, button.tintElapsed = 0, 0
	if not button:IsMouseOver() then
		button.highlight:Hide()
	end
	button.highlight:SetAlpha(GLYPH_HIGHLIGHT_ALPHA)

	if not enabled then
		button.shine:Hide()
		button.background:Hide()
		button.glyph:Hide()
		button.ring:Hide()
		button.setting:SetTexture(LOCKED_TEXTURE)
		button.setting:SetTexCoord(0.1, 0.9, 0.1, 0.9)
	else
		button.shine:Show()
		button.background:Show()
		button.background:SetAlpha(1)
		button.ring:Show()
		if glyphSpell then
			button.background:SetTexCoord(unpack(GLYPH_SLOTS[socket]))
			button.glyph:SetTexture(iconFile or "Interface\\Spellbook\\UI-Glyph-Rune1")
			button.glyph:Show()
		else
			button.background:SetTexCoord(unpack(GLYPH_SLOTS[0]))
			button.glyph:Hide()
		end
	end
	for _, region in ipairs({ button.setting, button.background, button.glyph, button.ring }) do
		region:SetDesaturated(not editable)
	end

	local name = button.nameText
	if not enabled then
		name:SetText(GLYPH_LOCKED)
		name:SetTextColor(unpack(PARCHMENT_DISABLED_COLOR))
	elseif not glyphSpell then
		name:SetText(GLYPH_EMPTY)
		name:SetTextColor(unpack(PARCHMENT_DISABLED_COLOR))
	else
		name:SetText((GetSpellInfo(glyphSpell)))
		name:SetTextColor(unpack(PARCHMENT_TEXT_COLOR))
	end
end

local function updateGlyphs(height, numGroups)
	local panel = frame.glyphPanel
	local spec = SPECS[view.group]
	panel.title:SetText(numGroups > 1 and spec and spec.glyphName and _G[spec.glyphName] or GLYPHS)
	local editable = glyphEditable()
	panel.background:SetDesaturated(not editable)
	local y = PANE_BORDER + PANE_HEADER + GLYPH_ART_HEIGHT + 8
	for glyphType = 1, 2 do
		local header = panel.headers[glyphType]
		header:SetPoint("TOPLEFT", 12, -y)
		y = y + 22
		for socket = 1, GetNumGlyphSockets() do
			local _, socketType = GetGlyphSocketInfo(socket, view.group)
			if (socketType or GLYPH_TYPES[socket]) == glyphType then
				local button = panel.sockets[socket] or createGlyphSocket(panel, socket)
				if not button.nameText then
					local name = panel:CreateFontString(nil, "ARTWORK", "QuestFontNormalSmall")
					name:SetJustifyH("LEFT")
					button.nameText = name
				end
				button.nameText:SetPoint("TOPLEFT", 20, -y)
				button.nameText:SetPoint("RIGHT", -12, 0)
				updateGlyphSocket(button, editable)
				y = y + GLYPH_NAME_HEIGHT
			end
		end
		y = y + 6
	end
	panel:SetHeight(height)
	local owner = GameTooltip:GetOwner()
	if owner and owner.socket and owner:GetParent() == panel.art and owner:IsMouseOver() then
		showGlyphTooltip(owner)
	end
end

local function createGlyphPanel()
	local panel = ns.CreateInset(frame, "panel")
	panel:SetWidth(GLYPH_WIDTH)

	local background = panel:CreateTexture(nil, "BACKGROUND")
	background:SetTexture(PARCHMENT_TEXTURE)
	background:SetPoint("TOPLEFT", PANE_BORDER, -(PANE_BORDER + PANE_HEADER))
	background:SetPoint("BOTTOMRIGHT", -PANE_BORDER, PANE_BORDER)
	panel.background = background

	local header = createBar(panel)
	header:SetHeight(PANE_HEADER)
	header:SetPoint("TOPLEFT", PANE_BORDER, -PANE_BORDER)
	header:SetPoint("TOPRIGHT", -PANE_BORDER, -PANE_BORDER)
	local title = header:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	title:SetPoint("CENTER", 0, 1)
	panel.title = title

	local art = CreateFrame("Frame", nil, panel)
	art:SetPoint("TOPLEFT", PANE_BORDER, -(PANE_BORDER + PANE_HEADER))
	art:SetSize(GLYPH_WIDTH - PANE_BORDER * 2, GLYPH_ART_HEIGHT)
	panel.art = art

	panel.headers = {}
	for glyphType, label in ipairs(GLYPH_LABELS) do
		local header = ns.CreateLabel(panel, _G[label], "QuestTitleFont")
		header:SetTextColor(unpack(PARCHMENT_TITLE_COLOR))
		panel.headers[glyphType] = header
	end
	panel.sockets = {}
	frame.glyphPanel = panel
end

local function refresh()
	if not frame or not frame:IsShown() then
		return
	end
	local numGroups = GetNumTalentGroups(false, false)
	local numPetGroups = GetNumTalentGroups(false, true)
	if view.pet and numPetGroups == 0 then
		view.pet, view.group = false, GetActiveTalentGroup(false, false)
	end
	if not view.pet and view.group > numGroups then
		view.group = GetActiveTalentGroup(false, false)
	end

	local preview = GetCVarBool("previewTalents")
	local editable = isEditable()
	local unspent = GetUnspentTalentPoints(false, view.pet, view.group)
		- GetGroupPreviewTalentPointsSpent(view.pet, view.group)
	local context = {
		preview = preview,
		editable = editable,
		unspent = unspent,
		perTier = view.pet and PET_TALENTS_PER_TIER or PLAYER_TALENTS_PER_TIER,
	}

	local spec = view.pet and SPECS[3] or SPECS[view.group]
	frame.title:SetText((view.pet or numGroups > 1) and _G[spec.name] or TALENTS)

	local paneTop = CONTENT_TOP + (numGroups > 1 and STATUS_HEIGHT or 0)
	local numTabs = min(GetNumTalentTabs(false, view.pet), MAX_TABS)
	local showGlyphs = not view.pet and UnitLevel("player") >= SHOW_INSCRIPTION_LEVEL
	local contentWidth = numTabs * PANE_WIDTH + (numTabs - 1) * PANE_GAP
	if showGlyphs then
		contentWidth = contentWidth + PANE_GAP + GLYPH_WIDTH
	end
	local left = (WIDTH - contentWidth) / 2
	local tiers = 1
	for tab = 1, MAX_TABS do
		local pane = panes[tab]
		if tab <= numTabs then
			pane:ClearAllPoints()
			pane:SetPoint("TOPLEFT", left + (tab - 1) * (PANE_WIDTH + PANE_GAP), -paneTop)
			tiers = max(tiers, updatePane(pane, tab, context))
			pane:Show()
		else
			pane:Hide()
		end
	end

	local bodyHeight = MARGIN * 2 + (tiers - 1) * CELL_Y + BUTTON_SIZE
	local paneHeight = PANE_BORDER + PANE_HEADER + bodyHeight
	for tab = 1, numTabs do
		panes[tab]:SetHeight(paneHeight)
		layoutArt(panes[tab], bodyHeight)
	end
	frame:SetHeight(paneTop + paneHeight + 6 + BAR_HEIGHT + FOOTER_BOTTOM)

	local glyphPanel = frame.glyphPanel
	if showGlyphs then
		glyphPanel:ClearAllPoints()
		glyphPanel:SetPoint("TOPLEFT", panes[numTabs], "TOPRIGHT", PANE_GAP, 0)
		updateGlyphs(paneHeight, numGroups)
		glyphPanel:Show()
	else
		glyphPanel:Hide()
	end

	updateSpecTabs(numGroups, numPetGroups)
	updateStatus(numGroups)
	updateFooter(unspent, preview, editable)

	local owner = GameTooltip:GetOwner()
	if owner and owner.tab and owner:IsShown() and owner:GetParent() and owner:GetParent().pane then
		showTalentTooltip(owner)
	end
end

local function queueRefresh()
	if frame and frame:IsShown() then
		ns.Defer(frame, refresh)
	end
end

local function createPane(index)
	local pane = ns.CreateInset(frame, "panel")
	pane:SetWidth(PANE_WIDTH)

	local header = createBar(pane)
	header:SetHeight(PANE_HEADER)
	header:SetPoint("TOPLEFT", PANE_BORDER, -PANE_BORDER)
	header:SetPoint("TOPRIGHT", -PANE_BORDER, -PANE_BORDER)

	local icon = header:CreateTexture(nil, "ARTWORK")
	icon:SetSize(18, 18)
	icon:SetPoint("LEFT", 8, 0)
	icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	pane.icon = icon

	local name = header:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	name:SetPoint("LEFT", icon, "RIGHT", 6, 1)
	pane.name = name

	local points = header:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	points:SetPoint("RIGHT", -10, 1)
	pane.points = points

	local body = CreateFrame("Frame", nil, pane)
	body:SetPoint("TOPLEFT", 0, -(PANE_BORDER + PANE_HEADER))
	body:SetPoint("BOTTOMRIGHT")
	body.pane = pane
	pane.body = body

	local art = {}
	for _, suffix in ipairs({ "TopLeft", "TopRight", "BottomLeft", "BottomRight" }) do
		art[suffix] = body:CreateTexture(nil, "BACKGROUND")
	end
	art.TopLeft:SetPoint("TOPLEFT", PANE_BORDER, 0)
	art.TopRight:SetPoint("TOPLEFT", art.TopLeft, "TOPRIGHT")
	art.BottomLeft:SetPoint("TOPLEFT", art.TopLeft, "BOTTOMLEFT")
	art.BottomRight:SetPoint("TOPLEFT", art.TopLeft, "BOTTOMRIGHT")
	art.TopLeft:SetTexCoord(ART_CROP, 1, 0, 1)
	art.TopRight:SetTexCoord(0, 0.6875, 0, 1)
	art.BottomLeft:SetTexCoord(ART_CROP, 1, 0, 0.5859375)
	art.BottomRight:SetTexCoord(0, 0.6875, 0, 0.5859375)
	pane.art = art

	local arrowLayer = CreateFrame("Frame", nil, body)
	arrowLayer:SetAllPoints()
	arrowLayer:SetFrameLevel(body:GetFrameLevel() + 5)
	pane.arrowLayer = arrowLayer

	pane.buttons, pane.branches, pane.arrows, pane.occupied = {}, {}, {}, {}
	pane.branchCount, pane.arrowCount = 0, 0
	panes[index] = pane
	return pane
end

local function selectSpec(self)
	view.pet, view.group = self.spec.pet, self.spec.group
	PlaySound("igCharacterInfoTab")
	refresh()
end

local function showButtonTooltip(self)
	GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
	GameTooltip:SetText(self.tooltip)
end

local function createStatus()
	local status = CreateFrame("Frame", nil, frame)
	status:SetSize(264, 20)
	status:SetPoint("TOP", 0, -CONTENT_TOP)

	local left = status:CreateTexture(nil, "BACKGROUND")
	left:SetTexture(INPUT_BORDER)
	left:SetTexCoord(0, 0.0625, 0, 0.625)
	left:SetSize(8, 20)
	left:SetPoint("LEFT")

	local right = status:CreateTexture(nil, "BACKGROUND")
	right:SetTexture(INPUT_BORDER)
	right:SetTexCoord(0.9375, 1, 0, 0.625)
	right:SetSize(8, 20)
	right:SetPoint("RIGHT")

	local middle = status:CreateTexture(nil, "BACKGROUND")
	middle:SetTexture(INPUT_BORDER)
	middle:SetTexCoord(0.0625, 0.9375, 0, 0.625)
	middle:SetPoint("TOPLEFT", left, "TOPRIGHT")
	middle:SetPoint("BOTTOMRIGHT", right, "BOTTOMLEFT")

	local text = status:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	text:SetPoint("CENTER")
	text:SetText(TALENT_ACTIVE_SPEC_STATUS)
	frame.status = status

	local activate = ns.CreateButton(frame, TALENT_SPEC_ACTIVATE, 80, 22)
	ns.FitButton(activate, 24, 80)
	activate:SetPoint("TOP", 0, -CONTENT_TOP + 1)
	activate:SetScript("OnClick", function()
		SetActiveTalentGroup(view.group)
	end)
	frame.activate = activate
end

local function createFooter()
	local pointsBar = createBar(frame)
	local unspent = pointsBar:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
	unspent:SetPoint("RIGHT", -12, 1)
	frame.unspent = unspent
	frame.pointsBar = pointsBar

	local previewBar = CreateFrame("Frame", nil, frame)
	previewBar:SetSize(164, BAR_HEIGHT)
	previewBar:SetPoint("BOTTOMRIGHT", -INSET.right, FOOTER_BOTTOM)
	local border = previewBar:CreateTexture(nil, "BORDER")
	border:SetTexture(BORDERS)
	border:SetTexCoord(0.16015625, 0.470703125, 0, 0.203125)
	border:SetAllPoints()
	frame.previewBar = previewBar

	local reset = ns.CreateButton(previewBar, RESET, 80, 22)
	reset:SetPoint("RIGHT", -4, 0)
	reset.tooltip = TALENT_TOOLTIP_RESETTALENTGROUP
	reset:SetScript("OnEnter", showButtonTooltip)
	reset:SetScript("OnLeave", GameTooltip_Hide)
	reset:SetScript("OnClick", function()
		ResetGroupPreviewTalentPoints(view.pet, view.group)
	end)
	frame.reset = reset

	local learn = ns.CreateButton(previewBar, LEARN, 80, 22)
	learn:SetPoint("RIGHT", reset, "LEFT")
	learn.tooltip = TALENT_TOOLTIP_LEARNTALENTGROUP
	learn:SetScript("OnEnter", showButtonTooltip)
	learn:SetScript("OnLeave", GameTooltip_Hide)
	learn:SetScript("OnClick", function()
		StaticPopup_Show("FROSTATOMUI_LEARN_PREVIEW_TALENTS")
	end)
	frame.learn = learn
end

local function createFrame()
	frame = ns.CreateWindow(
		FRAME_NAME,
		{ width = WIDTH, height = 600, title = TALENTS, strata = "MEDIUM", movable = false, special = false }
	)
	frame.close:SetScript("OnClick", HideParentPanel)
	ns.SetUIPanelLayout(frame, "left", 6)

	local specTabs = {}
	for i, spec in ipairs(SPECS) do
		local tab = ns.CreateSideTab(frame, DEFAULT_SPEC_ICON)
		tab.spec = spec
		tab.cache = {}
		tab:SetScript("OnClick", selectSpec)
		tab:SetScript("OnEnter", showSpecTooltip)
		specTabs[i] = tab
	end
	frame.specTabs = specTabs

	createStatus()
	for i = 1, MAX_TABS do
		createPane(i)
	end
	createGlyphPanel()
	createFooter()

	frame:SetScript("OnShow", function()
		PlaySound("TalentScreenOpen")
		SetButtonPulse(TalentMicroButton, 0, 1)
		TalentMicroButton:SetButtonState("PUSHED", 1)
		refresh()
	end)
	frame:SetScript("OnHide", function()
		PlaySound("TalentScreenClose")
		TalentMicroButton:SetButtonState("NORMAL")
	end)
end

StaticPopupDialogs.FROSTATOMUI_LEARN_PREVIEW_TALENTS = {
	text = CONFIRM_LEARN_PREVIEW_TALENTS,
	button1 = YES,
	button2 = NO,
	OnAccept = function()
		LearnPreviewTalents(view.pet)
	end,
	timeout = 0,
	exclusive = 1,
	hideOnEscape = 1,
	preferredIndex = 3,
}

StaticPopupDialogs.FROSTATOMUI_REMOVE_GLYPH = {
	text = CONFIRM_REMOVE_GLYPH,
	button1 = YES,
	button2 = NO,
	OnAccept = function(self)
		if glyphEditable() then
			RemoveGlyphFromSocket(self.data)
		end
	end,
	timeout = 0,
	hideOnEscape = 1,
	preferredIndex = 3,
}

StaticPopupDialogs.FROSTATOMUI_GLYPH_PLACEMENT = {
	text = CONFIRM_GLYPH_PLACEMENT,
	button1 = YES,
	button2 = NO,
	OnAccept = function(self)
		PlaceGlyphInSocket(self.data)
	end,
	timeout = 0,
	exclusive = 1,
	hideOnEscape = 1,
	preferredIndex = 3,
}

local function open()
	if UnitLevel("player") < SHOW_TALENT_LEVEL then
		return
	end
	if not frame then
		createFrame()
	end
	if frame:IsShown() then
		refresh()
	else
		view.pet, view.group = false, GetActiveTalentGroup(false, false)
		ShowUIPanel(frame)
	end
end

local function toggle()
	if frame and frame:IsShown() then
		HideUIPanel(frame)
	else
		open()
	end
end

local function setMicroButtonState()
	if frame and frame:IsShown() then
		TalentMicroButton:SetButtonState("PUSHED", 1)
	end
end

function TalentFrame:Initialize()
	ToggleTalentFrame = toggle
	ToggleGlyphFrame = toggle
	OpenGlyphFrame = open
	TalentMicroButton:SetScript("OnClick", toggle)
	hooksecurefunc("UpdateMicroButtons", setMicroButtonState)

	for _, event in ipairs({
		"PLAYER_TALENT_UPDATE",
		"PET_TALENT_UPDATE",
		"PREVIEW_TALENT_POINTS_CHANGED",
		"PREVIEW_PET_TALENT_POINTS_CHANGED",
		"ACTIVE_TALENT_GROUP_CHANGED",
		"CHARACTER_POINTS_CHANGED",
		"PLAYER_LEVEL_UP",
		"CURRENT_SPELL_CAST_CHANGED",
		"GLYPH_ADDED",
		"GLYPH_REMOVED",
		"GLYPH_UPDATED",
		"USE_GLYPH",
	}) do
		self:RegisterEvent(event, queueRefresh)
	end
	self:RegisterEvent("UNIT_PET", function(_, unit)
		if unit == "player" then
			queueRefresh()
		end
	end)
	self:RegisterEvent("UNIT_PORTRAIT_UPDATE", function(_, unit)
		if unit == "player" or unit == "pet" then
			queueRefresh()
		end
	end)
end
