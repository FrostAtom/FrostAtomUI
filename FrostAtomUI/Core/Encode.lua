local _, ns = ...
local L = ns.L

local floor, strbyte, strchar, strsub, concat = math.floor, string.byte, string.char, string.sub, table.concat

local Z85 = "0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ.-:+=^!/*?&<>()[]{}@%$#"
local Z85_INDEX = {}
for i = 1, 85 do
	Z85_INDEX[strbyte(Z85, i)] = i - 1
end

local MIN_WIDTH = 9
local MAX_WIDTH = 16
local MAX_CODES = 2 ^ MAX_WIDTH

local function widthFor(emission)
	local width = MIN_WIDTH
	local highest = 256 + emission - 2
	while width < MAX_WIDTH and highest >= 2 ^ width do
		width = width + 1
	end
	return width
end

local function compress(text)
	local dict, nextCode = {}, 256
	for i = 0, 255 do
		dict[strchar(i)] = i
	end
	local out, acc, nbits, emission = {}, 0, 0, 0
	local function emit(code)
		emission = emission + 1
		local width = widthFor(emission)
		acc = acc * 2 ^ width + code
		nbits = nbits + width
		while nbits >= 8 do
			local shift = 2 ^ (nbits - 8)
			local byte = floor(acc / shift)
			out[#out + 1] = strchar(byte)
			acc = acc - byte * shift
			nbits = nbits - 8
		end
	end
	local w = ""
	for i = 1, #text do
		local c = strsub(text, i, i)
		local wc = w .. c
		if dict[wc] then
			w = wc
		else
			emit(dict[w])
			if nextCode < MAX_CODES then
				dict[wc] = nextCode
				nextCode = nextCode + 1
			end
			w = c
		end
	end
	if w ~= "" then
		emit(dict[w])
	end
	if nbits > 0 then
		out[#out + 1] = strchar(acc * 2 ^ (8 - nbits))
	end
	return concat(out)
end

local function decompress(data)
	local dict, nextCode = {}, 256
	for i = 0, 255 do
		dict[i] = strchar(i)
	end
	local out, acc, nbits, pos, emission = {}, 0, 0, 1, 0
	local total = #data
	local prev
	while true do
		emission = emission + 1
		local width = widthFor(emission)
		while nbits < width and pos <= total do
			acc = acc * 256 + strbyte(data, pos)
			nbits = nbits + 8
			pos = pos + 1
		end
		if nbits < width then
			break
		end
		local shift = 2 ^ (nbits - width)
		local code = floor(acc / shift)
		acc = acc - code * shift
		nbits = nbits - width
		local entry = dict[code]
		if not entry then
			if code ~= nextCode or not prev then
				return nil
			end
			entry = prev .. strsub(prev, 1, 1)
		end
		out[#out + 1] = entry
		if prev and nextCode < MAX_CODES then
			dict[nextCode] = prev .. strsub(entry, 1, 1)
			nextCode = nextCode + 1
		end
		prev = entry
	end
	return concat(out)
end

local function adler32(text)
	local a, b = 1, 0
	for i = 1, #text do
		a = (a + strbyte(text, i)) % 65521
		b = (b + a) % 65521
	end
	return b * 65536 + a
end

local function toZ85(bytes)
	local pad = (4 - #bytes % 4) % 4
	bytes = bytes .. strchar(0):rep(pad)
	local out = { tostring(pad) }
	local chunk = {}
	for i = 1, #bytes, 4 do
		local b1, b2, b3, b4 = strbyte(bytes, i, i + 3)
		local value = ((b1 * 256 + b2) * 256 + b3) * 256 + b4
		for j = 5, 1, -1 do
			local index = value % 85
			chunk[j] = strsub(Z85, index + 1, index + 1)
			value = (value - index) / 85
		end
		out[#out + 1] = concat(chunk)
	end
	return concat(out)
end

local function fromZ85(text)
	local pad = tonumber(strsub(text, 1, 1))
	if not pad or pad > 3 or (#text - 1) % 5 ~= 0 then
		return nil
	end
	local out = {}
	for i = 2, #text, 5 do
		local value = 0
		for j = i, i + 4 do
			local index = Z85_INDEX[strbyte(text, j)]
			if not index then
				return nil
			end
			value = value * 85 + index
		end
		if value >= 2 ^ 32 then
			return nil
		end
		local b4 = value % 256
		value = (value - b4) / 256
		local b3 = value % 256
		value = (value - b3) / 256
		local b2 = value % 256
		out[#out + 1] = strchar((value - b2) / 256, b2, b3, b4)
	end
	local bytes = concat(out)
	return strsub(bytes, 1, #bytes - pad)
end

function ns.Encode(text)
	local sum = adler32(text)
	local header = strchar(floor(sum / 16777216) % 256, floor(sum / 65536) % 256, floor(sum / 256) % 256, sum % 256)
	return toZ85(header .. compress(text))
end

function ns.Decode(encoded)
	local bytes = fromZ85((encoded:gsub("%s", "")))
	if not bytes or #bytes < 4 then
		return nil, L["malformed string"]
	end
	local b1, b2, b3, b4 = strbyte(bytes, 1, 4)
	local text = decompress(strsub(bytes, 5))
	if not text then
		return nil, L["corrupted data"]
	end
	if adler32(text) ~= ((b1 * 256 + b2) * 256 + b3) * 256 + b4 then
		return nil, L["checksum mismatch"]
	end
	return text
end
