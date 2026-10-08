local _, ns = ...

local SetCVar, GetCVar, GetCVarDefault = SetCVar, GetCVar, GetCVarDefault

local CVars = ns:NewModule("CVars")
local originalsSlot = ns.Storage.Claim("cvarOriginals", "CVars", "state")

local pinnedValues = {}
local eventToCVar = {}
local earlyOriginals = {}

local function originals()
	return originalsSlot:Table()
end

local function remember(name, value)
	local current = GetCVar(name)
	if current == nil or current == value then
		return
	end
	if not ns.Storage.IsLoaded() then
		if earlyOriginals[name] == nil then
			earlyOriginals[name] = current
		end
		return
	end
	local store = originals()
	if store[name] == nil then
		store[name] = current
	end
end

function CVars:Pin(name, value, updateEvent)
	remember(name, value)
	SetCVar(name, value)

	pinnedValues[name] = value
	if updateEvent then
		eventToCVar[updateEvent] = name
	end
end

function CVars:Unpin(name)
	if not pinnedValues[name] then
		return
	end
	pinnedValues[name] = nil
	local store = originalsSlot:Get()
	local original = store and store[name]
	SetCVar(name, original or GetCVarDefault(name))
	if store then
		store[name] = nil
	end
end

function CVars:IsPinned(name)
	return pinnedValues[name] ~= nil
end

function CVars:GetOriginal(name)
	local store = originalsSlot:Get()
	return store and store[name]
end

function CVars:CVAR_UPDATE(name, newValue)
	name = eventToCVar[name] or name

	local pinned = pinnedValues[name]
	if pinned and pinned ~= newValue then
		SetCVar(name, pinned)
	end
end

local SCALE_CVARS = { useUiScale = true, uiScale = true }

local function restoreUnpinned()
	local store = originalsSlot:Get()
	if type(store) ~= "table" then
		return
	end
	for name, value in pairs(store) do
		if not pinnedValues[name] and not SCALE_CVARS[name] then
			SetCVar(name, value)
			store[name] = nil
		end
	end
end

CVars:RegisterEvent(ns.E.DB_LOADED, function()
	local store = originals()
	for name, value in pairs(earlyOriginals) do
		if store[name] == nil then
			store[name] = value
		end
	end
	wipe(earlyOriginals)
end)

function CVars:Initialize()
	self:RegisterEvent("CVAR_UPDATE")
	self:RegisterEvent("PLAYER_ENTERING_WORLD", function(module)
		module:UnregisterEvent("PLAYER_ENTERING_WORLD")
		restoreUnpinned()
	end)
end
