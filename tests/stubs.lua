local M = { autoStubbed = {}, errors = {}, frames = {} }

wipe = function(t)
	for k in pairs(t) do
		t[k] = nil
	end
	return t
end
tinsert, tremove = table.insert, table.remove
tContains = function(t, v)
	for _, x in pairs(t) do
		if x == v then
			return true
		end
	end
	return false
end
strsplit = function(sep, s, limit)
	local out, pos, n = {}, 1, 0
	while true do
		n = n + 1
		local a, b = s:find(sep, pos, true)
		if not a or (limit and n >= limit) then
			out[#out + 1] = s:sub(pos)
			break
		end
		out[#out + 1] = s:sub(pos, a - 1)
		pos = b + 1
	end
	return unpack(out)
end
strtrim = function(s)
	return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end
string.trim = strtrim
strlower, strupper, strfind, strmatch, strsub, strlen, strrep, strbyte, strchar, format, gsub, gmatch =
	string.lower,
	string.upper,
	string.find,
	string.match,
	string.sub,
	string.len,
	string.rep,
	string.byte,
	string.char,
	string.format,
	string.gsub,
	string.gmatch
floor, ceil, abs, max, min, mod, sqrt = math.floor, math.ceil, math.abs, math.max, math.min, math.fmod, math.sqrt
getglobal = function(k)
	return _G[k]
end
setglobal = function(k, v)
	_G[k] = v
end
CopyTable = function(t)
	local c = {}
	for k, v in pairs(t) do
		c[k] = type(v) == "table" and CopyTable(v) or v
	end
	return c
end
hooksecurefunc = function() end
geterrorhandler = function()
	return function(e)
		M.errors[#M.errors + 1] = tostring(e)
	end
end
seterrorhandler = function() end
debugprofilestop = function()
	return os.clock() * 1000
end
time = os.time
date = os.date
StaticPopupDialogs = {}
YES, NO = "Yes", "No"

M.clock = 1000
GetTime = function()
	return M.clock
end
UnitName = function(unit)
	if unit == "player" then
		return "Tester"
	end
end
UnitClass = function()
	return "Mage", "MAGE"
end
UnitFactionGroup = function()
	return "Alliance"
end
GetRealmName = function()
	return "TestRealm"
end
GetLocale = function()
	return "enUS"
end
M.cvars = { gxResolution = "1920x1080", gxWindow = "0", gxApi = "D3D9" }
GetCVar = function(name)
	return M.cvars[name]
end
SetCVar = function(name, value)
	M.cvars[name] = value ~= nil and tostring(value) or nil
end
GetCVarDefault = function()
	return "default"
end
M.inCombat = false
InCombatLockdown = function()
	return M.inCombat
end
IsAddOnLoaded = function()
	return false
end
GetAddOnMetadata = function(_, field)
	return ({ Version = "1.4.0", ["X-Build"] = "2026-10-07" })[field]
end
GetScreenWidth = function()
	return 1920
end
GetScreenHeight = function()
	return 1080
end

local Widget = {}
local widgetMeta
local function newWidget()
	local widget = setmetatable({ __scripts = {}, __events = {}, __shown = true }, widgetMeta)
	M.frames[#M.frames + 1] = widget
	return widget
end
widgetMeta = {
	__index = function(_, key)
		local v = rawget(Widget, key)
		if v then
			return v
		end
		if type(key) == "string" and key:find("^Create") then
			return function()
				return newWidget()
			end
		end
		if type(key) == "string" and key:find("^Get") then
			return function()
				return 0
			end
		end
		if type(key) == "string" and key:find("^Is") then
			return function()
				return false
			end
		end
		return function() end
	end,
}
function Widget:SetScript(name, fn)
	self.__scripts[name] = fn
end
function Widget:GetScript(name)
	return self.__scripts[name]
end
function Widget:RegisterEvent(event)
	self.__events[event] = true
end
function Widget:UnregisterEvent(event)
	self.__events[event] = nil
end
function Widget:Show()
	self.__shown = true
end
function Widget:Hide()
	self.__shown = false
end
function Widget:IsShown()
	return self.__shown
end
function Widget:GetParent()
	return UIParent
end
function Widget:GetScale()
	return 1
end
function Widget:GetEffectiveScale()
	return 1
end
function Widget:GetName()
	return nil
end
M.newWidget = newWidget
CreateFrame = function()
	return newWidget()
end
UIParent, WorldFrame, GameTooltip = newWidget(), newWidget(), newWidget()

function M.tick(elapsed)
	M.clock = M.clock + (elapsed or 0)
	for _, frame in ipairs(M.frames) do
		local onUpdate = frame.__scripts.OnUpdate
		if onUpdate and frame.__shown then
			onUpdate(frame, elapsed or 0)
		end
	end
end

function M.event(event, ...)
	for _, frame in ipairs(M.frames) do
		local onEvent = frame.__scripts.OnEvent
		if onEvent and frame.__events[event] then
			onEvent(frame, event, ...)
		end
	end
end

function M.takeErrors()
	local errors = M.errors
	M.errors = {}
	return errors
end

local function c(r, g, b)
	return { r = r, g = g, b = b }
end
RAID_CLASS_COLORS = {}
for _, k in ipairs({
	"WARRIOR",
	"PALADIN",
	"HUNTER",
	"ROGUE",
	"PRIEST",
	"DEATHKNIGHT",
	"SHAMAN",
	"MAGE",
	"WARLOCK",
	"DRUID",
}) do
	RAID_CLASS_COLORS[k] = c(1, 1, 1)
end
CLASS_ICON_TCOORDS = setmetatable({}, {
	__index = function()
		return { 0, 1, 0, 1 }
	end,
})
PowerBarColor =
	{ [0] = c(0, 0, 1), c(1, 0, 0), c(1, 0.5, 0.25), c(1, 1, 0), c(0, 1, 1), c(0.5, 0.5, 0.5), c(0, 0.82, 1) }
DebuffTypeColor = {
	none = c(0.8, 0, 0),
	Magic = c(0.2, 0.6, 1),
	Curse = c(0.6, 0, 1),
	Disease = c(0.6, 0.4, 0),
	Poison = c(0, 0.6, 0),
}
ITEM_QUALITY_COLORS = setmetatable({}, {
	__index = function()
		return c(1, 1, 1)
	end,
})
FACTION_BAR_COLORS = setmetatable({}, {
	__index = function()
		return c(1, 1, 1)
	end,
})
LOCALIZED_CLASS_NAMES_MALE = setmetatable({}, {
	__index = function(_, k)
		return k
	end,
})
LOCALIZED_CLASS_NAMES_FEMALE = LOCALIZED_CLASS_NAMES_MALE

local sharedMedia = { MediaType = { FONT = "font", STATUSBAR = "statusbar" }, media = {} }
function sharedMedia:Register(kind, name, path)
	self.media[kind] = self.media[kind] or {}
	self.media[kind][name] = path
end
function sharedMedia:HashTable(kind)
	return self.media[kind] or {}
end
function sharedMedia.RegisterCallback() end
local libraries = { ["LibSharedMedia-3.0"] = sharedMedia }
function LibStub(name)
	return libraries[name]
end

local autoMeta = {}
autoMeta.__index = function()
	return setmetatable({}, autoMeta)
end
autoMeta.__call = function() end
setmetatable(_G, {
	__index = function(_, key)
		M.autoStubbed[key] = (M.autoStubbed[key] or 0) + 1
		if type(key) == "string" and key:find("^[A-Z][A-Z0-9_]*$") then
			if key:find("^NUM_") or key:find("^MAX_") then
				return 10
			end
			return key
		end
		return setmetatable({}, autoMeta)
	end,
})

function M.sandbox(globals, isUndefined)
	globals._G = globals
	return setmetatable(globals, {
		__index = function(_, key)
			if isUndefined and type(key) == "string" and isUndefined(key) then
				return nil
			end
			return _G[key]
		end,
	})
end

function M.loadFile(path, ns, box)
	local chunk = assert(loadfile(M.root .. "/FrostAtomUI/" .. path))
	if box then
		setfenv(chunk, box)
	end
	return chunk("FrostAtomUI", ns)
end

function M.loadLayout(ns)
	for line in io.lines(M.root .. "/FrostAtomUI/FrostAtomUI.toc") do
		line = line:gsub("\r", "")
		if line:find("^Core\\Layout\\") then
			M.loadFile((line:gsub("\\", "/")), ns)
		end
	end
end

function M.loadToc(root, addon, stopAfter, ns)
	ns = ns or {}
	local loaded = {}
	for line in io.lines(root .. "/" .. addon .. "/" .. addon .. ".toc") do
		line = line:gsub("\r", "")
		if line ~= "" and not line:find("^#") and not line:find("^Libs") then
			local path = root .. "/" .. addon .. "/" .. line:gsub("\\", "/")
			local chunk = assert(loadfile(path))
			chunk(addon, ns)
			loaded[#loaded + 1] = line
			if line == stopAfter then
				break
			end
		end
	end
	return ns, loaded
end

return M
