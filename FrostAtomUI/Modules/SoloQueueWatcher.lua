local _, ns = ...

local match = string.match
local tonumber = tonumber

local SoloQueueWatcher = ns:NewModule("SoloQueueWatcher")
ns.SoloQueueWatcher = SoloQueueWatcher

local SEARCHING_PATTERN = "^We are looking for the best team for you on the selection rating %[(%d+)%-(%d+)%]$"
local TEAM_FOUND_PATTERN =
	"^Team to fight found! Team rating (%d+), looking for suitable opponents on the rating %[(%d+)%-(%d+)%]$"

function SoloQueueWatcher.Parse(message)
	local low, high = match(message, SEARCHING_PATTERN)
	if low then
		return tonumber(low), tonumber(high)
	end
	local teamRating
	teamRating, low, high = match(message, TEAM_FOUND_PATTERN)
	if teamRating then
		return tonumber(low), tonumber(high), tonumber(teamRating)
	end
end

ns.OnRealm("wowcircle", function()
	SoloQueueWatcher:RegisterEvent("CHAT_MSG_SYSTEM", function(_, message)
		local low, high, teamRating = SoloQueueWatcher.Parse(message)
		if low then
			ns:Fire(ns.E.SOLOQ_SEARCHING, low, high, teamRating)
		end
	end)
end)
