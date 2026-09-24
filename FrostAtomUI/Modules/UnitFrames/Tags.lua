local _, ns = ...
local UF = ns:GetModule("UnitFrames")

local UnitName, UnitClass, UnitRace, UnitLevel = UnitName, UnitClass, UnitRace, UnitLevel
local UnitHealth, UnitHealthMax = UnitHealth, UnitHealthMax
local UnitPower, UnitPowerMax, UnitPowerType = UnitPower, UnitPowerMax, UnitPowerType
local UnitIsAFK, UnitIsDND = UnitIsAFK, UnitIsDND
local UnitIsConnected, UnitIsDeadOrGhost = UnitIsConnected, UnitIsDeadOrGhost
local UnitIsPlayer, UnitReaction = UnitIsPlayer, UnitReaction
local GetGuildInfo = GetGuildInfo
local floor, tonumber, tostring = math.floor, tonumber, tostring
local concat = table.concat
local DEAD, AFK, DND, OFFLINE = DEAD, AFK, DND, FRIENDS_LIST_OFFLINE

local FormatValue = ns.FormatValue
local TruncateUTF8 = ns.TruncateUTF8
local ColorGradient = ns.ColorGradient
local config = ns.Config.unitFrames

local HP_GRADIENT = { 1, 0.2, 0.2, 1, 0.85, 0.2, 0.3, 1, 0.3 }
local REACTION_COLORS = { hostile = { 1, 0.3, 0.3 }, neutral = { 1, 0.85, 0.3 }, friendly = { 0.3, 1, 0.3 } }
local WHITE = { 1, 1, 1 }

local function percent(current, max)
	return max > 0 and floor(current / max * 100 + 0.5) or 0
end

local function value(raw, amount)
	return raw and tostring(amount) or FormatValue(amount)
end

local function unitClass(unit, data)
	if data then
		return data.class
	end
	if UnitIsPlayer(unit) then
		return (select(2, UnitClass(unit)))
	end
end

local function health(unit, data)
	if data then
		return data.dead and 0 or data.health, data.healthMax
	end
	return UnitHealth(unit), UnitHealthMax(unit)
end

local function power(unit, data)
	if data then
		return data.dead and 0 or data.power, data.powerMax
	end
	return UnitPower(unit), UnitPowerMax(unit)
end

local tags = {
	name = {
		func = function(unit, data)
			return data and data.name or UnitName(unit) or "UNKNOWN"
		end,
	},
	curhp = {
		health = true,
		func = function(unit, data, raw)
			return value(raw, (health(unit, data)))
		end,
	},
	maxhp = {
		health = true,
		func = function(unit, data, raw)
			return value(raw, (select(2, health(unit, data))))
		end,
	},
	misshp = {
		health = true,
		func = function(unit, data, raw)
			local current, max = health(unit, data)
			return value(raw, max - current)
		end,
	},
	perhp = {
		health = true,
		func = function(unit, data)
			return percent(health(unit, data))
		end,
	},
	curpp = {
		power = true,
		func = function(unit, data, raw)
			return value(raw, (power(unit, data)))
		end,
	},
	maxpp = {
		power = true,
		func = function(unit, data, raw)
			return value(raw, (select(2, power(unit, data))))
		end,
	},
	perpp = {
		power = true,
		func = function(unit, data)
			return percent(power(unit, data))
		end,
	},
	druidmana = {
		power = true,
		func = function(unit, data, raw)
			if data or UnitPowerType(unit) == 0 then
				return ""
			end
			local max = UnitPowerMax(unit, 0)
			return max > 0 and value(raw, UnitPower(unit, 0)) or ""
		end,
	},
	class = {
		func = function(unit, data)
			if data then
				return data.class and LOCALIZED_CLASS_NAMES_MALE[data.class] or ""
			end
			return UnitClass(unit) or ""
		end,
	},
	race = {
		func = function(unit, data)
			return data and "" or UnitRace(unit) or ""
		end,
	},
	guild = {
		func = function(unit, data)
			return data and "" or GetGuildInfo(unit) or ""
		end,
	},
	level = {
		func = function(unit, data)
			if data then
				return MAX_PLAYER_LEVEL
			end
			local level = UnitLevel(unit)
			return level > 0 and level or "??"
		end,
	},
	afk = {
		func = function(unit, data)
			return not data and UnitIsAFK(unit) and AFK or ""
		end,
	},
	dnd = {
		func = function(unit, data)
			return not data and UnitIsDND(unit) and DND or ""
		end,
	},
	status = {
		health = true,
		func = function(unit, data)
			if data then
				return data.dead and DEAD or ""
			elseif not UnitIsConnected(unit) then
				return OFFLINE
			elseif UnitIsDeadOrGhost(unit) then
				return DEAD
			elseif UnitIsAFK(unit) then
				return AFK
			elseif UnitIsDND(unit) then
				return DND
			end
			return ""
		end,
	},
}

local colors = {
	class = function(unit, data)
		local class = unitClass(unit, data)
		return class and UF.classColors[class] or WHITE
	end,
	hp = function(unit, data)
		local current, max = health(unit, data)
		return ColorGradient(max > 0 and current / max or 0, unpack(HP_GRADIENT))
	end,
	power = function(unit, data)
		local powerType = data and data.powerType or UnitPowerType(unit)
		local color = PowerBarColor[powerType]
		return color and color.r or 1, color and color.g or 1, color and color.b or 1
	end,
	reaction = function(unit, data)
		if data then
			return WHITE
		end
		local reaction = UnitReaction(unit, "player") or 4
		return REACTION_COLORS[reaction <= 3 and "hostile" or reaction == 4 and "neutral" or "friendly"]
	end,
}

local function colorCode(r, g, b)
	if type(r) == "table" then
		r, g, b = r[1], r[2], r[3]
	end
	return ("|cff%02x%02x%02x"):format(r * 255, g * 255, b * 255)
end

local function parseTag(body)
	local part
	for token in body:gmatch("[^:]+") do
		if not part then
			if not tags[token] then
				return
			end
			part = { tag = token }
		elseif tonumber(token) then
			part.length = tonumber(token)
		elseif token == "raw" then
			part.raw = true
		elseif colors[token] then
			part.color = colors[token]
		elseif token:find("^%x%x%x%x%x%x$") then
			part.code = "|cff" .. token:lower()
		end
	end
	return part
end

local compiled = setmetatable({}, {
	__index = function(self, template)
		local result = { health = false, power = false }
		local position = 1
		while true do
			local start, stop, body = template:find("%[([^%[%]]*)%]", position)
			if not start then
				break
			end
			if start > position then
				result[#result + 1] = template:sub(position, start - 1)
			end
			local part = parseTag(body)
			if part then
				local info = tags[part.tag]
				result.health = result.health or info.health or false
				result.power = result.power or info.power or false
				result[#result + 1] = part
			else
				result[#result + 1] = template:sub(start, stop)
			end
			position = stop + 1
		end
		if position <= #template then
			result[#result + 1] = template:sub(position)
		end
		self[template] = result
		return result
	end,
})

local buffer = {}

local function renderTags(template, unit, data)
	local parts = compiled[template]
	local n = 0
	for i = 1, #parts do
		local part = parts[i]
		if type(part) == "string" then
			n = n + 1
			buffer[n] = part
		else
			local text = tags[part.tag].func(unit, data, part.raw)
			if part.length then
				text = TruncateUTF8(tostring(text), part.length)
			end
			local code = part.code or (part.color and colorCode(part.color(unit, data)))
			if code then
				buffer[n + 1] = code
				buffer[n + 2] = text
				buffer[n + 3] = "|r"
				n = n + 3
			else
				n = n + 1
				buffer[n] = text
			end
		end
	end
	return concat(buffer, "", 1, n)
end

local TEXT_KEYS = { left = "leftText", right = "rightText", power = "powerText" }
local HOVER_KEYS = { left = "leftTextHover", right = "rightTextHover", power = "powerTextHover" }

local function textTemplate(frame, fontString, side)
	local template = fontString.template
	if template then
		return template
	end
	if frame.hovered then
		local hover = config[HOVER_KEYS[side]]
		if hover ~= "" then
			return hover
		end
	end
	return config[TEXT_KEYS[side]]
end

function UF.UpdateText(frame, fontString, side)
	fontString:SetText(renderTags(textTemplate(frame, fontString, side), frame.unit, frame.test))
end

function UF.UpdateTextIfUses(frame, fontString, side, key)
	local template = textTemplate(frame, fontString, side)
	if compiled[template][key] then
		fontString:SetText(renderTags(template, frame.unit, frame.test))
	end
end
