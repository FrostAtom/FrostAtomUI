local _, ns = ...

local UnitExists = UnitExists
local GetSpellInfo = GetSpellInfo

local Auras = ns.Auras
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

	local aura = Auras.Find(self.unit, self.spell, self.filter)
	if not aura then
		self.start = nil
		self:Hide()
		return
	end

	local duration = aura.duration
	if duration == 0 then
		self.start = nil
		self.cooldown:Hide()
	else
		local start = aura.expires - duration
		if start ~= self.start or duration ~= self.duration then
			self.start, self.duration = start, duration
			self.cooldown:SetCooldown(start, duration)
		end
	end

	local count = aura.count
	if count > 1 then
		self.count:SetFormattedText("%d", count)
		self.count:Show()
	else
		self.count:Hide()
	end

	self.texture:SetTexture(aura.icon)
	self:Show()
end

function AuraFrameMixin:Configure(data)
	self:UnregisterUnitEvent("UNIT_AURA")
	self:UnregisterEvent("PLAYER_TARGET_CHANGED")
	self:UnregisterEvent("PLAYER_FOCUS_CHANGED")

	self.unit = data.unit
	self.spell = data.enabled ~= false and data.spell or nil
	self.filter = (data.debuff and "HARMFUL" or "HELPFUL") .. (data.isMine and "|PLAYER" or "")
	self.start = nil

	local size = data.size
	self:SetSize(size, size)
	self:ClearAllPoints()
	self:SetPoint(unpack(data.point))
	ns.SetFont(self.cooldown.timer, size * 0.3, "OUTLINE")

	if self.spell then
		self:RegisterUnitEvent("UNIT_AURA", data.unit, "Update")
		local event = UNIT_EVENTS[data.unit]
		if event then
			self:RegisterEvent(event, "Update")
		end
	end
	self:Update()
end

function AuraFrameMixin:Release()
	self.spell = nil
	self:UnregisterUnitEvent("UNIT_AURA")
	self:UnregisterEvent("PLAYER_TARGET_CHANGED")
	self:UnregisterEvent("PLAYER_FOCUS_CHANGED")
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
		local path = ("auraTracker.auras.%s.%d.point"):format(ns.PLAYER_CLASS, i)
		ns.Movers.Register(frame, path, GetSpellInfo(auras[i].spell) or tostring(auras[i].spell))
	end
	for i = #auras + 1, #frames do
		frames[i]:Release()
		ns.Movers.Unregister(frames[i])
	end
end

function AuraTracker:Initialize()
	applyConfig()
	self:WatchConfig("auraTracker", applyConfig)
end
