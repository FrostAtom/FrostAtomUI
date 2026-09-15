local engine = select(2,...)
local UF = engine:Get("UnitFrames")

local GetPartyLeaderIndex = GetPartyLeaderIndex
local IsPartyLeader = IsPartyLeader
local tonumber = tonumber


local function updateFunc(self)
	local unit = self.unit
	local leader = self.leader

	local show
	if unit == "player" then
		show = IsPartyLeader()
	else
		show = GetPartyLeaderIndex() == tonumber(unit:match("(%d)"))
	end

	if show then
		leader:Show()
	else
		leader:Hide()
	end
end

local function createFunc(self)
	local leader = self:CreateTexture(nil,"OVERLAY")
	leader:SetTexture("Interface\\GroupFrame\\UI-Group-LeaderIcon")
	leader:SetSize(18,18)
	
	self:RegisterEvent("PARTY_LEADER_CHANGED",updateFunc)

	return leader
end

UF:AddModule("leader",createFunc,updateFunc)