local _, ns = ...
local UF = ns:GetModule("UnitFrames")

local GetRaidTargetIndex = GetRaidTargetIndex
local SetRaidTargetIconTexture = SetRaidTargetIconTexture

local config = ns.Config.unitFrames

local function setIcon(icon, index)
	local shown = icon.shown
	if shown == nil then
		shown = config.showRaidIcon
	end
	if index and shown then
		SetRaidTargetIconTexture(icon, index)
		local size = icon.size or config.raidIconSize
		icon:SetSize(size, size)
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
