local _, ns = ...

local UnitHealth, UnitHealthMax = UnitHealth, UnitHealthMax

local Misc = ns:GetModule("Misc")

local PULSE_SPEED = 1.2

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

	local config = ns.Config.lowHealthFlash
	if config.enabled and UnitHealth("player") / UnitHealthMax("player") < config.threshold then
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
Misc:WatchConfig("lowHealthFlash", update)
