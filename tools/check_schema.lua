local ROOT = arg[1] or "."
package.path = ROOT .. "/tests/?.lua;" .. package.path

local env = require("stubs")
local ns = env.loadToc(ROOT, "FrostAtomUI", "Core\\Settings\\Watch.lua")
local defaults = assert(ns.Defaults, "ns.Defaults is not defined")

local GITHUB = os.getenv("GITHUB_ACTIONS") == "true"
local FIELDS = { path = "any", pathY = "any", enabledBy = "boolean", enabledByAny = "boolean" }
local CALLS = { GetConfig = true, SetConfig = true, WatchConfig = true, ResetConfig = true }
local errors, checked = 0, 0

local function fail(file, line, message)
	errors = errors + 1
	if GITHUB then
		print(("::error file=%s,line=%d::%s"):format(file, line, message))
	else
		print(("error: %s:%d: %s"):format(file, line, message))
	end
end

local function resolve(path)
	local node = defaults
	for key in path:gmatch("[^.]+") do
		if type(node) ~= "table" then
			return nil
		end
		node = node[tonumber(key) or key]
		if node == nil then
			return nil
		end
	end
	return node
end

local function check(file, line, what, path, want)
	checked = checked + 1
	local value = resolve(path)
	if value == nil then
		fail(file, line, ('%s "%s" is not in ns.Defaults'):format(what, path))
	elseif want ~= "any" and type(value) ~= want then
		fail(file, line, ('%s "%s" is a %s in ns.Defaults, expected a %s'):format(what, path, type(value), want))
	end
end

local function tocFiles(addon)
	local files = {}
	for line in io.lines(ROOT .. "/" .. addon .. "/" .. addon .. ".toc") do
		line = line:gsub("\r", "")
		if line:find("%.lua$") and not line:find("^#") and not line:find("^Libs") then
			files[#files + 1] = addon .. "/" .. line:gsub("\\", "/")
		end
	end
	return files
end

local function scan(file, schema)
	local f = assert(io.open(ROOT .. "/" .. file, "rb"))
	local src = f:read("*a")
	f:close()
	local lineNo = 0
	for line in (src .. "\n"):gmatch("(.-)\n") do
		lineNo = lineNo + 1
		local code = line:gsub("%-%-.*$", ""):gsub('%.%.%s*"[^"]*"', ".. _"):gsub('"[^"]*"%s*%.%.', "_ ..")
		if schema then
			for field, path in code:gmatch('(%w+) = "([%w_%.]+)"') do
				if FIELDS[field] and (path:find("%.") or field:find("^enabled")) then
					check(file, lineNo, field, path, FIELDS[field])
				end
			end
			for field, list in code:gmatch("(enabledBy%w*) = (%b{})") do
				for path in list:gmatch('"([%w_%.]+)"') do
					check(file, lineNo, field, path, FIELDS[field] or "boolean")
				end
			end
		end
		for method, path in code:gmatch(':(%a+Config)%(%s*"([%w_%.]+)"%s*[,)]') do
			if CALLS[method] then
				check(file, lineNo, method, path, "any")
			end
		end
	end
end

for _, file in ipairs(tocFiles("FrostAtomUI")) do
	scan(file, false)
end
for _, file in ipairs(tocFiles("FrostAtomUI_Config")) do
	scan(file, true)
end

local CENTER_FRAMES = {
	{ "lossOfControl.point", 58 },
	{ "diminishingReturns.playerPoint", resolve("diminishingReturns.playerSize") },
	{ "combatAlert.point", 30 },
}

for i = 1, #CENTER_FRAMES do
	for j = i + 1, #CENTER_FRAMES do
		local a, b = CENTER_FRAMES[i], CENTER_FRAMES[j]
		local pointA, pointB = resolve(a[1]), resolve(b[1])
		checked = checked + 1
		if pointA[1] ~= "CENTER" or pointB[1] ~= "CENTER" or pointA[4] or pointB[4] then
			fail(
				"FrostAtomUI/Core/Settings/Defaults/Combat.lua",
				1,
				("%s and %s must both be anchored to the screen center"):format(a[1], b[1])
			)
		elseif math.abs(pointA[3] - pointB[3]) < (a[2] + b[2]) / 2 then
			fail("FrostAtomUI/Core/Settings/Defaults/Combat.lua", 1, ("default %s overlaps %s"):format(a[1], b[1]))
		end
	end
end

print(("check_schema: %d literal config paths and anchors, %d errors"):format(checked, errors))
os.exit(errors == 0 and 0 or 1)
