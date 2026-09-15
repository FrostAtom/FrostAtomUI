local namespace = select(2,...)
local math_floor = math.floor


local function formatV(v)
	if v > 0 then
		if v < 1e3 then
			return v
		elseif v < 1e6 then
			return ("%.1fk"):format(v/1e3)
		else
			return ("%.1fm"):format(v/1e6)
		end
	end
end

local function formatTime(v)
	if v > 0 then
		if v <= 3 then
		    return ("%.1f"):format(v)
		elseif v <= 60 then
			return math_floor(v)
		elseif v <= 3600 then
			return math_floor(v/60).."m"
		else
			return math_floor(v/3600).."h"
		end
	end
end

local function pixelPerfect(x)
	return x*(2-UIParent:GetEffectiveScale())
end


namespace.formatV = formatV
namespace.formatTime = formatTime
namespace.pixelPerfect = pixelPerfect






--------------------------------------------------
-- test
--[[
SlashCmdList.TEST = function()
    local GetTime = GetTime
    local print = print

    local tinsert = table.insert
    local tbl = {}

    local startTime
    for i = 1,3 do
        startTime = GetTime()
        for i = 1,1e5 do
        	tbl[#tbl+1] = true
        end
        print("one",GetTime()-startTime)
        wipe(tbl)

        startTime = GetTime()
        for i = 1,1e5 do
        	tinsert(tbl,true)
        end
        print("two",GetTime()-startTime)
        wipe(tbl)
    end
end
SLASH_TEST1 = "/test"
]]