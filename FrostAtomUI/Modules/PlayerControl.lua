local _, ns = ...

local GetTime, UnitGUID = GetTime, UnitGUID

local PlayerControl = ns.Mixin({}, ns.Demand)
ns.PlayerControl = PlayerControl

local interruptedAt, interruptSpell, interruptSchool = -math.huge, nil, nil
local playerGUID

local function onInterrupt(_, _, _, _, _, _, destGUID, _, _, spellId, _, _, _, _, extraSchool)
	playerGUID = playerGUID or UnitGUID("player")
	if destGUID ~= playerGUID then
		return
	end
	interruptedAt, interruptSpell, interruptSchool = GetTime(), spellId, extraSchool
	ns:Fire(ns.E.PLAYER_INTERRUPTED, spellId, extraSchool)
end

function PlayerControl:OnDemandStart()
	ns.CombatLog.Register(self, { "SPELL_INTERRUPT" }, onInterrupt)
end

function PlayerControl:OnDemandStop()
	ns.CombatLog.Unregister(self, onInterrupt)
end

function PlayerControl.GetInterruption()
	return interruptedAt, interruptSpell, interruptSchool
end
