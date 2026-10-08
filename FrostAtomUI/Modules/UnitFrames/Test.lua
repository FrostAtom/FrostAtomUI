local _, ns = ...
local UF = ns:GetModule("UnitFrames")
local L = ns.L

local RegisterUnitWatch, UnregisterUnitWatch = RegisterUnitWatch, UnregisterUnitWatch
local InCombatLockdown = InCombatLockdown
local random, floor, tremove, wipe = math.random, math.floor, table.remove, wipe

local NAMES = {
	"Frostatom",
	"Nightshade",
	"Zephyra",
	"Thoralf",
	"Mirelle",
	"Kaelith",
	"Dravok",
	"Sylvara",
	"Ignatius",
	"Vexara",
	"Bramblefoot",
	"Orinthal",
	"Ravenna",
	"Grimshaw",
	"Aldric",
	"Brynja",
	"Corvin",
	"Darika",
	"Elowen",
	"Fenrick",
	"Galena",
	"Hroth",
	"Isolde",
	"Jorvik",
	"Kestra",
	"Lothar",
	"Maelis",
	"Norvak",
	"Oriel",
	"Perrin",
	"Quilla",
	"Rurik",
	"Seraphine",
	"Tamsin",
	"Ulfgar",
	"Velka",
	"Wrenna",
	"Xandor",
	"Yselle",
	"Zarek",
}
local PET_NAMES = { "Voidwalker", "Felhunter", "Wolf", "Ghoul", "Cat", "Succubus", "Bear", "Imp", "Treant" }

local CLASS_POWER = { WARRIOR = 1, ROGUE = 3, DEATHKNIGHT = 6 }
local DRUID_POWER = { 0, 1, 3 }
local POWER_MAX = { [0] = 24000, [1] = 100, [2] = 100, [3] = 100, [6] = 100 }

local namePool = {}

local function takeName(names)
	local pool = namePool[names]
	if not pool or #pool == 0 then
		pool = {}
		for i = 1, #names do
			pool[i] = names[i]
		end
		namePool[names] = pool
	end
	return tremove(pool, random(#pool))
end

local function makeData(frame)
	local unit = frame.baseUnit
	local data = {}

	if unit:find("pet") then
		data.name = takeName(PET_NAMES)
		data.healthMax = random(8000, 18000)
		data.powerType = random(2) == 1 and 0 or 2
	else
		local class = UF.classList[random(#UF.classList)]
		data.class = class
		data.spec = random(4) ~= 1 and random(3) or nil
		data.name = takeName(NAMES)
		data.healthMax = random(22000, 36000)
		data.powerType = class == "DRUID" and DRUID_POWER[random(#DRUID_POWER)] or CLASS_POWER[class] or 0
		data.leader = random(4) == 1
	end

	data.dead = unit ~= "player" and random(10) == 1
	data.health = floor(data.healthMax * random(15, 100) / 100)
	data.incoming = random(2) == 1 and floor(data.healthMax * random(5, 25) / 100) or 0
	data.incomingOwn = random(2) == 1 and floor(data.incoming * random(20, 80) / 100) or 0
	data.absorb = random(3) == 1 and floor(data.healthMax * random(5, 20) / 100) or 0
	data.powerMax = POWER_MAX[data.powerType]
	data.power = floor(data.powerMax * random(0, 100) / 100)

	return data
end

function UF:RunTest(frame)
	if not frame.test then
		return
	end
	for _, element in ipairs(self.elementOrder) do
		if frame[element.name] and element.test then
			element.test(frame)
		end
	end
end

local function startTest(frame)
	UnregisterUnitWatch(frame)
	if not frame.watched then
		frame.test = nil
		frame:Hide()
		return
	end
	frame:Show()
	frame.test = makeData(frame)
	UF:RunTest(frame)
end
UF.StartTest = startTest

local function stopTest(frame)
	frame.test = nil
	if frame.watched then
		RegisterUnitWatch(frame)
	else
		frame:Hide()
	end
	frame:UpdateAll()
end

function UF:SetTestMode(enabled)
	if enabled == (self.testing or false) then
		return
	end
	if InCombatLockdown() then
		ns.Print(L["unit frame test mode is not available in combat"])
		return
	end

	self.testing = enabled
	wipe(namePool)
	for i = 1, #self.frames do
		local frame = self.frames[i]
		if enabled then
			startTest(frame)
		else
			stopTest(frame)
		end
	end
	ns.Print(L["unit frame test mode %s"], enabled and L["on"] or L["off"])
	ns.API.PreviewChanged("unitFrames")
end

local function toggleTest()
	UF:SetTestMode(not UF.testing)
end

ns.API.RegisterPreview("unitFrames", {
	Set = function(active)
		UF:SetTestMode(active)
	end,
	IsActive = function()
		return UF.testing
	end,
	IsAvailable = function()
		return UF.frames ~= nil and #UF.frames > 0
	end,
})
ns.API.RegisterAction("unitFrameTest", toggleTest)

SlashCmdList.FROSTATOMUI_UNITFRAME_TEST = toggleTest
SLASH_FROSTATOMUI_UNITFRAME_TEST1 = "/uftest"
