local _, ns = ...
local UF = ns:GetModule("UnitFrames")

local GetTime = GetTime
local UnitGUID = UnitGUID
local IsInInstance = IsInInstance
local random = math.random

local CooldownTimer = ns:GetModule("CooldownTimer")
local CooldownTracker = ns:GetModule("CooldownTracker")

local PVP_TRINKET = ns.CooldownData.PVP_TRINKET
local TRINKET_ICON = "Interface\\Icons\\INV_Jewelry_TrinketPVP_02"
local DEFAULT_SIZE = 30
local TIMER_FONT_SCALE = 0.4

function UF.IsTrinketSeparate(side)
	local config = ns.Config.groupCooldowns
	return config.enabled
			and config[side]
			and config[side .. "SeparateTrinket"]
			and config[side .. "Categories"].trinket
		or false
end

local function isShown(frame)
	if not frame.trinket.arenaOnly then
		return UF.IsTrinketSeparate("enemy")
	end
	return UF.IsTrinketSeparate("friendly") and (frame.test ~= nil or select(2, IsInInstance()) == "arena")
end

local function guidOf(frame)
	return UnitGUID(frame.unit) or UF.GhostGUID and UF.GhostGUID(frame)
end

local function refresh(frame)
	local start, duration = CooldownTracker:GetCooldown(guidOf(frame), PVP_TRINKET)
	frame.trinket.cooldown:SetCooldown(start or 0, duration or 0)
end

local function update(frame)
	ns.SetShown(frame.trinket, isShown(frame))
	if not frame.test then
		refresh(frame)
	end
end

local function test(frame)
	ns.SetShown(frame.trinket, isShown(frame))
	if random(3) == 1 then
		frame.trinket.cooldown:SetCooldown(0, 0)
	else
		frame.trinket.cooldown:SetCooldown(GetTime() - random(0, 100), 120)
	end
end

local function onCooldownUpdated(frame, guid)
	if not frame.test and (guid == nil or guid == guidOf(frame)) then
		refresh(frame)
	end
end

local function onOpponentUpdate(frame, unit)
	if unit == frame.unit and not frame.test then
		refresh(frame)
	end
end

local function setIconSize(trinket, size)
	trinket:SetSize(size, size)
	ns.SetFont(trinket.cooldown.timer, size * TIMER_FONT_SCALE, "OUTLINE")
end

local function create(frame, options)
	local size = options and options.size or DEFAULT_SIZE

	local trinket = CreateFrame("Frame", nil, frame)
	trinket:SetSize(size, size)
	trinket.SetIconSize = setIconSize
	trinket.arenaOnly = options and options.arenaOnly
	trinket.Refresh = function()
		update(frame)
	end

	trinket.icon = trinket:CreateTexture(nil, "BORDER")
	trinket.icon:SetTexture(TRINKET_ICON)
	UF.SkinIcon(trinket, trinket.icon)

	trinket.cooldown = CreateFrame("Cooldown", nil, trinket)
	trinket.cooldown:SetAllPoints()
	CooldownTimer:Attach(trinket.cooldown, size * TIMER_FONT_SCALE)

	frame:RegisterEvent(ns.E.COOLDOWN_UPDATED, onCooldownUpdated)
	frame:RegisterEvent("ARENA_OPPONENT_UPDATE", onOpponentUpdate)
	frame:RegisterEvent("PLAYER_ENTERING_WORLD", update)

	return trinket
end

UF:RegisterElement({ name = "trinket", Create = create, Update = update, Test = test })
