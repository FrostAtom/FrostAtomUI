local _, ns = ...

local InCombatLockdown = InCombatLockdown
local RegisterStateDriver = RegisterStateDriver

local ActionBar = ns:GetModule("ActionBar")

local holder

local function anchorBar()
	if InCombatLockdown() then
		return
	end
	local bar = MultiCastActionBarFrame
	local _, relativeTo = bar:GetPoint()
	if bar:GetParent() ~= holder or relativeTo ~= holder or bar:GetNumPoints() ~= 1 then
		bar:SetParent(holder)
		bar:ClearAllPoints()
		bar:SetPoint("BOTTOMLEFT", holder)
	end
end

function ActionBar:InitializeTotemBar()
	local bar = MultiCastActionBarFrame
	if ns.PLAYER_CLASS ~= "SHAMAN" or not bar then
		return
	end

	holder = CreateFrame("Frame", nil, UIParent, "SecureHandlerStateTemplate")
	holder:SetSize(bar:GetWidth(), bar:GetHeight())
	RegisterStateDriver(holder, "visibility", "[vehicleui] hide; show")

	bar:SetScript("OnUpdate", nil)
	bar:SetScript("OnShow", nil)
	bar:SetScript("OnHide", nil)
	anchorBar()

	hooksecurefunc("MultiCastSummonSpellButton_Update", anchorBar)
	hooksecurefunc("MultiCastRecallSpellButton_Update", anchorBar)
	hooksecurefunc("MultiCastSlotButton_Update", anchorBar)

	self:AnchorToConfig(holder, "actionBar.totemBar", "Totem bar", { secure = true })
end
