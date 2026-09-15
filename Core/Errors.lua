--[[local namespace = select(2,...)

local debugstack = debugstack
local print	= print


local main = namespace:New("Errors")

local patterns = {
	"^%[C%]: in function `(.+)'.-Interface\\AddOns\\(.+): in function.-$",
	"^%[C%]: in function `(.+)'.-(%[string\".+\"%]:%d+)",
}

local function ErrorHandler()
	local stackTrace = debugstack(3,2,0)

	local funcName,callFrom
	for i = 1,#patterns do
		funcName,callFrom = stackTrace:match(patterns[i])
		if funcName then
			break
		end
	end

	if funcName then
		print(("|cffFFC929%2|r |cffFF4249attempt to call %1()|r"):format(funcName,callFrom))
	else
		print("Error parsing:",	stackTrace)
	end
end


seterrorhandler(ErrorHandler)
main:RegisterEvent("ADDON_ACTION_BLOCKED",ErrorHandler)
main:RegisterEvent("ADDON_ACTION_FORBIDDEN",ErrorHandler)



main:RegisterEvent("EXECUTE_CHAT_LINE",function() RunMacroText("") end)]]