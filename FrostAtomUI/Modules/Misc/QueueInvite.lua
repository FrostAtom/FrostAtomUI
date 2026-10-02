local _, ns = ...

local L = ns.L

local GetBattlefieldStatus = GetBattlefieldStatus
local GetBattlefieldPortExpiration = GetBattlefieldPortExpiration
local StaticPopup_FindVisible = StaticPopup_FindVisible
local PlaySoundFile = PlaySoundFile
local GetCVar = GetCVar
local GetTime = GetTime
local random = math.random
local abs, ceil, cos, min, max = math.abs, math.ceil, math.cos, math.min, math.max
local MAX_BATTLEFIELD_QUEUES = MAX_BATTLEFIELD_QUEUES or 2

local Misc = ns:GetModule("Misc")
local pulse = ns.QueuePulse

local WHICH = "CONFIRM_BATTLEFIELD_ENTRY"
local INVITE_SOUND = "Sound\\Spells\\PVPThroughQueue.wav"
local COUNTDOWN_FONT_SIZE = 20
local COUNTDOWN_TICK = 0.2
local COUNTDOWN_URGENT = 10
local COUNTDOWN_URGENT_COLOR = { 1, 0.3, 0.3 }
local COUNTDOWN_OFFSET = 8
local COUNTDOWN_FALLBACK_Y = 160

local DIALOG_WIDTH = 340
local DIALOG_HEIGHT = 178
local DIALOG_INSETS = { left = 11, right = 12, top = 12, bottom = 11 }
local DIALOG_BACKDROP = {
	bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
	edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Gold-Border",
	tile = true,
	tileSize = 32,
	edgeSize = 32,
	insets = DIALOG_INSETS,
}
local BLIZZARD_BACKDROP = {
	bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
	edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
	tile = true,
	tileSize = 32,
	edgeSize = 32,
	insets = DIALOG_INSETS,
}
local BANNER_HEIGHT = 90
local BAR_HEIGHT = 16
local BAR_BOTTOM = 50
local BAR_SIDE = 26
local BAR_COLOR = { 1, 0.72, 0 }
local BAR_URGENT_COLOR = { 1, 0.15, 0.1 }
local GOLD = { 1, 0.82, 0 }
local GLOW_TEXTURE = "Interface\\Buttons\\UI-Panel-Button-Glow"
local SHINE_WIDTH = 90
local SHINE_ALPHA = 0.55
local SHINE_TIME = 0.8
local SHINE_FIRST = 0.25
local SHINE_EVERY = 3.5
local TITLE_POP_TIME = 0.35
local TITLE_POP_SCALE = 2.2
local TITLE_GLOW_TIME = 0.6
local TITLE_BEAT_GLOW = 0.5
local DETAIL_DELAY = 0.2
local DETAIL_FADE = 0.3
local ZOOM_TIME = 0.9
local ZOOM_FROM = 1.18
local DRIFT_ZOOM = 0.04
local DRIFT_SPEED = 0.3
local ART_DIM = 0.75
local ART_BEAT = 0.25
local BUTTON_GLOW_MIN = 0.3

local ARENA_ART = {
	{ "Interface\\Glues\\LoadingScreens\\LoadScreenOrgrimmarArena", 0.42, 0.8 },
	{ "Interface\\Glues\\LoadingScreens\\LoadScreenDalaranSewersArena", 0.42, 0.8 },
	{ "Interface\\Glues\\LoadingScreens\\LoadScreenBladesEdgeArena", 0.44, 0.82 },
	{ "Interface\\Glues\\LoadingScreens\\LoadScreenNagrandArenaBattlegrounds", 0.44, 0.82 },
	{ "Interface\\Glues\\LoadingScreens\\LoadScreenRuinsofLordaeronBattlegrounds", 0.44, 0.82 },
}
local BATTLEGROUND_ART = { "Interface\\Glues\\LoadingScreens\\LoadScreenPvpBattleground", 0.22, 0.6 }

local invites = {}

local function getInvite(index)
	local invite = invites[index]
	if invite then
		return invite
	end
	local _, _, _, _, _, teamSize = GetBattlefieldStatus(index)
	local expiration = GetBattlefieldPortExpiration(index)
	invite = {
		start = GetTime(),
		total = max(expiration, 1),
		expireAt = GetTime() + expiration,
		art = teamSize ~= 0 and ARENA_ART[random(#ARENA_ART)] or BATTLEGROUND_ART,
	}
	invites[index] = invite
	return invite
end

local function easeOut(progress)
	local rest = 1 - progress
	return 1 - rest * rest * rest
end

local function fade(t, delay, duration)
	return min(max((t - delay) / duration, 0), 1)
end

local function setSegment(texture, left, right, x0, x1, a0, a1)
	local c0, c1 = max(x0, left), min(x1, right)
	if c1 <= c0 then
		texture:Hide()
		return
	end
	local span = x1 - x0
	local ca0 = a0 + (a1 - a0) * (c0 - x0) / span
	local ca1 = a0 + (a1 - a0) * (c1 - x0) / span
	texture:ClearAllPoints()
	texture:SetPoint("TOPLEFT", c0, 0)
	texture:SetPoint("BOTTOMLEFT", c0, 0)
	texture:SetWidth(c1 - c0)
	texture:SetGradientAlpha("HORIZONTAL", 1, 1, 1, ca0, 1, 1, 1, ca1)
	texture:Show()
end

local function createGradient(parent, layer, orientation, fromAlpha, toAlpha)
	local texture = parent:CreateTexture(nil, layer)
	texture:SetTexture(ns.Media.blank)
	texture:SetGradientAlpha(orientation, 0, 0, 0, fromAlpha, 0, 0, 0, toAlpha)
	return texture
end

local function createSkin(dialog)
	local skin = CreateFrame("Frame", nil, dialog)
	skin:SetAllPoints()
	skin:Hide()

	local banner = CreateFrame("Frame", nil, skin)
	banner:SetPoint("TOPLEFT", 11, -12)
	banner:SetPoint("TOPRIGHT", -12, -12)
	banner:SetHeight(BANNER_HEIGHT)
	skin.banner = banner

	local art = banner:CreateTexture(nil, "BACKGROUND")
	art:SetAllPoints()
	skin.art = art

	local shade = createGradient(banner, "BORDER", "VERTICAL", 0.9, 0)
	shade:SetPoint("BOTTOMLEFT")
	shade:SetPoint("BOTTOMRIGHT")
	shade:SetHeight(BANNER_HEIGHT * 0.75)

	local topShade = createGradient(banner, "BORDER", "VERTICAL", 0, 0.6)
	topShade:SetPoint("TOPLEFT")
	topShade:SetPoint("TOPRIGHT")
	topShade:SetHeight(BANNER_HEIGHT * 0.3)

	skin.shine = {}
	for i = 1, 2 do
		local shine = banner:CreateTexture(nil, "ARTWORK")
		shine:SetTexture(ns.Media.blank)
		shine:SetBlendMode("ADD")
		shine:Hide()
		skin.shine[i] = shine
	end

	local line = banner:CreateTexture(nil, "OVERLAY")
	line:SetTexture(ns.Media.blank)
	line:SetVertexColor(GOLD[1], GOLD[2], GOLD[3], 0.7)
	line:SetHeight(1)
	line:SetPoint("BOTTOMLEFT")
	line:SetPoint("BOTTOMRIGHT")

	local kicker = banner:CreateFontString(nil, "OVERLAY")
	kicker:SetPoint("TOP", 0, -8)
	kicker:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
	kicker:SetShadowOffset(1, -1)
	skin.kicker = kicker

	local titleFrame = CreateFrame("Frame", nil, banner)
	titleFrame:SetSize(1, 1)
	titleFrame:SetPoint("CENTER", 0, 2)
	skin.titleFrame = titleFrame

	local title = titleFrame:CreateFontString(nil, "OVERLAY")
	title:SetPoint("CENTER")
	title:SetTextColor(1, 1, 1)
	skin.title = title

	local titleGlow = titleFrame:CreateFontString(nil, "OVERLAY")
	titleGlow:SetPoint("CENTER")
	titleGlow:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
	skin.titleGlow = titleGlow

	local subtitle = banner:CreateFontString(nil, "OVERLAY")
	subtitle:SetPoint("BOTTOM", 0, 8)
	subtitle:SetTextColor(0.9, 0.9, 0.9)
	subtitle:SetShadowOffset(1, -1)
	skin.subtitle = subtitle

	local bar = CreateFrame("StatusBar", nil, skin)
	bar:SetPoint("BOTTOMLEFT", BAR_SIDE, BAR_BOTTOM)
	bar:SetPoint("BOTTOMRIGHT", -BAR_SIDE, BAR_BOTTOM)
	bar:SetHeight(BAR_HEIGHT)
	ns.SkinStatusBar(bar)
	skin.bar = bar

	local barBorder = bar:CreateTexture(nil, "BACKGROUND")
	barBorder:SetTexture(ns.Media.blank)
	barBorder:SetVertexColor(0, 0, 0, 1)
	barBorder:SetPoint("TOPLEFT", -1, 1)
	barBorder:SetPoint("BOTTOMRIGHT", 1, -1)

	local barBackground = bar:CreateTexture(nil, "BORDER")
	barBackground:SetTexture(ns.Media.blank)
	barBackground:SetVertexColor(0.15, 0.12, 0.05, 1)
	barBackground:SetAllPoints()

	local barText = bar:CreateFontString(nil, "OVERLAY")
	barText:SetPoint("CENTER", 0, 1)
	barText:SetShadowOffset(1, -1)
	skin.barText = barText

	local glow = skin:CreateTexture(nil, "BACKGROUND")
	glow:SetTexture(GLOW_TEXTURE)
	glow:SetTexCoord(0, 0.75, 0, 0.5625)
	glow:SetBlendMode("ADD")
	skin.glow = glow

	dialog.frostAtomSkin = skin
	return skin
end

local function fitGlow(skin, button)
	local glow = skin.glow
	glow:ClearAllPoints()
	glow:SetPoint("CENTER", button, "CENTER", 0, 0)
	glow:SetSize(button:GetWidth() * 1.2, button:GetHeight() * 2)
end

local function applyFonts(skin)
	ns.SetFont(skin.kicker, 12, "", true)
	ns.SetFont(skin.title, 26, "THICKOUTLINE", true)
	ns.SetFont(skin.titleGlow, 26, "THICKOUTLINE", true)
	ns.SetFont(skin.subtitle, 12, "", true)
	ns.SetFont(skin.barText, 11, "OUTLINE")
end

local function fillSkin(skin, index)
	local _, mapName, instanceID, _, _, teamSize, registeredMatch = GetBattlefieldStatus(index)
	local invite = getInvite(index)
	skin.invite = invite

	if teamSize ~= 0 then
		skin.title:SetFormattedText(L["%d vs %d"], teamSize, teamSize)
		skin.subtitle:SetText(registeredMatch and ARENA_RATED_MATCH or ARENA_CASUAL)
	else
		if mapName and instanceID and instanceID ~= 0 then
			mapName = mapName .. " " .. instanceID
		end
		skin.title:SetText(mapName or BATTLEGROUND)
		skin.subtitle:SetText(BATTLEGROUND)
	end
	skin.titleGlow:SetText(skin.title:GetText())
	skin.kicker:SetText(L["Match found!"])

	skin.art:SetTexture(invite.art[1])
	skin.bar:SetMinMaxValues(0, invite.total)
end

local function setArtZoom(skin, zoom)
	local art = skin.invite.art
	local top, bottom = art[2], art[3]
	local halfX = 0.5 / zoom
	local middle, halfY = (top + bottom) / 2, (bottom - top) / 2 / zoom
	skin.art:SetTexCoord(0.5 - halfX, 0.5 + halfX, middle - halfY, middle + halfY)
end

local function updateShine(skin, t)
	local cycle = t - SHINE_FIRST
	local progress = cycle >= 0 and (cycle % SHINE_EVERY) / SHINE_TIME or 1
	if progress >= 1 then
		skin.shine[1]:Hide()
		skin.shine[2]:Hide()
		return
	end
	local width = skin.banner:GetWidth()
	local center = -SHINE_WIDTH / 2 + (width + SHINE_WIDTH) * progress
	local half = SHINE_WIDTH / 2
	setSegment(skin.shine[1], 0, width, center - half, center, 0, SHINE_ALPHA)
	setSegment(skin.shine[2], 0, width, center, center + half, SHINE_ALPHA, 0)
end

local function updateBar(skin, now)
	local invite = skin.invite
	local remain = max(invite.expireAt - now, 0)
	skin.bar:SetValue(remain)
	local urgent = remain <= COUNTDOWN_URGENT
	local color = urgent and BAR_URGENT_COLOR or BAR_COLOR
	skin.bar:SetStatusBarColor(color[1], color[2], color[3])
	skin.barText:SetFormattedText(L["Invite expires in %d sec"], ceil(remain))
	if urgent then
		skin.barText:SetTextColor(1, 0.85, 0.85)
	else
		skin.barText:SetTextColor(1, 1, 1)
	end
end

local function updateSkin(skin)
	local now = GetTime()
	local t = now - skin.invite.start
	local beat = pulse.value

	local pop = fade(t, 0, TITLE_POP_TIME)
	skin.titleFrame:SetScale(1 + (TITLE_POP_SCALE - 1) * (1 - easeOut(pop)))
	skin.title:SetAlpha(min(pop * 3, 1))
	local flare = 1 - fade(t, 0, TITLE_GLOW_TIME)
	skin.titleGlow:SetAlpha(max(flare, beat * TITLE_BEAT_GLOW))

	local detail = fade(t, DETAIL_DELAY, DETAIL_FADE)
	skin.kicker:SetAlpha(detail)
	skin.subtitle:SetAlpha(detail)

	local zoom = 1 + (ZOOM_FROM - 1) * (1 - easeOut(fade(t, 0, ZOOM_TIME)))
	zoom = zoom + DRIFT_ZOOM * (0.5 - 0.5 * cos(t * DRIFT_SPEED))
	setArtZoom(skin, zoom)
	local light = ART_DIM + ART_BEAT * beat
	skin.art:SetVertexColor(light, light, light)

	updateShine(skin, t)
	updateBar(skin, now)

	local button = skin:GetParent().button1
	if button:IsEnabled() == 1 then
		skin.glow:SetAlpha(BUTTON_GLOW_MIN + (1 - BUTTON_GLOW_MIN) * beat)
		skin.glow:Show()
	else
		skin.glow:Hide()
	end
end

local function styleEnabled()
	local config = ns.Config.queueInvite
	return config.enabled and config.style
end

local function unstyle(dialog)
	local skin = dialog.frostAtomSkin
	if not (skin and skin:IsShown()) then
		return
	end
	skin:Hide()
	skin:SetScript("OnUpdate", nil)
	dialog:SetBackdrop(BLIZZARD_BACKDROP)
	dialog.text:Show()
end

local function style(dialog)
	local index = dialog.data
	if not (index and GetBattlefieldStatus(index) == "confirm") then
		return
	end
	local skin = dialog.frostAtomSkin or createSkin(dialog)
	applyFonts(skin)
	fillSkin(skin, index)

	dialog:SetBackdrop(DIALOG_BACKDROP)
	dialog.text:Hide()
	dialog:SetWidth(DIALOG_WIDTH)
	dialog:SetHeight(DIALOG_HEIGHT)
	fitGlow(skin, dialog.button1)

	skin:Show()
	updateSkin(skin)
	skin:SetScript("OnUpdate", updateSkin)
end

local function isStyled(dialog)
	return dialog and dialog.frostAtomSkin and dialog.frostAtomSkin:IsShown()
end

local function refreshDialogs()
	for i = 1, STATICPOPUP_NUMDIALOGS do
		local dialog = _G["StaticPopup" .. i]
		if dialog:IsShown() and dialog.which == WHICH and styleEnabled() then
			if not isStyled(dialog) then
				style(dialog)
			end
		else
			unstyle(dialog)
		end
	end
end

for i = 1, STATICPOPUP_NUMDIALOGS do
	_G["StaticPopup" .. i]:HookScript("OnHide", unstyle)
end

hooksecurefunc("StaticPopup_Show", function(which)
	if which == WHICH then
		refreshDialogs()
	end
end)

local countdown = CreateFrame("Frame", nil, UIParent)
countdown:SetFrameStrata("DIALOG")
countdown:SetSize(1, 1)
countdown:Hide()

local countdownText = countdown:CreateFontString(nil, "OVERLAY")
countdownText:SetPoint("BOTTOM")

local function refreshCountdown()
	local seconds, index
	for i = 1, MAX_BATTLEFIELD_QUEUES do
		if GetBattlefieldStatus(i) == "confirm" then
			local expiration = GetBattlefieldPortExpiration(i)
			if expiration > 0 and (not seconds or expiration < seconds) then
				seconds, index = expiration, i
			end
		end
	end
	if not seconds then
		countdownText:SetText("")
		return
	end

	local dialog = StaticPopup_FindVisible(WHICH, index)
	if isStyled(dialog) then
		countdownText:SetText("")
		return
	end
	countdown:ClearAllPoints()
	if dialog then
		countdown:SetPoint("BOTTOM", dialog, "TOP", 0, COUNTDOWN_OFFSET)
	else
		countdown:SetPoint("BOTTOM", UIParent, "CENTER", 0, COUNTDOWN_FALLBACK_Y)
	end
	countdownText:SetFormattedText(L["Invite expires in %d sec"], seconds)
	if seconds <= COUNTDOWN_URGENT then
		countdownText:SetTextColor(unpack(COUNTDOWN_URGENT_COLOR))
	else
		countdownText:SetTextColor(1, 1, 1)
	end
end

countdown:SetScript("OnUpdate", function(self, elapsed)
	self.untilTick = self.untilTick - elapsed
	if self.untilTick > 0 then
		return
	end
	self.untilTick = COUNTDOWN_TICK
	refreshCountdown()
end)

local confirmed = {}

local function syncInvite(index)
	local invite = getInvite(index)
	local expiration = GetBattlefieldPortExpiration(index)
	local expireAt = GetTime() + expiration
	if abs(expireAt - invite.expireAt) > 1 then
		invite.expireAt = expireAt
	end
end

local function updateInvite()
	local config = ns.Config.queueInvite
	local pendingInvite = false
	for i = 1, MAX_BATTLEFIELD_QUEUES do
		local confirm = GetBattlefieldStatus(i) == "confirm"
		if confirm then
			pendingInvite = true
			syncInvite(i)
			if not confirmed[i] and config.enabled and config.sound and GetCVar("Sound_EnableSFX") == "0" then
				PlaySoundFile(INVITE_SOUND)
			end
		else
			invites[i] = nil
		end
		confirmed[i] = confirm
	end
	if pendingInvite and config.enabled then
		countdown.untilTick = 0
		countdown:Show()
	else
		countdown:Hide()
	end
end

local function applyConfig()
	ns.SetFont(countdownText, COUNTDOWN_FONT_SIZE, "OUTLINE", true)
	updateInvite()
	refreshDialogs()
end

applyConfig()
Misc:WatchConfig("queueInvite", applyConfig)
Misc:RegisterEvent("UPDATE_BATTLEFIELD_STATUS", updateInvite)
