local _, ns = ...
local UF = ns:GetModule("UnitFrames")

local GetSpellCooldown = GetSpellCooldown
local GetSpellInfo = GetSpellInfo
local GetTime = GetTime

local config = ns.Config.unitFrames

local MAX_GCD = 1.5
local BAR_GAP = 1
local TEST_DURATION = 1.5

local REFERENCE_SPELLS = {
	WARRIOR = 1715, -- Hamstring
	PALADIN = 21084, -- Seal of Righteousness
	HUNTER = 1978, -- Serpent Sting
	ROGUE = 1752, -- Sinister Strike
	PRIEST = 1243, -- Power Word: Fortitude
	DEATHKNIGHT = 47541, -- Death Coil
	SHAMAN = 403, -- Lightning Bolt
	MAGE = 116, -- Frostbolt
	WARLOCK = 686, -- Shadow Bolt
	DRUID = 5176, -- Wrath
}

local referenceName = REFERENCE_SPELLS[ns.PLAYER_CLASS] and GetSpellInfo(REFERENCE_SPELLS[ns.PLAYER_CLASS])

local function onUpdate(bar)
	local elapsed = GetTime() - bar.start
	if elapsed >= bar.duration then
		bar:SetScript("OnUpdate", nil)
		bar:Hide()
		return
	end
	bar:SetValue(elapsed / bar.duration)
end

local function run(bar, start, duration)
	bar.start, bar.duration = start, duration
	bar:SetValue(0)
	bar:Show()
	bar:SetScript("OnUpdate", onUpdate)
end

local function stop(bar)
	bar:SetScript("OnUpdate", nil)
	bar:Hide()
end

local function layout(bar, castbar)
	bar:ClearAllPoints()
	bar:SetPoint("TOPLEFT", castbar, "BOTTOMLEFT", 0, -BAR_GAP)
	bar:SetPoint("TOPRIGHT", castbar, "BOTTOMRIGHT", 0, -BAR_GAP)
	bar:SetHeight(config.playerGcdHeight)
	bar:SetStatusBarColor(unpack(config.playerGcdColor))
end

local function update(frame)
	local bar = frame.gcd
	if not bar then
		return
	end
	layout(bar, frame.castbar)
	if not config.playerGcd or not referenceName then
		stop(bar)
		return
	end
	local start, duration = GetSpellCooldown(referenceName)
	if start and duration and duration > 0 and duration <= MAX_GCD then
		if bar.start ~= start or not bar:IsShown() then
			run(bar, start, duration)
		end
	else
		stop(bar)
	end
end

local function test(frame)
	local bar = frame.gcd
	if bar and config.playerGcd then
		layout(bar, frame.castbar)
		run(bar, GetTime(), TEST_DURATION)
	end
end

local function create(frame)
	if frame.unit ~= "player" or not frame.castbar then
		return nil
	end
	local bar = CreateFrame("StatusBar", nil, frame)
	bar:SetFrameLevel(frame.castbar:GetFrameLevel())
	ns.SkinStatusBar(bar)
	bar:SetMinMaxValues(0, 1)
	bar:Hide()
	local background = bar:CreateTexture(nil, "BACKGROUND")
	background:SetAllPoints()
	background:SetTexture(0, 0, 0, 0.6)
	frame:RegisterEvent("SPELL_UPDATE_COOLDOWN", update)
	return bar
end

UF:RegisterElement({ name = "gcd", Create = create, Update = update, Test = test })
