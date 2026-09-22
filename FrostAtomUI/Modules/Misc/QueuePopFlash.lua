local _, ns = ...

local GetBattlefieldStatus = GetBattlefieldStatus
local GetTime = GetTime
local cos, pi, min = math.cos, math.pi, math.min
local MAX_BATTLEFIELD_QUEUES = MAX_BATTLEFIELD_QUEUES or 2

local Misc = ns:GetModule("Misc")

local SOLID_TEXTURE = "Interface\\Buttons\\WHITE8X8"
local VIGNETTE_TEXTURE = "Interface\\FullScreenTextures\\LowHealth"
local RAMP_TIME = 15
local RAMP_START = 0.6

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

local function update()
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

local function applyConfig()
	local color = ns.Config.queuePopFlash.color
	solid:SetVertexColor(unpack(color))
	vignette:SetVertexColor(unpack(color))
	update()
end

local function setProposal(shown)
	return function()
		proposalPending = shown
		update()
	end
end

applyConfig()
Misc:WatchConfig("queuePopFlash", applyConfig)
Misc:RegisterEvent("UPDATE_BATTLEFIELD_STATUS", update)
Misc:RegisterEvent("PLAYER_ENTERING_WORLD", setProposal(false))
Misc:RegisterEvent("LFG_PROPOSAL_SHOW", setProposal(true))
Misc:RegisterEvent("LFG_PROPOSAL_FAILED", setProposal(false))
Misc:RegisterEvent("LFG_PROPOSAL_SUCCEEDED", setProposal(false))
