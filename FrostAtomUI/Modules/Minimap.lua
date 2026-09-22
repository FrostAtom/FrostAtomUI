local _, ns = ...

local MinimapZoomIn = MinimapZoomIn
local MinimapZoomOut = MinimapZoomOut
local ToggleCalendar = ToggleCalendar
local ToggleDropDownMenu = ToggleDropDownMenu
local Minimap_OnClick = Minimap_OnClick
local GetMinimapZoneText = GetMinimapZoneText
local GetZonePVPInfo = GetZonePVPInfo

local MinimapModule = ns:NewModule("Minimap")
MinimapModule.configKey = "minimap"
local config = ns.Config.minimap

local CLOCK_UPDATE_INTERVAL = 1
local ICON_INSET = 3
local ZONE_TEXT_INSET = 4
local MAIL_ICON = "Interface\\Minimap\\Tracking\\Mailbox"
local BATTLEFIELD_ICON = "Interface\\GossipFrame\\BattleMasterGossipIcon"

local ZONE_COLORS = {
	sanctuary = { 0.41, 0.8, 0.94 },
	arena = { 1, 0.1, 0.1 },
	friendly = { 0.1, 1, 0.1 },
	hostile = { 1, 0.1, 0.1 },
	contested = { 1, 0.7, 0 },
}
local DEFAULT_ZONE_COLOR = { 1, 0.82, 0 }

local LFG_BUTTON_SIZE = 33

local clock, zoneText, lfgHolder, fader
local icons = {}

local function skinIcon(frame, icon, border, texture, point, dx, dy)
	border:Hide()
	icon:ClearAllPoints()
	icon:SetAllPoints()
	if texture then
		icon:SetTexture(texture)
	end
	icon:SetTexCoord(0, 1, 0, 1)
	icons[#icons + 1] = { frame = frame, point = point, dx = dx, dy = dy }
end

local function updateClock()
	clock:SetText(date(config.clock24h and "%H:%M" or "%I:%M %p"))
end

local function updateZoneText()
	if not config.showZoneText then
		return
	end
	zoneText:SetText(GetMinimapZoneText())
	local color = ZONE_COLORS[GetZonePVPInfo() or ""] or DEFAULT_ZONE_COLOR
	zoneText:SetTextColor(color[1], color[2], color[3])
end

local function applyLfg()
	local size = config.lfgSize
	lfgHolder:SetSize(size, size)
	ns.ApplyPoint(lfgHolder, "minimap.lfgPoint")
	MiniMapLFGFrame:SetScale(size / LFG_BUTTON_SIZE)
	MiniMapLFGFrame:ClearAllPoints()
	MiniMapLFGFrame:SetPoint("CENTER", lfgHolder)
end

local function applyConfig()
	local size, iconSize = config.size, config.iconSize
	Minimap:SetSize(size, size)
	ns.ApplyPoint(Minimap, "minimap.point")
	MinimapBackdrop:SetBackdropBorderColor(unpack(config.borderColor))
	fader:Configure(config.mouseover, config.fadeAlpha)
	applyLfg()

	ns.SetFont(clock, config.clockFont.size, config.clockFont.outline, true)
	clock:ClearAllPoints()
	clock:SetPoint(unpack(config.clockPoint))
	if config.showClock then
		clock:Show()
		updateClock()
	else
		clock:Hide()
	end

	ns.SetFont(zoneText, config.zoneFont.size, config.zoneFont.outline, true)
	zoneText:SetSize(size - ZONE_TEXT_INSET * 2, config.zoneFont.size + 4)
	if config.showZoneText then
		zoneText:Show()
		updateZoneText()
	else
		zoneText:Hide()
	end

	if config.showTracking then
		MiniMapTracking:Show()
	else
		MiniMapTracking:Hide()
	end

	for i = 1, #icons do
		local icon = icons[i]
		icon.frame:SetSize(iconSize, iconSize)
		icon.frame:ClearAllPoints()
		icon.frame:SetPoint(icon.point, icon.dx * ICON_INSET, icon.dy * ICON_INSET)
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

	zoneText = Minimap:CreateFontString(nil, "OVERLAY")
	zoneText:SetPoint("TOP", 0, -ZONE_TEXT_INSET)
	zoneText:SetJustifyH("CENTER")
	zoneText:SetNonSpaceWrap(false)

	local untilNextTick = 0
	Minimap:SetScript("OnUpdate", function(_, elapsed)
		untilNextTick = untilNextTick - elapsed
		if untilNextTick > 0 then
			return
		end
		untilNextTick = CLOCK_UPDATE_INTERVAL

		updateClock()
	end)

	GameTimeCalendarInvitesTexture:ClearAllPoints()
	GameTimeCalendarInvitesTexture:SetParent(Minimap)
	GameTimeCalendarInvitesTexture:SetPoint("TOPRIGHT")

	MiniMapInstanceDifficulty:ClearAllPoints()
	MiniMapInstanceDifficulty:SetParent(Minimap)
	MiniMapInstanceDifficulty:SetPoint("TOPRIGHT", 3, 2)

	skinIcon(MiniMapMailFrame, MiniMapMailIcon, MiniMapMailBorder, MAIL_ICON, "TOPLEFT", 1, -1)
	skinIcon(
		MiniMapBattlefieldFrame,
		MiniMapBattlefieldIcon,
		MiniMapBattlefieldBorder,
		BATTLEFIELD_ICON,
		"BOTTOMLEFT",
		1,
		1
	)
	hooksecurefunc("BattlefieldFrame_UpdateStatus", function()
		MiniMapBattlefieldIcon:SetTexture(BATTLEFIELD_ICON)
	end)

	MiniMapTracking:SetParent(Minimap)
	MiniMapTracking:SetFrameLevel(Minimap:GetFrameLevel() + 2)
	MiniMapTrackingButton:ClearAllPoints()
	MiniMapTrackingButton:SetAllPoints(MiniMapTracking)
	MiniMapTrackingButton:SetScript("OnMouseDown", nil)
	MiniMapTrackingButton:SetScript("OnMouseUp", nil)
	MiniMapTrackingButtonBorder:Hide()
	skinIcon(MiniMapTracking, MiniMapTrackingIcon, MiniMapTrackingBackground, nil, "BOTTOMRIGHT", -1, 1)

	hooksecurefunc("Minimap_UpdateRotationSetting", function()
		MinimapNorthTag:Hide()
		MinimapCompassTexture:Hide()
	end)

	for _, object in ipairs({
		MinimapBorderTop,
		MinimapBorder,
		MinimapZoneTextButton,
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

	lfgHolder = CreateFrame("Frame", "FrostAtomUILFG", UIParent)
	MiniMapLFGFrame:SetParent(lfgHolder)
	MiniMapLFGFrame:SetFrameStrata("MEDIUM")

	fader = ns.CreateFader({ Minimap, MinimapBackdrop }, { Minimap })

	applyConfig()
	self:RegisterMover(lfgHolder, "minimap.lfgPoint", "Queue eye", {
		size = function()
			return config.lfgSize, config.lfgSize
		end,
		resize = {
			square = true,
			minWidth = 16,
			maxWidth = 96,
			get = function()
				return config.lfgSize, config.lfgSize
			end,
			set = function(size)
				ns:SetConfig("minimap.lfgSize", size)
			end,
		},
	})
	self:WatchConfig("minimap", applyConfig)
	self:RegisterEvent("ZONE_CHANGED", updateZoneText)
	self:RegisterEvent("ZONE_CHANGED_INDOORS", updateZoneText)
	self:RegisterEvent("ZONE_CHANGED_NEW_AREA", updateZoneText)
	self:RegisterEvent("PLAYER_ENTERING_WORLD", updateZoneText)
	self:RegisterMover(Minimap, "minimap.point", "Minimap", {
		resize = {
			square = true,
			minWidth = 100,
			maxWidth = 400,
			get = function()
				return config.size, config.size
			end,
			set = function(size)
				ns:SetConfig("minimap.size", size)
			end,
		},
	})
end
