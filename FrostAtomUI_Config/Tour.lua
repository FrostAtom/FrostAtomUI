local _, ns = ...

local ui = FrostAtomUI
local L = ui.L

local CALLOUT_WIDTH = 300
local CALLOUT_GAP = 10
local HIGHLIGHT_OUTSET = 4
local PADDING = 12
local TIPS_WIDTH = 380
local GOLD = { 1, 0.82, 0 }
local BACKDROP = {
	bgFile = "Interface\\Buttons\\WHITE8x8",
	edgeFile = "Interface\\Buttons\\WHITE8x8",
	edgeSize = 1,
}

local TOUR = {
	{
		target = "unitFrames.player",
		text = L["Drag a frame. It snaps to edges and neighbours and stays attached to them. Hold Shift to drop snapping."],
	},
	{
		target = "unitFrames.player",
		text = L["Click for this frame's settings: size, texts, buffs and debuffs. Right-click for more: move back, detach."],
	},
	{ target = "undo", text = L["Moved the wrong thing? This button (or Ctrl+Z) undoes it."] },
	{ target = "done", text = L["Done locks the frames. Entering combat locks them too."] },
}

local callout, highlight, tourStep

local function panelFrame(name, width)
	local frame = CreateFrame("Frame", name, UIParent)
	frame:SetWidth(width)
	frame:SetFrameStrata("FULLSCREEN_DIALOG")
	frame:SetToplevel(true)
	frame:EnableMouse(true)
	frame:SetBackdrop(BACKDROP)
	frame:SetBackdropColor(0.05, 0.05, 0.05, 0.95)
	frame:SetBackdropBorderColor(GOLD[1], GOLD[2], GOLD[3])
	frame:Hide()
	local title = frame:CreateFontString(nil, "ARTWORK")
	title:SetFontObject(ns.Font("GameFontNormal"))
	title:SetPoint("TOPLEFT", PADDING, -PADDING)
	frame.title = title
	local body = frame:CreateFontString(nil, "ARTWORK")
	body:SetFontObject(ns.Font("GameFontHighlight"))
	body:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -6)
	body:SetWidth(width - PADDING * 2)
	body:SetJustifyH("LEFT")
	frame.body = body
	local close = ui.CreateGlyphButton(frame, "xmark", 12, CLOSE)
	close:SetPoint("TOPRIGHT", -4, -4)
	frame.close = close
	local nextButton = ns.CreateButton(frame, L["Next"], 90, nil, nil, "arrow-right", true)
	nextButton:SetPoint("BOTTOMRIGHT", -PADDING + 2, PADDING - 4)
	frame.next = nextButton
	return frame
end

local function setNext(frame, last)
	frame.next:SetText(last and L["Done"] or L["Next"])
	ui.SetGlyph(frame.next.glyph, last and "check" or "arrow-right")
end

local function fitHeight(frame)
	frame:Show()
	frame:SetHeight(PADDING * 2 + 20 + frame.body:GetStringHeight() + 34)
end

local function endTour()
	tourStep = nil
	if callout then
		callout:Hide()
		highlight:Hide()
	end
end

local function showStep()
	local step = TOUR[tourStep]
	local target = step and ui.Movers.GetTourTarget(step.target)
	if not target or not ui.Movers.IsUnlocked() then
		endTour()
		return
	end
	callout.title:SetText(L["Moving frames: %d of %d"]:format(tourStep, #TOUR))
	callout.body:SetText(step.text)
	setNext(callout, tourStep == #TOUR)
	fitHeight(callout)
	highlight:ClearAllPoints()
	highlight:SetPoint("TOPLEFT", target, "TOPLEFT", -HIGHLIGHT_OUTSET, HIGHLIGHT_OUTSET)
	highlight:SetPoint("BOTTOMRIGHT", target, "BOTTOMRIGHT", HIGHLIGHT_OUTSET, -HIGHLIGHT_OUTSET)
	highlight:Show()
	callout:ClearAllPoints()
	local _, centerY = target:GetCenter()
	local scale = target:GetEffectiveScale() / UIParent:GetEffectiveScale()
	if centerY and centerY * scale > UIParent:GetHeight() / 2 then
		callout:SetPoint("TOP", highlight, "BOTTOM", 0, -CALLOUT_GAP)
	else
		callout:SetPoint("BOTTOM", highlight, "TOP", 0, CALLOUT_GAP)
	end
	callout:Show()
end

local function createCallout()
	callout = panelFrame("FrostAtomUITour", CALLOUT_WIDTH)
	callout.close:SetScript("OnClick", endTour)
	callout.next:SetScript("OnClick", function()
		tourStep = tourStep + 1
		if tourStep > #TOUR then
			endTour()
			ui.Movers.Lock()
		else
			showStep()
		end
	end)
	callout:SetScript("OnUpdate", function()
		if not ui.Movers.IsUnlocked() then
			endTour()
		end
	end)
	highlight = CreateFrame("Frame", nil, UIParent)
	highlight:SetFrameStrata("FULLSCREEN_DIALOG")
	highlight:SetBackdrop({ edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 2 })
	highlight:SetBackdropBorderColor(GOLD[1], GOLD[2], GOLD[3])
	highlight:Hide()
end

function ns.StartTour()
	if InCombatLockdown() then
		return
	end
	ns.HideWindow()
	if not callout then
		createCallout()
	end
	if not ui.Movers.IsUnlocked() then
		ui.Movers.Unlock()
	end
	tourStep = 1
	showStep()
end

local tips, tipIndex

local function tipTexts()
	local modifier = ui:GetConfig("actionBar.dragModifier")
	local button = ui.SetupPresets.ValueText("actionBar.dragButton", ui:GetConfig("actionBar.dragButton"))
	local key = modifier ~= "none"
			and ("%s + %s"):format(ui.SetupPresets.ValueText("actionBar.dragModifier", modifier), button)
		or button
	return {
		L["To move a spell, drag it while holding %s."]:format(key),
		L["To find trainers, bankers or ore, right-click the minimap."],
		L['Settings and help: Esc > "FrostAtom UI".'],
	}
end

local function showTip()
	local texts = tipTexts()
	tips.title:SetText(L["Tip %d of %d"]:format(tipIndex, #texts))
	tips.body:SetText(texts[tipIndex])
	setNext(tips, tipIndex == #texts)
	fitHeight(tips)
	tips:Show()
end

function ns.ShowTips()
	if not tips then
		tips = panelFrame("FrostAtomUITips", TIPS_WIDTH)
		tips:SetPoint("TOP", 0, -140)
		tips:SetMovable(true)
		tips:RegisterForDrag("LeftButton")
		tips:SetScript("OnDragStart", tips.StartMoving)
		tips:SetScript("OnDragStop", tips.StopMovingOrSizing)
		tips.close:SetScript("OnClick", function()
			tips:Hide()
		end)
		tips.next:SetScript("OnClick", function()
			tipIndex = tipIndex + 1
			if tipIndex > 3 then
				tips:Hide()
			else
				showTip()
			end
		end)
	end
	tipIndex = 1
	showTip()
end
