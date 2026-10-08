local _, ns = ...

local GetBattlefieldStatus = GetBattlefieldStatus
local GetBattlefieldPortExpiration = GetBattlefieldPortExpiration
local StaticPopup_FindVisible = StaticPopup_FindVisible
local cos, pi, min, max = math.cos, math.pi, math.min, math.max
local MAX_BATTLEFIELD_QUEUES = MAX_BATTLEFIELD_QUEUES or 2

local QueuePopFlash = ns:NewModule("QueuePopFlash")

local SOLID_TEXTURE = "Interface\\Buttons\\WHITE8X8"
local VIGNETTE_TEXTURE = "Interface\\FullScreenTextures\\LowHealth"
local RING_TEXTURE = "Interface\\Cooldown\\ping4"
local BURST_TEXTURE = "Interface\\Cooldown\\starburst"
local FADE_IN_TIME = 5
local FADE_IN_ALPHA = 0.1
local RAMP_TIME = 15
local SOLID_SHARE = 0.45
local FIRST_BEAT_ATTACK = 0.09
local FIRST_BEAT_RELEASE = 0.22
local SECOND_BEAT_DELAY = 0.27
local SECOND_BEAT_ATTACK = 0.11
local SECOND_BEAT_RELEASE = 0.42
local SECOND_BEAT_STRENGTH = 0.75
local PULSE_SPEED = 1.5
local URGENT_SECONDS = 10
local URGENT_SPEED = 1.7
local URGENT_BLEND_TIME = 1
local URGENT_COLOR = { 1, 0.15, 0.1 }
local EXPIRATION_TICK = 0.2
local INTRO_FLASH_TIME = 0.45
local INTRO_RING_DELAYS = { 0, 0.14, 0.3 }
local BURST_TIME = 0.8
local BURST_FROM, BURST_TO = 120, 1100
local RING_TIME = 1.1
local RING_FROM, RING_TO = 80, 950
local RING_ALPHA = 0.9
local RING_POOL = 6

local pulse = { value = 0, urgency = 0 }
ns.QueuePulse = pulse

local function swell(x, attack, release)
	if x <= 0 or x >= attack + release then
		return 0
	elseif x < attack then
		return 0.5 - 0.5 * cos(pi * x / attack)
	end
	return 0.5 + 0.5 * cos(pi * (x - attack) / release)
end

local function heartbeat(phase)
	local first = swell(phase, FIRST_BEAT_ATTACK, FIRST_BEAT_RELEASE)
	local second = swell(phase - SECOND_BEAT_DELAY, SECOND_BEAT_ATTACK, SECOND_BEAT_RELEASE)
	return min(first + SECOND_BEAT_STRENGTH * second, 1)
end

local function rampAlpha(elapsed)
	if elapsed < FADE_IN_TIME then
		return FADE_IN_ALPHA * elapsed / FADE_IN_TIME
	end
	return FADE_IN_ALPHA + (1 - FADE_IN_ALPHA) * min((elapsed - FADE_IN_TIME) / (RAMP_TIME - FADE_IN_TIME), 1)
end

local function easeOut(progress)
	local rest = 1 - progress
	return 1 - rest * rest * rest
end

local flash = CreateFrame("Frame", nil, UIParent)
flash:SetFrameStrata("HIGH")
flash:SetAllPoints(UIParent)
flash:Hide()

local solid = flash:CreateTexture(nil, "BACKGROUND")
solid:SetAllPoints()
solid:SetTexture(SOLID_TEXTURE)
solid:SetBlendMode("ADD")

local vignette = flash:CreateTexture(nil, "BORDER")
vignette:SetAllPoints()
vignette:SetTexture(VIGNETTE_TEXTURE)
vignette:SetBlendMode("ADD")

local burst = flash:CreateTexture(nil, "ARTWORK")
burst:SetTexture(BURST_TEXTURE)
burst:SetBlendMode("ADD")

local rings = {}
for i = 1, RING_POOL do
	local ring = flash:CreateTexture(nil, "ARTWORK")
	ring:SetTexture(RING_TEXTURE)
	ring:SetBlendMode("ADD")
	ring:Hide()
	rings[i] = ring
end

local function anchorFrame()
	local dialog = StaticPopup_FindVisible("CONFIRM_BATTLEFIELD_ENTRY")
	if dialog then
		return dialog
	end
	if LFDDungeonReadyPopup and LFDDungeonReadyPopup:IsShown() then
		return LFDDungeonReadyPopup
	end
end

local function anchorPoint()
	local frame = anchorFrame()
	local x, y
	if frame then
		x, y = frame:GetCenter()
	end
	if not x then
		return UIParent:GetWidth() / 2, UIParent:GetHeight() / 2
	end
	local ratio = frame:GetEffectiveScale() / UIParent:GetEffectiveScale()
	return x * ratio, y * ratio
end

local function placeCentered(texture, x, y, size)
	texture:ClearAllPoints()
	texture:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x, y)
	texture:SetSize(size, size)
end

local function spawnRing(delay)
	for i = 1, RING_POOL do
		local ring = rings[i]
		if not ring.start then
			ring.start = flash.elapsed + (delay or 0)
			ring:SetAlpha(0)
			ring:Show()
			return
		end
	end
end

local function currentColor()
	local color = ns.Config.queuePopFlash.color
	local u = pulse.urgency
	return color[1] + (URGENT_COLOR[1] - color[1]) * u,
		color[2] + (URGENT_COLOR[2] - color[2]) * u,
		color[3] + (URGENT_COLOR[3] - color[3]) * u
end

local function updateRings(intensity, x, y, r, g, b)
	for i = 1, RING_POOL do
		local ring = rings[i]
		local start = ring.start
		if start then
			local age = flash.elapsed - start
			if age >= RING_TIME then
				ring.start = nil
				ring:Hide()
			elseif age >= 0 then
				local progress = age / RING_TIME
				placeCentered(ring, x, y, RING_FROM + (RING_TO - RING_FROM) * easeOut(progress))
				ring:SetVertexColor(r, g, b)
				ring:SetAlpha(intensity * RING_ALPHA * (1 - progress) * (1 - progress))
			end
		end
	end
end

local function updateBurst(intensity, x, y, r, g, b)
	local elapsed = flash.elapsed
	if elapsed >= BURST_TIME then
		burst:Hide()
		return
	end
	local progress = elapsed / BURST_TIME
	placeCentered(burst, x, y, BURST_FROM + (BURST_TO - BURST_FROM) * easeOut(progress))
	burst:SetVertexColor(r, g, b)
	burst:SetAlpha(intensity * (1 - progress))
	burst:Show()
end

flash:SetScript("OnUpdate", function(self, elapsed)
	local intensity = ns.Config.queuePopFlash.intensity
	self.elapsed = self.elapsed + elapsed
	if pulse.beatStarted then
		spawnRing()
	end

	local r, g, b = currentColor()
	local beat = intensity * rampAlpha(self.elapsed) * pulse.value
	local intro = max(1 - self.elapsed / INTRO_FLASH_TIME, 0)
	intro = intensity * intro * intro

	solid:SetVertexColor(r, g, b)
	vignette:SetVertexColor(r, g, b)
	solid:SetAlpha(min(beat * SOLID_SHARE + intro, 1))
	vignette:SetAlpha(min(beat + intro, 1))

	local x, y = anchorPoint()
	updateBurst(intensity, x, y, r, g, b)
	updateRings(intensity, x, y, r, g, b)
end)

local driver = CreateFrame("Frame")
driver:Hide()

local function soonestExpiration()
	local soonest
	for i = 1, MAX_BATTLEFIELD_QUEUES do
		if GetBattlefieldStatus(i) == "confirm" then
			local expiration = GetBattlefieldPortExpiration(i)
			if expiration > 0 and (not soonest or expiration < soonest) then
				soonest = expiration
			end
		end
	end
	return soonest
end

driver:SetScript("OnUpdate", function(self, elapsed)
	self.untilTick = self.untilTick - elapsed
	if self.untilTick <= 0 then
		self.untilTick = EXPIRATION_TICK
		local expiration = soonestExpiration()
		self.urgent = expiration and expiration <= URGENT_SECONDS
	end

	local speed = PULSE_SPEED
	local step = elapsed / URGENT_BLEND_TIME
	if self.urgent then
		speed = speed * URGENT_SPEED
		pulse.urgency = min(pulse.urgency + step, 1)
	else
		pulse.urgency = max(pulse.urgency - step, 0)
	end

	local phase = self.phase + elapsed * speed
	pulse.beatStarted = phase >= 1
	self.phase = phase % 1
	pulse.value = heartbeat(self.phase)
end)

local pending, proposalPending = false, false
local flashing = false

local function hasBattlefieldConfirm()
	for i = 1, MAX_BATTLEFIELD_QUEUES do
		if GetBattlefieldStatus(i) == "confirm" then
			return true
		end
	end
	return false
end

local function startFlash()
	flash.elapsed = 0
	for _, ring in ipairs(rings) do
		ring.start = nil
		ring:Hide()
	end
	for _, delay in ipairs(INTRO_RING_DELAYS) do
		spawnRing(delay)
	end
	solid:SetAlpha(0)
	vignette:SetAlpha(0)
	burst:Hide()
	flash:Show()
end

local function updateFlash()
	local active = proposalPending or hasBattlefieldConfirm()
	if active ~= pending then
		pending = active
		if active then
			driver.phase, driver.untilTick, driver.urgent = 0, 0, nil
			pulse.value, pulse.urgency, pulse.beatStarted = 0, 0, nil
			driver:Show()
			ns.ExplainOnce("queueFlash")
		else
			driver:Hide()
			pulse.value = 0
		end
	end

	local show = active and ns.Config.queueInvite.enabled and ns.Config.queuePopFlash.enabled
	if show == flashing then
		return
	end
	flashing = show
	if show then
		startFlash()
	else
		flash:Hide()
	end
end

local function setProposal(shown)
	return function()
		proposalPending = shown
		updateFlash()
	end
end

updateFlash()
QueuePopFlash:WatchConfig("queuePopFlash", updateFlash)
QueuePopFlash:WatchConfig("queueInvite.enabled", updateFlash)
QueuePopFlash:RegisterEvent("UPDATE_BATTLEFIELD_STATUS", updateFlash)
QueuePopFlash:RegisterEvent("PLAYER_ENTERING_WORLD", setProposal(false))
QueuePopFlash:RegisterEvent("LFG_PROPOSAL_SHOW", setProposal(true))
QueuePopFlash:RegisterEvent("LFG_PROPOSAL_FAILED", setProposal(false))
QueuePopFlash:RegisterEvent("LFG_PROPOSAL_SUCCEEDED", setProposal(false))
