local _, ns = ...
local UF = ns:GetModule("UnitFrames")

local GetRaidTargetIndex = GetRaidTargetIndex
local SetRaidTargetIconTexture = SetRaidTargetIconTexture

local config = ns.Config.unitFrames

local function setIcon(icon, index)
	if index and config.showRaidIcon then
		SetRaidTargetIconTexture(icon, index)
		icon:SetSize(config.raidIconSize, config.raidIconSize)
		icon:Show()
	else
		icon:Hide()
	end
end

local function update(frame)
	setIcon(frame.raidicon, GetRaidTargetIndex(frame.unit))
end

local function test(frame)
	setIcon(frame.raidicon, math.random(3) == 1 and math.random(8) or nil)
end

local function create(frame)
	local icon = frame:CreateTexture(nil, "OVERLAY")
	icon:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcons")
	icon:SetSize(config.raidIconSize, config.raidIconSize)
	icon:Hide()

	frame:RegisterEvent("RAID_TARGET_UPDATE", update)

	return icon
end

UF:RegisterElement("raidicon", create, update, test)
