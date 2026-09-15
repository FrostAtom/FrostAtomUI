local engine = select(2,...)

local DATA = {
	["WARRIOR"] = {
		{spell = 60503, unit = "player", type = "buff", points = {"CENTER",18,-72}, size = 36}, -- holy shock proc
		{spell = 52437, unit = "player", type = "buff", points = {"CENTER",-18,-72}, size = 36}, -- judgement buff
	},
	["PALADIN"] = {
		{spell = 54149, unit = "player", type = "buff", points = {"CENTER",0,-72}, size = 36}, -- holy shock proc
		{spell = 54153, unit = "player", type = "buff", points = {"CENTER",72,36}, size = 36}, -- judgement buff
		{spell = 53563, isMine = true, unit = "player", type = "buff", points = {"CENTER",-108,36}, size = 36}, -- beacon
		{spell = 53601, isMine = true, unit = "player", type = "buff", points = {"CENTER",-72,36}, size = 36}, -- shield
		{spell = 58597, unit = "player", type = "buff", points = {"CENTER",0,-36}, size = 40}, -- shield proc
	},
	["PRIEST"] = {
		{spell = 48168, unit = "player", type = "buff", points = {"CENTER",72,36}, size = 36}, -- inner fire
	},
	["DEATHKNIGHT"] = {
		{spell = 55379, unit = "player", type = "buff", points = {"CENTER",0,-72}, size = 36}, -- haste meta
		{spell = 55078, unit = "target", type = "debuff", isMine = true, points = {"CENTER",-48,-42}, size = 30},
		{spell = 55095, unit = "target", type = "debuff", isMine = true, points = {"CENTER",-16,-42}, size = 30},
		{spell = 51735, unit = "target", type = "debuff", isMine = true, points = {"CENTER",16,-42}, size = 30},
		{spell = 50536, unit = "target", type = "debuff", isMine = true, points = {"CENTER",48,-42}, size = 30},
	},
	["SHAMAN"] = {
		{spell = 57960, unit = "player", type = "buff", points = {"CENTER",72,36}, size = 36}, -- shield
		{spell = 70806, unit = "player", type = "buff", points = {"CENTER",0,-72}, size = 36}, -- 2t10 restor proc
		{spell = 8178, isMine = true, unit = "player", type = "buff", points = {"CENTER",-108,36}, size = 36}, -- ground

	}
}


local type,pairs = type,pairs
local setmetatable,CreateFrame = setmetatable,CreateFrame
local UnitExists,UnitAura = UnitExists,UnitAura


local AT = engine:New("AuraTracker")
local CT = engine:Get("CooldownTimer")


local function UnitAuraBySpellID(unit,a_spellId,filter)
	local ret1,ret2,ret3,ret4,ret5,ret6,ret7,ret8,ret9,ret10,spellId
	for i = 1,40 do
		ret1,ret2,ret3,ret4,ret5,ret6,ret7,ret8,ret9,ret10,spellId = UnitAura(unit,i,filter)

		if not ret1 then
			break
		end

		if spellId == a_spellId then
			return ret1,ret2,ret3,ret4,ret5,ret6,ret7,ret8,ret9,ret10,spellId
		end
	end
end


local prototype = setmetatable(CopyTable(engine:GetObjectPrototype()),getmetatable(FriendsListFrame))
local frameMT = {__index = prototype}


function prototype:UpdateAuras()
	local unit = self.unit
	local spell = self.spell
	local filter = self.filter


	local name,texture,count,duration,endTime,_
	if type(spell) == "number" then
		name,_,texture,count,_,duration,endTime = UnitAuraBySpellID(unit,spell,filter)
	else
		name,_,texture,count,_,duration,endTime = UnitAura(unit,spell,nil,filter)
	end

	if texture then
		if duration == 0 then
			self.cd:Hide()
		else
			self.cd:SetCooldown(endTime-duration,duration)
		end

		if count > 1 then
			self.count:Show()
			self.count:SetText(count)
		else
			self.count:Hide()
		end

		self.texture:SetTexture(texture)

		self:Show()
	else
		self:Hide()
	end
end

function prototype:Update()
	if UnitExists(self.unit) then
		self:UpdateAuras()
	else
		self:Hide()
	end
end


function prototype:OnUnitAura(unit)
	if unit ~= self.unit then
		return
	end

	self:Update()
end

function AT:CreateFrame()
	local frame = setmetatable(CreateFrame("frame",nil,UIParent),frameMT)
	frame:Hide()
	frame:SetFrameStrata("HIGH")

	local texture = frame:CreateTexture(nil,"BORDER")
	texture:SetAllPoints()

	local cd = CreateFrame("Cooldown",nil,frame)
	cd:SetReverse(true)
	cd:SetDrawEdge(true)
	cd:SetAllPoints()

	local count = frame:CreateFontString(nil,"ARTWORK","NumberFontNormal")
	count:SetPoint("BOTTOMRIGHT")

	frame:RegisterEvent("UNIT_AURA",frame.OnUnitAura)
	frame:RegisterEvent("PLAYER_ENTERING_WORLD",frame.Update)

	frame.texture = texture
	frame.cd = cd
	frame.count = count

	return frame
end

function AT:SetupFrame(frame,data)
	assert(data.spell,"spell field missed")
	local unit = data.unit
	frame.unit = unit
	frame.spell = data.spell

	if not data.type or data.type == "buff" then
		frame.filter = "HELPFUL"
	else
		frame.filter = "HARMFUL"
	end

	if unit == "target" then
		frame:RegisterEvent("PLAYER_TARGET_CHANGED",frame.Update)
	elseif unit == "focus" then
		frame:RegisterEvent("PLAYER_FOCUS_CHANGED",frame.Update)
	end

	if data.isMine then
		frame.filter = frame.filter.."|PLAYER"
	end

	if data.points then
		frame:SetPoint(unpack(data.points))
	else
		frame:SetPoint("CENTER")
	end

	local size = data.size or 32
	frame:SetSize(size,size)
	CT:Create(frame.cd,size*0.3)
end

function AT:Initialize()
	for i = 1,#DATA do
		self:SetupFrame(self:CreateFrame(),DATA[i])
	end

	local classDATA = DATA[select(2,UnitClass("player"))]
	if classDATA then
		for i = 1,#classDATA do
			self:SetupFrame(self:CreateFrame(),classDATA[i])
		end
	end

	self.CreateFrame,self.SetupFrame = nil
end