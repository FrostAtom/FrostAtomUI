local ROOT = arg[1] or "."
package.path = ROOT .. "/tests/?.lua;" .. package.path

local env = require("stubs")
env.root = ROOT
os.setlocale("C", "ctype")

local GITHUB = os.getenv("GITHUB_ACTIONS") == "true"
local errors, entries = 0, 0

local function fail(where, message)
	errors = errors + 1
	if GITHUB then
		print(("::error file=%s::%s"):format(where, message))
	else
		print(("error: %s: %s"):format(where, message))
	end
end

local KNOWN = {}
for key in
	([[
	path pathY label desc type header glyph description values get set func text width min max step unit
	percent advanced hidden new enabledBy enabledByAny disabled disabledDesc confirm confirmRevert noReset
	reload applyOnRelease zeroText placeholder style preview binding indent keep toggles toggleDesc element
	build refresh setEnabled height maxLetters validate userContent actions layout options columns
	format keywords term copy hub child showValue multiline blizzard onClick values2 group tab
	elements entries prefix render limits radio order labelWidth softMin softMax wide signature page seenTab defaultText tags marked modifiers describe isDefault points reset alpha
	alias extraLabel lessLabel
	]]):gmatch("%S+")
do
	KNOWN[key] = true
end

local ns = env.loadToc(ROOT, "FrostAtomUI", "Core\\Diagnostics.lua")
local autoMeta = {}
autoMeta.__index = function()
	return setmetatable({}, autoMeta)
end
autoMeta.__call = function()
	return setmetatable({}, autoMeta)
end
setmetatable(ns, autoMeta)
local cfg = {}
local pages, elements = {}, {}

for line in io.lines(ROOT .. "/FrostAtomUI_Config/FrostAtomUI_Config.toc") do
	line = line:gsub("\r", "")
	if line:find("%.lua$") and not line:find("^#") then
		local chunk = assert(loadfile(ROOT .. "/FrostAtomUI_Config/" .. line:gsub("\\", "/")))
		local ok, err = xpcall(function()
			chunk("FrostAtomUI_Config", cfg)
		end, debug.traceback)
		if not ok then
			fail(line, "does not load: " .. tostring(err))
		end
		if line == "Core.lua" then
			local registerPage, registerElement = cfg.RegisterPage, cfg.RegisterElement
			function cfg.RegisterPage(page)
				pages[#pages + 1] = page
				return registerPage(page)
			end
			function cfg.RegisterElement(element)
				elements[#elements + 1] = element
				return registerElement(element)
			end
		end
	end
end
local loadErrors = env.takeErrors()
for _, message in ipairs(loadErrors) do
	fail("load", tostring(message))
end
assert(ns.Defaults)

local unknown = {}
local paths, aliases = {}, {}
local ranges = {}

local function checkSchema(where, schema)
	if type(schema) ~= "table" then
		return
	end
	for index, entry in ipairs(schema) do
		entries = entries + 1
		if type(entry.path) == "string" then
			paths[entry.path] = true
			if entry.type == "number" and entry.min and entry.max then
				local range = ("%s..%s step %s"):format(entry.min, entry.max, tostring(entry.step))
				local seen = ranges[entry.path]
				if seen and seen.range ~= range then
					fail(
						where,
						("%s: range %s differs from %s in %s"):format(entry.path, range, seen.range, seen.where)
					)
				elseif not seen then
					ranges[entry.path] = { range = range, where = where }
				end
			end
		end
		if entry.alias then
			aliases[#aliases + 1] = { where = where, path = entry.alias }
		end
		if entry.preview and type(entry.values) ~= "table" then
			fail(
				where,
				("%s: a select with a preview needs a values table"):format(tostring(entry.path or entry.label))
			)
		end
		for key in pairs(entry) do
			if type(key) == "string" and not KNOWN[key] then
				local seen = unknown[key]
				if seen then
					seen.count = seen.count + 1
				else
					unknown[key] = {
						count = 1,
						where = ("%s, entry %d (%s)"):format(
							where,
							index,
							tostring(entry.label or entry.header or entry.path)
						),
					}
				end
			end
		end
	end
end

local function build(source)
	if source.buildSchema then
		local ok, schema = pcall(source.buildSchema)
		if ok then
			return schema
		end
	end
	return source.schema
end

for _, page in ipairs(pages) do
	checkSchema("page " .. page.key, build(page))
	for _, tab in ipairs(page.tabs or {}) do
		checkSchema(("page %s / %s"):format(page.key, tab.key), build(tab))
	end
end
for _, element in ipairs(elements) do
	checkSchema("element " .. tostring(element.path), element.schema)
end

for _, alias in ipairs(aliases) do
	if not paths[alias.path] then
		fail(alias.where, ("alias of a path no page shows: %s"):format(alias.path))
	end
end
for key, seen in pairs(unknown) do
	fail(seen.where, ("unknown schema key %q (%d entries)"):format(key, seen.count))
end
print(("check_settings: %d pages, %d elements, %d entries, %d errors"):format(#pages, #elements, entries, errors))
os.exit(errors == 0 and 0 or 1)
