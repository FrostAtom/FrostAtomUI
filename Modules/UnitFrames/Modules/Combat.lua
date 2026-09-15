local engine = select(2,...)
local UF = engine:Get("UnitFrames")

local UnitAffectingCombat = UnitAffectingCombat
local UnitIsConnected = UnitIsConnected


local function updateFunc(self,unit)
    if unit then
        if unit ~= self.unit then
            return
        end
    else
        unit = self.unit
    end

	if UnitIsConnected(unit) and UnitAffectingCombat(unit) then
		self.combat:Show()
	else
		self.combat:Hide()
	end
end

local function createFunc(self)
	local combat = self:CreateTexture(nil,"OVERLAY")
	combat:SetSize(18,18)
	combat:SetTexture("Interface\\CharacterFrame\\UI-StateIcon")
	combat:SetTexCoord(0.6,0.9,0.1,0.4)
	combat:SetVertexColor(1,0.9,0.9)

	self:RegisterEvent("UNIT_FLAGS",updateFunc)

	return combat
end


UF:AddModule("combat",createFunc,updateFunc)