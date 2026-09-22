local _, ns = ...
local L = ns.L

local tremove = table.remove

local ActionBar = ns:GetModule("ActionBar")

local config = ns.Config.actionBar
local PREALLOCATED = 20
local pool = {}

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
	if not config.clickAnimation then
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
	if db.video_record ~= nil then
		ns:SetConfig("actionBar.clickAnimation", not db.video_record)
		db.video_record = nil
	end
end)

SlashCmdList.FROSTATOMUI_VIDEORECORD = function()
	local enabled = not config.clickAnimation
	ns:SetConfig("actionBar.clickAnimation", enabled)
	ns.Print(L["click animation %s"], enabled and L["enabled"] or L["disabled"])
end
SLASH_FROSTATOMUI_VIDEORECORD1 = "/vr"
