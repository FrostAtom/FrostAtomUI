local _, ns = ...

-- Six rune bars for death knights, under the player castbar.

local CreateFrame = CreateFrame
local GetRuneType = GetRuneType
local GetRuneCooldown = GetRuneCooldown
local GetTime = GetTime
local unpack = unpack

local Runes = ns:NewModule("Runes")

local NUM_RUNES = 6
local RUNE_WIDTH, RUNE_HEIGHT, RUNE_GAP = 48, 16, 2

-- GetRuneType() values
local RUNE_COLORS = {
	[1] = { 1, 0, 0 }, -- blood
	[2] = { 0, 0.5, 0 }, -- unholy
	[3] = { 0, 1, 1 }, -- frost
	[4] = { 0.8, 0.1, 1 }, -- death
}
local EMPTY_COLOR = { 0.2, 0.2, 0.2 }

local RuneMixin = {}

function RuneMixin:UpdateType()
	local r, g, b = unpack(RUNE_COLORS[GetRuneType(self:GetID())] or EMPTY_COLOR)
	self:GetStatusBarTexture():SetTexture(r, g, b)
	self.bg:SetTexture(r * 0.3, g * 0.3, b * 0.3)
end

function RuneMixin:OnUpdate()
	local start, duration, ready = GetRuneCooldown(self:GetID())
	if ready or duration == 0 then
		self:SetValue(1)
		self:SetScript("OnUpdate", nil)
	else
		self:SetValue((GetTime() - start) / duration)
	end
end

-- Full refresh (login, /reload mid-cooldown): type and current cooldown.
function RuneMixin:UpdateAll()
	self:UpdateType()
	self:SetScript("OnUpdate", self.OnUpdate)
	self:OnUpdate()
end

function RuneMixin:RUNE_TYPE_UPDATE(rune)
	if rune == self:GetID() then
		self:UpdateType()
	end
end

function RuneMixin:RUNE_POWER_UPDATE(rune, usable)
	if rune ~= self:GetID() then
		return
	end

	if usable then
		self:SetValue(1)
	else
		self:SetScript("OnUpdate", self.OnUpdate)
	end
end

local function createRune(id)
	local rune = CreateFrame("StatusBar", nil, UIParent)
	ns.Mixin(rune, ns.EventMixin, RuneMixin)
	rune:SetID(id)
	rune:SetSize(RUNE_WIDTH, RUNE_HEIGHT)
	rune:SetMinMaxValues(0, 1)

	local bar = rune:CreateTexture(nil, "BORDER")
	bar:SetAllPoints()
	rune:SetStatusBarTexture(bar)

	rune.bg = rune:CreateTexture(nil, "BACKGROUND")
	rune.bg:SetAllPoints()

	rune:RegisterEvent("PLAYER_ENTERING_WORLD", "UpdateAll")
	rune:RegisterEvent("RUNE_TYPE_UPDATE")
	rune:RegisterEvent("RUNE_POWER_UPDATE")
	rune:UpdateAll()

	return rune
end

function Runes:Initialize()
	if ns.PLAYER_CLASS ~= "DEATHKNIGHT" then
		return
	end

	local point, x, y = unpack(ns.Config.runes)
	local slot = RUNE_WIDTH + RUNE_GAP
	for i = 1, NUM_RUNES do
		createRune(i):SetPoint(point, x - 1 + (3.5 - i) * slot, y)
	end
end
