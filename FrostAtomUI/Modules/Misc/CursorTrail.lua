local _, ns = ...

local CreateFrame = CreateFrame
local GetCursorPosition = GetCursorPosition

local Misc = ns:GetModule("Misc")

local trail = CreateFrame("Model")
trail:SetAllPoints()
trail:SetFrameStrata("FULLSCREEN_DIALOG")
trail:SetModel("spells\\lightningboltivus_missile.mdx")
trail:SetModelScale(0.0018)
trail:SetAlpha(0.6)

local shine = CreateFrame("Model", nil, trail)
shine:SetAllPoints()
shine:SetModel("spells\\manafunnel_impact_chest.mdx")
shine:SetModelScale(0.01)
shine:SetAlpha(0.5)

local screenDiagonal = (GetScreenWidth() ^ 2 + GetScreenHeight() ^ 2) ^ 0.5
local lastX, lastY

shine:SetScript("OnUpdate", function(self)
	local x, y = GetCursorPosition()
	if x == lastX and y == lastY then
		return
	end
	lastX, lastY = x, y

	x, y = (x + 4) / screenDiagonal, (y - 6) / screenDiagonal
	self:SetPosition(x, y)
	trail:SetPosition(x, y)
end)

local function applyConfig()
	if ns.Config.cursorTrail.enabled then
		lastX, lastY = nil, nil
		trail:Show()
	else
		trail:Hide()
	end
end

applyConfig()
Misc:WatchConfig("cursorTrail", applyConfig)
