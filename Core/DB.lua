local AddOnName,namespace = ...

local assert = assert
local _G = _G

local main,DB = namespace:New("DB")
local DBName = AddOnName.."DB"


function main:VARIABLES_LOADED()
	DB = _G[DBName]
	if DB then
		_G[DBName] = nil
	else
		DB = {}
	end

	namespace:SetEvent("VariablesLoaded",DB)
end

function main:PLAYER_LOGOUT()
	_G[DBName] = DB
end

function namespace:SaveVariable(name,value)
	assert(DB and name)
	DB[name] = value
end

function main:Initialize()
	self:RegisterEvent("VARIABLES_LOADED")
	self:RegisterEvent("PLAYER_LOGOUT")
end
