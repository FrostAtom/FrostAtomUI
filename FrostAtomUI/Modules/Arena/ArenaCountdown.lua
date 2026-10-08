local _, ns = ...

local IsInInstance = IsInInstance
local ceil, floor, min, max = math.ceil, math.floor, math.min, math.max

local ArenaCountdown = ns:NewModule("ArenaCountdown")

local COUNTDOWN_MESSAGES = {
	{ "Thirty seconds until the Arena battle begins!", 30 },
	{ "Тридцать секунд", 30 },
	{ "тридцать секунд", 30 },
	{ "30 секунд", 30 },
	{ "Fifteen seconds until the Arena battle begins!", 15 },
	{ "Пятнадцать секунд", 15 },
	{ "пятнадцать секунд", 15 },
	{ "15 секунд", 15 },
}
local COUNTDOWN_SECONDS = 30
local NUMBERS_SECONDS = 10
local LARGE_SECONDS = 5
local URGENT_SECONDS = 3
local DIGIT_SIZE = 7
local DIGIT_PITCH = 0.8
local WORD_COORDS = {
	enUS = { 0.4375, 0.8125, 0.5, 0.75 },
	ruRU = { 0.4375, 0.8125, 0.75, 1 },
}
local BAR_WIDTH = 195
local BAR_HEIGHT = 13
local BAR_FADE_IN = 1.9
local BAR_FADE_OUT = 0.9
local BAR_COLOR = { 1, 0, 0 }
local TIME_SIZE = 0.5
local GROW_FROM = 0.25
local NUMBER_GROW = 0.3
local NUMBER_HOLD = 0.9
local NUMBER_FADE = 0.1
local NUMBER_FADE_SCALE = 1.2
local FIGHT_GROW = 0.4
local FIGHT_HOLD = 1
local FIGHT_FADE = 0.2
local FIGHT_FADE_SCALE = 1.4
local BAR_TEXTURE = "Interface\\TargetingFrame\\UI-StatusBar"
local BAR_BORDER = "Interface\\CastingBar\\UI-CastingBar-Border"

local countdown = CreateFrame("Frame", nil, UIParent)
countdown:SetFrameStrata("HIGH")
countdown:Hide()
ArenaCountdown:AnchorToConfig(countdown, "arena.countdownPoint", "Arena countdown", {
	size = function()
		local size = ns.Config.arena.countdownFont.size * DIGIT_SIZE
		return size * 1.5, size
	end,
	floating = true,
})

local bar = CreateFrame("StatusBar", nil, countdown)
bar:SetSize(BAR_WIDTH, BAR_HEIGHT)
bar:SetPoint("CENTER")
bar:SetStatusBarTexture(BAR_TEXTURE)
bar:SetStatusBarColor(unpack(BAR_COLOR))

local barBackground = bar:CreateTexture(nil, "BACKGROUND")
barBackground:SetTexture(ns.Media.blank)
barBackground:SetVertexColor(0, 0, 0, 0.5)
barBackground:SetAllPoints()

local barBorder = bar:CreateTexture(nil, "OVERLAY")
barBorder:SetTexture(BAR_BORDER)
barBorder:SetSize(256, 64)
barBorder:SetPoint("TOP", 0, 25)

local timeText = bar:CreateFontString(nil, "OVERLAY")
timeText:SetPoint("CENTER")

local function createGlyph(frame, blend)
	local texture = frame:CreateTexture(nil, "ARTWORK")
	texture:SetBlendMode(blend)
	return texture
end

local function createGlyphs(blend, level)
	local frame = CreateFrame("Frame", nil, countdown)
	frame:SetSize(1, 1)
	frame:SetPoint("CENTER")
	frame:SetFrameLevel(countdown:GetFrameLevel() + level)
	frame.digits = { createGlyph(frame, blend), createGlyph(frame, blend) }
	frame.word = createGlyph(frame, blend)
	frame.word:SetPoint("CENTER")
	return frame
end

local numberFrame = createGlyphs("BLEND", 1)
local glowFrame = createGlyphs("ADD", 2)
local glyphFrames = { numberFrame, glowFrame }

local function setDigit(texture, digit)
	local row = digit < 8 and 0 or 0.5
	local left = (digit < 8 and digit or digit - 8) * 0.125
	texture:SetTexCoord(left, left + 0.125, row, row + 0.5)
	texture:Show()
end

local function setGlyphs(frame, value, r, g, b)
	local digits, word = frame.digits, frame.word
	for i = 1, 2 do
		digits[i]:Hide()
		digits[i]:SetVertexColor(r, g, b)
	end
	word:SetVertexColor(r, g, b)
	if not value then
		word:SetTexCoord(unpack(WORD_COORDS[ns.LOCALE] or WORD_COORDS.enUS))
		word:Show()
		return
	end
	word:Hide()
	local pitch = frame.pitch
	if value < 10 then
		setDigit(digits[1], value)
		digits[1]:SetPoint("CENTER")
	else
		setDigit(digits[1], floor(value / 10))
		setDigit(digits[2], value % 10)
		digits[1]:SetPoint("CENTER", -pitch / 2, 0)
		digits[2]:SetPoint("CENTER", pitch / 2, 0)
	end
end

local function sizeGlyphs(frame, height)
	for i = 1, 2 do
		frame.digits[i]:ClearAllPoints()
		frame.digits[i]:SetSize(height / 2, height)
	end
	frame.word:SetSize(height * 1.5, height / 2)
	frame.pitch = height / 2 * DIGIT_PITCH
end

local texturesLoaded = false

local function loadTextures()
	texturesLoaded = true
	for _, frame in ipairs(glyphFrames) do
		for _, texture in ipairs({ frame.digits[1], frame.digits[2], frame.word }) do
			texture:SetTexture(ns.Media.arenaCountdown)
		end
	end
end

local function showGlyphs(value, height, r, g, b)
	if not texturesLoaded then
		loadTextures()
	end
	for i = 1, #glyphFrames do
		local frame = glyphFrames[i]
		sizeGlyphs(frame, height)
		setGlyphs(frame, value, r, g, b)
	end
end

local function easeOut(progress)
	local rest = 1 - progress
	return 1 - rest * rest
end

local function pop(scale, alpha, glowAlpha)
	numberFrame:SetScale(scale)
	numberFrame:SetAlpha(alpha)
	glowFrame:SetScale(scale)
	glowFrame:SetAlpha(glowAlpha)
end

local function animate(phase, grow, hold, fade, fadeScale, smoothFade)
	if phase < grow then
		local progress = phase / grow
		pop(GROW_FROM + (1 - GROW_FROM) * easeOut(progress), 1, 1 - progress * progress)
	elseif phase < hold then
		pop(1, 1, 0)
	else
		local progress = min((phase - hold) / fade, 1)
		if smoothFade then
			progress = easeOut(progress)
		end
		pop(1 + (fadeScale - 1) * progress, 1 - progress, 0)
	end
end

local function updateBar(self)
	local fadeIn = min(self.elapsed / BAR_FADE_IN, 1)
	local fadeOut = min((self.remain - NUMBERS_SECONDS) / BAR_FADE_OUT, 1)
	bar:SetAlpha(max(fadeIn * fadeOut, 0))
	bar:SetValue(self.remain)
	timeText:SetText(ns.FormatClock(self.remain))
end

local function updateNumber(self)
	local second = ceil(self.remain)
	if second ~= self.second then
		self.second = second
		bar:Hide()
		local config = ns.Config.arena
		local color = second <= URGENT_SECONDS and config.countdownUrgentColor or config.countdownColor
		local height = second <= LARGE_SECONDS and self.digitSize or self.digitSize / 2
		showGlyphs(second, height, unpack(color))
	end
	animate(second - self.remain, NUMBER_GROW, NUMBER_HOLD, NUMBER_FADE, NUMBER_FADE_SCALE)
end

local function updateFight(self, phase)
	if self.second ~= 0 then
		self.second = 0
		bar:Hide()
		showGlyphs(nil, self.digitSize, unpack(ns.Config.arena.countdownColor))
	end
	animate(phase, FIGHT_GROW, FIGHT_HOLD, FIGHT_FADE, FIGHT_FADE_SCALE, true)
	if phase >= FIGHT_HOLD + FIGHT_FADE then
		self:Hide()
	end
end

countdown:SetScript("OnUpdate", function(self, elapsed)
	self.remain = self.remain - elapsed
	self.elapsed = self.elapsed + elapsed
	if self.remain > NUMBERS_SECONDS then
		updateBar(self)
	elseif self.remain > 0 then
		updateNumber(self)
	else
		updateFight(self, -self.remain)
	end
end)

local function startCountdown(seconds)
	if countdown:IsShown() and countdown.remain > NUMBERS_SECONDS then
		countdown.remain = seconds
		return
	end
	countdown.remain = seconds
	countdown.elapsed = 0
	countdown.second = nil
	bar:SetMinMaxValues(0, seconds)
	pop(1, 0, 0)
	updateBar(countdown)
	bar:Show()
	countdown:Show()
end

SlashCmdList.FROSTATOMUI_ARENA_COUNTDOWN_TEST = function(seconds)
	startCountdown(tonumber(seconds) or COUNTDOWN_SECONDS)
end
ns.API.RegisterAction("arenaCountdownTest", SlashCmdList.FROSTATOMUI_ARENA_COUNTDOWN_TEST)

local function countdownSeconds(message)
	for i = 1, #COUNTDOWN_MESSAGES do
		local entry = COUNTDOWN_MESSAGES[i]
		if message:find(entry[1], 1, true) then
			return entry[2]
		end
	end
end

countdown:SetScript("OnEvent", function(self, event, message)
	if event == "PLAYER_ENTERING_WORLD" then
		self:Hide()
	elseif
		ns.Config.arena.enabled
		and ns.Config.arena.countdown
		and message
		and select(2, IsInInstance()) == "arena"
	then
		local seconds = countdownSeconds(message)
		if seconds then
			startCountdown(seconds)
		end
	end
end)
countdown:RegisterEvent("CHAT_MSG_BG_SYSTEM_NEUTRAL")
countdown:RegisterEvent("PLAYER_ENTERING_WORLD")

local function applyConfig()
	local config = ns.Config.arena
	local font = config.countdownFont
	countdown.digitSize = font.size * DIGIT_SIZE
	countdown:SetSize(countdown.digitSize * 1.5, countdown.digitSize)
	ns.SetFont(timeText, font.size * TIME_SIZE, font.outline)
	if not (config.enabled and config.countdown) then
		countdown:Hide()
	end
end

applyConfig()
ArenaCountdown:WatchConfig("arena", applyConfig)
