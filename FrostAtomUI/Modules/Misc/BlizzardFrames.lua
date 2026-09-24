local _, ns = ...

local IsInInstance = IsInInstance

local BlizzardFrames = ns:NewModule("BlizzardFrames")
BlizzardFrames.configKey = "blizzardFrames"
local config = ns.Config.blizzardFrames

local CAPTURE_BAR_WIDTH, CAPTURE_BAR_HEIGHT = 173, 26

local captureHolder
local hookedBars = {}
local stacking = false

local function stackCaptureBars()
	if stacking then
		return
	end
	stacking = true
	local y = 0
	for i = 1, NUM_EXTENDED_UI_FRAMES or 0 do
		local bar = _G["WorldStateCaptureBar" .. i]
		if bar then
			if not hookedBars[bar] then
				hookedBars[bar] = true
				hooksecurefunc(bar, "SetPoint", stackCaptureBars)
			end
			if bar:IsShown() then
				bar:ClearAllPoints()
				bar:SetPoint("TOP", captureHolder, "TOP", 0, y)
				y = y - bar:GetHeight()
			end
		end
	end
	stacking = false
end

local function pin(module, frame, path, label, size)
	local applying = false
	local function apply()
		applying = true
		ns.ApplyPoint(frame, path)
		applying = false
	end
	hooksecurefunc(frame, "SetPoint", function()
		if not applying then
			apply()
		end
	end)
	apply()
	module:WatchConfig(path, apply)
	module:RegisterMover(frame, path, label, size and { size = size })
end

local inCombat = false
local trackerHidden = false

local function shouldHideTracker()
	local tracker = config.questTracker
	local _, instanceType = IsInInstance()
	if instanceType == "arena" and tracker.arena then
		return true
	elseif instanceType == "pvp" and tracker.battleground then
		return true
	end
	return inCombat and tracker.combat
end

local function updateTracker()
	if shouldHideTracker() then
		if WatchFrame:IsShown() then
			trackerHidden = true
			WatchFrame:Hide()
		end
	elseif trackerHidden then
		trackerHidden = false
		WatchFrame:Show()
	end
end

function BlizzardFrames:Initialize()
	captureHolder = CreateFrame("Frame", "FrostAtomUICaptureBars", UIParent)
	captureHolder:SetSize(CAPTURE_BAR_WIDTH, CAPTURE_BAR_HEIGHT)
	self:AnchorToConfig(captureHolder, "blizzardFrames.captureBarPoint", "Capture bars")
	hooksecurefunc("WorldStateAlwaysUpFrame_Update", stackCaptureBars)
	stackCaptureBars()

	pin(self, VehicleSeatIndicator, "blizzardFrames.vehicleSeatPoint", "Vehicle seats", { 128, 128 })
	pin(self, UIErrorsFrame, "blizzardFrames.errorsPoint", "Error messages")
	pin(self, RaidWarningFrame, "blizzardFrames.raidWarningPoint", "Raid warnings", { 512, 70 })

	for _, event in ipairs({ "PLAYER_ENTERING_WORLD", "ZONE_CHANGED_NEW_AREA" }) do
		self:RegisterEvent(event, updateTracker)
	end
	self:RegisterEvent("PLAYER_REGEN_DISABLED", function()
		inCombat = true
		updateTracker()
	end)
	self:RegisterEvent("PLAYER_REGEN_ENABLED", function()
		inCombat = false
		updateTracker()
	end)
	self:WatchConfig("blizzardFrames.questTracker", updateTracker)
end
