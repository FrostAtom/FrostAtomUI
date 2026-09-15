local namespace = select(2,...)

local Totems = namespace:New("NamePlates_Totems")

local GetTime = GetTime
local bit_band = bit.band
local COMBATLOG_OBJECT_REACTION_HOSTILE = COMBATLOG_OBJECT_REACTION_HOSTILE
local COMBATLOG_OBJECT_AFFILIATION_PARTY = COMBATLOG_OBJECT_AFFILIATION_PARTY
local COMBATLOG_OBJECT_AFFILIATION_MINE = COMBATLOG_OBJECT_AFFILIATION_MINE
local TREMOR_TOTEM = 8143
local TREMOR_TEXTURE = select(3,GetSpellInfo(TREMOR_TOTEM))


local friendlyTremorsShown = 0
local friendlyTremors,hostileTremors = {},{}


local unusedTrackers = {}
do
	local ObjectExists = ObjectExists
	local CreateFrame = CreateFrame
	local UnitRange = UnitRange
	local ceil = ceil


	local function tracker_OnShow(self)
		self.toUpd = -1
	end

	local function tracker_OnUpdate(self,elapsed)
		self.toUpd = self.toUpd - elapsed
		if self.toUpd < 0 then
			if not ObjectExists(self.GUID) then
				self:Hide()
				return
			end

			self:SetValue((GetTime()-self.startTime)%3)

			if self.otherUnit then
				local range = UnitRange(self.otherUnit,self.GUID)
				self.text:SetText(ceil(range))
				if range > 30 then
					self.text:SetTextColor(0.8,0.2,0.2)
				else
					self.text:SetTextColor(0.2,0.8,0.2)
				end
			end

			self.toUpd = 0.1
		end
	end

	local function tracker_OnHide(self)
		self:Hide()

		if self.isFriendly then
			friendlyTremors[self.ownerGUID] = nil
			friendlyTremorsShown = friendlyTremorsShown - 1
		else
			hostileTremors[self.ownerGUID] = nil
		end

		unusedTrackers[#unusedTrackers+1] = self
	end

	function Totems:CreateTracker()
		local frame = CreateFrame("StatusBar",nil,UIParent)
		frame:Hide()
		frame:SetMinMaxValues(0,3)
		frame:SetStatusBarTexture("Interface\\Buttons\\WHITE8x8")
		frame:SetStatusBarColor(0,0,0,0.7)
		frame:SetOrientation("VERTICAL")

		local texture = frame:CreateTexture(nil,"BORDER")
		texture:SetTexture(TREMOR_TEXTURE)
		texture:SetAllPoints()
		frame.texture = texture

		local text = frame:CreateFontString(nil,"ARTWORK","NumberFontNormal")
		text:SetPoint("BOTTOMRIGHT")
		frame.text = text


		frame:SetScript("OnUpdate",tracker_OnUpdate)
		frame:SetScript("OnHide",tracker_OnHide)
		frame:SetScript("OnShow",tracker_OnShow)

		return frame
	end
end

function Totems:GetFreeTracker()
	return tremove(unusedTrackers) or self:CreateTracker()
end



function Totems:AddFriendlyTremor(ownerGUID,GUID)
	local frame
	if friendlyTremors[ownerGUID] then
		frame = friendlyTremors[ownerGUID]
	else
		frame = self:GetFreeTracker()
		frame:SetSize(40,40)
		frame:SetPoint("BOTTOM",200-(42*friendlyTremorsShown),144)
		frame.ownerGUID = ownerGUID
		frame.isFriendly = true
		frame.otherUnit = "player"

		friendlyTremors[ownerGUID] = frame
		friendlyTremorsShown = friendlyTremorsShown + 1
	end

	frame.GUID = GUID
	frame.startTime = GetTime()
	frame:Show()
end

function Totems:AddHostileTremor(ownerGUID,GUID)
	--print("AddHostileTremor",GUID)
end

function Totems:COMBAT_LOG_EVENT_UNFILTERED(_,subEvent,...)
	if subEvent == "SPELL_SUMMON" then
		local srcGUID,_,srcFlags,dstGUID,_,dstFlags,spellId = ...
		if spellId == TREMOR_TOTEM then
			if bit_band(srcFlags,COMBATLOG_OBJECT_REACTION_HOSTILE) > 0 then
				self:AddHostileTremor(srcGUID,dstGUID)
			elseif bit_band(srcFlags,COMBATLOG_OBJECT_REACTION_FRIENDLY) > 0 then
				if bit_band(srcFlags,COMBATLOG_OBJECT_AFFILIATION_PARTY) > 0 or bit_band(srcFlags,COMBATLOG_OBJECT_AFFILIATION_MINE) > 0 then
					self:AddFriendlyTremor(srcGUID,dstGUID)
				end
			end
		end
	end
end

function Totems:Initialize()
	self:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")

end