local _, ns = ...
local L = ns.L

local InCombatLockdown = InCombatLockdown
local GetMouseFocus = GetMouseFocus
local GetBindingKey = GetBindingKey
local SetBinding = SetBinding
local SetBindingClick = SetBindingClick
local SaveBindings = SaveBindings
local LoadBindings = LoadBindings
local GetCurrentBindingSet = GetCurrentBindingSet
local IsAltKeyDown = IsAltKeyDown
local IsControlKeyDown = IsControlKeyDown
local IsShiftKeyDown = IsShiftKeyDown
local StaticPopup_Show = StaticPopup_Show
local StaticPopup_Hide = StaticPopup_Hide

local POPUP = "FROSTATOMUI_KEYBIND_MODE"

local IGNORED_KEYS = {
	LSHIFT = true,
	RSHIFT = true,
	LCTRL = true,
	RCTRL = true,
	LALT = true,
	RALT = true,
	UNKNOWN = true,
	LeftButton = true,
	RightButton = true,
}

local binder

local function isBindable(frame)
	return frame and frame:IsObjectType("Button") and frame:GetAttribute("type") and frame:GetName()
end

local function onUpdate(self)
	local focus = GetMouseFocus()
	if focus == self or focus == self.target then
		return
	end

	if isBindable(focus) then
		self:SetAllPoints(focus)
		self:SetAlpha(1)
		self.target = focus
	else
		self:SetAlpha(0)
		self.target = nil
	end
end

local function normalizeKey(key)
	if key == "MiddleButton" then
		return "BUTTON3"
	elseif key:find("^Button%d+$") then
		return key:upper()
	end
	return key
end

local function onKey(self, key)
	local target = self.target
	if not target or IGNORED_KEYS[key] then
		return
	end

	local targetName = target:GetName()
	if key == "ESCAPE" then
		local bound = GetBindingKey(("CLICK %s:LeftButton"):format(targetName))
		if bound then
			SetBinding(bound, nil)
		end
		return
	end

	local combo = normalizeKey(key)
	if IsShiftKeyDown() then
		combo = "SHIFT-" .. combo
	end
	if IsControlKeyDown() then
		combo = "CTRL-" .. combo
	end
	if IsAltKeyDown() then
		combo = "ALT-" .. combo
	end

	SetBindingClick(combo, targetName)
end

local function onMouseWheel(self, delta)
	onKey(self, delta > 0 and "MOUSEWHEELUP" or "MOUSEWHEELDOWN")
end

local function closeBinder()
	binder:Hide()
	binder:ClearAllPoints()
end

local function createBinder()
	binder = CreateFrame("Frame")
	binder:Hide()
	binder:SetFrameStrata("DIALOG")
	binder:EnableMouse(true)
	binder:EnableMouseWheel(true)
	binder:EnableKeyboard(true)
	binder:SetScript("OnUpdate", onUpdate)
	binder:SetScript("OnKeyUp", onKey)
	binder:SetScript("OnMouseUp", onKey)
	binder:SetScript("OnMouseWheel", onMouseWheel)

	local highlight = binder:CreateTexture()
	highlight:SetAllPoints()
	highlight:SetTexture(0, 1, 0, 0.4)

	StaticPopupDialogs[POPUP] = {
		text = L["Hover your mouse over any action button and press a key to bind it."]
			.. " "
			.. L["Press Escape to clear the hovered button's binding."],
		button1 = L["Save bindings"],
		button2 = L["Discard bindings"],
		OnAccept = function()
			SaveBindings(GetCurrentBindingSet())
			closeBinder()
		end,
		OnCancel = function()
			LoadBindings(GetCurrentBindingSet())
			closeBinder()
		end,
		timeout = 0,
		whileDead = 1,
		hideOnEscape = false,
	}
end

SlashCmdList.FROSTATOMUI_BIND = function()
	if not binder then
		createBinder()
	end

	if binder:IsShown() then
		binder:Hide()
		StaticPopup_Hide(POPUP)
	elseif InCombatLockdown() then
		ns.Print(L["cannot change bindings in combat"])
	else
		binder:Show()
		StaticPopup_Show(POPUP)
	end
end
SLASH_FROSTATOMUI_BIND1 = "/b"
SLASH_FROSTATOMUI_BIND2 = "/bind"

local combatWatcher = CreateFrame("Frame")
combatWatcher:RegisterEvent("PLAYER_REGEN_DISABLED")
combatWatcher:SetScript("OnEvent", function()
	if binder and binder:IsShown() then
		StaticPopupDialogs[POPUP].OnCancel()
		StaticPopup_Hide(POPUP)
		ns.Print(L["keybinding mode closed: entering combat, changes discarded"])
	end
end)
