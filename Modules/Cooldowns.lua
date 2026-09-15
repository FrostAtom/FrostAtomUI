local engine = select(2,...)

local spells = {

}

local COMBATLOG_OBJECT_REACTION_FRIENDLY = COMBATLOG_OBJECT_REACTION_FRIENDLY
local COMBATLOG_OBJECT_REACTION_HOSTILE = COMBATLOG_OBJECT_REACTION_HOSTILE
local bit = bit

local CD = engine:New("Cooldowns")



function CD:AddFriendlyCooldown(guid,spell)

end

function CD:AddEnemyCooldown(guid,spell)

end

function CD:CreateFrame()

end

function CD:COMBAT_LOG_EVENT_UNFILTERED(_,subEvent,...)
	if subEvent ~= "SPELL_CAST_SUCCESS" then
		return
	end

	local srcGUID,_,srcFlags,_,_,_,spellId = ...
	if not spells[spellId] then
		return
	end

	if bit.band(srcFlags,COMBATLOG_OBJECT_REACTION_FRIENDLY) == COMBATLOG_OBJECT_REACTION_FRIENDLY then
		self:AddFriendlyCooldown(srcGUID,spellId)
	elseif bit.band(srcFlags,COMBATLOG_OBJECT_REACTION_HOSTILE) == COMBATLOG_OBJECT_REACTION_HOSTILE then
		self:AddEnemyCooldown(srcFlags,spellId)
	end
end

function CD:Initialize()
	self:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
end