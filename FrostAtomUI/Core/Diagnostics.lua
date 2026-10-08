local ADDON_NAME, ns = ...
local L = ns.L

local GetAddOnMetadata, GetAddOnInfo, IsAddOnLoaded = GetAddOnMetadata, GetAddOnInfo, IsAddOnLoaded
local debugprofilestop = debugprofilestop
local format, concat, sort = string.format, table.concat, table.sort

local CONFIG_ADDON = "FrostAtomUI_Config"
local PERF_TOP = 30

local function showText(heading, text)
	local host = ns.API.LoadSettings()
	if host then
		host.ShowTextWindow(heading, text)
	end
end

local function otherAddons()
	local names = {}
	for i = 1, GetNumAddOns() do
		local name = GetAddOnInfo(i)
		if IsAddOnLoaded(i) and name ~= ADDON_NAME and name ~= CONFIG_ADDON then
			names[#names + 1] = name
		end
	end
	sort(names)
	return concat(names, ", ")
end

local function moduleStates()
	local on, off = {}, {}
	for _, module in ns:IterateModules() do
		local list = module.initialized == false and off or on
		list[#list + 1] = module.name
	end
	return concat(on, ", "), concat(off, ", ")
end

local function debugReport()
	local lines = {}
	local function add(text, ...)
		lines[#lines + 1] = format(text, ...)
	end
	local clientVersion, clientBuild = GetBuildInfo()
	UpdateAddOnMemoryUsage()
	add(
		"FrostAtom UI %s (%s), settings schema %s",
		GetAddOnMetadata(ADDON_NAME, "Version") or "?",
		GetAddOnMetadata(ADDON_NAME, "X-Build") or "?",
		tostring(ns:GetSchemaVersion())
	)
	add("Client %s (%s), locale %s, addon language %s", clientVersion, clientBuild, GetLocale(), tostring(ns.LOCALE))
	add("Realm %s, realmlist %s", GetRealmName(), GetCVar("realmlist") or "?")
	add(
		"%s level %d, profile %s",
		ns.PLAYER_CLASS or "?",
		UnitLevel("player"),
		ns.GetActiveProfile and ns:GetActiveProfile() or "?"
	)
	add(
		"Setup %s, style %s",
		tostring(ns.SetupState and ns.SetupState()),
		tostring(ns.SetupPresets and ns.SetupPresets.GetActiveStyle())
	)
	local unclaimed = ns.Storage.Unclaimed()
	if #unclaimed > 0 then
		add("Unclaimed saved keys: %s", table.concat(unclaimed, ", "))
	end
	add(
		"Resolution %s, UI scale %.3f, memory %.0f KB (Lua %.0f KB)",
		GetCVar("gxResolution") or "?",
		UIParent:GetScale(),
		GetAddOnMemoryUsage(ADDON_NAME),
		collectgarbage("count")
	)
	local on, off = moduleStates()
	add("Modules: %s", on)
	add("Disabled modules: %s", off ~= "" and off or "-")
	add("Other addons: %s", otherAddons())
	local errors = ns.recentErrors
	add("")
	add("Recent errors: %d", #errors)
	for i = #errors, 1, -1 do
		local entry = errors[i]
		add("")
		add("[%s] %s", date("%H:%M:%S", entry.time), entry.message)
		if entry.stack and entry.stack ~= "" then
			lines[#lines + 1] = entry.stack
		end
	end
	return concat(lines, "\n")
end

function ns.ShowDebugReport()
	showText(L["Debug report"], debugReport())
end

local profileStart

local function ownerName(owner)
	if type(owner) ~= "table" then
		return "?"
	elseif type(owner.name) == "string" then
		return owner.name
	end
	local frameName = type(owner.GetName) == "function" and owner:GetName()
	return frameName and (frameName:gsub("^" .. ADDON_NAME, ""):gsub("%d+$", "")) or "?"
end

local function perfReport(profile, seconds)
	local rows, byKey = {}, {}
	local totalMs = 0
	for event, byOwner in pairs(profile) do
		for owner, entry in pairs(byOwner) do
			local name = ownerName(owner)
			local key = event .. "\0" .. name
			local row = byKey[key]
			if not row then
				row = { event = event, owner = name, entry = { calls = 0, ms = 0, max = 0 } }
				byKey[key] = row
				rows[#rows + 1] = row
			end
			local sum = row.entry
			sum.calls, sum.ms, sum.max = sum.calls + entry.calls, sum.ms + entry.ms, math.max(sum.max, entry.max)
			totalMs = totalMs + entry.ms
		end
	end
	sort(rows, function(a, b)
		return a.entry.ms > b.entry.ms
	end)
	local lines = {
		format(
			"Event handlers: %.1f s, %.1f ms total (%.2f ms/s)",
			seconds,
			totalMs,
			totalMs / math.max(seconds, 0.001)
		),
		"",
		"    total ms    calls   avg ms   max ms  event / owner",
	}
	for i = 1, math.min(#rows, PERF_TOP) do
		local row, entry = rows[i], rows[i].entry
		lines[#lines + 1] = format(
			"%12.2f %8d %8.3f %8.3f  %s / %s",
			entry.ms,
			entry.calls,
			entry.ms / entry.calls,
			entry.max,
			row.event:gsub("^" .. ADDON_NAME .. "_", ""),
			row.owner
		)
	end
	return concat(lines, "\n")
end

function ns.TogglePerf()
	if not profileStart then
		profileStart = debugprofilestop()
		ns.StartEventProfile()
		ns.Print(L["profiling event handlers: type /fui perf again to stop"])
		return
	end
	local seconds = (debugprofilestop() - profileStart) / 1000
	profileStart = nil
	showText(L["Performance"], perfReport(ns.StopEventProfile(), seconds))
end
