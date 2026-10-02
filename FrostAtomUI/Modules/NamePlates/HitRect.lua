local _, ns = ...
local NamePlates = ns:GetModule("NamePlates")

local InCombatLockdown = InCombatLockdown

local config = ns.Config.namePlates

local HitRect = {}
NamePlates.HitRect = HitRect

local MARKER_OFFSET = -100
local SPARE_MARKERS = 40
local PRE_BODY = "return nil, true"
local SWEEP_BODY = [[
	wipe(plateList)
	worldFrame:GetChildList(plateList)
	local index = 0
	for i = 1, #plateList do
		local plate = plateList[i]
		local _, explicit = plate:IsProtected()
		if explicit then
			index = index + 1
			local marker = markers[index]
			if marker then
				local width, height = marker:GetRect()
				if width and width > 1 then
					if abs(plate:GetWidth() - width) > 0.01 or abs(plate:GetHeight() - height) > 0.01 then
						plate:SetWidth(width)
						plate:SetHeight(height)
					end
				end
			end
		end
	end
]]
local TICK_BODY = [[
	local counter = pulse:GetRect()
	if counter ~= lastCounter then
		lastCounter = counter
]] .. SWEEP_BODY .. [[
	end
	self:Hide()
]]
local FAST_BODY = [[stateDriver:SetAttribute("updatetime", 0)]]
local SLOW_BODY = [[stateDriver:SetAttribute("updatetime", 0.2)]]
local SETUP_BODY = [[
	worldFrame = self:GetFrameRef("worldFrame")
	stateDriver = self:GetFrameRef("stateDriver")
	pulse = self:GetFrameRef("pulse")
	markers = newtable()
	plateList = newtable()
]]
local ADD_MARKER_BODY = [[tinsert(markers, self:GetFrameRef("marker"))]]
local PULSE_CYCLE = 500

local header, pulse, markerParent
local markers = {}
local wrapped = {}
local pending = {}
local counter = 1
local defaultWidth

local function createMarker()
	local marker = CreateFrame("Frame", nil, markerParent, "SecureFrameTemplate")
	marker:SetSize(1, 1)
	marker:SetPoint("TOPRIGHT", WorldFrame, "BOTTOMLEFT", MARKER_OFFSET, MARKER_OFFSET)
	return marker
end

local function addMarkers(count)
	for _ = #markers + 1, count do
		local marker = createMarker()
		markers[#markers + 1] = marker
		header:SetFrameRef("marker", marker)
		header:Execute(ADD_MARKER_BODY)
	end
end

local function combatFrame(body)
	local frame = CreateFrame("Frame", nil, nil, "SecureFrameTemplate")
	frame:Hide()
	header:WrapScript(frame, "OnShow", body)
	RegisterStateDriver(frame, "visibility", "[combat] show; hide")
	return frame
end

local function setup()
	markerParent = CreateFrame("Frame", nil, WorldFrame)
	pulse = createMarker()
	header = CreateFrame("Frame", nil, nil, "SecureHandlerBaseTemplate")
	header:SetFrameRef("worldFrame", WorldFrame)
	header:SetFrameRef("stateDriver", SecureStateDriverManager)
	header:SetFrameRef("pulse", pulse)
	header:Execute(SETUP_BODY)
	local guard = combatFrame(FAST_BODY)
	header:WrapScript(guard, "OnHide", SLOW_BODY)
	combatFrame(TICK_BODY)
end

local function trigger()
	counter = counter % PULSE_CYCLE + 1
	pulse:SetClampRectInsets(-counter, 0, 0, -1)
	pulse:SetClampedToScreen(true)
end

local function plateIndex(plate)
	local children = { WorldFrame:GetChildren() }
	local index = 0
	for i = 1, #children do
		local child = children[i]
		if select(2, child:IsProtected()) then
			index = index + 1
			if child == plate then
				return index
			end
		end
	end
end

local function targetSize(plate)
	if plate.hitHidden then
		return defaultWidth, 0
	end
	return plate.hitWidth, plate.hitHeight
end

local function write(plate)
	local marker = markers[plate.hitIndex]
	if not marker then
		return
	end
	local width, height = targetSize(plate)
	marker:SetClampRectInsets(-width, 0, 0, -height)
	marker:SetClampedToScreen(true)
end

local function wrap(plate)
	if not wrapped[plate] then
		wrapped[plate] = true
		header:WrapScript(plate, "OnShow", PRE_BODY, SWEEP_BODY)
		header:WrapScript(plate, "OnHide", PRE_BODY, SWEEP_BODY)
	end
end

local function apply(plate)
	plate:SetSize(targetSize(plate))
	wrap(plate)
end

local function prepare()
	if not header then
		setup()
	end
	local plates = NamePlates.plates
	addMarkers(#plates + SPARE_MARKERS)
	for i = 1, #plates do
		local plate = plates[i]
		if plate.hitWidth then
			write(plate)
		end
		wrap(plate)
	end
end

function HitRect.Update(plate, width, height, hidden)
	if not defaultWidth then
		defaultWidth = plate:GetWidth()
	end
	if not plate.hitIndex then
		plate.hitIndex = plateIndex(plate)
	end
	plate.hitWidth, plate.hitHeight, plate.hitHidden = width, height, hidden
	if InCombatLockdown() then
		write(plate)
		pending[plate] = true
		if pulse then
			trigger()
		end
		return
	end
	if not header or not markers[plate.hitIndex] then
		prepare()
	end
	write(plate)
	apply(plate)
end

NamePlates:OnInitialize(function(self)
	if not config.enabled then
		return
	end
	if not InCombatLockdown() then
		prepare()
	end
	self:RegisterEvent("PLAYER_REGEN_ENABLED", function()
		prepare()
		for plate in pairs(pending) do
			if plate:IsShown() then
				apply(plate)
			end
		end
		wipe(pending)
	end)
end)
