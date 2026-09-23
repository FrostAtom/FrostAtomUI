local _, ns = ...

local GetCursorPosition = GetCursorPosition
local InCombatLockdown = InCombatLockdown

local Misc = ns:GetModule("Misc")

local TRAIL_SCALE = 0.0018
local SHINE_SCALE = 0.01
local CURSOR_OFFSET_X, CURSOR_OFFSET_Y = 4, -6

local trail = CreateFrame("Model")
trail:SetAllPoints()
trail:SetFrameStrata("FULLSCREEN_DIALOG")
trail:SetModel("spells\\lightningboltivus_missile.mdx")

local shine = CreateFrame("Model", nil, trail)
shine:SetAllPoints()
shine:SetModel("spells\\manafunnel_impact_chest.mdx")

local screenDiagonal = (GetScreenWidth() ^ 2 + GetScreenHeight() ^ 2) ^ 0.5
local lastX, lastY

shine:SetScript("OnUpdate", function(self)
	local x, y = GetCursorPosition()
	if x == lastX and y == lastY then
		return
	end
	lastX, lastY = x, y

	x, y = (x + CURSOR_OFFSET_X) / screenDiagonal, (y + CURSOR_OFFSET_Y) / screenDiagonal
	self:SetPosition(x, y)
	trail:SetPosition(x, y)
end)

local function applyConfig()
	local config = ns.Config.cursorTrail
	trail:SetModelScale(TRAIL_SCALE * config.scale)
	trail:SetAlpha(config.trailAlpha)
	shine:SetModelScale(SHINE_SCALE * config.scale)
	shine:SetAlpha(config.shineAlpha)
	if config.enabled and not (config.hideInCombat and InCombatLockdown()) then
		lastX, lastY = nil, nil
		trail:Show()
	else
		trail:Hide()
	end
end

applyConfig()
Misc:WatchConfig("cursorTrail", applyConfig)
Misc:RegisterEvent("PLAYER_REGEN_DISABLED", applyConfig)
Misc:RegisterEvent("PLAYER_REGEN_ENABLED", applyConfig)
