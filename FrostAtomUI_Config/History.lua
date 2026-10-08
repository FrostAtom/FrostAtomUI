local _, ns = ...

local ui = FrostAtomUI
local L = ui.L

local ceil = math.ceil

local P = ns.private
local EDGE = P.EDGE
local FOOTER_BUTTON_WIDTH = P.FOOTER_BUTTON_WIDTH
local FRAME_NAME = P.FRAME_NAME
local POPUP_STRATA = P.POPUP_STRATA
local addTooltipLine = P.addTooltipLine
local changes = P.changes
local createButton = P.createButton
local createWindow = P.createWindow
local font = P.font
local nextName = P.nextName
local pages = P.pages
local resetPlan = P.resetPlan
local setControlEnabled = P.setControlEnabled
local showTooltip = P.showTooltip

local history = {}

do
	local function labelIn(schema, path)
		for _, entry in ipairs(schema or {}) do
			if entry.path == path and type(entry.label) == "string" and entry.label ~= "" then
				return entry.label
			end
		end
	end

	local function findLabel(path)
		for _, page in ipairs(pages) do
			local label = labelIn(page.schema, path)
			if label then
				return label, page.name
			end
			for _, tab in ipairs(page.tabs or {}) do
				label = labelIn(tab.schema, path)
				if label then
					return label, tab.name or page.name
				end
			end
		end
	end

	local function settingLabel(path)
		return findLabel(path) or ui.Movers.GetLabel(path)
	end
	ns.SettingLabel = settingLabel

	local function stepLabel(path)
		local label, scope = findLabel(path)
		if label and scope then
			return ("%s › %s"):format(scope, label)
		end
		return label or ui.Movers.GetLabel(path)
	end

	local function valueText(value)
		if type(value) == "boolean" then
			return value and L["on"] or L["off"]
		elseif type(value) == "number" then
			return (("%.2f"):format(value):gsub("%.?0+$", ""))
		elseif type(value) == "string" and value ~= "" then
			return value
		end
	end

	function history.Describe(step)
		local text, path = ui.Undo.Describe(step)
		if text then
			return text
		elseif not path then
			return L["Several settings"]
		end
		local _, before, after = ui.Undo.ChangedValue(step)
		if before == nil then
			before = ui:GetFactoryConfig(path)
		end
		if after == nil then
			after = ui:GetFactoryConfig(path)
		end
		local label, from, to = stepLabel(path), valueText(before), valueText(after)
		if from and to then
			return L["%s: from %s to %s"]:format(label, from, to)
		end
		return label
	end

	function history.ShowTooltip(button)
		local step = ui.Undo.GetUndo()
		showTooltip(button, L["Undo"], step and history.Describe(step) or L["Nothing to undo"])
		local redo = ui.Undo.GetRedo()
		if redo then
			addTooltipLine(L["Redo: %s"]:format(history.Describe(redo)), GRAY_FONT_COLOR, true)
		end
		addTooltipLine(L["Ctrl+Z undoes, Ctrl+Y redoes when these keys are free."], GRAY_FONT_COLOR, true)
		GameTooltip:Show()
	end

	function history.Update()
		local button = P.frame and P.frame.undoButton
		if not button then
			return
		end
		setControlEnabled(button, ui.Undo.GetUndo() ~= nil)
		if GameTooltip:IsOwned(button) then
			history.ShowTooltip(button)
		end
	end
end

local confirmDefaults

do
	local UNDO_SECONDS = 10
	local DIALOG = { WIDTH = 500, PADDING = 20, TEXT_TOP = 42, GAP = 10 }
	local resetDialog
	local last = {}

	local function undoText(seconds)
		return L['"%s" was reset. You can undo it for %d s.']:format(last.page or "", seconds)
	end

	local function undoReset()
		if last.step and ui.Undo.GetUndo() == last.step then
			ui.Undo.Undo()
		end
		last.step = nil
	end

	StaticPopupDialogs["FROSTATOMUI_CONFIG_UNDO_RESET"] = {
		text = "%s",
		button1 = L["Undo"],
		button2 = OKAY,
		OnAccept = function()
			undoReset()
		end,
		OnUpdate = function(dialog)
			_G[dialog:GetName() .. "Text"]:SetText(undoText(ceil(dialog.timeleft)))
		end,
		OnHide = function(dialog)
			dialog:SetFrameStrata("DIALOG")
		end,
		timeout = UNDO_SECONDS,
		whileDead = 1,
		hideOnEscape = 1,
		preferredIndex = 3,
	}

	local function listSize(value)
		local count = 0
		if type(value) == "table" then
			for _ in pairs(value) do
				count = count + 1
			end
		end
		return count
	end

	local function performReset(page, positions)
		local plan = resetPlan(page)
		ui.API.SetUIState("lastReset", nil)
		ui.Undo.Snapshot("resetPage", page.name)
		ui.Undo.Begin(L['Reset "%s"']:format(page.name))
		for _, entry in ipairs(plan.custom) do
			entry.reset()
		end
		for _, path in ipairs(plan.settings) do
			ui:ResetConfig(path)
		end
		if positions then
			for _, path in ipairs(plan.positions) do
				ui.Movers.ResetPosition(path)
			end
		end
		ui.Undo.End()
		last.step = ui.Undo.Flush()
		last.page = page.name
		local popup = StaticPopup_Show("FROSTATOMUI_CONFIG_UNDO_RESET", undoText(UNDO_SECONDS))
		if popup then
			popup:SetFrameStrata(POPUP_STRATA)
		end
	end

	local function createResetDialog()
		local dialog = createWindow(FRAME_NAME .. "Reset", {
			width = DIALOG.WIDTH,
			height = 200,
			parent = P.frame,
			strata = POPUP_STRATA,
			noClose = true,
			movable = false,
		})
		dialog:SetPoint("TOP", P.frame, "TOP", 0, -120)

		local shade = dialog:CreateTexture(nil, "BACKGROUND")
		shade:SetTexture(0, 0, 0, 0.92)
		shade:SetPoint("TOPLEFT", 4, -4)
		shade:SetPoint("BOTTOMRIGHT", -4, 4)

		local text = dialog:CreateFontString(nil, "ARTWORK")
		text:SetFontObject(font("GameFontHighlight"))
		text:SetPoint("TOPLEFT", DIALOG.PADDING, -DIALOG.TEXT_TOP)
		text:SetWidth(DIALOG.WIDTH - DIALOG.PADDING * 2)
		text:SetJustifyH("LEFT")
		dialog.text = text

		local check = ui.CreateCheckButton(dialog, "", nextName())
		check.text:SetFontObject(font("GameFontHighlight"))
		dialog.check = check

		local note = dialog:CreateFontString(nil, "ARTWORK")
		note:SetFontObject(font("GameFontNormalSmall"))
		note:SetWidth(DIALOG.WIDTH - DIALOG.PADDING * 2)
		note:SetJustifyH("LEFT")
		dialog.note = note

		local cancel = createButton(dialog, CANCEL, FOOTER_BUTTON_WIDTH)
		cancel:SetPoint("BOTTOMRIGHT", -DIALOG.PADDING, EDGE)
		cancel:SetScript("OnClick", function()
			dialog:Hide()
		end)

		local accept = createButton(dialog, "", 120)
		accept:SetPoint("RIGHT", cancel, "LEFT", -4, 0)
		dialog.accept = accept

		resetDialog = dialog
	end

	local function showResetDialog(page)
		if not resetDialog then
			createResetDialog()
		end
		local dialog = resetDialog
		dialog:Show()
		local plan = resetPlan(page)
		local settings = #plan.settings + #plan.custom
		local positions = #plan.positions
		local count = changes.CountPage(page)

		dialog.heading:SetText(L['Reset "%s"?']:format(page.name))
		if settings == 0 then
			dialog.text:SetText(L["The settings of this page already have FrostAtom UI's starting values."])
		elseif count > 0 then
			dialog.text:SetText(
				L["Changed settings on this page: %d. They go back to FrostAtom UI's starting values."]:format(count)
			)
		else
			dialog.text:SetText(L["The settings of this page go back to FrostAtom UI's starting values."])
		end

		local check = dialog.check
		check:SetChecked(false)
		check:SetLabel(
			L['Also move frames of this page back to the "%s" layout: %d']:format(
				ui.Movers.GetBaseLayoutName(),
				positions
			)
		)
		check:ClearAllPoints()
		check:SetPoint("TOPLEFT", dialog.text, "BOTTOMLEFT", -4, -DIALOG.GAP)
		ui.SetShown(check, positions > 0)

		local kept = {}
		for _, entry in ipairs(plan.lists) do
			kept[#kept + 1] = ("%s (%d)"):format(entry.label, listSize(ui:GetConfig(entry.path)))
		end
		local note = L["A copy of the settings is saved first: the reset can be undone."]
		if #kept > 0 then
			note = L["Not touched: %s."]:format(table.concat(kept, ", ")) .. " " .. note
		end
		dialog.note:SetText(note)
		dialog.note:ClearAllPoints()
		if positions > 0 then
			dialog.note:SetPoint("TOPLEFT", check, "BOTTOMLEFT", 4, -DIALOG.GAP)
		else
			dialog.note:SetPoint("TOPLEFT", dialog.text, "BOTTOMLEFT", 0, -DIALOG.GAP)
		end

		local height = DIALOG.TEXT_TOP + dialog.text:GetStringHeight() + DIALOG.GAP + dialog.note:GetStringHeight()
		if positions > 0 then
			height = height + check:GetHeight() + DIALOG.GAP
		end
		dialog:SetHeight(height + DIALOG.GAP * 2 + 22 + EDGE)

		local accept = dialog.accept
		accept:SetText(L['Reset "%s"']:format(page.name))
		ui.FitButton(accept, 20, 120)
		local function updateAccept()
			setControlEnabled(accept, settings > 0 or (check:GetChecked() and positions > 0))
		end
		check:SetScript("OnClick", updateAccept)
		updateAccept()
		accept:SetScript("OnClick", function()
			dialog:Hide()
			performReset(page, check:GetChecked() and positions > 0)
		end)
	end

	function confirmDefaults()
		local page = P.currentPage
		if not page or page.noReset then
			return
		end
		PlaySound("igMainMenuOption")
		showResetDialog(page)
	end
end

P.confirmDefaults = confirmDefaults
P.history = history
