local _, ns = ...

-- Shaman totem tracker: one icon per element with the remaining time.
-- Right click destroys the totem.

local CreateFrame = CreateFrame
local GetTotemInfo = GetTotemInfo

local Totems = ns:NewModule("Totems")
local CooldownTimer = ns:GetModule("CooldownTimer")

local MAX_TOTEMS = MAX_TOTEMS or 4
local ICON_SIZE = 30
local ICON_GAP = 2

-- Blizzard's slot order: fire, earth, water, air.
local SLOT_ORDER = { 1, 2, 3, 4 }

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
	for _, button in pairs(buttons) do
		updateButton(button)
	end
end

local function createButton(slot, parent, index)
	-- "destroytotem" is a secure action: it works in combat.
	local button = CreateFrame("Button", nil, parent, "SecureActionButtonTemplate")
	button:SetID(slot)
	button:SetSize(ICON_SIZE, ICON_SIZE)
	button:SetPoint("LEFT", (index - 1) * (ICON_SIZE + ICON_GAP), 0)
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
	return button
end

function Totems:Initialize()
	if ns.PLAYER_CLASS ~= "SHAMAN" then
		return
	end

	local holder = CreateFrame("Frame", nil, UIParent)
	holder:SetSize(MAX_TOTEMS * (ICON_SIZE + ICON_GAP) - ICON_GAP, ICON_SIZE)
	holder:SetPoint(unpack(ns.Config.totems))

	for index, slot in ipairs(SLOT_ORDER) do
		createButton(slot, holder, index)
	end

	self:RegisterEvent("PLAYER_TOTEM_UPDATE")
	self:RegisterEvent("PLAYER_ENTERING_WORLD", "UpdateAll")
end
