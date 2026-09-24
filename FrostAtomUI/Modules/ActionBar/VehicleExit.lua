local ADDON_NAME, ns = ...

local CanExitVehicle = CanExitVehicle
local GetPossessInfo = GetPossessInfo
local InCombatLockdown = InCombatLockdown
local IsPossessBarVisible = IsPossessBarVisible
local RegisterStateDriver = RegisterStateDriver
local UnitExists = UnitExists
local UnitHasVehicleUI = UnitHasVehicleUI
local GameTooltip = GameTooltip

local ActionBar = ns:GetModule("ActionBar")

local config = ns.Config.actionBar
local BUTTON_NAME = ADDON_NAME .. "VehicleExitButton"
local EXIT_TEXTURE = "Interface\\Vehicles\\UI-Vehicles-Button-Exit-Up"
local EXIT_TEXCOORD = 0.140625
local POSSESS_CANCEL_SLOT = 2
local EXIT_MACRO = "/leavevehicle\n/stopcasting [bonusbar:5]"
local CANCEL_AURA_LINE = "\n/cancelaura [bonusbar:5] %s"
local VISIBILITY_CONDITION = "[target=vehicle,exists][bonusbar:5] show; hide"

local VISIBILITY_SNIPPET = [[
	if newstate == "show" then
		self:Show()
	else
		self:Hide()
	end
]]

local button

local function isPossessing()
	return IsPossessBarVisible() and true or false
end

local function setTooltip()
	if UnitExists("vehicle") or CanExitVehicle() then
		GameTooltip:SetText(LEAVE_VEHICLE)
	else
		GameTooltip:SetText(CANCEL)
	end
end

local function updateMacro()
	if InCombatLockdown() then
		return
	end
	local _, name = GetPossessInfo(POSSESS_CANCEL_SLOT)
	local macro = name and EXIT_MACRO .. CANCEL_AURA_LINE:format(name) or EXIT_MACRO
	if button:GetAttribute("macrotext") ~= macro then
		button:SetAttribute("macrotext", macro)
	end
end

local function hideAfterCombat()
	ActionBar:UnregisterEvent("PLAYER_REGEN_ENABLED", hideAfterCombat)
	if not UnitExists("vehicle") and not CanExitVehicle() and not isPossessing() then
		button:Hide()
	end
	button:SetAlpha(1)
end

local function onVehicleChanged(_, unit)
	if unit ~= "player" then
		return
	end
	if CanExitVehicle() or UnitHasVehicleUI("player") or isPossessing() then
		if not InCombatLockdown() then
			button:Show()
		end
		button:SetAlpha(1)
	elseif InCombatLockdown() then
		button:SetAlpha(0)
		ActionBar:RegisterEvent("PLAYER_REGEN_ENABLED", hideAfterCombat)
	elseif not UnitExists("vehicle") then
		button:Hide()
	end
end

function ActionBar:LayoutVehicleExit()
	if not button then
		return
	end
	local size = config.vehicleExit.buttonSize
	button:SetSize(size, size)
	ns.ApplyPoint(button, "actionBar.vehicleExit.point")
end

function ActionBar:InitializeVehicleExit()
	button = CreateFrame("Button", BUTTON_NAME, UIParent, "SecureActionButtonTemplate, SecureHandlerStateTemplate")
	button:Hide()
	button:SetAttribute("type", "macro")
	button:SetAttribute("macrotext", EXIT_MACRO)
	button.bindingName = "CLICK " .. BUTTON_NAME .. ":LeftButton"

	self:StyleButton(button)
	button.icon = button:CreateTexture(nil, "BORDER")
	button.icon:SetAllPoints()
	button.icon:SetTexture(EXIT_TEXTURE)
	button.icon:SetTexCoord(EXIT_TEXCOORD, 1 - EXIT_TEXCOORD, EXIT_TEXCOORD, 1 - EXIT_TEXCOORD)

	button:RegisterForClicks("AnyUp")
	button:HookScript("OnShow", function(self)
		self:SetAlpha(1)
	end)
	self:AttachTooltip(button, setTooltip)

	button:SetAttribute("_onstate-exit", VISIBILITY_SNIPPET)
	RegisterStateDriver(button, "exit", VISIBILITY_CONDITION)

	self:RegisterEvent("UNIT_ENTERED_VEHICLE", onVehicleChanged)
	self:RegisterEvent("UNIT_EXITED_VEHICLE", onVehicleChanged)
	self:RegisterEvent("UPDATE_BONUS_ACTIONBAR", updateMacro)
	self:RegisterEvent("PLAYER_ENTERING_WORLD", updateMacro)

	self:LayoutVehicleExit()
	self:RegisterMover(button, "actionBar.vehicleExit.point", "Vehicle exit", { secure = true })

	if not InCombatLockdown() and (CanExitVehicle() or UnitHasVehicleUI("player")) then
		button:Show()
	end
end
