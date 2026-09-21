local _, ns = ...

local CreateFrame = CreateFrame
local UnitExists = UnitExists
local unpack = unpack
local FindAura = ns.FindAura

local AuraTracker = ns:NewModule("AuraTracker")
local CooldownTimer = ns:GetModule("CooldownTimer")

local UNIT_EVENTS = {
	target = "PLAYER_TARGET_CHANGED",
	focus = "PLAYER_FOCUS_CHANGED",
}

local AuraFrameMixin = {}

function AuraFrameMixin:Update()
	if not self.spell or not ns.Config.auraTracker.enabled or not UnitExists(self.unit) then
		self:Hide()
		return
	end

	local name, _, texture, count, _, duration, endTime = FindAura(self.unit, self.spell, self.filter)

	if not name then
		self:Hide()
		return
	end

	if duration == 0 then
		self.cooldown:Hide()
	else
		self.cooldown:SetCooldown(endTime - duration, duration)
	end

	if count > 1 then
		self.count:SetText(count)
		self.count:Show()
	else
		self.count:Hide()
	end

	self.texture:SetTexture(texture)
	self:Show()
end

function AuraFrameMixin:UNIT_AURA(unit)
	if unit == self.unit then
		self:Update()
	end
end

function AuraFrameMixin:Configure(data)
	self.unit = data.unit
	self.spell = data.enabled ~= false and data.spell or nil
	self.filter = (data.debuff and "HARMFUL" or "HELPFUL") .. (data.isMine and "|PLAYER" or "")

	local size = data.size
	self:SetSize(size, size)
	self:ClearAllPoints()
	self:SetPoint(unpack(data.point))
	self.cooldown.timer:SetFont(ns.Media.font, size * 0.3, "OUTLINE")

	self:UnregisterEvent("PLAYER_TARGET_CHANGED")
	self:UnregisterEvent("PLAYER_FOCUS_CHANGED")
	local event = UNIT_EVENTS[data.unit]
	if event then
		self:RegisterEvent(event, "Update")
	end
	self:Update()
end

function AuraFrameMixin:Release()
	self.spell = nil
	self:Hide()
end

local function createAuraFrame()
	local frame = CreateFrame("Frame", nil, UIParent)
	ns.Mixin(frame, ns.EventMixin, AuraFrameMixin)
	frame:Hide()
	frame:SetFrameStrata("HIGH")

	frame.texture = frame:CreateTexture(nil, "BORDER")
	frame.texture:SetAllPoints()

	frame.cooldown = CreateFrame("Cooldown", nil, frame)
	frame.cooldown:SetReverse(true)
	frame.cooldown:SetDrawEdge(true)
	frame.cooldown:SetAllPoints()
	CooldownTimer:Attach(frame.cooldown)

	frame.count = frame:CreateFontString(nil, "ARTWORK", "NumberFontNormal")
	frame.count:SetPoint("BOTTOMRIGHT")

	frame:RegisterEvent("UNIT_AURA")
	frame:RegisterEvent("PLAYER_ENTERING_WORLD", "Update")

	return frame
end

local frames = {}

local function applyConfig()
	local config = ns.Config.auraTracker
	local auras = config.auras[ns.PLAYER_CLASS] or {}

	for i = 1, #auras do
		local frame = frames[i]
		if not frame then
			frame = createAuraFrame()
			frames[i] = frame
		end
		frame:SetScale(config.scale)
		frame:Configure(auras[i])
	end
	for i = #auras + 1, #frames do
		frames[i]:Release()
	end
end

function AuraTracker:Initialize()
	applyConfig()
	self:WatchConfig("auraTracker", applyConfig)
end
