local _, ns = ...

local CreateFrame = CreateFrame
local GetRuneType = GetRuneType
local GetRuneCooldown = GetRuneCooldown
local GetTime = GetTime

local Runes = ns:NewModule("Runes")
Runes.configKey = "runes"

local NUM_RUNES = 6

local RUNE_COLOR_KEYS = { "bloodColor", "unholyColor", "frostColor", "deathColor" }

local runes = {}
local holder

local RuneMixin = {}

function RuneMixin:UpdateType()
	local config = ns.Config.runes
	local color = config[RUNE_COLOR_KEYS[GetRuneType(self:GetID())]] or config.emptyColor
	local r, g, b = color[1], color[2], color[3]
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
	local rune = CreateFrame("StatusBar", nil, holder)
	ns.Mixin(rune, ns.EventMixin, RuneMixin)
	rune:SetID(id)
	rune:SetMinMaxValues(0, 1)

	local bar = rune:CreateTexture(nil, "BORDER")
	bar:SetAllPoints()
	rune:SetStatusBarTexture(bar)

	rune.bg = rune:CreateTexture(nil, "BACKGROUND")
	rune.bg:SetAllPoints()

	rune:RegisterEvent("PLAYER_ENTERING_WORLD", "UpdateAll")
	rune:RegisterEvent("RUNE_TYPE_UPDATE")
	rune:RegisterEvent("RUNE_POWER_UPDATE")

	runes[id] = rune
	return rune
end

local function applyConfig()
	local config = ns.Config.runes
	local width, height, gap = config.width, config.height, config.gap
	holder:SetSize(NUM_RUNES * (width + gap) - gap, height)

	local slot = width + gap
	for i = 1, NUM_RUNES do
		local rune = runes[i]
		rune:SetSize(width, height)
		rune:ClearAllPoints()
		rune:SetPoint("CENTER", holder, -1 + (3.5 - i) * slot, 0)
		rune:UpdateAll()
	end
end

function Runes:Initialize()
	if ns.PLAYER_CLASS ~= "DEATHKNIGHT" then
		return
	end
	ns.DestroyFrame(RuneFrame, true)

	holder = CreateFrame("Frame", nil, UIParent)
	self:AnchorToConfig(holder, "runes.point")

	for i = 1, NUM_RUNES do
		createRune(i)
	end

	applyConfig()
	self:WatchConfig("runes", applyConfig)
end
