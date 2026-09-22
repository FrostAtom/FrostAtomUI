local _, ns = ...

local GetCursorPosition = GetCursorPosition

local Misc = ns:GetModule("Misc")

local PAN_SPEED = 0.01

local function onMouseDown(model, button)
	model.dragButton = button
	model.dragX, model.dragY = GetCursorPosition()
end

local function onMouseUp(model)
	model.dragButton = nil
end

local function onUpdate(model)
	local button = model.dragButton
	if not button then
		return
	end

	local x, y = GetCursorPosition()
	local dx, dy = x - model.dragX, y - model.dragY
	model.dragX, model.dragY = x, y

	if button == "LeftButton" then
		model:SetFacing(model:GetFacing() + dx * ns.Config.modelControls.rotateSpeed)
	elseif button == "RightButton" then
		model.panY = model.panY + dx * PAN_SPEED
		model.panZ = model.panZ + dy * PAN_SPEED
		model:SetPosition(model.zoom, model.panY, model.panZ)
	end
end

local function onMouseWheel(model, delta)
	model.zoom = model.zoom + delta * ns.Config.modelControls.zoomStep
	model:SetPosition(model.zoom, model.panY, model.panZ)
end

local function onShow(model)
	model.zoom, model.panY, model.panZ = 0, 0, 0
	model.dragButton = nil
end

local function setupModel(model, rotateLeft, rotateRight)
	onShow(model)
	model:EnableMouse(true)
	model:EnableMouseWheel(true)
	model:SetScript("OnMouseDown", onMouseDown)
	model:SetScript("OnMouseUp", onMouseUp)
	model:SetScript("OnUpdate", onUpdate)
	model:SetScript("OnMouseWheel", onMouseWheel)
	model:HookScript("OnShow", onShow)

	ns.DestroyFrame(rotateLeft)
	ns.DestroyFrame(rotateRight)
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
