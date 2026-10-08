local _, ns = ...

local UnitHealth, UnitHealthMax, UnitIsDeadOrGhost = UnitHealth, UnitHealthMax, UnitIsDeadOrGhost

local LowHealthFlash = ns:NewModule("LowHealthFlash")

local PULSE_SPEED = 1.2

local flash = CreateFrame("Frame")
flash:Hide()
flash:SetAlpha(0)
flash.direction = 1

local texture = flash:CreateTexture(nil, "BORDER")
texture:SetAllPoints(UIParent)
texture:SetTexture("Interface\\FullScreenTextures\\LowHealth")
texture:SetBlendMode("ADD")

flash:SetScript("OnUpdate", function(self, elapsed)
	local alpha = self:GetAlpha() + elapsed * self.direction * PULSE_SPEED
	if alpha > 1 or alpha < 0 then
		self.direction = -self.direction
	end
	self:SetAlpha(alpha)
end)

local function update()
	local config = ns.Config.lowHealthFlash
	local max = UnitHealthMax("player")
	if
		config.enabled
		and max > 0
		and not UnitIsDeadOrGhost("player")
		and UnitHealth("player") / max < config.threshold
	then
		flash:Show()
	elseif flash:IsShown() then
		flash:Hide()
		flash:SetAlpha(0)
		flash.direction = 1
	end
end

LowHealthFlash:RegisterUnitEvent("UNIT_HEALTH", "player", update)
LowHealthFlash:RegisterUnitEvent("UNIT_MAXHEALTH", "player", update)
LowHealthFlash:RegisterEvent("PLAYER_ENTERING_WORLD", update)
LowHealthFlash:RegisterEvent("PLAYER_DEAD", update)
LowHealthFlash:RegisterEvent("PLAYER_ALIVE", update)
LowHealthFlash:RegisterEvent("PLAYER_UNGHOST", update)
LowHealthFlash:WatchConfig("lowHealthFlash", update)
