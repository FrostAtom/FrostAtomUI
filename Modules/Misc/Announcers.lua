local _, ns = ...

local SendChatMessage = SendChatMessage
local UnitName = UnitName

local Misc = ns:GetModule("Misc")

--------------------------------------------------
-- Paladin: announce Aura Mastery (with Concentration Aura) to the group

if ns.PLAYER_CLASS == "PALADIN" then
	local UnitInRaid = UnitInRaid
	local IsPartyLeader = IsPartyLeader
	local UnitExists = UnitExists
	local UnitBuff = UnitBuff

	local AURA_MASTERY = GetSpellInfo(31821)
	local CONCENTRATION_AURA = GetSpellInfo(19746)
	local ANNOUNCEMENT = "<<< AURA MASTERY >>>"

	local function groupChannel()
		local inRaid = UnitInRaid("player")
		if inRaid and IsPartyLeader() then
			return "RAID_WARNING"
		elseif inRaid or UnitExists("party1") then
			return "PARTY"
		end
	end

	Misc:RegisterEvent("COMBAT_TEXT_UPDATE", function(_, messageType, spellName)
		if messageType ~= "SPELL_AURA_START" or spellName ~= AURA_MASTERY then
			return
		end
		if not UnitBuff("player", CONCENTRATION_AURA) then
			return
		end

		local channel = groupChannel()
		if channel then
			-- Twice, so it is not missed.
			SendChatMessage(ANNOUNCEMENT, channel)
			SendChatMessage(ANNOUNCEMENT, channel)
		end
	end)
end

--------------------------------------------------
-- Rating changes after an arena match

local GetNumBattlefieldScores = GetNumBattlefieldScores
local GetBattlefieldScore = GetBattlefieldScore
local GetBattlefieldTeamInfo = GetBattlefieldTeamInfo
local GetBattlefieldWinner = GetBattlefieldWinner
local IsActiveBattlefieldArena = IsActiveBattlefieldArena

local function playerTeamIndex()
	local playerName = UnitName("player")
	for i = 1, GetNumBattlefieldScores() do
		local name, _, _, _, _, teamIndex = GetBattlefieldScore(i)
		if name == playerName then
			return teamIndex
		end
	end
end

-- The status event keeps firing after the match ends; report once per match.
local ratingReported = false

Misc:RegisterEvent("PLAYER_ENTERING_WORLD", function()
	ratingReported = false
end)

Misc:RegisterEvent("UPDATE_BATTLEFIELD_STATUS", function()
	if ratingReported or not (IsActiveBattlefieldArena() and GetBattlefieldWinner()) then
		return
	end
	ratingReported = true

	for teamIndex = 0, 1 do
		local name, lost, gained, rating = GetBattlefieldTeamInfo(teamIndex)

		-- Solo queue teams have generated names.
		if name:find("^Solo Team [1-2]$") then
			name = playerTeamIndex() == teamIndex and "Our team" or "Enemy team"
		end

		if gained > 0 then
			ns.Print("%q(%d) +%d", name, rating, gained)
		elseif lost > 0 then
			ns.Print("%q(%d) -%d", name, rating, lost)
		else
			ns.Print("%q(%d) no changes", name, rating)
		end
	end
end)
