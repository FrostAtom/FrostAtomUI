local _, ns = ...
local L = ns.L

local InCombatLockdown, GetMacroInfo = InCombatLockdown, GetMacroInfo
local GetBindingKey, GetBindingText = GetBindingKey, GetBindingText

local Macros = ns:GetModule("Macros")

local SecureList = {}
Macros.SecureList = SecureList

local TOGGLE_NAME = "FrostAtomUIMacrosToggle"
SecureList.TOGGLE_COMMAND = "CLICK " .. TOGGLE_NAME .. ":LeftButton"

local SETUP_SNIPPET = [[
	WINDOW = self
	CELLS = newtable()
	for i = 1, %d do
		CELLS[i] = self:GetFrameRef("cell" .. i)
	end
	TAB = "account"
	OFFSET = 0
	MAX_OFFSET = 0
]]

local RENDER_SNIPPET = [[
	local count = self:GetAttribute("count-" .. TAB) or 0
	local minimum = self:GetAttribute("min-" .. TAB)
	local slots
	if minimum then
		slots = max(count, minimum)
	else
		slots = max(%d, ceil(count / %d)) * %d
	end
	MAX_OFFSET = max(0, ceil(slots / %d) - %d)
	OFFSET = max(0, min(OFFSET, MAX_OFFSET))
	for i = 1, %d do
		local cell, index = CELLS[i], OFFSET * %d + i
		if index <= count then
			cell:Enable()
			cell:Show()
		elseif index <= slots then
			cell:Disable()
			cell:Show()
		else
			cell:Hide()
		end
	end
	control:CallMethod("OnSecureView", TAB, OFFSET)
]]

local VIEW_SNIPPET = [[
	TAB = %q
	OFFSET = %d
	control:RunAttribute("render")
]]

local TAB_SNIPPET = [[
	if TAB ~= %q then
		TAB = %q
		OFFSET = 0
		control:RunAttribute("render")
	end
]]

local WHEEL_SNIPPET = [[
	local value = max(0, min(MAX_OFFSET, OFFSET - offset))
	if value ~= OFFSET then
		OFFSET = value
		control:RunAttribute("render")
	end
	return false
]]

local DRAG_SNIPPET = [[
	if not PlayerInCombat() then
		return
	end
	local index = OFFSET * %d + self:GetID()
	if index > (WINDOW:GetAttribute("count-" .. TAB) or 0) then
		return false
	end
	local macro = WINDOW:GetAttribute("stub-" .. TAB .. "-" .. index)
	if macro then
		return "macro", macro
	end
]]

local TOGGLE_SNIPPET = [[
	local window = self:GetFrameRef("window")
	if window:IsShown() then
		window:Hide()
	else
		window:Show()
	end
]]

local window, exitButton
local gameIndices = {}
local GAME_LIMITS = { gameAccount = Macros.MAX_ACCOUNT, gameChar = Macros.MAX_CHARACTER }

local function setData(name, value)
	if window:GetAttribute(name) ~= value then
		window:SetAttribute(name, value)
	end
end

function SecureList.Setup(frame, onView)
	window = frame
	frame.OnSecureView = onView

	local toggle = CreateFrame("Button", TOGGLE_NAME, UIParent, "SecureHandlerClickTemplate")
	toggle:SetFrameRef("window", frame)
	toggle:SetAttribute("_onclick", TOGGLE_SNIPPET)
end

function SecureList.AttachMenuButton(button)
	local click = CreateFrame("Button", window:GetName() .. "MenuButton", button, "SecureActionButtonTemplate")
	click:SetAllPoints()
	click:SetAttribute("type", "click")
	click:SetAttribute("clickbutton", button)
	click:SetScript("OnEnter", function()
		button:LockHighlight()
	end)
	click:SetScript("OnLeave", function()
		button:UnlockHighlight()
	end)
	click:SetScript("OnMouseDown", function()
		button:SetButtonState("PUSHED")
	end)
	click:SetScript("OnMouseUp", function()
		button:SetButtonState("NORMAL")
	end)
	window:WrapScript(click, "OnClick", [[WINDOW:Show()]])
end

function SecureList.AddCells(cells, columns, rows)
	for i = 1, #cells do
		local cell = cells[i]
		cell:SetID(i)
		window:WrapScript(cell, "OnDragStart", DRAG_SNIPPET:format(columns))
		window:WrapScript(cell, "OnMouseWheel", WHEEL_SNIPPET)
		window:SetFrameRef("cell" .. i, cell)
	end
	window:SetAttribute("render", RENDER_SNIPPET:format(rows, columns, columns, columns, rows, #cells, columns))
	window:Execute(SETUP_SNIPPET:format(#cells))
end

function SecureList.CreateTabOverlay(button, key)
	local overlay = CreateFrame("Button", nil, window, "SecureFrameTemplate")
	overlay:SetFrameLevel(button:GetFrameLevel() + 2)
	overlay:RegisterForClicks("LeftButtonUp")
	overlay:SetScript("OnEnter", function()
		if button:IsEnabled() == 1 then
			button:LockHighlight()
		end
	end)
	overlay:SetScript("OnLeave", function()
		button:UnlockHighlight()
	end)
	window:WrapScript(overlay, "OnClick", TAB_SNIPPET:format(key, key))
	return overlay
end

function SecureList.PlaceTabOverlays(tabs, overlays)
	local _, _, _, x, y = tabs[1]:GetPoint()
	for i = 1, #tabs do
		local button = tabs[i]
		if i > 1 then
			x = x + select(4, button:GetPoint())
		end
		local overlay = overlays[i]
		overlay:ClearAllPoints()
		overlay:SetPoint("TOPLEFT", window, "TOPLEFT", x, y)
		overlay:SetSize(button:GetWidth(), button:GetHeight())
		x = x + button:GetWidth()
	end
end

function SecureList.CreateExitButton(name, text, width, height)
	exitButton = CreateFrame("Button", name, window, "UIPanelButtonTemplate,SecureHandlerClickTemplate")
	exitButton:SetSize(width, height)
	exitButton:SetText(text)
	exitButton:SetFrameRef("window", window)
	exitButton:SetAttribute("_onclick", [[self:GetFrameRef("window"):Hide()]])

	local escape = CreateFrame("Frame", nil, window, "SecureHandlerShowHideTemplate")
	escape:SetAttribute(
		"_onshow",
		([[if PlayerInCombat() then self:SetBindingClick(true, "ESCAPE", "%s") end]]):format(name)
	)
	escape:SetAttribute("_onhide", [[self:ClearBindings()]])
	exitButton.escape = escape
	return exitButton
end

function SecureList.Push(tab, offset)
	if window.syncing or InCombatLockdown() then
		return
	end
	for key, limit in pairs(GAME_LIMITS) do
		wipe(gameIndices)
		local indices, hidden = Macros.GameIndices(key, gameIndices)
		setData("count-" .. key, #indices)
		setData("min-" .. key, limit - hidden)
		for i = 1, #indices do
			setData(("stub-%s-%d"):format(key, i), indices[i])
		end
	end
	setData("count-account", #Macros.GetList("account"))
	setData("count-char", #Macros.GetList("char"))
	window:Execute(VIEW_SNIPPET:format(tab, offset))
end

function SecureList.CombatBlocked()
	if not InCombatLockdown() then
		return false
	end
	local key = GetBindingKey(SecureList.TOGGLE_COMMAND)
	if key then
		ns.Print(L["in combat the macro window opens and closes only with its key (%s)"], GetBindingText(key, "KEY_"))
	else
		ns.Print(
			L["in combat the macro window opens and closes only with its key; set one in Key Bindings - FrostAtomUI"]
		)
	end
	return true
end

local function enableScrolling(enabled)
	local scrollBar = window.listScrollBar
	window.listScroll:EnableMouseWheel(enabled)
	scrollBar:EnableMouse(enabled)
	_G[scrollBar:GetName() .. "ScrollUpButton"]:EnableMouse(enabled)
	_G[scrollBar:GetName() .. "ScrollDownButton"]:EnableMouse(enabled)
end

function SecureList.EnterCombat()
	enableScrolling(false)
	if InCombatLockdown() then
		return
	end
	local stubs = {}
	for index = 1, Macros.MAX_ACCOUNT + Macros.MAX_CHARACTER do
		local id = Macros.StubOf(select(3, GetMacroInfo(index)))
		if id and not stubs[id] then
			stubs[id] = index
		end
	end
	for _, key in ipairs({ "account", "char" }) do
		local list = Macros.GetList(key)
		for i = 1, #list do
			setData(("stub-%s-%d"):format(key, i), stubs[list[i].id])
		end
	end
	if window:IsShown() then
		SetOverrideBindingClick(exitButton.escape, true, "ESCAPE", exitButton:GetName())
	end
end

function SecureList.LeaveCombat()
	enableScrolling(true)
	if not InCombatLockdown() then
		ClearOverrideBindings(exitButton.escape)
	end
end
