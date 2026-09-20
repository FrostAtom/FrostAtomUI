local _, ns = ...
local UF = ns:GetModule("UnitFrames")

local GetRaidTargetIndex = GetRaidTargetIndex
local SetRaidTargetIconTexture = SetRaidTargetIconTexture

local function update(frame)
	local icon = frame.raidicon
	local index = GetRaidTargetIndex(frame.unit)
	if index then
		SetRaidTargetIconTexture(icon, index)
		icon:Show()
	else
		icon:Hide()
	end
end

local function create(frame)
	local icon = frame:CreateTexture(nil, "OVERLAY")
	icon:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcons")
	icon:SetSize(16, 16)
	icon:Hide()

	frame:RegisterEvent("RAID_TARGET_UPDATE", update)

	return icon
end

UF:RegisterElement("raidicon", create, update)
