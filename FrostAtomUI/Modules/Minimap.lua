local _, ns = ...

local MinimapZoomIn = MinimapZoomIn
local MinimapZoomOut = MinimapZoomOut
local ToggleCalendar = ToggleCalendar
local ToggleDropDownMenu = ToggleDropDownMenu
local Minimap_OnClick = Minimap_OnClick
local GetMinimapZoneText = GetMinimapZoneText
local GetZonePVPInfo = GetZonePVPInfo
local ToggleFrame = ToggleFrame
local floor, ceil, min = math.floor, math.ceil, math.min

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

local BLIP_HIDE_ALPHA = 0.5
local BLIP_TEXTURES = {
	SetBlipTexture = "Interface\\Minimap\\ObjectIcons",
	SetIconTexture = "Interface\\Minimap\\POIIcons",
	SetClassBlipTexture = "Interface\\Minimap\\PartyRaidBlips",
	SetPlayerTexture = "Interface\\Minimap\\MinimapArrow",
	SetPOIArrowTexture = "Interface\\Minimap\\ROTATING-MINIMAPGUIDEARROW",
	SetStaticPOIArrowTexture = "Interface\\Minimap\\ROTATING-MINIMAPARROW",
	SetCorpsePOIArrowTexture = "Interface\\Minimap\\ROTATING-MINIMAPCORPSEARROW",
}

local COLLECTOR_TICKER = "FrostAtomUI_MinimapButtons"
local COLLECTOR_INTERVAL = 1
local COLLECTOR_CELL = 32
local COLLECTOR_COLUMNS = 4
local COLLECTOR_PADDING = 6
local COLLECTOR_TOGGLE_SIZE = 14
local COLLECTOR_GLYPH_SIZE = 10
local COLLECTOR_GLYPH_OPEN = "chevron-right"
local COLLECTOR_GLYPH_CLOSED = "chevron-left"

local IGNORED_BUTTONS = {
	MiniMapTrackingButton = true,
	MiniMapBattlefieldFrame = true,
	MiniMapMailFrame = true,
	MiniMapLFGFrame = true,
	MiniMapVoiceChatFrame = true,
	MiniMapWorldMapButton = true,
	MiniMapInstanceDifficulty = true,
	MinimapZoomIn = true,
	MinimapZoomOut = true,
	MinimapZoneTextButton = true,
	GameTimeFrame = true,
	TimeManagerClockButton = true,
}
local IGNORED_PATTERNS = {
	"^FrostAtomUI",
	"Pin",
	"Node",
	"Note",
	"^GatherMate",
	"^Questie",
	"^TomTom",
	"^Routes",
	"^QuestHelper",
	"^Carbonite",
}

local clock, zoneText, zoneButton, lfgHolder, fader
local cornerIcons = {}
local blipsHidden = false
local blipSetters, blipTextures = {}, {}

local function setBlipsHidden(hidden)
	if hidden == blipsHidden then
		return
	end
	blipsHidden = hidden
	for method, set in pairs(blipSetters) do
		set(Minimap, hidden and ns.Media.transparent or blipTextures[method])
	end
end

local function guardBlipTextures()
	for method, texture in pairs(BLIP_TEXTURES) do
		local set = Minimap[method]
		blipSetters[method], blipTextures[method] = set, texture
		Minimap[method] = function(self, path)
			blipTextures[method] = path
			if not blipsHidden then
				set(self, path)
			end
		end
	end
end

local function refreshTerrain()
	local zoom = Minimap:GetZoom()
	Minimap:SetZoom(zoom > 0 and zoom - 1 or zoom + 1)
	Minimap:SetZoom(zoom)
end

local collectorPanel, collectorToggle
local collected, collectedState, hookedButtons = {}, {}, {}
local lastChildCount = -1

local function methodsOf(frame)
	return getmetatable(frame).__index
end

local function layoutCollector()
	local shown = 0
	for i = 1, #collected do
		local button = collected[i]
		if button:IsShown() then
			local methods = methodsOf(button)
			local column, row = shown % COLLECTOR_COLUMNS, floor(shown / COLLECTOR_COLUMNS)
			methods.ClearAllPoints(button)
			methods.SetPoint(
				button,
				"CENTER",
				collectorPanel,
				"TOPRIGHT",
				-COLLECTOR_PADDING - (column + 0.5) * COLLECTOR_CELL,
				-COLLECTOR_PADDING - (row + 0.5) * COLLECTOR_CELL
			)
			shown = shown + 1
		end
	end
	if shown == 0 then
		collectorToggle:Hide()
		collectorPanel:Hide()
		return
	end
	local columns, rows = min(shown, COLLECTOR_COLUMNS), ceil(shown / COLLECTOR_COLUMNS)
	collectorPanel:SetSize(
		columns * COLLECTOR_CELL + COLLECTOR_PADDING * 2,
		rows * COLLECTOR_CELL + COLLECTOR_PADDING * 2
	)
	collectorToggle:Show()
end

local function onCollectedVisibility(button)
	if collectedState[button] then
		layoutCollector()
	end
end

local function isCollectable(child)
	if child:GetObjectType() ~= "Button" or collectedState[child] then
		return false
	end
	local name = child:GetName()
	if not name or IGNORED_BUTTONS[name] then
		return false
	end
	if name:find("^LibDBIcon10_") then
		return true
	end
	for i = 1, #IGNORED_PATTERNS do
		if name:find(IGNORED_PATTERNS[i]) then
			return false
		end
	end
	return true
end

local function collectButton(button)
	local state = { parent = button:GetParent(), strata = button:GetFrameStrata() }
	for i = 1, button:GetNumPoints() do
		state[i] = { button:GetPoint(i) }
	end
	collectedState[button] = state
	collected[#collected + 1] = button
	button:SetParent(collectorPanel)
	button:SetFrameStrata(collectorPanel:GetFrameStrata())
	button.SetPoint, button.ClearAllPoints = ns.noop, ns.noop
	if not hookedButtons[button] then
		hookedButtons[button] = true
		button:HookScript("OnShow", onCollectedVisibility)
		button:HookScript("OnHide", onCollectedVisibility)
	end
end

local function collectFrom(frame)
	local children = { frame:GetChildren() }
	for i = 1, #children do
		local child = children[i]
		if isCollectable(child) then
			collectButton(child)
		end
	end
end

local function childCount()
	return Minimap:GetNumChildren() + MinimapBackdrop:GetNumChildren()
end

local function scanButtons()
	local count = childCount()
	if count == lastChildCount then
		return
	end
	local before = #collected
	pcall(collectFrom, Minimap)
	pcall(collectFrom, MinimapBackdrop)
	lastChildCount = childCount()
	if #collected ~= before then
		layoutCollector()
	end
end

local function releaseButtons()
	for i = #collected, 1, -1 do
		local button = collected[i]
		local state = collectedState[button]
		collected[i], collectedState[button] = nil, nil
		button.SetPoint, button.ClearAllPoints = nil, nil
		button:SetParent(state.parent)
		button:SetFrameStrata(state.strata)
		button:ClearAllPoints()
		for j = 1, #state do
			button:SetPoint(unpack(state[j]))
		end
	end
	lastChildCount = -1
end

local function setCollectorOpen(open)
	ns.SetShown(collectorPanel, open)
	ns.SetGlyph(collectorToggle.glyph, open and COLLECTOR_GLYPH_OPEN or COLLECTOR_GLYPH_CLOSED)
end

local function createCollector()
	collectorPanel = CreateFrame("Frame", "FrostAtomUIMinimapButtons", UIParent)
	collectorPanel:Hide()
	collectorPanel:SetFrameStrata("HIGH")
	collectorPanel:SetClampedToScreen(true)
	collectorPanel:SetPoint("TOPRIGHT", Minimap, "TOPLEFT", -ICON_INSET - 3, 3)
	collectorPanel:SetBackdrop(ns.CreateBackdrop(14, 3))
	collectorPanel:SetBackdropColor(0, 0, 0, 0.8)

	collectorToggle = ns.CreateGlyphButton(
		Minimap,
		COLLECTOR_GLYPH_CLOSED,
		COLLECTOR_GLYPH_SIZE,
		nil,
		"FrostAtomUIMinimapButtonsToggle"
	)
	ns.SetGlyph(collectorToggle.glyph, COLLECTOR_GLYPH_CLOSED, COLLECTOR_GLYPH_SIZE, "OUTLINE")
	collectorToggle:Hide()
	collectorToggle:SetSize(COLLECTOR_TOGGLE_SIZE, COLLECTOR_TOGGLE_SIZE)
	collectorToggle:SetPoint("LEFT", ICON_INSET, 0)
	collectorToggle:SetFrameLevel(Minimap:GetFrameLevel() + 2)
	collectorToggle:SetScript("OnClick", function()
		setCollectorOpen(not collectorPanel:IsShown())
	end)
end

local function applyCollector()
	if config.collectButtons then
		if not collectorPanel then
			createCollector()
		end
		collectorPanel:SetBackdropBorderColor(unpack(config.borderColor))
		ns.Scheduler.AddTicker(COLLECTOR_TICKER, scanButtons, COLLECTOR_INTERVAL)
		scanButtons()
	elseif collectorPanel then
		ns.Scheduler.RemoveTicker(COLLECTOR_TICKER)
		releaseButtons()
		setCollectorOpen(false)
		collectorToggle:Hide()
	end
end

local function skinCornerIcon(frame, icon, border, texture, point, dx, dy)
	border:Hide()
	icon:ClearAllPoints()
	icon:SetAllPoints()
	if texture then
		icon:SetTexture(texture)
	end
	icon:SetTexCoord(0, 1, 0, 1)
	cornerIcons[#cornerIcons + 1] = { frame = frame, point = point, dx = dx, dy = dy }
end

local function getLfgSize()
	return config.lfgSize, config.lfgSize
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
	zoneButton:SetSize(min(zoneText:GetStringWidth(), zoneText:GetWidth()) + 4, zoneText:GetHeight())
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
	fader:Configure(config.mouseover, config.fadeAlpha, config.combat)
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
		zoneButton:Show()
		updateZoneText()
	else
		zoneText:Hide()
		zoneButton:Hide()
	end

	if config.showTracking then
		MiniMapTracking:Show()
	else
		MiniMapTracking:Hide()
	end

	for i = 1, #cornerIcons do
		local icon = cornerIcons[i]
		icon.frame:SetSize(iconSize, iconSize)
		icon.frame:ClearAllPoints()
		icon.frame:SetPoint(icon.point, icon.dx * ICON_INSET, icon.dy * ICON_INSET)
	end
	applyCollector()
end

function MinimapModule:Initialize()
	TimeManager_LoadUI = ns.noop
	function GetMinimapShape()
		return "SQUARE"
	end

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

	zoneButton = CreateFrame("Button", nil, Minimap)
	zoneButton:SetPoint("CENTER", zoneText)
	zoneButton:SetFrameLevel(Minimap:GetFrameLevel() + 2)
	zoneButton:SetScript("OnClick", function()
		ToggleFrame(WorldMapFrame)
	end)

	local untilNextTick = 0
	Minimap:SetScript("OnUpdate", function(_, elapsed)
		untilNextTick = untilNextTick - elapsed
		if untilNextTick <= 0 then
			untilNextTick = CLOCK_UPDATE_INTERVAL
			updateClock()
		end
	end)

	GameTimeCalendarInvitesTexture:ClearAllPoints()
	GameTimeCalendarInvitesTexture:SetParent(Minimap)
	GameTimeCalendarInvitesTexture:SetPoint("TOPRIGHT")

	MiniMapInstanceDifficulty:ClearAllPoints()
	MiniMapInstanceDifficulty:SetParent(Minimap)
	MiniMapInstanceDifficulty:SetPoint("TOPRIGHT", 3, 2)

	skinCornerIcon(MiniMapMailFrame, MiniMapMailIcon, MiniMapMailBorder, MAIL_ICON, "TOPLEFT", 1, -1)
	skinCornerIcon(
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
	skinCornerIcon(MiniMapTracking, MiniMapTrackingIcon, MiniMapTrackingBackground, nil, "BOTTOMRIGHT", -1, 1)

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

	guardBlipTextures()
	fader = ns.CreateFader({ Minimap, MinimapBackdrop }, { Minimap })
	local faderSetAlpha = fader.SetAlpha
	function fader:SetAlpha(alpha)
		local wasInvisible = self.current <= 0
		faderSetAlpha(self, alpha)
		setBlipsHidden(alpha < BLIP_HIDE_ALPHA)
		if wasInvisible and alpha > 0 then
			refreshTerrain()
		end
	end

	applyConfig()
	self:RegisterMover(lfgHolder, "minimap.lfgPoint", "Queue eye", {
		size = getLfgSize,
		resize = {
			square = true,
			minWidth = 16,
			maxWidth = 96,
			get = getLfgSize,
			set = function(size)
				ns:SetConfig("minimap.lfgSize", size)
			end,
		},
	})
	self:WatchConfig("minimap", applyConfig)
	for _, event in ipairs({ "ZONE_CHANGED", "ZONE_CHANGED_INDOORS", "ZONE_CHANGED_NEW_AREA", "PLAYER_ENTERING_WORLD" }) do
		self:RegisterEvent(event, updateZoneText)
	end
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
