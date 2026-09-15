local namespace = select(2,...)

local tWipe = namespace.tWipe
local UnitName = UnitName
local UnitGUID = UnitGUID


local CastBars = namespace:New("NamePlate_CastBars")

local guid2name = {}
local guid2cast = {}



function CastBars:CastStart(guid,spell,...)
	if not guid2name[guid] then
		local name,unit = ...
		guid2name[guid] = name or UnitName(unit)
	end


end

function CastBars:UNIT_SPELLCAST_START(unit,spell)
	self:CastStart(UnitGUID(unit),spell,nil,unit)
end

function CastBars:COMBAT_LOG_EVENT_UNFILTERED(_,subEvent,...)
	if subEvent == "SPELL_CAST_START" then
		local srcGUID,srcName,_,_,_,_,_,spell = ...
		self:CastStart(srcGUID,spell,srcName)
	end
end

function CastBars:PLAYER_ENTERING_WORLD()
	tWipe(guid2name)
	tWipe(guid2cast)
end

function CastBars:Initialize()
	self:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
	self:RegisterEvent("UNIT_SPELLCAST_START")
	self:RegisterEvent("PLAYER_ENTERING_WORLD")
end