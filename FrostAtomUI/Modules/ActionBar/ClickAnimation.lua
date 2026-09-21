local _, ns = ...

local CreateFrame = CreateFrame
local tremove = table.remove

local ActionBar = ns:GetModule("ActionBar")

local PREALLOCATED = 20
local pool = {}
local disabled = false

local function onFinished(animGroup)
	pool[#pool + 1] = animGroup:GetParent():GetParent()
end

local function createAnimationFrame()
	local frame = CreateFrame("Frame")
	frame:SetFrameStrata("MEDIUM")

	local texture = frame:CreateTexture(nil, "OVERLAY")
	texture:SetTexture("Interface\\Cooldown\\star4")
	texture:SetAllPoints()
	texture:SetAlpha(0)
	texture:SetBlendMode("ADD")

	local animGroup = texture:CreateAnimationGroup()
	animGroup:SetScript("OnFinished", onFinished)

	local alpha = animGroup:CreateAnimation("Alpha")
	alpha:SetChange(1)
	alpha:SetDuration(0)
	alpha:SetOrder(1)

	local grow = animGroup:CreateAnimation("Scale")
	grow:SetScale(1.5, 1.5)
	grow:SetDuration(0)
	grow:SetOrder(1)

	local shrink = animGroup:CreateAnimation("Scale")
	shrink:SetScale(0, 0)
	shrink:SetDuration(0.2)
	shrink:SetOrder(2)

	local rotate = animGroup:CreateAnimation("Rotation")
	rotate:SetDegrees(90)
	rotate:SetDuration(0.2)
	rotate:SetOrder(2)

	frame.animGroup = animGroup
	return frame
end

function ActionBar.PlayClickAnimation(button)
	if disabled then
		return
	end

	local frame = tremove(pool) or createAnimationFrame()
	frame:SetParent(button)
	frame:SetAllPoints(button)
	frame.animGroup:Play()
end

for i = 1, PREALLOCATED do
	pool[i] = createAnimationFrame()
end

ActionBar:RegisterEvent(ns.DB_LOADED, function(_, db)
	disabled = db.video_record
end)

SlashCmdList.FROSTATOMUI_VIDEORECORD = function()
	disabled = not disabled
	ns:SaveVariable("video_record", disabled)
	ns.Print("video record mode %s", disabled and "enabled" or "disabled")
end
SLASH_FROSTATOMUI_VIDEORECORD1 = "/vr"
