local _, ns = ...

local GetWeaponEnchantInfo = GetWeaponEnchantInfo
local GetInventoryItemTexture = GetInventoryItemTexture
local CancelItemTempEnchantment = CancelItemTempEnchantment
local GameTooltip = GameTooltip
local GetTime = GetTime

local TemporaryEnchant = ns:NewModule("TemporaryEnchant")
TemporaryEnchant.configKey = "temporaryEnchant"
local SetTimerText = ns:GetModule("CooldownTimer").SetTimerText

local MAIN_HAND_SLOT = 16
local MAX_ICONS = 2
local TIMER_INTERVAL = 0.5

local holder

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
	icon:RegisterForClicks("RightButtonDown")
	icon:SetScript("OnClick", onClick)
	icon:SetScript("OnEnter", onEnter)
	icon:SetScript("OnLeave", onLeave)

	icon.texture = icon:CreateTexture(nil, "BORDER")
	icon.texture:SetAllPoints()

	icon.timer = icon:CreateFontString(nil, "OVERLAY")
	icon.timer:SetPoint("CENTER")

	return icon
end

local icons = {}
local shownCount = 0

local function updateTimers()
	local now = GetTime()
	for i = 1, shownCount do
		local icon = icons[i]
		local remain = icon.expires - now
		if remain > 0 then
			SetTimerText(icon.timer, remain)
		else
			icon.timer:SetText("")
		end
	end
end

local function onHolderUpdate(self, elapsed)
	self.untilTick = self.untilTick - elapsed
	if self.untilTick > 0 then
		return
	end
	self.untilTick = TIMER_INTERVAL
	updateTimers()
end

local function showEnchants(...)
	local shown = 0
	local weaponIndex = 0
	local now = GetTime()
	for i = 1, select("#", ...), 3 do
		weaponIndex = weaponIndex + 1
		if select(i, ...) then
			shown = shown + 1

			local icon = icons[shown]
			local slot = MAIN_HAND_SLOT - 1 + weaponIndex
			icon.weaponIndex = weaponIndex
			icon.slot = slot
			icon.expires = now + (select(i + 1, ...) or 0) / 1000
			icon.texture:SetTexture(GetInventoryItemTexture("player", slot))
			icon:Show()
		end
	end

	for i = shown + 1, #icons do
		icons[i]:Hide()
	end

	shownCount = shown
	if shown > 0 and ns.Config.temporaryEnchant.showTimer then
		holder.untilTick = 0
		holder:SetScript("OnUpdate", onHolderUpdate)
	else
		holder:SetScript("OnUpdate", nil)
	end
end

function TemporaryEnchant:Update()
	showEnchants(GetWeaponEnchantInfo())
end

function TemporaryEnchant:UNIT_INVENTORY_CHANGED(unit)
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
		icon:ClearAllPoints()
		icon:SetPoint("TOPLEFT", (i - 1) * (size + gap), 0)
		ns.SetFont(icon.timer, font.size, font.outline)
		if config.showTimer then
			icon.timer:Show()
		else
			icon.timer:Hide()
		end
	end
	TemporaryEnchant:Update()
end

function TemporaryEnchant:Initialize()
	ns.DestroyFrame(TemporaryEnchantFrame, true)

	holder = CreateFrame("Frame", nil, UIParent)
	self:AnchorToConfig(holder, "temporaryEnchant.point", "Weapon enchants")
	for i = 1, MAX_ICONS do
		icons[i] = createIcon()
	end

	applyConfig()
	self:WatchConfig("temporaryEnchant", applyConfig)

	self:RegisterEvent("UNIT_INVENTORY_CHANGED")
	self:RegisterEvent("PLAYER_ENTERING_WORLD", "Update")
end
