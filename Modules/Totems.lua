local _, ns = ...

local CreateFrame = CreateFrame
local GetTotemInfo = GetTotemInfo

local Totems = ns:NewModule("Totems")
local CooldownTimer = ns:GetModule("CooldownTimer")

local MAX_TOTEMS = MAX_TOTEMS or 4
local ICON_SIZE = 30
local ICON_GAP = 2

local buttons = {}

local function updateButton(button)
	local haveTotem, _, startTime, duration, icon = GetTotemInfo(button:GetID())
	if haveTotem and duration > 0 then
		button.icon:SetTexture(icon)
		button.cooldown:SetCooldown(startTime, duration)
		button:SetAlpha(1)
	else
		button.cooldown:SetCooldown(0, 0)
		button:SetAlpha(0)
	end
end

function Totems:PLAYER_TOTEM_UPDATE(slot)
	local button = buttons[slot]
	if button then
		updateButton(button)
	end
end

function Totems:UpdateAll()
	for i = 1, #buttons do
		updateButton(buttons[i])
	end
end

local function createButton(slot, parent)
	local button = CreateFrame("Button", nil, parent, "SecureActionButtonTemplate")
	button:SetID(slot)
	button:SetSize(ICON_SIZE, ICON_SIZE)
	button:SetPoint("LEFT", (slot - 1) * (ICON_SIZE + ICON_GAP), 0)
	button:SetAlpha(0)
	button:RegisterForClicks("RightButtonUp")
	button:SetAttribute("type", "destroytotem")
	button:SetAttribute("totem-slot", slot)

	button.icon = button:CreateTexture(nil, "BORDER")
	button.icon:SetAllPoints()
	button.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)

	button.cooldown = CreateFrame("Cooldown", nil, button)
	button.cooldown:SetAllPoints()
	button.cooldown:SetReverse(true)
	CooldownTimer:Attach(button.cooldown, 11)

	buttons[slot] = button
end

function Totems:Initialize()
	if ns.PLAYER_CLASS ~= "SHAMAN" then
		return
	end

	local holder = CreateFrame("Frame", nil, UIParent)
	holder:SetSize(MAX_TOTEMS * (ICON_SIZE + ICON_GAP) - ICON_GAP, ICON_SIZE)
	holder:SetPoint(unpack(ns.Config.totems))

	for slot = 1, MAX_TOTEMS do
		createButton(slot, holder)
	end

	self:RegisterEvent("PLAYER_TOTEM_UPDATE")
	self:RegisterEvent("PLAYER_ENTERING_WORLD", "UpdateAll")
end
