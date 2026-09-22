local _, ns = ...
local UF = ns:GetModule("UnitFrames")

local GetPartyLeaderIndex = GetPartyLeaderIndex
local IsPartyLeader = IsPartyLeader

local config = ns.Config.unitFrames

local function update(frame)
	local leader = frame.leader

	local isLeader
	if leader.partyIndex then
		isLeader = GetPartyLeaderIndex() == leader.partyIndex
	else
		isLeader = IsPartyLeader()
	end

	if isLeader and config.showLeaderIcon then
		leader:Show()
	else
		leader:Hide()
	end
end

local function test(frame)
	if frame.test.leader and config.showLeaderIcon then
		frame.leader:Show()
	else
		frame.leader:Hide()
	end
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
