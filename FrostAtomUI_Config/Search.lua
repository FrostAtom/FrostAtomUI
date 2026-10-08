local _, ns = ...

local ui = FrostAtomUI
local lower = ui.Lower
local sort = table.sort
local min, abs = math.min, math.abs

local SCORE_QUERY = 1000
local LABEL = { exact = 100, word = 60, prefix = 40, sub = 10 }
local SYNONYM = { exact = 50, word = 45, prefix = 30, sub = 8 }
local SECTION = { exact = 8, word = 8, prefix = 8, sub = 4 }
local VALUES = { exact = 5, word = 5, prefix = 4, sub = 2 }
local DESC = { exact = 2, word = 2, prefix = 2, sub = 1 }
local MIN_SUBSTRING = 4
local MAX_RESULTS = 60
local MIN_TYPO_WORD = 4
local LONG_WORD = 6

local OPERATORS = {
	["is:changed"] = "changed",
	["is:mine"] = "changed",
	["изм:"] = "changed",
	["is:preset"] = "preset",
	["is:new"] = "new",
	["нов:"] = "new",
	["is:reload"] = "reload",
	["is:off"] = "off",
}

local Search = {}
ns.Search = Search

local normalized = setmetatable({}, { __mode = "k" })

local function normalize(text)
	if not text or text == "" then
		return ""
	end
	local cached = normalized[text]
	if cached then
		return cached
	end
	local result = lower(text):gsub("\209\145", "\208\181"):gsub("[%p%c]", function(char)
		return char == "%" and char or " "
	end)
	result = result:gsub("%s+", " "):match("^%s*(.-)%s*$")
	normalized[text] = result
	return result
end
Search.Normalize = normalize

local function charCount(text)
	local _, count = text:gsub("[^\128-\191]", "")
	return count
end

local function match(text, token)
	if text == "" then
		return nil
	elseif text == token then
		return "exact"
	end
	local padded = " " .. text .. " "
	if padded:find(" " .. token .. " ", 1, true) then
		return "word"
	elseif padded:find(" " .. token, 1, true) then
		return "prefix"
	elseif charCount(token) >= MIN_SUBSTRING and text:find(token, 1, true) then
		return "sub"
	end
end

local function englishOf(label)
	local source = ui.SourceText and ui.SourceText(label)
	return source and normalize(source) or ""
end

local function valuesText(entry)
	local values = entry.values
	if type(values) ~= "table" then
		return ""
	end
	local parts = {}
	for _, option in ipairs(values) do
		if type(option) == "table" and type(option[2]) == "string" then
			parts[#parts + 1] = normalize(option[2])
		end
	end
	return table.concat(parts, " ")
end

local function best(score, weights, kind)
	local points = kind and weights[kind] or 0
	return points > score and points or score
end

local function tokenScore(fields, alternatives)
	local score = 0
	for i = 1, #alternatives do
		local form = alternatives[i]
		local label = i == 1 and LABEL or SYNONYM
		score = best(score, label, match(fields.label, form))
		score = best(score, label, match(fields.english, form))
		score = best(score, SECTION, match(fields.section, form))
		score = best(score, VALUES, match(fields.values, form))
		score = best(score, DESC, match(fields.desc, form))
	end
	return score
end

local function scoreFields(fields, search)
	if #search.tokens == 0 then
		return 1
	end
	local score = fields.label == search.query and SCORE_QUERY or 0
	for i = 1, #search.tokens do
		local points = tokenScore(fields, search.tokens[i])
		if points == 0 then
			return 0
		end
		score = score + points
	end
	return score
end

local function scoreEntry(entry, section, search)
	if not entry.label then
		return 0
	end
	local fields = {
		label = normalize(entry.label),
		english = englishOf(entry.label),
		section = section,
		values = valuesText(entry),
		desc = normalize(entry.desc) .. (entry.keywords and " " .. normalize(entry.keywords) or ""),
	}
	return scoreFields(fields, search)
end

local function addGroup(groups, title, glyph)
	local group = { title = title, glyph = glyph, order = #groups, score = 0, results = {} }
	groups[#groups + 1] = group
	return group
end

local function addResult(group, entry, score)
	local results = group.results
	results[#results + 1] = { entry = entry, score = score, order = #results }
	if score > group.score then
		group.score = score
	end
end

local function byScore(a, b)
	if a.score ~= b.score then
		return a.score > b.score
	end
	return a.order < b.order
end

local function resultKey(entry)
	return entry.path or entry
end

local function canonicalSources(sources)
	local canonical = {}
	for _, source in ipairs(sources) do
		for _, entry in ipairs(source.entries) do
			local path = entry.path
			if path and not entry.header and not entry.hidden then
				local current = canonical[path]
				if not current or source.rank < current.rank then
					canonical[path] = source
				end
			end
		end
	end
	return canonical
end

local function accepts(search, entry)
	local accept = search.accept
	if not accept then
		return true
	end
	for _, filter in ipairs(search.filters) do
		if not accept(filter, entry) then
			return false
		end
	end
	return true
end

local function collectSource(groups, source, search, canonical, used)
	local group
	local context = normalize(source.context)
	if search.scope and not context:find(search.scope, 1, true) then
		return true
	end
	local header, section = nil, context
	local matched = false
	for _, entry in ipairs(source.entries) do
		if entry.header then
			header, group = entry.header, nil
			section = context .. " " .. normalize(entry.header) .. " " .. englishOf(entry.header)
		elseif not entry.hidden and accepts(search, entry) then
			local score = scoreEntry(entry, section, search)
			if score > 0 then
				matched = true
				local key = resultKey(entry)
				local owner = entry.path and canonical[entry.path]
				if not used[key] and (not owner or owner == source) then
					used[key] = true
					group = group
						or addGroup(groups, header and (source.title .. " / " .. header) or source.title, source.glyph)
					addResult(group, entry, score)
				end
			end
		end
	end
	return matched
end

function Search.Collect(sources, search)
	local groups, used = {}, {}
	local canonical = canonicalSources(sources)
	for _, source in ipairs(sources) do
		local matched = collectSource(groups, source, search, canonical, used)
		local fallback = source.fallback
		if not matched and fallback and #search.filters == 0 and not used[fallback.key] then
			local fields = {
				label = normalize(fallback.name),
				english = englishOf(fallback.name),
				section = normalize(fallback.context),
				values = "",
				desc = "",
			}
			local score = scoreFields(fields, search)
			if score > 0 then
				used[fallback.key] = true
				addResult(addGroup(groups, source.title, source.glyph), fallback.build(), score)
			end
		end
	end

	sort(groups, byScore)
	local schema, count, shown = {}, 0, 0
	for _, group in ipairs(groups) do
		sort(group.results, byScore)
		for index, result in ipairs(group.results) do
			count = count + 1
			if shown < (search.limit or MAX_RESULTS) then
				if index == 1 then
					schema[#schema + 1] = { header = group.title, glyph = group.glyph }
				end
				schema[#schema + 1] = result.entry
				shown = shown + 1
			end
		end
	end
	return schema, count, shown
end

local synonymIndex

local function buildSynonyms()
	synonymIndex = {}
	local data = ns.SearchSynonyms
	if not data then
		return
	end
	for _, group in ipairs(data.groups or {}) do
		local forms = {}
		for _, form in ipairs(group) do
			forms[#forms + 1] = normalize(form)
		end
		for _, form in ipairs(forms) do
			local list = synonymIndex[form] or {}
			synonymIndex[form] = list
			for _, other in ipairs(forms) do
				if other ~= form then
					list[#list + 1] = other
				end
			end
		end
	end
	for alias, targets in pairs(data.aliases or {}) do
		local list = synonymIndex[normalize(alias)] or {}
		synonymIndex[normalize(alias)] = list
		for _, target in ipairs(targets) do
			list[#list + 1] = normalize(target)
		end
	end
end

local function alternatives(token)
	if not synonymIndex then
		buildSynonyms()
	end
	local list = { token }
	for _, form in ipairs(synonymIndex[token] or {}) do
		list[#list + 1] = form
	end
	return list
end

function Search.ParseQuery(query)
	local filters, scope = {}, nil
	query = lower(query):gsub("%S+", function(word)
		local filter = OPERATORS[word]
		if filter then
			filters[#filters + 1] = filter
			return ""
		end
		local target = word:match("^in:(.+)$") or word:match("^в:(.+)$")
		if target then
			scope = normalize(target)
			return ""
		end
	end)
	query = normalize(query)
	local tokens = {}
	if synonymIndex == nil then
		buildSynonyms()
	end
	if query:find(" ", 1, true) and synonymIndex[query] then
		tokens[1] = alternatives(query)
	else
		for word in query:gmatch("%S+") do
			tokens[#tokens + 1] = alternatives(word)
		end
	end
	return { query = query, tokens = tokens, filters = filters, scope = scope }
end

local function chars(text)
	local list = {}
	for char in text:gmatch("[%z\1-\127\192-\255][\128-\191]*") do
		list[#list + 1] = char
	end
	return list
end

local function distance(a, b, limit, length)
	local n, m = #a, length or #b
	if abs(n - m) > limit then
		return limit + 1
	end
	local previous, current = {}, {}
	for j = 0, m do
		previous[j] = j
	end
	for i = 1, n do
		current[0] = i
		local lowest = i
		local char = a[i]
		for j = 1, m do
			local value = min(previous[j] + 1, current[j - 1] + 1, previous[j - 1] + (char == b[j] and 0 or 1))
			current[j] = value
			if value < lowest then
				lowest = value
			end
		end
		if lowest > limit then
			return limit + 1
		end
		previous, current = current, previous
	end
	return previous[m]
end

local function addWords(set, text)
	for word in text:gmatch("%S+") do
		if charCount(word) >= MIN_TYPO_WORD then
			set[word] = true
		end
	end
end

local function vocabulary(sources)
	local set = {}
	for _, source in ipairs(sources) do
		addWords(set, normalize(source.context))
		for _, entry in ipairs(source.entries) do
			local label = entry.label or entry.header
			if type(label) == "string" and not entry.hidden then
				addWords(set, normalize(label))
				addWords(set, englishOf(label))
				if entry.keywords then
					addWords(set, normalize(entry.keywords))
				end
			end
		end
	end
	for form in pairs(synonymIndex) do
		addWords(set, form)
	end
	local list = {}
	for word in pairs(set) do
		list[#list + 1] = chars(word)
	end
	return list
end

local function closest(word, words)
	local token = chars(word)
	local limit = #token >= LONG_WORD and 2 or 1
	local found, nearest = nil, limit + 1
	for _, candidate in ipairs(words) do
		local value = distance(token, candidate, limit)
		if #candidate > #token then
			value = min(value, distance(token, candidate, limit, #token))
		end
		if value == 0 then
			return nil
		elseif value < nearest then
			found, nearest = candidate, value
		end
	end
	return found and table.concat(found)
end

function Search.Correct(query, sources)
	if synonymIndex == nil then
		buildSynonyms()
	end
	local words, list, changed = nil, {}, false
	for word in normalize(query):gmatch("%S+") do
		local fixed
		if charCount(word) >= MIN_TYPO_WORD then
			words = words or vocabulary(sources)
			fixed = closest(word, words)
		end
		list[#list + 1] = fixed or word
		changed = changed or fixed ~= nil
	end
	return changed and table.concat(list, " ") or nil
end

function Search.HasOperators(search)
	return #search.filters > 0 or search.scope ~= nil
end
