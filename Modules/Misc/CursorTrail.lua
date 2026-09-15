-- A lightning spell effect that follows the mouse cursor.

local CreateFrame = CreateFrame
local GetCursorPosition = GetCursorPosition

local trail = CreateFrame("Model")
trail:SetAllPoints()
trail:SetFrameStrata("FULLSCREEN_DIALOG")
trail:SetModel("spells\\lightningboltivus_missile.mdx")
trail:SetModelScale(0.0024)

local shine = CreateFrame("Model", nil, trail)
shine:SetAllPoints()
shine:SetModel("spells\\manafunnel_impact_chest.mdx")
shine:SetModelScale(0.014)

-- Model positions are in screen-diagonal units.
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
