local _, ns = ...

local L = ns.L
local tconcat = table.concat

local Macros = ns:GetModule("Macros")
local P = {}
Macros.windowShared = P

local exportItem, scopeItems = Macros.ExportItem, Macros.ScopeItems

local function transferSummary(items)
	local counts = {}
	for i = 1, #items do
		local scope = items[i].scope
		counts[scope] = (counts[scope] or 0) + 1
	end
	local parts = {}
	for i = 1, #P.TABS do
		local count = counts[P.TABS[i].key]
		if count then
			parts[#parts + 1] = ("%s: %d"):format(L[P.TABS[i].label], count)
		end
	end
	return L["Macros: %d"]:format(#items) .. " - " .. tconcat(parts, ", ")
end

local transfer

local function createTransfer()
	transfer = ns.CreateWindow(
		P.FRAME_NAME .. "Transfer",
		{ width = 520, height = 340, header = true, strata = "DIALOG", movable = false }
	)
	transfer:SetPoint("CENTER")

	local holder = CreateFrame("Frame", nil, transfer)
	holder:SetPoint("TOPLEFT", 16, -30)
	holder:SetPoint("BOTTOMRIGHT", -16, 16 + P.BUTTON_HEIGHT + 24)
	holder:SetBackdrop(P.TOOLTIP_BACKDROP)
	P.applyTooltipColors(holder)

	local scroll = CreateFrame("ScrollFrame", P.FRAME_NAME .. "TransferScroll", holder, "UIPanelScrollFrameTemplate")
	scroll:SetPoint("TOPLEFT", 9, -6)
	scroll:SetPoint("BOTTOMRIGHT", -30, 6)
	ns.SkinSlimScrollBar(_G[scroll:GetName() .. "ScrollBar"])

	local box = CreateFrame("EditBox", nil, scroll)
	box:SetMultiLine(true)
	box:SetAutoFocus(false)
	box:SetMaxLetters(0)
	box:SetMaxBytes(0)
	box:SetWidth(520 - 32 - 39)
	box:SetFontObject(GameFontHighlightSmall)
	box:SetTextInsets(2, 2, 2, 2)
	box:SetScript("OnEscapePressed", box.ClearFocus)
	box:SetScript("OnTextChanged", function(self)
		scroll:UpdateScrollChildRect()
		if transfer.importing then
			local items, err = Macros.DecodeExport(self:GetText())
			transfer.items = items
			local color
			if items then
				transfer.summary:SetText(transferSummary(items))
				color = GREEN_FONT_COLOR
			else
				transfer.summary:SetText(strtrim(self:GetText()) == "" and "" or err)
				color = RED_FONT_COLOR
			end
			transfer.summary:SetTextColor(color.r, color.g, color.b)
			ns.SetShown(transfer.action, items ~= nil)
		end
	end)
	scroll:SetScrollChild(box)
	holder:EnableMouse(true)
	holder:SetScript("OnMouseDown", function()
		box:SetFocus()
	end)
	transfer.box = box

	local summary = transfer:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	summary:SetPoint("TOPLEFT", holder, "BOTTOMLEFT", 6, -6)
	summary:SetPoint("RIGHT", holder, -6, 0)
	summary:SetJustifyH("LEFT")
	transfer.summary = summary

	local close = ns.CreateButton(transfer, CLOSE, 90, P.BUTTON_HEIGHT, P.FRAME_NAME .. "TransferClose")
	close:SetPoint("BOTTOMRIGHT", -16, 16)
	close:SetScript("OnClick", function()
		transfer:Hide()
	end)

	local action = ns.CreateButton(transfer, L["Import"], 90, P.BUTTON_HEIGHT, P.FRAME_NAME .. "TransferImport")
	action:SetPoint("RIGHT", close, "LEFT", -2, 0)
	transfer.action = action
end

local function showExport(heading, items)
	if #items == 0 then
		ns.Print(L["nothing to export"])
		return
	end
	if not transfer then
		createTransfer()
	end
	transfer.importing = false
	transfer.title:SetText(heading)
	transfer.action:Hide()
	transfer.summary:SetText(transferSummary(items))
	transfer.summary:SetTextColor(1, 1, 1)
	transfer.box:SetText(Macros.Export(items))
	transfer:Show()
	transfer.box:SetFocus()
	transfer.box:HighlightText()
end

local function importItems()
	local items = transfer.items
	if not items then
		return
	end
	local count, converted, scope, entry = Macros.Import(items)
	transfer:Hide()
	ns.Print(L["Macros imported: %d"], count)
	if converted > 0 then
		ns.Print(
			L["%d game macros did not fit (no free slot, longer than 255 characters or in combat) and became unlimited ones"],
			converted
		)
	end
	if scope and not InCombatLockdown() then
		P.selectTab(scope)
		P.selectEntry(entry)
	end
end

local function showImport()
	if not transfer then
		createTransfer()
	end
	transfer.importing = true
	transfer.items = nil
	transfer.title:SetText(L["Import macros"])
	transfer.action:SetScript("OnClick", importItems)
	transfer.box:SetText("")
	transfer:Show()
	transfer.box:SetFocus()
end

local function exportSelected()
	local entry = P.selected()
	if not entry then
		return
	end
	local target = P.stubTarget(entry)
	local item = target and exportItem(Macros.ScopeOf(target), target) or exportItem(P.currentTab(), entry)
	showExport(L["Export macro: %s"]:format((P.displayName(target or entry))), { item })
end

local function exportTab()
	for i = 1, #P.TABS do
		if P.TABS[i].key == P.currentTab() then
			showExport(L["Export: %s"]:format(L[P.TABS[i].label]), scopeItems(P.currentTab(), {}))
		end
	end
end

local function exportAll()
	local items = {}
	for i = 1, #P.TABS do
		scopeItems(P.TABS[i].key, items)
	end
	showExport(L["Export all macros"], items)
end

local EXPORT_CHOICES = {
	{ label = "Selected macro", func = exportSelected },
	{ label = "This tab", func = exportTab },
	{ label = "All macros", func = exportAll },
}

P.showImport = showImport
P.hideTransfer = function()
	if transfer then
		transfer:Hide()
	end
end
P.exportSelected = exportSelected
P.EXPORT_CHOICES = EXPORT_CHOICES
