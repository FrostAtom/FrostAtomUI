local _, ns = ...

local GetRuneType = GetRuneType
local GetRuneCooldown = GetRuneCooldown
local GetTime = GetTime
local ceil, max, min = math.ceil, math.max, math.min

local Runes = ns:NewModule("Runes")
Runes.configKey = "runes"

local NUM_RUNES = 6
local DEATH_RUNE = 4
local CHARGING_SHADE = 0.4
local BACKGROUND_SHADE = 0.12
local BACKGROUND_ALPHA = 0.9
local GLOSS_ALPHA = 0.3
local ICON_EXTRA = 10
local ICON_CHARGING_SHADE = 0.5
local SPARK_WIDTH = 10
local SPARK_SCALE = 2.2
local FLASH_DURATION = 0.4
local FLASH_ALPHA = 0.8

local SPARK_TEXTURE = "Interface\\CastingBar\\UI-CastingBar-Spark"

local RUNE_COLOR_KEYS = { "bloodColor", "unholyColor", "frostColor", "deathColor" }

local RUNE_ICONS = {
	"Interface\\PlayerFrame\\UI-PlayerFrame-Deathknight-Blood",
	"Interface\\PlayerFrame\\UI-PlayerFrame-Deathknight-Unholy",
	"Interface\\PlayerFrame\\UI-PlayerFrame-Deathknight-Frost",
	"Interface\\PlayerFrame\\UI-PlayerFrame-Deathknight-Death",
}

local runes = {}
local holder

local RuneMixin = {}

function RuneMixin:Flash()
	if not ns.Config.runes.readyFlash then
		return
	end
	local flash = self.flash
	flash.animation:Stop()
	flash:Show()
	flash.animation:Play()
end

function RuneMixin:UpdateColors()
	local color = self.color
	local r, g, b = color[1], color[2], color[3]
	local ready = self.ready
	local shade = ready and 1 or CHARGING_SHADE
	self:SetStatusBarColor(r * shade, g * shade, b * shade)
	self.bg:SetVertexColor(r * BACKGROUND_SHADE, g * BACKGROUND_SHADE, b * BACKGROUND_SHADE, BACKGROUND_ALPHA)
	ns.SetShown(self.gloss, ready)
	ns.SetShown(self.spark, not ready)

	local iconShade = ready and 1 or ICON_CHARGING_SHADE
	self.icon:SetDesaturated(not ready)
	self.icon:SetVertexColor(iconShade, iconShade, iconShade)
	if ready then
		self.timer:SetText(nil)
	end
end

function RuneMixin:UpdateType()
	local config = ns.Config.runes
	local runeType = GetRuneType(self:GetID())
	if runeType == DEATH_RUNE and self.runeType and self.runeType ~= DEATH_RUNE then
		self:Flash()
	end
	self.runeType = runeType
	self.color = config[RUNE_COLOR_KEYS[runeType]] or config.emptyColor
	self.icon:SetTexture(RUNE_ICONS[runeType])
	self:UpdateColors()
end

function RuneMixin:OnUpdate()
	local start, duration, ready = GetRuneCooldown(self:GetID())
	if not start then
		return
	end
	ready = ready or duration == 0
	if ready ~= self.ready then
		if ready and self.ready == false then
			self:Flash()
		end
		self.ready = ready
		self:UpdateColors()
	end
	if ready then
		self:SetValue(1)
		self:SetScript("OnUpdate", nil)
		return
	end

	local now = GetTime()
	local progress = min(max((now - start) / duration, 0), 1)
	self:SetValue(progress)
	self.spark:SetPoint("CENTER", self, "LEFT", self:GetWidth() * progress, 0)
	self.timer:SetFormattedText("%d", ceil(start + duration - now))
end

function RuneMixin:UpdateAll()
	self.ready = nil
	self.runeType = nil
	self:UpdateType()
	self:SetScript("OnUpdate", self.OnUpdate)
	self:OnUpdate()
end

function RuneMixin:RUNE_TYPE_UPDATE(rune)
	if rune == self:GetID() then
		self:UpdateType()
	end
end

function RuneMixin:RUNE_POWER_UPDATE(rune)
	if rune == self:GetID() then
		self:SetScript("OnUpdate", self.OnUpdate)
		self:OnUpdate()
	end
end

local function hideFlash(animation)
	animation:GetParent():Hide()
end

local function createRune(id)
	local rune = CreateFrame("StatusBar", nil, holder)
	ns.Mixin(rune, ns.EventMixin, RuneMixin)
	rune:SetID(id)
	rune:SetMinMaxValues(0, 1)

	ns.SkinStatusBar(rune)

	rune.border = rune:CreateTexture(nil, "BACKGROUND", nil, -1)
	rune.border:SetTexture(0, 0, 0, 1)

	rune.bg = rune:CreateTexture(nil, "BACKGROUND")
	rune.bg:SetTexture(ns.Media.blank)
	rune.bg:SetAllPoints()

	rune.gloss = rune:CreateTexture(nil, "OVERLAY")
	rune.gloss:SetTexture(ns.Media.blank)
	rune.gloss:SetBlendMode("ADD")
	rune.gloss:SetGradientAlpha("VERTICAL", 1, 1, 1, 0, 1, 1, 1, GLOSS_ALPHA)
	rune.gloss:SetAllPoints()

	rune.spark = rune:CreateTexture(nil, "OVERLAY", nil, 1)
	rune.spark:SetTexture(SPARK_TEXTURE)
	rune.spark:SetBlendMode("ADD")

	local flash = CreateFrame("Frame", nil, rune)
	flash:SetAllPoints()
	flash:SetFrameLevel(rune:GetFrameLevel() + 1)
	flash:Hide()
	local flashTexture = flash:CreateTexture(nil, "OVERLAY")
	flashTexture:SetTexture(ns.Media.blank)
	flashTexture:SetBlendMode("ADD")
	flashTexture:SetVertexColor(1, 1, 1, FLASH_ALPHA)
	flashTexture:SetAllPoints()
	local animation = flash:CreateAnimationGroup()
	local alpha = animation:CreateAnimation("Alpha")
	alpha:SetChange(-1)
	alpha:SetDuration(FLASH_DURATION)
	animation:SetScript("OnFinished", hideFlash)
	flash.animation = animation
	rune.flash = flash

	local overlay = CreateFrame("Frame", nil, rune)
	overlay:SetAllPoints()
	overlay:SetFrameLevel(rune:GetFrameLevel() + 2)

	rune.icon = overlay:CreateTexture(nil, "ARTWORK")
	rune.icon:SetPoint("CENTER")

	rune.timer = overlay:CreateFontString(nil, "OVERLAY")
	rune.timer:SetPoint("CENTER")

	rune:RegisterEvent("PLAYER_ENTERING_WORLD", "UpdateAll")
	rune:RegisterEvent("RUNE_TYPE_UPDATE")
	rune:RegisterEvent("RUNE_POWER_UPDATE")

	runes[id] = rune
	return rune
end

local function applyConfig()
	local config = ns.Config.runes
	local width, height, gap = config.width, config.height, config.gap
	local iconSize = min(height + ICON_EXTRA, width)
	local edge = ns.PixelPerfect(1, holder)
	local font = config.timerFont
	holder:SetSize(NUM_RUNES * (width + gap) - gap, height)

	local slot = width + gap
	for i = 1, NUM_RUNES do
		local rune = runes[i]
		rune:SetSize(width, height)
		rune:ClearAllPoints()
		rune:SetPoint("CENTER", holder, -1 + (3.5 - i) * slot, 0)
		rune.border:ClearAllPoints()
		rune.border:SetPoint("TOPLEFT", -edge, edge)
		rune.border:SetPoint("BOTTOMRIGHT", edge, -edge)
		rune.spark:SetSize(SPARK_WIDTH, height * SPARK_SCALE)
		rune.icon:SetSize(iconSize, iconSize)
		ns.SetShown(rune.icon, config.showIcons)
		ns.SetFont(rune.timer, font.size, font.outline)
		ns.SetShown(rune.timer, config.showTimer)
		rune:UpdateAll()
	end
end

function Runes:Initialize()
	if ns.PLAYER_CLASS ~= "DEATHKNIGHT" then
		return
	end

	holder = CreateFrame("Frame", nil, UIParent)
	self:AnchorToConfig(holder, "runes.point", "Runes")

	for i = 1, NUM_RUNES do
		createRune(i)
	end

	applyConfig()
	self:WatchConfig("runes", applyConfig)
	self:RegisterEvent(ns.PIXEL_CHANGED, applyConfig)
end
