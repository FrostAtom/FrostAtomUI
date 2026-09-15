if not GetCVar("realmlist"):lower():find("circle") then return end -- needed only on wowcircle

local namespace = select(2,...)

local printf = namespace.printf
local CombatLogClearEntries = CombatLogClearEntries
local IsInInstance = IsInInstance
local select = select

local CombatLogFix = namespace:New("CombatLogFix")
local frame = CreateFrame("frame")
frame:Hide()


local function onUpdate(self,elapsed)
	self.remain  = self.remain - elapsed
	if self.remain < 0 then
		CombatLogClearEntries()
		printf("CombatLog Debuged")

		self:Hide()
	end
end

local function onShow(self)
	self.remain = 0.8
end

frame:SetScript("OnUpdate",onUpdate)
frame:SetScript("OnShow",onShow)


function CombatLogFix:UNIT_SPELLCAST_SENT()
	frame:Show()
end

function CombatLogFix:COMBAT_LOG_EVENT_UNFILTERED()
	frame:Hide()
end

function CombatLogFix:PLAYER_ENTERING_WORLD()
	if IsInInstance() then
		self:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
		self:RegisterEvent("UNIT_SPELLCAST_SENT")
	else
		self:UnregisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
		self:UnregisterEvent("UNIT_SPELLCAST_SENT")
	end
end

function CombatLogFix:Initialize()
	self:RegisterEvent("PLAYER_ENTERING_WORLD")
end