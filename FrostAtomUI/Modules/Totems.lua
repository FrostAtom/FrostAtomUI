local _, ns = ...

local GetTotemInfo = GetTotemInfo
local DestroyTotem = DestroyTotem

local Totems = ns:NewModule("Totems")
local CooldownTimer = ns:GetModule("CooldownTimer")

local MAX_TOTEMS = MAX_TOTEMS or 4
local SLOT_ORDER = TOTEM_PRIORITIES or { 2, 1, 3, 4 }

local buttons = {}
local holder

local function updateButton(button)
	local haveTotem, _, startTime, duration, icon = GetTotemInfo(button:GetID())
	local active = haveTotem and duration > 0
	if active then
		button.icon:SetTexture(icon)
		button.cooldown:SetCooldown(startTime, duration)
		button:SetAlpha(1)
	else
		button.cooldown:SetCooldown(0, 0)
		button:SetAlpha(0)
	end
	button:EnableMouse(active and not ns.Config.totems.clickThrough)
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

local function onClick(self)
	DestroyTotem(self:GetID())
end

local function createButton(slot, parent)
	local button = CreateFrame("Button", nil, parent)
	button:SetID(slot)
	button:SetAlpha(0)
	button:RegisterForClicks("RightButtonUp")
	button:SetScript("OnClick", onClick)

	button.icon = button:CreateTexture(nil, "BACKGROUND")
	button.icon:SetAllPoints()

	button.border = button:CreateTexture(nil, "ARTWORK")
	button.border:SetTexture(ns.Media.buttonNormal)
	button.border:SetAllPoints()

	button.cooldown = CreateFrame("Cooldown", nil, button)
	button.cooldown:SetAllPoints()
	button.cooldown:SetReverse(true)
	button.cooldown:SetDrawEdge(true)
	button.cooldown:SetFrameLevel(button:GetFrameLevel())

	local text = CreateFrame("Frame", nil, button)
	text:SetAllPoints()
	text:SetFrameLevel(button:GetFrameLevel() + 1)
	CooldownTimer:Attach(button.cooldown, nil, text)

	buttons[slot] = button
end

local function applyConfig()
	local config = ns.Config.totems
	local size, gap, font = config.size, config.gap, config.timerFont
	holder:SetSize(MAX_TOTEMS * (size + gap) - gap, size)
	for index, slot in ipairs(SLOT_ORDER) do
		local button = buttons[slot]
		button:SetSize(size, size)
		button:ClearAllPoints()
		button:SetPoint("LEFT", (index - 1) * (size + gap), 0)
		ns.SetFont(button.cooldown.timer, font.size, font.outline)
		updateButton(button)
	end
	if config.enabled then
		holder:Show()
	else
		holder:Hide()
	end
end

function Totems:Initialize()
	if ns.PLAYER_CLASS ~= "SHAMAN" then
		return
	end

	holder = CreateFrame("Frame", nil, UIParent)
	self:AnchorToConfig(holder, "totems.point", "Totems", { secure = true })

	for slot = 1, MAX_TOTEMS do
		createButton(slot, holder)
	end

	applyConfig()
	self:WatchConfig("totems", applyConfig, true)

	self:RegisterEvent("PLAYER_TOTEM_UPDATE")
	self:RegisterEvent("PLAYER_ENTERING_WORLD", "UpdateAll")
end
