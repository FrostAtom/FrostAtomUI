local namespace = select(2,...)


local MinimapZoomIn = MinimapZoomIn
local MinimapZoomOut = MinimapZoomOut
local ToggleCalendar = ToggleCalendar
local Minimap_OnClick = Minimap_OnClick


local function Minimap_UpdateRotationSetting()
	MinimapNorthTag:Hide()
	MinimapCompassTexture:Hide()
end

local function Minimap_OnMouseWheel(self,delta)
	if delta > 0 then
		MinimapZoomIn:Click()
	elseif delta < 0 then
		MinimapZoomOut:Click()
	end
end

TimeManager_LoadUI = namespace.null

local clock = Minimap:CreateFontString(nil,"OVERLAY")
clock:SetFont("Fonts/FRIZQT__.ttf",12,"OUTLINE")
clock:SetPoint("BOTTOM",0,4)

local remain = 0
Minimap:SetScript("OnUpdate",function(self,elapsed)
	remain = remain - elapsed
	if remain <= 0 then
		remain = 1
		clock:SetText(date("%H:%M"))
	end
end)
Minimap:SetScript("OnMouseUp",function(self,button)
	if button == "MiddleButton" then
		ToggleCalendar()
	else
		Minimap_OnClick(self,button)
	end
end)

Minimap:ClearAllPoints()
Minimap:SetParent(UIParent)
Minimap:SetPoint("TOPRIGHT",-15,-15)
Minimap:SetMaskTexture("Interface\\Buttons\\WHITE8x8")
Minimap:EnableMouseWheel(true)
Minimap:SetScript("OnMouseWheel",Minimap_OnMouseWheel)

MinimapBackdrop:SetBackdrop{edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 14}
MinimapBackdrop:SetBackdropBorderColor(1,1,1)
MinimapBackdrop:ClearAllPoints()
MinimapBackdrop:SetPoint("TOPLEFT",-3,3)
MinimapBackdrop:SetPoint("BOTTOMRIGHT",3,-3)

GameTimeCalendarInvitesTexture:ClearAllPoints()
GameTimeCalendarInvitesTexture:SetParent(Minimap)
GameTimeCalendarInvitesTexture:SetPoint("TOPRIGHT")

MiniMapInstanceDifficulty:ClearAllPoints()
MiniMapInstanceDifficulty:SetParent(Minimap)
MiniMapInstanceDifficulty:SetPoint("TOPRIGHT",3,2)

MiniMapBattlefieldFrame:ClearAllPoints()
MiniMapBattlefieldFrame:SetPoint("BOTTOMLEFT")


hooksecurefunc("Minimap_UpdateRotationSetting",Minimap_UpdateRotationSetting)
do
	local tbl = {
		MinimapBorderTop,
		MinimapBorder,
		MinimapZoneTextButton,
		MiniMapTracking,
		MiniMapWorldMapButton,
		GameTimeFrame,
		MinimapZoomIn,
		MinimapZoomOut,
		MinimapTracking
	}

	local obj
	for i = 1,#tbl do
		obj = tbl[i]

		obj:Hide()
		if obj.UnregisterAllEvents then
			obj:UnregisterAllEvents()
		end
	end
end

namespace.destroyObject(MinimapCluster,true)