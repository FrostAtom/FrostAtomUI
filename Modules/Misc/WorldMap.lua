local _, ns = ...

local WorldMapFrame = WorldMapFrame
local BlackoutWorld = BlackoutWorld
local GetScreenHeight = GetScreenHeight

local Misc = ns:GetModule("Misc")

local SCREEN_FRACTION = 0.8
local LAYOUT_WIDTH, LAYOUT_HEIGHT = 1024, 768

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
	WorldMapFrame:SetScale(GetScreenHeight() * SCREEN_FRACTION / LAYOUT_HEIGHT)
	WorldMapFrame:ClearAllPoints()
	WorldMapFrame:SetSize(LAYOUT_WIDTH, LAYOUT_HEIGHT)
	WorldMapFrame:SetPoint("CENTER", UIParent)
end

hooksecurefunc("ToggleMapFramerate", layout)
WorldMapFrame:HookScript("OnShow", layout)

local WorldMapBlobFrame = WorldMapBlobFrame
local blobWasShown, blobScale

hooksecurefunc(WorldMapDetailFrame, "SetScale", function(_, scale)
	blobScale = scale
end)

Misc:RegisterEvent("PLAYER_REGEN_DISABLED", function()
	blobWasShown = WorldMapFrame:IsShown() and WorldMapBlobFrame:IsShown()

	WorldMapBlobFrame:SetParent(nil)
	WorldMapBlobFrame:ClearAllPoints()
	WorldMapBlobFrame:SetPoint("TOP", UIParent, "BOTTOM")
	WorldMapBlobFrame:Hide()
	WorldMapBlobFrame.Show = function()
		blobWasShown = true
	end
	WorldMapBlobFrame.Hide = function()
		blobWasShown = nil
	end
	WorldMapBlobFrame.SetScale = ns.noop
	WorldMapBlobFrame.SetFrameLevel = ns.noop
end)

Misc:RegisterEvent("PLAYER_REGEN_ENABLED", function()
	WorldMapBlobFrame.Show = nil
	WorldMapBlobFrame.Hide = nil
	WorldMapBlobFrame.SetScale = nil
	WorldMapBlobFrame.SetFrameLevel = nil

	local level = WorldMapDetailFrame:GetFrameLevel() + 1
	WorldMapBlobFrame:SetParent(WorldMapFrame)
	WorldMapBlobFrame:ClearAllPoints()
	WorldMapBlobFrame:SetPoint("TOPLEFT", WorldMapDetailFrame)
	WorldMapBlobFrame:SetScale(blobScale or WORLDMAP_SETTINGS.size)
	WorldMapBlobFrame:SetFrameLevel(level)
	WorldMapBlobFrame:SetFrameLevel(level)

	if blobWasShown then
		WorldMapBlobFrame:Show()
		WorldMapBlobFrame_CalculateHitTranslations()
	end
	if WORLDMAP_SETTINGS.selectedQuest then
		WorldMapBlobFrame:DrawQuestBlob(WORLDMAP_SETTINGS.selectedQuest.questId, false)
		if blobWasShown and not WORLDMAP_SETTINGS.selectedQuest.completed then
			WorldMapBlobFrame:DrawQuestBlob(WORLDMAP_SETTINGS.selectedQuest.questId, true)
		end
	end
end)

Misc:RegisterEvent("PLAYER_ENTERING_WORLD", function()
	if WORLDMAP_SETTINGS.size ~= WORLDMAP_WINDOWED_SIZE then
		WorldMap_ToggleSizeUp()
	end
end)
