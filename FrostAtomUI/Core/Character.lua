local _, ns = ...

local Character = {}
ns.Character = Character

-- Private servers rename characters and proxy realms change the realm name; the GUID stays.
---@return string
function Character.Key()
	return UnitGUID("player")
end

---@param map table<string, unknown>
---@return unknown
function Character.Adopt(map)
	local key, legacy = Character.Key(), UnitName("player") .. " - " .. GetRealmName()
	if map[key] == nil then
		map[key] = map[legacy]
	end
	map[legacy] = nil
	return map[key]
end
