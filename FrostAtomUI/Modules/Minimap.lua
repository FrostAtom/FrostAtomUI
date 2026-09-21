local _, ns = ...

local MinimapZoomIn = MinimapZoomIn
local MinimapZoomOut = MinimapZoomOut
local ToggleCalendar = ToggleCalendar
local ToggleDropDownMenu = ToggleDropDownMenu
local Minimap_OnClick = Minimap_OnClick
local unpack = unpack

local MinimapModule = ns:NewModule("Minimap")
MinimapModule.configKey = "minimap"
local config = ns.Config.minimap

local CLOCK_UPDATE_INTERVAL = 1

local clock

local function applyConfig()
	Minimap:SetSize(config.size, config.size)
	Minimap:ClearAllPoints()
	Minimap:SetPoint(unpack(config.point))
	MinimapBackdrop:SetBackdropBorderColor(unpack(config.borderColor))
	clock:SetFont(ns.Media.fontBold, config.clockFont.size, config.clockFont.outline)
	if config.showClock then
		clock:Show()
	else
		clock:Hide()
	end
end

function MinimapModule:Initialize()
	TimeManager_LoadUI = ns.noop

	Minimap:SetParent(UIParent)
	Minimap:SetMaskTexture(ns.Media.blank)
	Minimap:EnableMouseWheel(true)

	Minimap:SetScript("OnMouseWheel", function(_, delta)
		if delta > 0 then
			MinimapZoomIn:Click()
		elseif delta < 0 then
			MinimapZoomOut:Click()
		end
	end)

	Minimap:SetScript("OnMouseUp", function(frame, button)
		if button == "MiddleButton" then
			ToggleCalendar()
		elseif button == "RightButton" then
			ToggleDropDownMenu(1, nil, MiniMapTrackingDropDown, "cursor")
		else
			Minimap_OnClick(frame, button)
		end
	end)

	MinimapBackdrop:SetBackdrop({ edgeFile = ns.Media.border, edgeSize = 14 })
	MinimapBackdrop:ClearAllPoints()
	MinimapBackdrop:SetPoint("TOPLEFT", -3, 3)
	MinimapBackdrop:SetPoint("BOTTOMRIGHT", 3, -3)

	clock = Minimap:CreateFontString(nil, "OVERLAY")
	clock:SetPoint("BOTTOM", 0, 4)

	local untilNextTick = 0
	Minimap:SetScript("OnUpdate", function(_, elapsed)
		untilNextTick = untilNextTick - elapsed
		if untilNextTick > 0 then
			return
		end
		untilNextTick = CLOCK_UPDATE_INTERVAL

		clock:SetText(date("%H:%M"))
	end)

	GameTimeCalendarInvitesTexture:ClearAllPoints()
	GameTimeCalendarInvitesTexture:SetParent(Minimap)
	GameTimeCalendarInvitesTexture:SetPoint("TOPRIGHT")

	MiniMapInstanceDifficulty:ClearAllPoints()
	MiniMapInstanceDifficulty:SetParent(Minimap)
	MiniMapInstanceDifficulty:SetPoint("TOPRIGHT", 3, 2)

	MiniMapBattlefieldFrame:ClearAllPoints()
	MiniMapBattlefieldFrame:SetPoint("BOTTOMLEFT")

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

	applyConfig()
	self:WatchConfig("minimap", applyConfig)
end
