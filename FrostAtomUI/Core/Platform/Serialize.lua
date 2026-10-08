local _, ns = ...

local concat, strchar = table.concat, string.char

local function formatNumber(value)
	if value ~= value then
		return "0"
	elseif value == math.huge then
		return "1e999"
	elseif value == -math.huge then
		return "-1e999"
	end
	local text = ("%.14g"):format(value)
	if tonumber(text) ~= value then
		text = ("%.17g"):format(value)
	end
	return text
end

local function serialize(value, out)
	local kind = type(value)
	if kind == "table" then
		out[#out + 1] = "{"
		local count = 0
		while value[count + 1] ~= nil do
			count = count + 1
		end
		for i = 1, count do
			serialize(value[i], out)
			out[#out + 1] = ","
		end
		for key, item in pairs(value) do
			if not (type(key) == "number" and key >= 1 and key <= count and key % 1 == 0) then
				out[#out + 1] = "["
				serialize(key, out)
				out[#out + 1] = "]="
				serialize(item, out)
				out[#out + 1] = ","
			end
		end
		out[#out + 1] = "}"
	elseif kind == "string" then
		out[#out + 1] = ("%q"):format(value)
	elseif kind == "number" then
		out[#out + 1] = formatNumber(value)
	elseif kind == "boolean" then
		out[#out + 1] = tostring(value)
	else
		error("cannot serialize " .. kind)
	end
end

local ESCAPES = { n = "\n", r = "\r", t = "\t", ["\n"] = "\n" }

local function unescape(body)
	local out, i = {}, 1
	while i <= #body do
		local char = body:sub(i, i)
		if char == "\\" then
			local digits = body:match("^%d%d?%d?", i + 1)
			if digits then
				out[#out + 1] = strchar(tonumber(digits))
				i = i + 1 + #digits
			else
				local escaped = body:sub(i + 1, i + 1)
				out[#out + 1] = ESCAPES[escaped] or escaped
				i = i + 2
			end
		else
			out[#out + 1] = char
			i = i + 1
		end
	end
	return concat(out)
end

local parseValue

local function parseTable(text, pos)
	local result, index = {}, 1
	pos = pos + 1
	while true do
		local char = text:sub(pos, pos)
		if char == "}" then
			return result, pos + 1
		elseif char == "" then
			return nil
		end
		local key, value
		if char == "[" then
			key, pos = parseValue(text, pos + 1)
			if not key or text:sub(pos, pos) ~= "]" or text:sub(pos + 1, pos + 1) ~= "=" then
				return nil
			end
			pos = pos + 2
		else
			key, index = index, index + 1
		end
		value, pos = parseValue(text, pos)
		if value == nil then
			return nil
		end
		result[key] = value
		if text:sub(pos, pos) == "," then
			pos = pos + 1
		end
	end
end

function parseValue(text, pos)
	local char = text:sub(pos, pos)
	if char == "{" then
		return parseTable(text, pos)
	elseif char == '"' then
		local stop = pos
		repeat
			stop = text:find('"', stop + 1, true)
			if not stop then
				return nil
			end
			local backslashes = #text:sub(pos + 1, stop - 1):match("\\*$")
		until backslashes % 2 == 0
		return unescape(text:sub(pos + 1, stop - 1)), stop + 1
	elseif text:sub(pos, pos + 3) == "true" then
		return true, pos + 4
	elseif text:sub(pos, pos + 4) == "false" then
		return false, pos + 5
	end
	local number = text:match("^-?%d+%.?%d*[eE]?[-+]?%d*", pos)
	if number and number ~= "" and tonumber(number) then
		return tonumber(number), pos + #number
	end
	return nil
end

function ns.Serialize(value)
	local out = {}
	serialize(value, out)
	return concat(out)
end

function ns.Deserialize(text)
	local value, pos = parseValue(text, 1)
	if value == nil or pos ~= #text + 1 then
		return nil
	end
	return value
end
