local _, ns = ...

local GetWeaponEnchantInfo = GetWeaponEnchantInfo
local GetInventoryItemTexture = GetInventoryItemTexture
local GetInventoryItemQuality = GetInventoryItemQuality
local CancelItemTempEnchantment = CancelItemTempEnchantment
local UnitHasVehicleUI = UnitHasVehicleUI
local GameTooltip = GameTooltip
local GetTime = GetTime
local min, max = math.min, math.max

local TemporaryEnchant = ns:NewModule("TemporaryEnchant")
TemporaryEnchant.configKey = "temporaryEnchant"
local SetTimerText = ns:GetModule("CooldownTimer").SetTimerText
local UF = ns:GetModule("UnitFrames")

local MAIN_HAND_SLOT = 16
local MAX_ICONS = 2
local TIMER_INTERVAL = 0.5
local WARNING_TIME = 31
local FLASH_PERIOD = 0.75
local FLASH_MIN_ALPHA = 0.3
local KNOWN_DURATIONS = { 600, 1800, 3600 }

local holder, ticker
local icons = {}
local enchants = {}
local enchantCount = 0
local knownDurations = {}
local nextExpiry

local function inAuras()
	return ns.Config.temporaryEnchant.showInAuras and UF.HasWeaponEnchantAuras()
end

local function standaloneVisible()
	return not inAuras()
end

local function estimateDuration(slot, remain)
	local known = knownDurations[slot]
	if known and remain <= known then
		return known
	end
	known = remain
	for i = 1, #KNOWN_DURATIONS do
		if remain <= KNOWN_DURATIONS[i] then
			known = KNOWN_DURATIONS[i]
			break
		end
	end
	knownDurations[slot] = known
	return known
end

local function onClick(icon)
	CancelItemTempEnchantment(icon.weaponIndex)
end

local function refreshTooltip(icon)
	GameTooltip:SetInventoryItem("player", icon.slot)
end

local function onEnter(icon)
	GameTooltip:SetOwner(icon, "ANCHOR_BOTTOMLEFT")
	refreshTooltip(icon)
	icon:SetScript("OnUpdate", refreshTooltip)
end

local function onLeave(icon)
	GameTooltip:Hide()
	icon:SetScript("OnUpdate", nil)
end

local function createIcon()
	local icon = CreateFrame("Button", nil, holder)
	icon:Hide()
	icon:RegisterForClicks("RightButtonUp")
	icon:SetScript("OnClick", onClick)
	icon:SetScript("OnEnter", onEnter)
	icon:SetScript("OnLeave", onLeave)

	icon.texture = icon:CreateTexture(nil, "BORDER")
	icon.texture:SetAllPoints()

	icon.timer = icon:CreateFontString(nil, "OVERLAY")
	icon.timer:SetPoint("CENTER")

	return icon
end

local function flashAlpha(now)
	local phase = now % (2 * FLASH_PERIOD)
	local alpha = phase < FLASH_PERIOD and phase / FLASH_PERIOD or (2 * FLASH_PERIOD - phase) / FLASH_PERIOD
	return alpha * (1 - FLASH_MIN_ALPHA) + FLASH_MIN_ALPHA
end

local function updateIcons(now, withTimer)
	local showTimer = withTimer and ns.Config.temporaryEnchant.showTimer
	for i = 1, enchantCount do
		local icon = icons[i]
		local expires = enchants[i].expires
		local remain = expires and expires - now or 0
		if showTimer then
			if remain > 0 then
				SetTimerText(icon.timer, remain)
			else
				icon.timer:SetText("")
			end
		end
		icon:SetAlpha(remain > 0 and remain < WARNING_TIME and flashAlpha(now) or 1)
	end
end

local function onTick(self, elapsed)
	local now = GetTime()
	if nextExpiry and now >= nextExpiry then
		TemporaryEnchant:Update()
		return
	end
	if not holder:IsShown() then
		return
	end
	self.untilTick = self.untilTick - elapsed
	local tick = self.untilTick <= 0
	if tick then
		self.untilTick = TIMER_INTERVAL
	end
	updateIcons(now, tick)
end

local function showStandalone()
	for i = 1, enchantCount do
		local enchant = enchants[i]
		local icon = icons[i]
		icon.weaponIndex = enchant.weaponIndex
		icon.slot = enchant.slot
		icon.texture:SetTexture(enchant.icon)
		icon:Show()
		if GameTooltip:IsOwned(icon) then
			refreshTooltip(icon)
		end
	end
	for i = enchantCount + 1, MAX_ICONS do
		icons[i]:Hide()
	end
	ticker.untilTick = 0
	updateIcons(GetTime(), true)
end

local function readEnchants(...)
	local now = GetTime()
	local hidden = UnitHasVehicleUI("player")
	local count = 0
	nextExpiry = nil
	for weaponIndex = 1, MAX_ICONS do
		local has, remainMs = select(weaponIndex * 3 - 2, ...)
		local slot = MAIN_HAND_SLOT - 1 + weaponIndex
		if not has or remainMs and remainMs <= 0 then
			knownDurations[slot] = nil
		elseif not hidden then
			count = count + 1
			local enchant = enchants[count]
			if not enchant then
				enchant = { caster = "player" }
				enchants[count] = enchant
			end
			enchant.weaponIndex = weaponIndex
			enchant.slot = slot
			enchant.icon = GetInventoryItemTexture("player", slot)
			enchant.quality = GetInventoryItemQuality("player", slot)
			if remainMs then
				local remain = remainMs / 1000
				enchant.expires = now + remain
				enchant.duration = estimateDuration(slot, remain)
				nextExpiry = min(nextExpiry or enchant.expires, enchant.expires)
			else
				enchant.expires = nil
				enchant.duration = 0
			end
		end
	end
	enchantCount = count
	if nextExpiry then
		nextExpiry = max(nextExpiry, now + TIMER_INTERVAL)
	end
end

function TemporaryEnchant:Update()
	readEnchants(GetWeaponEnchantInfo())

	if inAuras() then
		holder:Hide()
		UF.SetWeaponEnchants(enchants, enchantCount)
	else
		UF.SetWeaponEnchants(nil, 0)
		holder:Show()
		showStandalone()
	end

	if enchantCount > 0 then
		ticker:Show()
	else
		ticker:Hide()
	end
end

function TemporaryEnchant:UNIT_INVENTORY_CHANGED(unit)
	if unit == "player" then
		self:Update()
	end
end

function TemporaryEnchant:OnVehicleChanged(unit)
	if unit == "player" then
		self:Update()
	end
end

local function applyConfig()
	local config = ns.Config.temporaryEnchant
	local size, gap, font = config.size, config.gap, config.timerFont
	holder:SetSize(MAX_ICONS * (size + gap) - gap, size)
	for i = 1, MAX_ICONS do
		local icon = icons[i]
		icon:SetSize(size, size)
		icon:EnableMouse(not config.clickThrough)
		icon:ClearAllPoints()
		icon:SetPoint("TOPLEFT", (i - 1) * (size + gap), 0)
		ns.SetFont(icon.timer, font.size, font.outline)
		ns.SetShown(icon.timer, config.showTimer)
	end
	ns.Movers.Register(holder, "temporaryEnchant.point", "Weapon enchants", { visible = standaloneVisible })
	TemporaryEnchant:Update()
end

function TemporaryEnchant:Initialize()
	ns.DestroyFrame(TemporaryEnchantFrame, true)

	holder = CreateFrame("Frame", nil, UIParent)
	self:AnchorToConfig(holder, "temporaryEnchant.point", "Weapon enchants", { visible = standaloneVisible })
	for i = 1, MAX_ICONS do
		icons[i] = createIcon()
	end

	ticker = CreateFrame("Frame")
	ticker:Hide()
	ticker.untilTick = 0
	ticker:SetScript("OnUpdate", onTick)

	applyConfig()
	self:WatchConfig("temporaryEnchant", applyConfig)

	self:RegisterEvent("UNIT_INVENTORY_CHANGED")
	self:RegisterEvent("UNIT_ENTERED_VEHICLE", "OnVehicleChanged")
	self:RegisterEvent("UNIT_EXITED_VEHICLE", "OnVehicleChanged")
	self:RegisterEvent("PLAYER_ENTERING_WORLD", "Update")
end
