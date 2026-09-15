local engine = select(2,...)
local UF = engine:Get("UnitFrames")


local UnitAura = UnitAura
local CreateFrame = CreateFrame

local CooldownTimer = engine:Get("CooldownTimer")

local SPELLS = { -- 0 = debuff, 1 = buff
    [47481] = 0, [51209] = 0, [47476] = 0, [5211]  = 0, [33786] = 0, [2637]  = 0, [22570] = 0, [9005]  = 0,
    [339]   = 0, [19675] = 0, [60210] = 0, [3355]  = 0, [24394] = 0, [1513]  = 0, [19503] = 0, [19386] = 0,
    [34490] = 0, [53359] = 0, [19306] = 0, [19185] = 0, [50519] = 0, [50541] = 0, [50245] = 0, [50518] = 0,
    [54706] = 0, [4167]  = 0, [44572] = 0, [31661] = 0, [12355] = 0, [118]   = 0, [18469] = 0, [64346] = 0,
    [33395] = 0, [122]   = 0, [11071] = 0, [55080] = 0, [853]   = 0, [2812]  = 0, [20066] = 0, [20170] = 0,
    [10326] = 0, [63529] = 0, [605]   = 0, [64044] = 0, [8122]  = 0, [9484]  = 0, [15487] = 0, [2094]  = 0,
    [1833]  = 0, [1776]  = 0, [408]   = 0, [6770]  = 0, [1330]  = 0, [18425] = 0, [51722] = 0, [39796] = 0,
    [51514] = 0, [64695] = 0, [63685] = 0, [710]   = 0, [6789]  = 0, [5782]  = 0, [5484]  = 0, [6358]  = 0,
    [30283] = 0, [24259] = 0, [7922]  = 0, [12809] = 0, [20253] = 0, [5246]  = 0, [12798] = 0, [46968] = 0,
    [18498] = 0, [676]   = 0, [58373] = 0, [23694] = 0, [30217] = 0, [67769] = 0, [30216] = 0, [20549] = 0,
    [25046] = 0, [39965] = 0, [55536] = 0, [13099] = 0, [46924] = 1, [642]   = 1, [45438] = 1, [34692] = 1,
    [28169] = 0, [28059] = 0, [28084] = 0, [27819] = 0, [63024] = 0, [63018] = 0, [62589] = 0, [63276] = 0,
    [66770] = 0, [48792] = 0, [1044] = 1, [10278] = 1,
}

do
    local GetSpellInfo = GetSpellInfo
    local tmp = SPELLS
    SPELLS = {}
    for spellid,value in pairs(tmp) do
        SPELLS[GetSpellInfo(spellid)] = value
    end
end



local function updateFunc(self,unit)
    if unit then
        if unit ~= self.unit then
            return
        end
    else
        unit = self.unit
    end

    local maxEndTime,_dur,_texture = 0
    local name,texture,dur,endTime,_
	for i = 1,40 do
        name,_,texture,_,_,dur,endTime = UnitAura(unit,i,"HARMFUL")
        if not name then
            break
        end

        if SPELLS[name] and endTime > maxEndTime then
            maxEndTime = endTime
            _dur,_texture = dur,texture
        end
    end

    --[[if unit ~= "player" then
        for i = 1,40 do
            name,_,texture,_,_,dur,endTime = UnitAura(unit,i,"HELPFUL")
            if not name then break end

            if SPELLS[name] == 1 and endTime > maxEndTime then
	            maxEndTime = endTime
	            _dur,_texture = dur,texture
            end
        end
    end]]

	local losecontrol = self.losecontrol
    if maxEndTime == 0 then
		losecontrol:Hide()
    else
    	losecontrol.texture:SetTexture(_texture)
    	losecontrol:SetCooldown(maxEndTime-_dur,_dur)
    end
end

local function createFunc(self,fontSize)
	local losecontrol = CreateFrame("Cooldown",nil,self)
	losecontrol:SetReverse(true)
	CooldownTimer:Create(losecontrol,fontSize or 10)

	local texture = losecontrol:CreateTexture(nil,"BORDER")
	texture:SetAllPoints(losecontrol)


	self:RegisterEvent("UNIT_AURA",updateFunc)

    losecontrol.texture = texture
	return losecontrol
end


UF:AddModule("losecontrol",createFunc,updateFunc)