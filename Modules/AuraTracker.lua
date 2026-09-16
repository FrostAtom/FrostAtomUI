local _, ns = ...

local TRACKED_AURAS = {
	WARRIOR = {
		{ spell = 60503, unit = "player", point = { "CENTER", 18, -72 }, size = 36 }, -- Taste for Blood
		{ spell = 52437, unit = "player", point = { "CENTER", -18, -72 }, size = 36 }, -- Sudden Death
	},
	PALADIN = {
		{ spell = 54149, unit = "player", point = { "CENTER", 0, -72 }, size = 36 }, -- Infusion of Light
		{ spell = 54153, unit = "player", point = { "CENTER", 72, 36 }, size = 36 }, -- Judgements of the Pure
		{ spell = 53563, unit = "player", isMine = true, point = { "CENTER", -108, 36 }, size = 36 }, -- Beacon of Light
		{ spell = 53601, unit = "player", isMine = true, point = { "CENTER", -72, 36 }, size = 36 }, -- Sacred Shield
		{ spell = 58597, unit = "player", point = { "CENTER", 0, -36 }, size = 40 }, -- Sacred Shield proc
	},
	PRIEST = {
		{ spell = 48168, unit = "player", point = { "CENTER", 72, 36 }, size = 36 }, -- Inner Fire
	},
	DEATHKNIGHT = {
		{ spell = 55379, unit = "player", point = { "CENTER", 0, -72 }, size = 36 }, -- haste proc (meta gem)
		-- own diseases on the target: Blood Plague, Frost Fever, Ebon Plague, Unholy Blight
		{ spell = 55078, unit = "target", type = "debuff", isMine = true, point = { "CENTER", -48, -42 }, size = 30 },
		{ spell = 55095, unit = "target", type = "debuff", isMine = true, point = { "CENTER", -16, -42 }, size = 30 },
		{ spell = 51735, unit = "target", type = "debuff", isMine = true, point = { "CENTER", 16, -42 }, size = 30 },
		{ spell = 50536, unit = "target", type = "debuff", isMine = true, point = { "CENTER", 48, -42 }, size = 30 },
	},
	SHAMAN = {
		{ spell = 57960, unit = "player", point = { "CENTER", 72, 36 }, size = 36 }, -- Water Shield
		{ spell = 70806, unit = "player", point = { "CENTER", 0, -72 }, size = 36 }, -- 2p T10 resto proc
		{ spell = 8178, unit = "player", isMine = true, point = { "CENTER", -108, 36 }, size = 36 }, -- Grounding Totem
	},
}

local CreateFrame = CreateFrame
local UnitExists = UnitExists
local FindAura = ns.FindAura

local AuraTracker = ns:NewModule("AuraTracker")
local CooldownTimer = ns:GetModule("CooldownTimer")

local AuraFrameMixin = {}

function AuraFrameMixin:Update()
	if not UnitExists(self.unit) then
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

local function createAuraFrame(data)
	local frame = CreateFrame("Frame", nil, UIParent)
	ns.Mixin(frame, ns.EventMixin, AuraFrameMixin)
	frame:Hide()
	frame:SetFrameStrata("HIGH")

	local size = data.size or 32
	frame:SetSize(size, size)
	frame:SetPoint(unpack(data.point or { "CENTER" }))

	frame.unit = data.unit
	frame.spell = data.spell
	frame.filter = (data.type == "debuff" and "HARMFUL" or "HELPFUL") .. (data.isMine and "|PLAYER" or "")

	frame.texture = frame:CreateTexture(nil, "BORDER")
	frame.texture:SetAllPoints()

	frame.cooldown = CreateFrame("Cooldown", nil, frame)
	frame.cooldown:SetReverse(true)
	frame.cooldown:SetDrawEdge(true)
	frame.cooldown:SetAllPoints()
	CooldownTimer:Attach(frame.cooldown, size * 0.3)

	frame.count = frame:CreateFontString(nil, "ARTWORK", "NumberFontNormal")
	frame.count:SetPoint("BOTTOMRIGHT")

	frame:RegisterEvent("UNIT_AURA")
	frame:RegisterEvent("PLAYER_ENTERING_WORLD", "Update")
	if data.unit == "target" then
		frame:RegisterEvent("PLAYER_TARGET_CHANGED", "Update")
	elseif data.unit == "focus" then
		frame:RegisterEvent("PLAYER_FOCUS_CHANGED", "Update")
	end

	return frame
end

function AuraTracker:Initialize()
	local auras = TRACKED_AURAS[ns.PLAYER_CLASS]
	if not auras then
		return
	end

	self.frames = {}
	for _, data in ipairs(auras) do
		assert(type(data.spell) == "number", "tracked aura needs a spell id")
		self.frames[#self.frames + 1] = createAuraFrame(data)
	end
end
