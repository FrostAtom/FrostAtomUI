local _, ns = ...

-- Square minimap in the top right corner with a clock and fps/latency below;
-- scroll to zoom, middle click opens the calendar.

local MinimapZoomIn = MinimapZoomIn
local MinimapZoomOut = MinimapZoomOut
local ToggleCalendar = ToggleCalendar
local ToggleDropDownMenu = ToggleDropDownMenu
local Minimap_OnClick = Minimap_OnClick
local GetFramerate = GetFramerate
local GetNetStats = GetNetStats

local STATS_UPDATE_INTERVAL = 1

TimeManager_LoadUI = ns.noop

--------------------------------------------------
-- Minimap

Minimap:SetParent(UIParent)
Minimap:ClearAllPoints()
Minimap:SetPoint("TOPRIGHT", -15, -15)
Minimap:SetMaskTexture(ns.Media.blank)
Minimap:EnableMouseWheel(true)

Minimap:SetScript("OnMouseWheel", function(_, delta)
	if delta > 0 then
		MinimapZoomIn:Click()
	elseif delta < 0 then
		MinimapZoomOut:Click()
	end
end)

-- Right click opens the tracking menu (the tracking button itself is hidden).
Minimap:SetScript("OnMouseUp", function(self, button)
	if button == "MiddleButton" then
		ToggleCalendar()
	elseif button == "RightButton" then
		ToggleDropDownMenu(1, nil, MiniMapTrackingDropDown, "cursor")
	else
		Minimap_OnClick(self, button)
	end
end)

MinimapBackdrop:SetBackdrop({ edgeFile = ns.Media.border, edgeSize = 14 })
MinimapBackdrop:SetBackdropBorderColor(1, 1, 1)
MinimapBackdrop:ClearAllPoints()
MinimapBackdrop:SetPoint("TOPLEFT", -3, 3)
MinimapBackdrop:SetPoint("BOTTOMRIGHT", 3, -3)

--------------------------------------------------
-- Clock and FPS/latency

local clock = Minimap:CreateFontString(nil, "OVERLAY")
clock:SetFont(ns.Media.fontBold, 12, "OUTLINE")
clock:SetPoint("BOTTOM", 0, 4)

-- Centered under the minimap; weapon enchant icons sit below it.
local stats = Minimap:CreateFontString(nil, "OVERLAY")
stats:SetFont(ns.Media.font, 18, "OUTLINE")
stats:SetPoint("TOP", Minimap, "BOTTOM", 0, -4)
stats:SetJustifyH("CENTER")
stats:SetTextColor(1, 0.9, 0.8)

local function latencyColor(ms)
	if ms < 100 then
		return "|cff55ff55"
	elseif ms < 250 then
		return "|cffffff55"
	else
		return "|cffff5555"
	end
end

local untilNextTick = 0
Minimap:SetScript("OnUpdate", function(_, elapsed)
	untilNextTick = untilNextTick - elapsed
	if untilNextTick > 0 then
		return
	end
	untilNextTick = STATS_UPDATE_INTERVAL

	clock:SetText(date("%H:%M"))

	local _, _, latency = GetNetStats()
	stats:SetFormattedText("%d fps  %s%d ms|r", GetFramerate(), latencyColor(latency), latency)
end)

--------------------------------------------------
-- Blizzard bits

GameTimeCalendarInvitesTexture:ClearAllPoints()
GameTimeCalendarInvitesTexture:SetParent(Minimap)
GameTimeCalendarInvitesTexture:SetPoint("TOPRIGHT")

MiniMapInstanceDifficulty:ClearAllPoints()
MiniMapInstanceDifficulty:SetParent(Minimap)
MiniMapInstanceDifficulty:SetPoint("TOPRIGHT", 3, 2)

MiniMapBattlefieldFrame:ClearAllPoints()
MiniMapBattlefieldFrame:SetPoint("BOTTOMLEFT")

-- The compass is redrawn when the rotation setting changes.
hooksecurefunc("Minimap_UpdateRotationSetting", function()
	MinimapNorthTag:Hide()
	MinimapCompassTexture:Hide()
end)

for _, object in ipairs({
	MinimapBorderTop,
	MinimapBorder,
	MinimapZoneTextButton,
	MiniMapTracking,
	MiniMapWorldMapButton,
	GameTimeFrame,
	MinimapZoomIn,
	MinimapZoomOut,
}) do
	object:Hide()
	if object.UnregisterAllEvents then
		object:UnregisterAllEvents()
	end
end

ns.DestroyFrame(MinimapCluster, true)
