local _, ns = ...

if not ns.IS_WOWCIRCLE then
	return
end

local L = ns.L

local IsInInstance = IsInInstance
local GetBattlefieldStatus = GetBattlefieldStatus
local GetBattlefieldTimeWaited = GetBattlefieldTimeWaited
local GetBattlefieldEstimatedWaitTime = GetBattlefieldEstimatedWaitTime
local SecondsToTime = SecondsToTime
local AcceptBattlefieldPort = AcceptBattlefieldPort
local LeaveBattlefield = LeaveBattlefield
local SendChatMessage = SendChatMessage
local UnitName = UnitName
local UnitIsDeadOrGhost = UnitIsDeadOrGhost
local UnitIsFeignDeath = UnitIsFeignDeath
local UnitIsConnected = UnitIsConnected
local GetNumPartyMembers = GetNumPartyMembers
local GetBattlefieldWinner = GetBattlefieldWinner
local GameTooltip = GameTooltip
local GetTime = GetTime
local cos, pi, floor = math.cos, math.pi, math.floor
local format = string.format
local MAX_BATTLEFIELD_QUEUES = MAX_BATTLEFIELD_QUEUES or 2

local Misc = ns:GetModule("Misc")

local JOIN_COMMAND = ".soloq join"
local RANGE_OFFSET = 8
local PULSE_PERIOD = 1.6
local PULSE_MIN_ALPHA = 0.35
local TOOLTIP_REFRESH_INTERVAL = 0.1
local GLOW_TEXTURE = "Interface\\Buttons\\UI-ActionButton-Border"
local GLOW_SCALE = 2.2
local BACKDROP = ns.CreateBackdrop(8, 2)
local BACKGROUND_ALPHA = 0.85
local ICON_INSET = 3
local ICON_CROP = 0.08
local SHINE_ALPHA = 0.18
local HIGHLIGHT_ALPHA = 0.25
local GLYPH_SCALE = 0.5
local QUEUE_ICON = "Interface\\Icons\\Achievement_Arena_2v2_7"

local STATES = {
	join = { icon = QUEUE_ICON, tooltip = "Join solo queue", color = { 1, 0.82, 0 } },
	queued = { icon = QUEUE_ICON, tooltip = LEAVE_QUEUE, color = { 0.25, 0.7, 1 }, pulse = true },
	enter = { icon = QUEUE_ICON, tooltip = ENTER_BATTLE, color = { 0.3, 1, 0.3 }, glow = true },
	arena = { glyph = "arrow-right-from-bracket", tooltip = LEAVE_ARENA, color = { 1, 0.3, 0.25 } },
}

ns.OnLocaleReady(function()
	STATES.join.tooltip = L["Join solo queue"]
end)

local button = CreateFrame("Button", nil, UIParent)
button:Hide()
button:RegisterForClicks("LeftButtonUp")

button:SetBackdrop(BACKDROP)
button:SetBackdropColor(0, 0, 0, BACKGROUND_ALPHA)

button.icon = button:CreateTexture(nil, "BORDER")
button.icon:SetPoint("TOPLEFT", ICON_INSET, -ICON_INSET)
button.icon:SetPoint("BOTTOMRIGHT", -ICON_INSET, ICON_INSET)
button.icon:SetTexCoord(ICON_CROP, 1 - ICON_CROP, ICON_CROP, 1 - ICON_CROP)

button.glyph = button:CreateFontString(nil, "ARTWORK")
button.glyph:SetPoint("CENTER")

button.shine = button:CreateTexture(nil, "ARTWORK")
button.shine:SetTexture(ns.Media.blank)
button.shine:SetPoint("TOPLEFT", button.icon)
button.shine:SetPoint("RIGHT", button.icon)
button.shine:SetGradientAlpha("VERTICAL", 1, 1, 1, 0, 1, 1, 1, SHINE_ALPHA)

button.highlight = button:CreateTexture(nil, "HIGHLIGHT")
button.highlight:SetTexture(ns.Media.blank)
button.highlight:SetAllPoints(button.icon)
button.highlight:SetVertexColor(1, 1, 1, HIGHLIGHT_ALPHA)
button.highlight:SetBlendMode("ADD")

button.glow = button:CreateTexture(nil, "OVERLAY")
button.glow:SetPoint("CENTER")
button.glow:SetTexture(GLOW_TEXTURE)
button.glow:SetBlendMode("ADD")

local range = button:CreateFontString(nil, "OVERLAY")
range:Hide()

local searchRange, opponentSearch

local function isQueueState(state)
	return state == "queued" or state == "enter"
end

local arenaPartySize = 0

local function allyLost()
	local count = GetNumPartyMembers()
	if count < arenaPartySize then
		return true
	end
	arenaPartySize = count
	for i = 1, count do
		local unit = "party" .. i
		if not UnitIsConnected(unit) or UnitIsDeadOrGhost(unit) and not UnitIsFeignDeath(unit) then
			return true
		end
	end
	return false
end

local function isPinned()
	local state = button.state
	if isQueueState(state) then
		return true
	end
	return state == "arena" and (GetBattlefieldWinner() ~= nil or allyLost())
end

local fader = ns.CreateFader({ button }, nil, isPinned)

local function formatWait(milliseconds)
	local seconds = floor(milliseconds / 1000)
	if seconds < 60 then
		return L["Less than a minute"]
	end
	return SecondsToTime(seconds, true)
end

local function queueLines(index)
	local waited = format(L["Time in queue: %s"], formatWait(GetBattlefieldTimeWaited(index)))
	local estimate = GetBattlefieldEstimatedWaitTime(index)
	if estimate > 0 then
		return waited, format(L["Average wait: %s"], formatWait(estimate))
	end
	return waited
end

local function onEnter(self)
	GameTooltip:SetOwner(self, "ANCHOR_LEFT")
	GameTooltip:SetText(STATES[self.state].tooltip)
	self.queueText = nil
	if self.state == "queued" then
		local waited, estimate = queueLines(self.queueIndex)
		self.queueText = waited .. (estimate or "")
		GameTooltip:AddLine(waited, 1, 1, 1)
		if estimate then
			GameTooltip:AddLine(estimate, 1, 1, 1)
		end
	end
	GameTooltip:Show()
end

local function onLeave()
	GameTooltip:Hide()
end

local function onPulse(self, elapsed)
	local phase = GetTime() % PULSE_PERIOD / PULSE_PERIOD
	local color = STATES.queued.color
	self:SetBackdropBorderColor(color[1], color[2], color[3], PULSE_MIN_ALPHA + (1 - PULSE_MIN_ALPHA) * (0.5 + 0.5 * cos(phase * 2 * pi)))

	self.untilTooltipRefresh = self.untilTooltipRefresh - elapsed
	if self.untilTooltipRefresh <= 0 then
		self.untilTooltipRefresh = TOOLTIP_REFRESH_INTERVAL
		if GameTooltip:IsOwned(self) then
			local waited, estimate = queueLines(self.queueIndex)
			if waited .. (estimate or "") ~= self.queueText then
				onEnter(self)
			end
		end
	end
end

local function refreshRange()
	if button.state == "queued" and searchRange then
		local config = ns.Config.soloQueue
		range:SetText(searchRange)
		range:SetTextColor(unpack(opponentSearch and config.opponentSearchColor or config.teamSearchColor))
		range:Show()
	else
		range:Hide()
	end
end

local function applySize()
	local config = ns.Config.soloQueue
	local size = isQueueState(button.state) and config.queuedSize or config.buttonSize
	button:SetSize(size, size)
	button.glow:SetSize(size * GLOW_SCALE, size * GLOW_SCALE)
	button.shine:SetHeight((size - 2 * ICON_INSET) / 2)
	ns.SetGlyph(button.glyph, STATES[button.state].glyph, floor(size * GLYPH_SCALE))
end

local function setState(state, queueIndex)
	if state ~= "queued" then
		searchRange = nil
	end
	if state ~= "arena" or button.state ~= "arena" then
		arenaPartySize = 0
	end
	button.state, button.queueIndex = state, queueIndex

	if not state then
		button:Hide()
		refreshRange()
		return
	end

	local info = STATES[state]
	applySize()
	local r, g, b = unpack(info.color)
	button.icon:SetTexture(info.icon)
	ns.SetShown(button.icon, info.icon)
	button.glyph:SetTextColor(r, g, b)
	button:SetBackdropBorderColor(r, g, b, 1)
	if isQueueState(state) then
		MiniMapBattlefieldFrame:Hide()
	end
	if info.glow then
		button.glow:Show()
	else
		button.glow:Hide()
	end
	button.untilTooltipRefresh = 0
	button:SetScript("OnUpdate", info.pulse and onPulse or nil)
	button:Show()
	refreshRange()

	if GameTooltip:IsOwned(button) then
		onEnter(button)
	end
end

hooksecurefunc("BattlefieldFrame_UpdateStatus", function()
	if isQueueState(button.state) then
		MiniMapBattlefieldFrame:Hide()
	end
end)

local function findQueue()
	local foundIndex, foundStatus
	for i = 1, MAX_BATTLEFIELD_QUEUES do
		local status, _, _, _, _, teamSize = GetBattlefieldStatus(i)
		if (status == "queued" or status == "confirm") and (not foundIndex or (teamSize or 0) > 0) then
			foundIndex, foundStatus = i, status
		end
	end
	return foundIndex, foundStatus
end

local function update()
	local _, instanceType = IsInInstance()
	if not ns.Config.soloQueue.enabled then
		setState(nil)
	elseif instanceType == "arena" then
		setState("arena")
	elseif instanceType == "pvp" then
		setState(nil)
	else
		local index, status = findQueue()
		if status == "confirm" then
			setState("enter", index)
		elseif status == "queued" then
			setState("queued", index)
		else
			setState("join")
		end
	end
end

button:SetScript("OnEnter", onEnter)
button:SetScript("OnLeave", onLeave)
button:SetScript("OnClick", function(self)
	GameTooltip:Hide()
	if self.state == "arena" then
		LeaveBattlefield()
	elseif self.state == "enter" then
		AcceptBattlefieldPort(self.queueIndex, 1)
	elseif self.state == "queued" then
		AcceptBattlefieldPort(self.queueIndex)
	else
		SendChatMessage(JOIN_COMMAND, "WHISPER", nil, UnitName("player"))
	end
end)

local function applyConfig()
	local config = ns.Config.soloQueue
	local font = config.rangeFont
	ns.SetFont(range, font.size, font.outline, true)
	ns.ApplyPoint(button, "soloQueue.point")
	button.glow:SetVertexColor(unpack(config.glowColor))
	fader:Configure(config.mouseover, 0)
	range:ClearAllPoints()
	range:SetPoint("TOP", button, "BOTTOM", 0, -RANGE_OFFSET)
	update()
end

applyConfig()
Misc:WatchConfig("soloQueue", applyConfig)
Misc:RegisterMover(button, "soloQueue.point", "Solo queue", {
	size = function()
		local config = ns.Config.soloQueue
		return config.buttonSize, config.buttonSize
	end,
})
Misc:RegisterEvent("PLAYER_ENTERING_WORLD", update)
Misc:RegisterEvent("UPDATE_BATTLEFIELD_STATUS", update)

Misc:RegisterEvent(ns.SOLOQ_SEARCHING, function(_, low, high, teamRating)
	searchRange = ("%d-%d"):format(low, high)
	opponentSearch = teamRating and true or false
	refreshRange()
end)
