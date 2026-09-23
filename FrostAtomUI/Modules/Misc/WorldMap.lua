local _, ns = ...

local L = ns.L

local Misc = ns:GetModule("Misc")

Misc:OnInitialize(function()
	if not ns.Config.worldMap.enabled then
		return
	end

	local WorldMapFrame = WorldMapFrame
	local WorldMapDetailFrame = WorldMapDetailFrame
	local WorldMapButton = WorldMapButton
	local WorldMapBlobFrame = WorldMapBlobFrame
	local WorldMapPOIFrame = WorldMapPOIFrame
	local WorldMapPlayer = WorldMapPlayer
	local WorldMapCorpse = WorldMapCorpse
	local WorldMapDeathRelease = WorldMapDeathRelease
	local WorldMapHighlight = WorldMapHighlight
	local WorldMapPositioningGuide = WorldMapPositioningGuide
	local WorldMapFrameAreaLabel = WorldMapFrameAreaLabel
	local PlayerArrowFrame = PlayerArrowFrame
	local BlackoutWorld = BlackoutWorld
	local WORLDMAP_SETTINGS = WORLDMAP_SETTINGS
	local MAP_VEHICLES = MAP_VEHICLES
	local VEHICLE_TEXTURES = VEHICLE_TEXTURES
	local GetScreenHeight = GetScreenHeight
	local GetCursorPosition = GetCursorPosition
	local GetPlayerMapPosition = GetPlayerMapPosition
	local GetCurrentMapZone = GetCurrentMapZone
	local GetCurrentMapContinent = GetCurrentMapContinent
	local SetMapToCurrentZone = SetMapToCurrentZone
	local GetNumRaidMembers = GetNumRaidMembers
	local GetBattlefieldPosition = GetBattlefieldPosition
	local GetNumBattlefieldFlagPositions = GetNumBattlefieldFlagPositions
	local GetBattlefieldFlagPosition = GetBattlefieldFlagPosition
	local GetCorpseMapPosition = GetCorpseMapPosition
	local GetDeathReleasePosition = GetDeathReleasePosition
	local GetNumBattlefieldVehicles = GetNumBattlefieldVehicles
	local GetBattlefieldVehicleInfo = GetBattlefieldVehicleInfo
	local UpdateMapHighlight = UpdateMapHighlight
	local UpdateWorldMapArrowFrames = UpdateWorldMapArrowFrames
	local ShowWorldMapArrowFrame = ShowWorldMapArrowFrame
	local WorldMap_GetVehicleTexture = WorldMap_GetVehicleTexture
	local UnitClass = UnitClass
	local UnitIsUnit = UnitIsUnit
	local UnitIsGhost = UnitIsGhost
	local UnitIsDeadOrGhost = UnitIsDeadOrGhost
	local InCombatLockdown = InCombatLockdown
	local max, min, abs = math.max, math.min, math.abs

	local UF = ns:GetModule("UnitFrames")
	local classColors = UF.classColors

	local LAYOUT_WIDTH, LAYOUT_HEIGHT = 1024, 768
	local MAP_WIDTH, MAP_HEIGHT = 1002, 668
	local MIN_ZOOM = 1
	local UNIT_ICON_DEFAULT = "Interface\\WorldMap\\WorldMapPartyIcon"
	local COORD_FORMAT = "%s: %.1f, %.1f"

	local partyFrames, partyUnits = {}, {}
	for i = 1, MAX_PARTY_MEMBERS do
		partyFrames[i] = _G["WorldMapParty" .. i]
		partyUnits[i] = "party" .. i
	end
	local raidFrames, raidUnits = {}, {}
	for i = 1, MAX_RAID_MEMBERS do
		raidFrames[i] = _G["WorldMapRaid" .. i]
		raidUnits[i] = "raid" .. i
	end
	local flagFrames, flagTextures = {}, {}
	for i = 1, NUM_WORLDMAP_FLAGS do
		flagFrames[i] = _G["WorldMapFlag" .. i]
		flagTextures[i] = _G["WorldMapFlag" .. i .. "Texture"]
	end

	local highlightTextures = setmetatable({}, {
		__index = function(t, fileName)
			local path = "Interface\\WorldMap\\" .. fileName .. "\\" .. fileName .. "Highlight"
			t[fileName] = path
			return path
		end,
	})

	local flagTexturePaths = setmetatable({}, {
		__index = function(t, token)
			local path = "Interface\\WorldStateFrame\\" .. token
			t[token] = path
			return path
		end,
	})

	BlackoutWorld:SetTexture(nil)

	WorldMapFrame:SetParent(UIParent)
	WorldMapFrame.SetParent = ns.noop
	WorldMapFrame:EnableMouse(false)
	WorldMapFrame.EnableMouse = ns.noop
	WorldMapFrame:EnableKeyboard(false)
	WorldMapFrame.EnableKeyboard = ns.noop

	local function layout()
		if WORLDMAP_SETTINGS.size == WORLDMAP_WINDOWED_SIZE then
			WorldMapFrame:SetScale(1)
			return
		end

		UIPanelWindows.WorldMapFrame.area = "center"
		UIPanelWindows.WorldMapFrame.allowOtherPanels = true
		WorldMapFrame:SetAttribute("UIPanelLayout-area", "center")
		WorldMapFrame:SetAttribute("UIPanelLayout-allowOtherPanels", true)
		WorldMapFrame:SetScale(GetScreenHeight() * ns.Config.worldMap.screenFraction / LAYOUT_HEIGHT)
		WorldMapFrame:ClearAllPoints()
		WorldMapFrame:SetSize(LAYOUT_WIDTH, LAYOUT_HEIGHT)
		WorldMapFrame:SetPoint("CENTER", UIParent)
	end

	hooksecurefunc("ToggleMapFramerate", layout)
	WorldMapFrame:HookScript("OnShow", layout)

	local scroll = CreateFrame("ScrollFrame", nil, WorldMapFrame)
	scroll:SetSize(MAP_WIDTH, MAP_HEIGHT)
	scroll:EnableMouseWheel(true)
	WorldMapDetailFrame:SetParent(scroll)
	scroll:SetScrollChild(WorldMapDetailFrame)

	local zoom = 1
	local maxScrollX, maxScrollY = 0, 0
	local panning, moved, panStartX, panStartY, scrollStartX, scrollStartY

	local function redrawBlob()
		local quest = WORLDMAP_SETTINGS.selectedQuest
		if not quest or InCombatLockdown() then
			return
		end
		WorldMapBlobFrame:DrawQuestBlob(quest.questId, false)
		if WorldMapBlobFrame:IsShown() and not quest.completed then
			WorldMapBlobFrame:DrawQuestBlob(quest.questId, true)
		end
	end

	local function layoutBlob()
		if InCombatLockdown() then
			return
		end
		WorldMapBlobFrame:SetParent(WorldMapDetailFrame)
		WorldMapBlobFrame:ClearAllPoints()
		WorldMapBlobFrame:SetAllPoints(WorldMapDetailFrame)
		WorldMapBlobFrame:SetScale(zoom)
		WorldMapBlobFrame.xRatio = nil
	end

	local function setScroll(x, y)
		scroll:SetHorizontalScroll(min(max(x, 0), maxScrollX))
		scroll:SetVerticalScroll(min(max(y, 0), maxScrollY))
	end

	local function scaleAll(frames, scale)
		for i = 1, #frames do
			frames[i]:SetScale(scale)
		end
	end

	local function setZoom(scale)
		zoom = scale
		local inverse = 1 / scale

		WorldMapDetailFrame:SetScale(scale)
		WorldMapPOIFrame:SetScale(1 / WORLDMAP_SETTINGS.size)
		WorldMapBlobFrame:SetScale(scale)
		WorldMapBlobFrame.xRatio = nil

		WorldMapPlayer:SetScale(inverse)
		WorldMapCorpse:SetScale(inverse)
		WorldMapDeathRelease:SetScale(inverse)
		scaleAll(flagFrames, inverse)
		scaleAll(partyFrames, inverse)
		scaleAll(raidFrames, inverse)
		scaleAll(MAP_VEHICLES, inverse)

		maxScrollX = MAP_WIDTH - MAP_WIDTH * inverse
		maxScrollY = MAP_HEIGHT - MAP_HEIGHT * inverse
	end

	local function resetZoom()
		setZoom(MIN_ZOOM)
		setScroll(0, 0)
		WorldMapFrame_UpdateQuests()
		redrawBlob()
	end

	local function reanchor(frame, relativeTo)
		local point, oldRelativeTo, relativePoint, x, y = frame:GetPoint()
		if oldRelativeTo == WorldMapDetailFrame then
			frame:ClearAllPoints()
			frame:SetPoint(point, relativeTo, relativePoint, x, y)
		end
	end

	local SCROLL_ANCHORED_FRAMES = {
		WorldMapQuestScrollFrame,
		WorldMapQuestDetailScrollFrame,
		WorldMapTrackQuest,
		WorldMapQuestShowObjectives,
		WorldMapFrameTitle,
	}

	local coords = CreateFrame("Frame", nil, WorldMapFrame)
	coords:SetFrameLevel(WORLDMAP_POI_FRAMELEVEL)
	local cursorText = coords:CreateFontString(nil, "OVERLAY")
	local playerText = coords:CreateFontString(nil, "OVERLAY")

	local function applyConfig()
		local config = ns.Config.worldMap
		local font = config.coordFont
		ns.SetFont(cursorText, font.size, font.outline)
		ns.SetFont(playerText, font.size, font.outline)
		if config.showCoords then
			coords:Show()
		else
			coords:Hide()
		end
		WorldMapPlayer:SetSize(config.arrowSize, config.arrowSize)
		if WorldMapFrame:IsShown() then
			layout()
			if zoom > config.maxZoom then
				resetZoom()
			end
		end
	end

	applyConfig()
	Misc:WatchConfig("worldMap", applyConfig)

	local function captureDetailAnchor()
		local point, relativeTo, relativePoint, x, y = WorldMapDetailFrame:GetPoint()
		if not point or (relativeTo == scroll and x == 0 and y == 0) then
			return
		end
		if relativeTo == scroll then
			relativeTo = WorldMapFrame
		end
		scroll:ClearAllPoints()
		scroll:SetPoint(point, relativeTo, relativePoint, x, y)
		WorldMapDetailFrame:ClearAllPoints()
		WorldMapDetailFrame:SetPoint("TOPLEFT", scroll, "TOPLEFT", 0, 0)
	end

	local function applyLayout()
		local size = WORLDMAP_SETTINGS.size

		captureDetailAnchor()
		cursorText:ClearAllPoints()
		playerText:ClearAllPoints()
		if size == WORLDMAP_WINDOWED_SIZE then
			cursorText:SetPoint("BOTTOMLEFT", scroll, "BOTTOM", 20, -22)
			playerText:SetPoint("BOTTOMRIGHT", scroll, "BOTTOM", -20, -22)
		else
			cursorText:SetPoint("BOTTOMLEFT", WorldMapPositioningGuide, "BOTTOM", 50, 10)
			playerText:SetPoint("BOTTOMRIGHT", WorldMapPositioningGuide, "BOTTOM", -50, 10)
		end
		scroll:SetScale(size)

		WorldMapButton:SetParent(WorldMapDetailFrame)
		WorldMapButton:SetScale(1)
		WorldMapButton:ClearAllPoints()
		WorldMapButton:SetAllPoints(WorldMapDetailFrame)
		WorldMapPOIFrame:SetParent(WorldMapDetailFrame)
		WorldMapPlayer:SetParent(WorldMapDetailFrame)

		for i = 1, #SCROLL_ANCHORED_FRAMES do
			reanchor(SCROLL_ANCHORED_FRAMES[i], scroll)
		end

		setZoom(zoom)
		setScroll(scroll:GetHorizontalScroll(), scroll:GetVerticalScroll())
		layoutBlob()
	end

	local function setup()
		zoom = MIN_ZOOM
		applyLayout()
		setScroll(0, 0)
		WorldMapFrame_UpdateQuests()
	end

	local LAYOUT_HOOKS = {
		"WorldMapFrame_SetFullMapView",
		"WorldMapFrame_SetQuestMapView",
		"WorldMapFrame_SetMiniMode",
		"WorldMapFrame_ToggleAdvanced",
		"WorldMap_ToggleSizeUp",
		"WorldMap_ToggleSizeDown",
	}
	for i = 1, #LAYOUT_HOOKS do
		local name = LAYOUT_HOOKS[i]
		if _G[name] then
			hooksecurefunc(name, applyLayout)
		end
	end
	WorldMapFrame:HookScript("OnShow", setup)

	hooksecurefunc("WorldMapQuestShowObjectives_AdjustPosition", function()
		reanchor(WorldMapQuestShowObjectives, scroll)
	end)

	hooksecurefunc("WorldMapFrame_DisplayQuestPOI", function(questFrame)
		local _, x, y = QuestPOIGetIconInfo(questFrame.questId)
		local icon = questFrame.poiIcon
		if not (x and icon) then
			return
		end
		icon:SetScale(WORLDMAP_SETTINGS.size / zoom)
		icon:SetPoint(
			"CENTER",
			WorldMapPOIFrame,
			"TOPLEFT",
			x * WorldMapDetailFrame:GetWidth() * zoom,
			-y * WorldMapDetailFrame:GetHeight() * zoom
		)
	end)

	WorldMapFrameAreaFrame:SetParent(WorldMapFrame)
	WorldMapFrameAreaFrame:SetFrameLevel(WORLDMAP_POI_FRAMELEVEL)
	WorldMapFrameAreaFrame:ClearAllPoints()
	WorldMapFrameAreaFrame:SetPoint("TOP", scroll, "TOP", 0, -10)

	WorldMapPing.Show = ns.noop
	WorldMapPing:SetModelScale(0)

	WorldMapPlayer:ClearAllPoints()
	WorldMapPlayer.arrow = WorldMapPlayer:CreateTexture(nil, "ARTWORK")
	WorldMapPlayer.arrow:SetAllPoints()
	WorldMapPlayer.arrow:SetTexture(ns.Media.mapArrow)

	local function colorUnitIcon(frame, unit)
		local icon = frame.icon
		icon:SetTexture(ns.Media.mapUnit)
		if UnitIsDeadOrGhost(unit) then
			icon:SetVertexColor(0.3, 0.3, 0.3)
			return
		end
		local _, class = UnitClass(unit)
		local color = classColors[class]
		if color then
			icon:SetVertexColor(color[1], color[2], color[3])
		else
			icon:SetVertexColor(0.8, 0.8, 0.8)
		end
	end

	local mapWidth, mapHeight = 0, 0

	local function isOffMap(x, y)
		return x == 0 and y == 0
	end

	local function placeUnit(frame, x, y)
		frame:SetPoint("CENTER", WorldMapDetailFrame, "TOPLEFT", x * mapWidth, -y * mapHeight)
		frame:Show()
	end

	local function onPan()
		local x, y = GetCursorPosition()
		local scale = WorldMapButton:GetEffectiveScale()
		local dx = (panStartX - x) / scale
		local dy = (y - panStartY) / scale
		if abs(dx) >= 1 or abs(dy) >= 1 then
			moved = true
			setScroll(scrollStartX + dx, scrollStartY + dy)
			redrawBlob()
		end
	end

	local function updateCursorHighlight(button)
		local scale = button:GetEffectiveScale()
		local x, y = GetCursorPosition()
		x, y = x / scale, y / scale
		local width, height = button:GetWidth(), button:GetHeight()
		local centerX, centerY = button:GetCenter()
		local adjustedX = (x - (centerX - width / 2)) / width
		local adjustedY = (centerY + height / 2 - y) / height

		local name, fileName, texPercentX, texPercentY, textureX, textureY, scrollChildX, scrollChildY
		if button:IsMouseOver() and scroll:IsMouseOver() then
			name, fileName, texPercentX, texPercentY, textureX, textureY, scrollChildX, scrollChildY =
				UpdateMapHighlight(adjustedX, adjustedY)
			cursorText:SetFormattedText(COORD_FORMAT, L["Cursor"], adjustedX * 100, adjustedY * 100)
		else
			cursorText:SetText("")
		end

		WorldMapFrame.areaName = name
		if not WorldMapFrame.poiHighlight then
			WorldMapFrameAreaLabel:SetText(name)
		end
		if not fileName then
			WorldMapHighlight:Hide()
			return
		end
		WorldMapHighlight:SetTexCoord(0, texPercentX, 0, texPercentY)
		WorldMapHighlight:SetTexture(highlightTextures[fileName])
		textureX = textureX * width
		textureY = textureY * height
		if textureX > 0 and textureY > 0 then
			WorldMapHighlight:SetSize(textureX, textureY)
			WorldMapHighlight:SetPoint(
				"TOPLEFT",
				WorldMapDetailFrame,
				"TOPLEFT",
				scrollChildX * width,
				-scrollChildY * height
			)
			WorldMapHighlight:Show()
		end
	end

	local function updatePlayerMarker()
		UpdateWorldMapArrowFrames()
		ShowWorldMapArrowFrame(nil)
		local playerX, playerY = GetPlayerMapPosition("player")
		if isOffMap(playerX, playerY) then
			WorldMapPlayer:Hide()
			playerText:SetText("")
		else
			WorldMapPlayer.arrow:SetRotation(PlayerArrowFrame:GetFacing())
			placeUnit(WorldMapPlayer, playerX, playerY)
			playerText:SetFormattedText(COORD_FORMAT, L["Player"], playerX * 100, playerY * 100)
		end
	end

	local function updateRaidMarkers()
		for i = 1, #partyFrames do
			partyFrames[i]:Hide()
		end
		local shown = 0
		for i = 1, #raidFrames do
			local unit = raidUnits[i]
			local unitX, unitY = GetPlayerMapPosition(unit)
			local frame = raidFrames[shown + 1]
			if isOffMap(unitX, unitY) or UnitIsUnit(unit, "player") then
				frame:Hide()
			else
				frame.name = nil
				frame.unit = unit
				colorUnitIcon(frame, unit)
				placeUnit(frame, unitX, unitY)
				shown = shown + 1
			end
		end
		return shown
	end

	local function updatePartyMarkers()
		for i = 1, #partyFrames do
			local unit = partyUnits[i]
			local unitX, unitY = GetPlayerMapPosition(unit)
			local frame = partyFrames[i]
			if isOffMap(unitX, unitY) then
				frame:Hide()
			else
				colorUnitIcon(frame, unit)
				placeUnit(frame, unitX, unitY)
			end
		end
	end

	local function updateBattlefieldMarkers(raidShown)
		for i = raidShown + 1, #raidFrames do
			local unitX, unitY, unitName = GetBattlefieldPosition(i - raidShown)
			local frame = raidFrames[i]
			if isOffMap(unitX, unitY) then
				frame:Hide()
			else
				frame.name = unitName
				frame.unit = nil
				frame.icon:SetTexture(UNIT_ICON_DEFAULT)
				frame.icon:SetVertexColor(1, 1, 1)
				placeUnit(frame, unitX, unitY)
			end
		end
	end

	local function updateFlagMarkers()
		local numFlags = GetNumBattlefieldFlagPositions()
		for i = 1, #flagFrames do
			local frame = flagFrames[i]
			local flagX, flagY, flagToken = 0, 0, nil
			if i <= numFlags then
				flagX, flagY, flagToken = GetBattlefieldFlagPosition(i)
			end
			if isOffMap(flagX, flagY) then
				frame:Hide()
			else
				flagTextures[i]:SetTexture(flagTexturePaths[flagToken])
				placeUnit(frame, flagX, flagY)
			end
		end
	end

	local function updateDeathMarkers()
		local corpseX, corpseY = GetCorpseMapPosition()
		if isOffMap(corpseX, corpseY) then
			WorldMapCorpse:Hide()
		else
			placeUnit(WorldMapCorpse, corpseX, corpseY)
		end

		local releaseX, releaseY = GetDeathReleasePosition()
		if isOffMap(releaseX, releaseY) or UnitIsGhost("player") then
			WorldMapDeathRelease:Hide()
		else
			placeUnit(WorldMapDeathRelease, releaseX, releaseY)
		end
	end

	local function vehicleFrame(index)
		local frame = MAP_VEHICLES[index]
		if not frame then
			local vehicleName = "WorldMapVehicles" .. index
			frame = CreateFrame("Frame", vehicleName, WorldMapButton, "WorldMapVehicleTemplate")
			frame.texture = _G[vehicleName .. "Texture"]
			frame:SetScale(1 / zoom)
			MAP_VEHICLES[index] = frame
		end
		return frame
	end

	local function updateVehicleMarkers()
		local numVehicles = 0
		local continent = GetCurrentMapContinent()
		if not (continent == WORLDMAP_WORLD_ID or (continent ~= -1 and GetCurrentMapZone() == 0)) then
			numVehicles = GetNumBattlefieldVehicles()
		end
		for i = 1, numVehicles do
			local frame = vehicleFrame(i)
			local vehicleX, vehicleY, unitName, isPossessed, vehicleType, orientation, isPlayer, isAlive =
				GetBattlefieldVehicleInfo(i)
			local vehicleTexture = vehicleX and isAlive and not isPlayer and VEHICLE_TEXTURES[vehicleType]
			if vehicleTexture then
				frame.texture:SetRotation(orientation)
				frame.texture:SetTexture(WorldMap_GetVehicleTexture(vehicleType, isPossessed))
				frame:SetSize(vehicleTexture.width, vehicleTexture.height)
				frame.name = unitName
				placeUnit(frame, vehicleX, vehicleY)
			else
				frame:Hide()
			end
		end
		for i = numVehicles + 1, #MAP_VEHICLES do
			MAP_VEHICLES[i]:Hide()
		end
	end

	local function onUpdate(self)
		updateCursorHighlight(self)

		mapWidth, mapHeight = WorldMapDetailFrame:GetWidth() * zoom, WorldMapDetailFrame:GetHeight() * zoom
		updatePlayerMarker()
		local raidShown = 0
		if GetNumRaidMembers() > 0 then
			raidShown = updateRaidMarkers()
		else
			updatePartyMarkers()
		end
		updateBattlefieldMarkers(raidShown)
		updateFlagMarkers()
		updateDeathMarkers()
		updateVehicleMarkers()

		if panning then
			onPan()
		end
	end

	WorldMapButton:SetScript("OnUpdate", onUpdate)

	scroll:SetScript("OnMouseWheel", function(self, delta)
		local config = ns.Config.worldMap
		local oldZoom = zoom
		local newZoom = min(max(oldZoom * (1 + delta * config.zoomStep), MIN_ZOOM), config.maxZoom)
		if newZoom == oldZoom then
			return
		end

		local scale = self:GetEffectiveScale()
		local cursorX, cursorY = GetCursorPosition()
		local frameX = cursorX / scale - self:GetLeft()
		local frameY = self:GetTop() - cursorY / scale
		local scrollX, scrollY = self:GetHorizontalScroll(), self:GetVerticalScroll()

		setZoom(newZoom)
		setScroll(scrollX + frameX / oldZoom - frameX / newZoom, scrollY + frameY / oldZoom - frameY / newZoom)
		WorldMapFrame_UpdateQuests()
		redrawBlob()
	end)

	WorldMapButton:SetScript("OnMouseDown", function(_, button)
		if button == "LeftButton" and zoom > MIN_ZOOM then
			panning = true
			moved = false
			panStartX, panStartY = GetCursorPosition()
			scrollStartX, scrollStartY = scroll:GetHorizontalScroll(), scroll:GetVerticalScroll()
		end
	end)

	local originalOnClick = WorldMapButton:GetScript("OnClick")
	local blizzardOnClick = originalOnClick or WorldMapButton_OnClick

	local function onClick(self, button)
		if moved then
			moved = false
			return
		end
		blizzardOnClick(self, button)
		if zoom > MIN_ZOOM then
			resetZoom()
		end
	end

	WorldMapButton:SetScript("OnMouseUp", function(self, button)
		panning = false
		if not originalOnClick then
			onClick(self, button)
		end
	end)

	if originalOnClick then
		WorldMapButton:SetScript("OnClick", onClick)
	end

	local function scaleDropDownList()
		DropDownList1:SetScale(WorldMapFrame:GetEffectiveScale())
	end

	local DROPDOWNS = {
		"WorldMapContinentDropDown",
		"WorldMapZoneDropDown",
		"WorldMapZoneMinimapDropDown",
		"WorldMapLevelDropDown",
	}
	for i = 1, #DROPDOWNS do
		local name = DROPDOWNS[i]
		local button = _G[name] and _G[name .. "Button"]
		if button then
			button:HookScript("OnClick", scaleDropDownList)
		end
	end

	hooksecurefunc(WorldMapTooltip, "Show", function(self)
		self:SetFrameStrata("TOOLTIP")
	end)

	local function zoneId()
		return GetCurrentMapZone() + GetCurrentMapContinent() * 100
	end

	local realZone, battlefieldMinimapOnUpdate

	WorldMapFrame:HookScript("OnShow", function()
		realZone = zoneId()
		if BattlefieldMinimap then
			battlefieldMinimapOnUpdate = BattlefieldMinimap:GetScript("OnUpdate")
			BattlefieldMinimap:SetScript("OnUpdate", nil)
		end
	end)

	WorldMapFrame:HookScript("OnHide", function()
		SetMapToCurrentZone()
		if BattlefieldMinimap then
			BattlefieldMinimap:SetScript("OnUpdate", battlefieldMinimapOnUpdate or BattlefieldMinimap_OnUpdate)
		end
	end)

	Misc:RegisterEvent("ZONE_CHANGED_NEW_AREA", function()
		local current = zoneId()
		if realZone == current or (current % 100 > 0 and GetPlayerMapPosition("player") ~= 0) then
			SetMapToCurrentZone()
			realZone = zoneId()
		end
	end)

	local blobWasShown

	local function rememberBlobShown()
		blobWasShown = true
	end

	local function rememberBlobHidden()
		blobWasShown = nil
	end

	Misc:RegisterEvent("PLAYER_REGEN_DISABLED", function()
		blobWasShown = WorldMapFrame:IsShown() and WorldMapBlobFrame:IsShown()

		WorldMapBlobFrame:SetParent(nil)
		WorldMapBlobFrame:ClearAllPoints()
		WorldMapBlobFrame:SetPoint("TOP", UIParent, "BOTTOM")
		WorldMapBlobFrame:Hide()
		WorldMapBlobFrame.Show = rememberBlobShown
		WorldMapBlobFrame.Hide = rememberBlobHidden
		WorldMapBlobFrame.SetScale = ns.noop
		WorldMapBlobFrame.SetFrameLevel = ns.noop
	end)

	Misc:RegisterEvent("PLAYER_REGEN_ENABLED", function()
		WorldMapBlobFrame.Show = nil
		WorldMapBlobFrame.Hide = nil
		WorldMapBlobFrame.SetScale = nil
		WorldMapBlobFrame.SetFrameLevel = nil

		layoutBlob()

		if blobWasShown then
			WorldMapBlobFrame:Show()
			WorldMapBlobFrame_CalculateHitTranslations()
		end
		redrawBlob()
	end)

	Misc:RegisterEvent("PLAYER_ENTERING_WORLD", function()
		if WORLDMAP_SETTINGS.size ~= WORLDMAP_WINDOWED_SIZE then
			WorldMap_ToggleSizeUp()
		end
	end)
end)
