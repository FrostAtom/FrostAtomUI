local _, ns = ...
local UF = ns:GetModule("UnitFrames")

local GetPartyLeaderIndex = GetPartyLeaderIndex
local IsPartyLeader = IsPartyLeader

local function update(frame)
	local leader = frame.leader

	local isLeader
	if leader.partyIndex then
		isLeader = GetPartyLeaderIndex() == leader.partyIndex
	else
		isLeader = IsPartyLeader()
	end

	if isLeader then
		leader:Show()
	else
		leader:Hide()
	end
end

local function create(frame)
	local leader = frame:CreateTexture(nil, "OVERLAY")
	leader:SetTexture("Interface\\GroupFrame\\UI-Group-LeaderIcon")
	leader:SetSize(18, 18)
	if frame.unit ~= "player" then
		leader.partyIndex = tonumber(frame.unit:match("%d"))
	end

	frame:RegisterEvent("PARTY_LEADER_CHANGED", update)

	return leader
end

UF:RegisterElement("leader", create, update)
