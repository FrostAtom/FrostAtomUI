local _, ns = ...

local CreateFrame = CreateFrame
local IsInInstance = IsInInstance
local GetBattlefieldStatus = GetBattlefieldStatus
local GetBattlefieldTimeWaited = GetBattlefieldTimeWaited
local AcceptBattlefieldPort = AcceptBattlefieldPort
local LeaveBattlefield = LeaveBattlefield
local SendChatMessage = SendChatMessage
local UnitName = UnitName
local GameTooltip = GameTooltip
local GetTime = GetTime
local cos, pi, floor = math.cos, math.pi, math.floor
local unpack = unpack
local MAX_BATTLEFIELD_QUEUES = MAX_BATTLEFIELD_QUEUES or 2

local Misc = ns:GetModule("Misc")

local JOIN_COMMAND = ".soloq join"
local BUTTON_SIZE = 20
local BUTTON_INSET = 3
local RANGE_OFFSET = 8
local PULSE_PERIOD = 1.6
local PULSE_MIN_ALPHA = 0.35
local TOOLTIP_REFRESH_INTERVAL = 0.5
local GLOW_TEXTURE = "Interface\\Buttons\\UI-ActionButton-Border"
local GLOW_SCALE = 2.2
local GLOW_COLOR = { 0.3, 1, 0.3 }
local QUEUE_ICON = "Interface\\GossipFrame\\BattleMasterGossipIcon"
local LEAVE_ICON = "Interface\\Buttons\\UI-GroupLoot-Pass-Up"
local TEAM_SEARCH_COLOR = { 1, 1, 1 }
local OPPONENT_SEARCH_COLOR = { 1, 0.85, 0.3 }

local STATES = {
	join = { icon = QUEUE_ICON, tooltip = "Join solo queue" },
	queued = { icon = QUEUE_ICON, tooltip = LEAVE_QUEUE, pulse = true },
	enter = { icon = QUEUE_ICON, tooltip = ENTER_BATTLE, glow = true },
	arena = { icon = LEAVE_ICON, tooltip = LEAVE_ARENA },
}

local button = CreateFrame("Button", nil, Minimap)
button:Hide()
button:SetSize(BUTTON_SIZE, BUTTON_SIZE)
button:SetPoint("BOTTOMRIGHT", -BUTTON_INSET, BUTTON_INSET)
button:RegisterForClicks("LeftButtonUp")

button.icon = button:CreateTexture(nil, "BORDER")
button.icon:SetAllPoints()

button.highlight = button:CreateTexture(nil, "HIGHLIGHT")
button.highlight:SetAllPoints()
button.highlight:SetBlendMode("ADD")

button.glow = button:CreateTexture(nil, "OVERLAY")
button.glow:SetPoint("CENTER")
button.glow:SetSize(BUTTON_SIZE * GLOW_SCALE, BUTTON_SIZE * GLOW_SCALE)
button.glow:SetTexture(GLOW_TEXTURE)
button.glow:SetBlendMode("ADD")
button.glow:SetVertexColor(unpack(GLOW_COLOR))

local range = button:CreateFontString(nil, "OVERLAY")
range:Hide()
range:SetPoint("TOPRIGHT", Minimap, "BOTTOMRIGHT", -BUTTON_INSET, -RANGE_OFFSET)

local searchRange

local function queueTime(index)
	local seconds = floor(GetBattlefieldTimeWaited(index) / 1000)
	return ("%d:%02d"):format(seconds / 60, seconds % 60)
end

local function onEnter(self)
	GameTooltip:SetOwner(self, "ANCHOR_LEFT")
	GameTooltip:SetText(STATES[self.state].tooltip)
	if self.state == "queued" then
		GameTooltip:AddLine("Time in queue: " .. queueTime(self.queueIndex), 1, 1, 1)
	end
	GameTooltip:Show()
end

local function onLeave()
	GameTooltip:Hide()
end

local function onPulse(self, elapsed)
	local phase = GetTime() % PULSE_PERIOD / PULSE_PERIOD
	self.icon:SetAlpha(PULSE_MIN_ALPHA + (1 - PULSE_MIN_ALPHA) * (0.5 + 0.5 * cos(phase * 2 * pi)))

	self.untilTooltipRefresh = self.untilTooltipRefresh - elapsed
	if self.untilTooltipRefresh <= 0 then
		self.untilTooltipRefresh = TOOLTIP_REFRESH_INTERVAL
		if GameTooltip:IsOwned(self) then
			onEnter(self)
		end
	end
end

local function refreshRange()
	if button.state == "queued" and searchRange then
		range:SetText(searchRange)
		range:Show()
	else
		range:Hide()
	end
end

local function setState(state, queueIndex)
	if state ~= "queued" then
		searchRange = nil
	end
	button.state, button.queueIndex = state, queueIndex

	if not state then
		button:Hide()
		refreshRange()
		return
	end

	local info = STATES[state]
	button.icon:SetTexture(info.icon)
	button.icon:SetAlpha(1)
	button.highlight:SetTexture(info.icon)
	if state == "queued" or state == "enter" then
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
	if button.state == "queued" or button.state == "enter" then
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
	local font = ns.Config.soloQueue.rangeFont
	range:SetFont(ns.Media.fontBold, font.size, font.outline)
	update()
end

applyConfig()
Misc:WatchConfig("soloQueue", applyConfig)
Misc:RegisterEvent("PLAYER_ENTERING_WORLD", update)
Misc:RegisterEvent("UPDATE_BATTLEFIELD_STATUS", update)

Misc:RegisterEvent(ns.SOLOQ_SEARCHING, function(_, low, high, teamRating)
	searchRange = ("%d-%d"):format(low, high)
	range:SetTextColor(unpack(teamRating and OPPONENT_SEARCH_COLOR or TEAM_SEARCH_COLOR))
	refreshRange()
end)
