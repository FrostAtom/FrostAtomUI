local _, ns = ...

local UnitExists, UnitName = UnitExists, UnitName
local GetCVarBool = GetCVarBool
local floor, tonumber = math.floor, tonumber
local byte = string.byte

local PlateLayer = {}
ns.PlateLayer = PlateLayer

local HOSTILE, NEUTRAL, FRIENDLY = "hostile", "neutral", "friendly"
PlateLayer.HOSTILE, PlateLayer.NEUTRAL, PlateLayer.FRIENDLY = HOSTILE, NEUTRAL, FRIENDLY

local TARGET_ALPHA = 0.99
local GUID_PLAYER_BYTE = 48

local function toByte(value)
	if value <= 0 then
		return 0
	elseif value >= 1 then
		return 255
	end
	return floor(value * 255 + 0.5)
end

local function byteKey(r, g, b)
	return r * 65536 + g * 256 + b
end

local CLIENT_COLORS = {
	[byteKey(255, 0, 0)] = { reaction = HOSTILE, isPlayer = false, classColored = true },
	[byteKey(255, 255, 0)] = { reaction = NEUTRAL, isPlayer = false },
	[byteKey(0, 255, 0)] = { reaction = FRIENDLY, isPlayer = false },
	[byteKey(0, 0, 255)] = { reaction = FRIENDLY, isPlayer = true },
	[byteKey(0, 0, 0)] = { reaction = HOSTILE, isPlayer = true },
}

local CLASS_BYTES = {
	WARRIOR = { 198, 155, 109 },
	PALADIN = { 244, 140, 186 },
	HUNTER = { 170, 211, 114 },
	ROGUE = { 255, 244, 104 },
	PRIEST = { 255, 255, 255 },
	DEATHKNIGHT = { 196, 30, 58 },
	SHAMAN = { 0, 112, 221 },
	MAGE = { 104, 204, 239 },
	WARLOCK = { 147, 130, 201 },
	DRUID = { 255, 124, 10 },
}
for class, color in pairs(CLASS_BYTES) do
	CLIENT_COLORS[byteKey(color[1], color[2], color[3])] = { reaction = HOSTILE, isPlayer = true, class = class }
end

local plates = {}
local infos = {}
local handlers = {}
local active = false
local targetExists = false
local targetSerial = 0
PlateLayer.plates = plates

local function fire(event, plate, info, arg)
	for i = 1, #handlers do
		local callback = handlers[i][event]
		if callback then
			callback(plate, info, arg)
		end
	end
end

local function readColor(info)
	local r, g, b = info.healthbar:GetStatusBarColor()
	local key = byteKey(toByte(r), toByte(g), toByte(b))
	local entry = CLIENT_COLORS[key]
	if not entry or key == info.colorKey and not info.painted then
		return false
	end
	info.colorKey = key
	info.painted = false
	local isPlayer = entry.isPlayer
	if entry.classColored and not GetCVarBool("ShowClassColorInNameplate") then
		isPlayer = nil
	end
	info.reaction = entry.reaction
	info.isEnemy = entry.reaction ~= FRIENDLY
	info.isPlayer = isPlayer
	info.class = entry.class
	return true
end

local function readTarget(plate, info)
	info.isTarget = targetExists and plate:GetAlpha() > TARGET_ALPHA
	info.targetSerial = targetSerial
end

local function isMouseover(info)
	return info.shown
		and info.highlight:IsShown() == 1
		and UnitExists("mouseover") == 1
		and UnitName("mouseover") == info.name
end
PlateLayer.IsMouseover = isMouseover

local function readMouseover(info)
	info.isMouseover = isMouseover(info)
end

local function onShow(plate)
	local info = infos[plate]
	info.shown = true
	info.name = info.nameText:GetText()
	info.colorKey = nil
	info.isTarget = false
	info.targetSerial = -1
	info.isMouseover = false
	readColor(info)
	fire("shown", plate, info)
end

local function onHide(plate)
	local info = infos[plate]
	info.shown = false
	info.isTarget = false
	info.isMouseover = false
	fire("hidden", plate, info)
end

local function onUpdate(plate, elapsed)
	local info = infos[plate]
	readTarget(plate, info)
	readMouseover(info)
	local name = info.nameText:GetText()
	if name ~= info.name then
		info.name = name
		fire("renamed", plate, info)
	end
	if readColor(info) then
		fire("recolored", plate, info)
	end
	fire("update", plate, info, elapsed)
end

local function enroll(plate, info)
	fire("created", plate, info)
	plate:SetScript("OnShow", onShow)
	plate:SetScript("OnHide", onHide)
	plate:SetScript("OnUpdate", onUpdate)
	if plate:IsShown() then
		onShow(plate)
	end
end

local function capture(plate)
	local healthbar, castbar = plate:GetChildren()
	-- luacheck: ignore 631 (client creation order, all eleven are needed)
	local threat, border, castBorder, castShield, castIcon, highlight, nameText, levelText, bossIcon, raidIcon, eliteIcon =
		plate:GetRegions()
	local info = {
		plate = plate,
		healthbar = healthbar,
		castbar = castbar,
		threat = threat,
		border = border,
		castBorder = castBorder,
		castShield = castShield,
		castIcon = castIcon,
		highlight = highlight,
		nameText = nameText,
		levelText = levelText,
		bossIcon = bossIcon,
		raidIcon = raidIcon,
		eliteIcon = eliteIcon,
		shown = false,
		isTarget = false,
		isMouseover = false,
		targetSerial = -1,
	}
	infos[plate] = info
	plates[#plates + 1] = plate
	if active then
		enroll(plate, info)
	end
end

function PlateLayer.Register(handler)
	handlers[#handlers + 1] = handler
	if not active then
		active = true
		for i = 1, #plates do
			local plate = plates[i]
			enroll(plate, infos[plate])
		end
		return
	end
	for i = 1, #plates do
		local plate = plates[i]
		local info = infos[plate]
		if handler.created then
			handler.created(plate, info)
		end
		if info.shown and handler.shown then
			handler.shown(plate, info)
		end
	end
end

function PlateLayer.GetInfo(plate)
	return infos[plate]
end

function PlateLayer.IsTarget(info)
	return info.isTarget and info.targetSerial == targetSerial
end

function PlateLayer.GetTargetPlate()
	if not targetExists then
		return
	end
	for i = 1, #plates do
		local plate = plates[i]
		local info = infos[plate]
		if info.shown and info.isTarget and info.targetSerial == targetSerial then
			return plate, info
		end
	end
end

function PlateLayer.SetHealthColor(info, r, g, b)
	local rb, gb, bb = toByte(r), toByte(g), toByte(b)
	if CLIENT_COLORS[byteKey(rb, gb, bb)] then
		bb = bb < 255 and bb + 1 or bb - 1
	end
	info.healthbar:SetStatusBarColor(rb / 255, gb / 255, bb / 255)
	info.painted = true
end

function PlateLayer.GetLevel(info)
	if info.levelText:IsShown() then
		return tonumber(info.levelText:GetText())
	elseif info.bossIcon:IsShown() then
		return -1
	end
end

function PlateLayer.IsElite(info)
	return info.eliteIcon:IsShown() == 1
end

function PlateLayer.GetRaidIcon(info)
	local icon = info.raidIcon
	if not icon:IsShown() then
		return
	end
	local left, top = icon:GetTexCoord()
	return floor(top * 4 + 0.5) * 4 + floor(left * 4 + 0.5) + 1
end

function PlateLayer.IsCastInterruptible(info)
	return info.castbar:IsShown() == 1 and not info.castShield:IsShown()
end

function PlateLayer.IsPlayerGUID(guid)
	return guid ~= nil and byte(guid, 3) == GUID_PLAYER_BYTE
end

local events = ns.Mixin({}, ns.EventMixin)

local function onTargetChanged()
	targetExists = UnitExists("target") == 1
	targetSerial = targetSerial + 1
end

events:RegisterEvent("PLAYER_TARGET_CHANGED", onTargetChanged)
events:RegisterEvent("PLAYER_ENTERING_WORLD", onTargetChanged)

ns.WorldChildren.Register("NamePlate", capture)
