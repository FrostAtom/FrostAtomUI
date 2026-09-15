local _, ns = ...

-- Pulsing red screen edges while the player is below a third of their health.

local CreateFrame = CreateFrame
local UnitHealth, UnitHealthMax = UnitHealth, UnitHealthMax

local Misc = ns:GetModule("Misc")

local LOW_HEALTH_PERCENT = 0.33
local PULSE_SPEED = 1.2 -- alpha per second

local flash = CreateFrame("Frame")
flash:Hide()
flash:SetAlpha(0)
flash.direction = PULSE_SPEED

local texture = flash:CreateTexture(nil, "BORDER")
texture:SetAllPoints(UIParent)
texture:SetTexture("Interface\\FullScreenTextures\\LowHealth")
texture:SetBlendMode("ADD")

flash:SetScript("OnUpdate", function(self, elapsed)
	local alpha = self:GetAlpha() + elapsed * self.direction
	if alpha > 1 or alpha < 0 then
		self.direction = -self.direction
	end
	self:SetAlpha(alpha)
end)

local function update(_, unit)
	if unit and unit ~= "player" then
		return
	end

	if UnitHealth("player") / UnitHealthMax("player") < LOW_HEALTH_PERCENT then
		flash:Show()
	elseif flash:IsShown() then
		flash:Hide()
		flash:SetAlpha(0)
		flash.direction = PULSE_SPEED
	end
end

Misc:RegisterEvent("UNIT_HEALTH", update)
Misc:RegisterEvent("UNIT_MAXHEALTH", update)
Misc:RegisterEvent("PLAYER_ENTERING_WORLD", update)
