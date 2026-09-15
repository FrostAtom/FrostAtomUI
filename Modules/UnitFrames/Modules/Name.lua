local engine = select(2,...)
local UF = engine:Get("UnitFrames")

local UnitIsConnected = UnitIsConnected
local UnitIsPlayer = UnitIsPlayer
local UnitClass = UnitClass
local UnitName = UnitName
local unpack = unpack

local classColors = UF.classColors


local function cutText(text,n)
    return text:sub(1,text:find("[\208\209]") and n*2 or n)
end

local function updateFunc(self,unit)
    if unit then
        if unit ~= self.unit then
            return
        end
    else
        unit = self.unit
    end

    local name = self.name
    local maxn = name.maxn

    local text
    if UnitIsUnit(unit,"player") then
        text = "Cute Boy"
    else
        text = UnitName(unit) or "UNKNOWN"
    end

    name:SetText(maxn and cutText(text,maxn) or text)

	if UnitIsPlayer(unit) then
        local _,class = UnitClass(unit)
        if class then
		    name:SetTextColor(unpack(classColors[class]))
            return
        end
    end

    name:SetTextColor(1,0.9,0.8)
end

local function createFunc(self,maxn)
    self:RegisterEvent("UNIT_NAME_UPDATE",updateFunc)
    local name = self:CreateFontString(nil,"OVERLAY","SystemFont_Outline_Small")
    name.maxn = maxn
    return name
end

UF:AddModule("name",createFunc,updateFunc)