local _, ns = ...

local GetCursorPosition = GetCursorPosition
local IsMouseButtonDown = IsMouseButtonDown
local max, min = math.max, math.min

local Misc = ns:GetModule("Misc")

local PAN_SPEED = 0.01
local PAN_LIMIT = 1.2
local ZOOM_MIN, ZOOM_MAX = 0.5, 3
local ZOOM_DEPTH = 4
local DEFAULT_FACING = 0.61

local function clamp(value, low, high)
	return max(low, min(high, value))
end

local function apply(model)
	local limit = PAN_LIMIT * model.zoom
	model.panY = clamp(model.panY, -limit, limit)
	model.panZ = clamp(model.panZ, -limit, limit)
	model:SetPosition(ZOOM_DEPTH * (1 - 1 / model.zoom), model.panY, model.panZ)
end

local function reset(model)
	model.zoom, model.panY, model.panZ = 1, 0, 0
	apply(model)
end

local function onMouseDown(model, button)
	if button == "MiddleButton" then
		reset(model)
		model:SetFacing(DEFAULT_FACING)
		return
	end
	model.dragButton = button
	model.dragX, model.dragY = GetCursorPosition()
end

local function onMouseUp(model, button)
	if button == model.dragButton then
		model.dragButton = nil
	end
end

local function onUpdate(model)
	local button = model.dragButton
	if not button then
		return
	end
	if not IsMouseButtonDown(button) then
		model.dragButton = nil
		return
	end

	local x, y = GetCursorPosition()
	local dx, dy = x - model.dragX, y - model.dragY
	if dx == 0 and dy == 0 then
		return
	end
	model.dragX, model.dragY = x, y

	if button == "LeftButton" then
		model:SetFacing(model:GetFacing() + dx * ns.Config.modelControls.rotateSpeed)
	elseif button == "RightButton" then
		model.panY = model.panY + dx * PAN_SPEED
		model.panZ = model.panZ + dy * PAN_SPEED
		apply(model)
	end
end

local function onMouseWheel(model, delta)
	model.zoom = clamp(model.zoom * (1 + ns.Config.modelControls.zoomStep) ^ delta, ZOOM_MIN, ZOOM_MAX)
	apply(model)
end

local function onShow(model)
	model.dragButton = nil
	reset(model)
end

local function setupModel(model, rotateLeft, rotateRight)
	model.zoom, model.panY, model.panZ = 1, 0, 0
	model:EnableMouse(true)
	model:EnableMouseWheel(true)
	model:SetScript("OnMouseDown", onMouseDown)
	if model:GetScript("OnMouseUp") then
		model:HookScript("OnMouseUp", onMouseUp)
	else
		model:SetScript("OnMouseUp", onMouseUp)
	end
	model:SetScript("OnUpdate", onUpdate)
	model:SetScript("OnMouseWheel", onMouseWheel)
	model:HookScript("OnShow", onShow)

	ns.DestroyFrame(rotateLeft)
	ns.DestroyFrame(rotateRight)
end

function ns.SetupModelControls(model)
	if ns.Config.modelControls.enabled then
		setupModel(model)
	end
end

Misc:OnInitialize(function()
	if not ns.Config.modelControls.enabled then
		return
	end
	setupModel(CharacterModelFrame, CharacterModelFrameRotateLeftButton, CharacterModelFrameRotateRightButton)
	setupModel(DressUpModel, DressUpModelRotateLeftButton, DressUpModelRotateRightButton)

	ns:OnAddonLoaded("Blizzard_InspectUI", function()
		setupModel(InspectModelFrame, InspectModelRotateLeftButton, InspectModelRotateRightButton)
	end)
end)
