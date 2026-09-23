local _, ns = ...

local L = ns.L

local GetBattlefieldStatus = GetBattlefieldStatus
local GetBattlefieldPortExpiration = GetBattlefieldPortExpiration
local StaticPopup_FindVisible = StaticPopup_FindVisible
local PlaySoundFile = PlaySoundFile
local GetCVar = GetCVar
local GetTime = GetTime
local cos, pi, min = math.cos, math.pi, math.min
local MAX_BATTLEFIELD_QUEUES = MAX_BATTLEFIELD_QUEUES or 2

local Misc = ns:GetModule("Misc")

local SOLID_TEXTURE = "Interface\\Buttons\\WHITE8X8"
local VIGNETTE_TEXTURE = "Interface\\FullScreenTextures\\LowHealth"
local RAMP_TIME = 15
local RAMP_START = 0.6
local INVITE_SOUND = "Sound\\Spells\\PVPThroughQueue.wav"
local COUNTDOWN_TICK = 0.2
local COUNTDOWN_URGENT = 10
local COUNTDOWN_URGENT_COLOR = { 1, 0.3, 0.3 }
local COUNTDOWN_OFFSET = 8
local COUNTDOWN_FALLBACK_Y = 160

local flash = CreateFrame("Frame", nil, UIParent)
flash:SetFrameStrata("HIGH")
flash:SetAllPoints(UIParent)
flash:SetAlpha(0)
flash:Hide()

local solid = flash:CreateTexture(nil, "BACKGROUND")
solid:SetAllPoints()
solid:SetTexture(SOLID_TEXTURE)
solid:SetBlendMode("ADD")

local vignette = flash:CreateTexture(nil, "BORDER")
vignette:SetAllPoints()
vignette:SetTexture(VIGNETTE_TEXTURE)
vignette:SetBlendMode("ADD")

flash:SetScript("OnUpdate", function(self, elapsed)
	local config = ns.Config.queuePopFlash
	self.elapsed = self.elapsed + elapsed
	local ramp = RAMP_START + (1 - RAMP_START) * min(self.elapsed / RAMP_TIME, 1)
	self:SetAlpha(config.intensity * ramp * (0.5 - 0.5 * cos(GetTime() * config.pulseSpeed * 2 * pi)))
end)

local pending, proposalPending = false, false

local function hasBattlefieldConfirm()
	for i = 1, MAX_BATTLEFIELD_QUEUES do
		if GetBattlefieldStatus(i) == "confirm" then
			return true
		end
	end
	return false
end

local function updateFlash()
	local config = ns.Config.queuePopFlash
	local active = config.enabled and (proposalPending or hasBattlefieldConfirm())
	if active == pending then
		return
	end

	pending = active
	if active then
		flash.elapsed = 0
		flash:SetAlpha(0)
		flash:Show()
	else
		flash:Hide()
		flash:SetAlpha(0)
	end
end

local function applyFlashConfig()
	local color = ns.Config.queuePopFlash.color
	solid:SetVertexColor(unpack(color))
	vignette:SetVertexColor(unpack(color))
	updateFlash()
end

local function setProposal(shown)
	return function()
		proposalPending = shown
		updateFlash()
	end
end

local countdown = CreateFrame("Frame", nil, UIParent)
countdown:SetFrameStrata("DIALOG")
countdown:SetSize(1, 1)
countdown:Hide()

local countdownText = countdown:CreateFontString(nil, "OVERLAY")
countdownText:SetPoint("BOTTOM")

local confirmed = {}

local function refreshCountdown()
	local seconds, index
	for i = 1, MAX_BATTLEFIELD_QUEUES do
		if GetBattlefieldStatus(i) == "confirm" then
			local expiration = GetBattlefieldPortExpiration(i)
			if expiration > 0 and (not seconds or expiration < seconds) then
				seconds, index = expiration, i
			end
		end
	end
	if not seconds then
		countdownText:SetText("")
		return
	end

	local dialog = StaticPopup_FindVisible("CONFIRM_BATTLEFIELD_ENTRY", index)
	countdown:ClearAllPoints()
	if dialog then
		countdown:SetPoint("BOTTOM", dialog, "TOP", 0, COUNTDOWN_OFFSET)
	else
		countdown:SetPoint("BOTTOM", UIParent, "CENTER", 0, COUNTDOWN_FALLBACK_Y)
	end
	countdownText:SetFormattedText(L["Invite expires in %d sec"], seconds)
	if seconds <= COUNTDOWN_URGENT then
		countdownText:SetTextColor(unpack(COUNTDOWN_URGENT_COLOR))
	else
		countdownText:SetTextColor(1, 1, 1)
	end
end

countdown:SetScript("OnUpdate", function(self, elapsed)
	self.untilTick = self.untilTick - elapsed
	if self.untilTick > 0 then
		return
	end
	self.untilTick = COUNTDOWN_TICK
	refreshCountdown()
end)

local function updateInvite()
	local config = ns.Config.queueInvite
	local pendingInvite = false
	for i = 1, MAX_BATTLEFIELD_QUEUES do
		local confirm = GetBattlefieldStatus(i) == "confirm"
		if confirm then
			pendingInvite = true
			if not confirmed[i] and config.enabled and config.sound and GetCVar("Sound_EnableSFX") == "0" then
				PlaySoundFile(INVITE_SOUND, "Master")
			end
		end
		confirmed[i] = confirm
	end
	if pendingInvite and config.enabled and config.countdown then
		countdown.untilTick = 0
		countdown:Show()
	else
		countdown:Hide()
	end
end

local function applyInviteConfig()
	local font = ns.Config.queueInvite.font
	ns.SetFont(countdownText, font.size, font.outline, true)
	updateInvite()
end

applyFlashConfig()
applyInviteConfig()
Misc:WatchConfig("queuePopFlash", applyFlashConfig)
Misc:WatchConfig("queueInvite", applyInviteConfig)
Misc:RegisterEvent("UPDATE_BATTLEFIELD_STATUS", updateFlash)
Misc:RegisterEvent("UPDATE_BATTLEFIELD_STATUS", updateInvite)
Misc:RegisterEvent("PLAYER_ENTERING_WORLD", setProposal(false))
Misc:RegisterEvent("LFG_PROPOSAL_SHOW", setProposal(true))
Misc:RegisterEvent("LFG_PROPOSAL_FAILED", setProposal(false))
Misc:RegisterEvent("LFG_PROPOSAL_SUCCEEDED", setProposal(false))
