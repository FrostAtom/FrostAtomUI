local namespace = select(2,...)

local CreateFrame = CreateFrame
local tremove = tremove

local ActionBar = namespace:Get("ActionBar")
local cache = {}
local STATE

local function OnFinished(self)
    cache[#cache+1] = self:GetParent():GetParent()
end

local function CreateAnimation()
    local frame = CreateFrame("Frame")
    frame:SetFrameStrata("MEDIUM")

    local texture = frame:CreateTexture(nil,"OVERLAY")
    texture:SetTexture("Interface\\Cooldown\\star4")
    texture:SetAllPoints()
    texture:SetAlpha(0)
    texture:SetBlendMode("ADD")

    local animGroup = texture:CreateAnimationGroup()
    animGroup:SetScript("OnFinished",OnFinished)

    local animation = animGroup:CreateAnimation("Alpha")
    animation:SetChange(1)
    animation:SetDuration(0)
    animation:SetOrder(1)

    animation = animGroup:CreateAnimation("Scale")
    animation:SetScale(1.5,1.5)
    animation:SetDuration(0)
    animation:SetOrder(1)

    animation = animGroup:CreateAnimation("Scale")
    animation:SetScale(0,0)
    animation:SetDuration(0.2)
    animation:SetOrder(2)

    animation = animGroup:CreateAnimation("Rotation")
    animation:SetDegrees(90)
    animation:SetDuration(0.2)
    animation:SetOrder(2)

    frame.animGroup = animGroup
    return frame
end


function ActionBar.PlayAnimation(self)
    if STATE then
        return
    end

    local frame = tremove(cache) or CreateAnimation()
    frame:SetParent(self)
    frame:SetAllPoints(self)
    frame.animGroup:Play()
end

for i = 1,20 do
    cache[i] = CreateAnimation()
end

SlashCmdList["VIDEORECORD"] = function()
    STATE = not STATE
    namespace:SaveVariable("video_record",STATE)
    namespace.printf("video record mode "..(STATE and "enabled" or "disabled"))
end
ActionBar:RegisterEvent("VariablesLoaded",function(self,db)
    BLOCKED = db["pm_blocked"]
end)
SLASH_VIDEORECORD1 = "/vr"
