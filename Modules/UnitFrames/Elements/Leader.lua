local _, ns = ...
local UF = ns:GetModule("UnitFrames")

local GetPartyLeaderIndex = GetPartyLeaderIndex
local IsPartyLeader = IsPartyLeader

local function update(frame)
	local unit = frame.unit

	local isLeader
	if unit == "player" then
		isLeader = IsPartyLeader()
	else
		isLeader = GetPartyLeaderIndex() == tonumber(unit:match("%d"))
	end

	if isLeader then
		frame.leader:Show()
	else
		frame.leader:Hide()
	end
end

local function create(frame)
	local leader = frame:CreateTexture(nil, "OVERLAY")
	leader:SetTexture("Interface\\GroupFrame\\UI-Group-LeaderIcon")
	leader:SetSize(18, 18)

	frame:RegisterEvent("PARTY_LEADER_CHANGED", update)

	return leader
end

UF:RegisterElement("leader", create, update)
