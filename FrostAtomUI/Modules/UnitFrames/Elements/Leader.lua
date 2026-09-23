local _, ns = ...
local UF = ns:GetModule("UnitFrames")

local GetPartyLeaderIndex = GetPartyLeaderIndex
local IsPartyLeader = IsPartyLeader

local config = ns.Config.unitFrames

local function isLeader(leader)
	if leader.partyIndex then
		return GetPartyLeaderIndex() == leader.partyIndex
	end
	return IsPartyLeader()
end

local function update(frame)
	local leader = frame.leader
	ns.SetShown(leader, isLeader(leader) and config.showLeaderIcon)
end

local function test(frame)
	ns.SetShown(frame.leader, frame.test.leader and config.showLeaderIcon)
end

local function create(frame)
	local leader = (frame.classicon or frame):CreateTexture(nil, "OVERLAY")
	leader:SetTexture("Interface\\GroupFrame\\UI-Group-LeaderIcon")
	leader:SetSize(14, 14)
	if frame.unit ~= "player" then
		leader.partyIndex = tonumber(frame.unit:match("%d"))
	end

	frame:RegisterEvent("PARTY_LEADER_CHANGED", update)

	return leader
end

UF:RegisterElement("leader", create, update, test)
