local ADDON_NAME, ns = ...

local GetAddOnMetadata = GetAddOnMetadata
local SendAddonMessage = SendAddonMessage
local GetNumRaidMembers = GetNumRaidMembers
local GetNumPartyMembers = GetNumPartyMembers
local IsInInstance = IsInInstance
local IsInGuild = IsInGuild
local UnitName = UnitName
local UnitIsPlayer = UnitIsPlayer
local UnitIsUnit = UnitIsUnit
local UnitFactionGroup = UnitFactionGroup
local UnitIsConnected = UnitIsConnected
local GetTime = GetTime

local Misc = ns:GetModule("Misc")

local PREFIX = "FAUI"
local ANNOUNCE_DELAY = 10
local PROBE_INTERVAL = 300

local version = GetAddOnMetadata(ADDON_NAME, "Version") or "0"
local build = GetAddOnMetadata(ADDON_NAME, "X-Build") or "0"
local payload = version .. ":" .. build

local playerName = UnitName("player")
local playerFaction = UnitFactionGroup("player")

local users = {}
local probed = {}
local announcePending, groupSize, newerReported = false, 0, false

local Version = { version = version, build = build }
ns.Version = Version

function Version.GetUser(name)
	if name == playerName then
		return version, build
	end
	local user = users[name]
	if user then
		return user.version, user.build
	end
end

function Version.Label(ver, bld)
	return ("%s |cff808080(%s)|r"):format(ver, bld)
end

local function groupChannel()
	if GetNumRaidMembers() > 1 then
		local _, instanceType = IsInInstance()
		return instanceType == "pvp" and "BATTLEGROUND" or "RAID"
	elseif GetNumPartyMembers() > 0 then
		return "PARTY"
	elseif IsInGuild() then
		return "GUILD"
	end
end

local function announce()
	announcePending = false
	local channel = groupChannel()
	if channel then
		SendAddonMessage(PREFIX, "V:" .. payload, channel)
	end
end

local function queueAnnounce()
	if not announcePending then
		announcePending = true
		ns.After(ANNOUNCE_DELAY, announce)
	end
end

function Version.Probe(unit)
	if not UnitIsPlayer(unit) or UnitIsUnit(unit, "player") or not UnitIsConnected(unit) then
		return
	end
	if UnitFactionGroup(unit) ~= playerFaction then
		return
	end
	local name = UnitName(unit)
	if not name or users[name] then
		return
	end
	local now = GetTime()
	local last = probed[name]
	if last and now - last < PROBE_INTERVAL then
		return
	end
	probed[name] = now
	SendAddonMessage(PREFIX, "Q:" .. payload, "WHISPER", name)
end

local function reportNewer(theirVersion, theirBuild)
	if newerReported then
		return
	end
	newerReported = true
	ns.Print("A newer version is available: %s (yours: %s)", Version.Label(theirVersion, theirBuild), Version.Label(version, build))
end

Misc:RegisterEvent("CHAT_MSG_ADDON", function(_, prefix, message, channel, sender)
	if prefix ~= PREFIX or not sender or sender == playerName then
		return
	end
	local kind, theirVersion, theirBuild = message:match("^(%a):([^:]+):(.+)$")
	if not kind then
		return
	end

	local user = users[sender]
	if not user then
		user = {}
		users[sender] = user
	end
	user.version, user.build = theirVersion, theirBuild

	if theirBuild > build then
		reportNewer(theirVersion, theirBuild)
	end
	if kind == "Q" and channel == "WHISPER" then
		SendAddonMessage(PREFIX, "V:" .. payload, "WHISPER", sender)
	end

	if GameTooltip:IsShown() then
		local name, unit = GameTooltip:GetUnit()
		if name == sender and unit then
			GameTooltip:SetUnit(unit)
		end
	end
end)

local function onGroupChanged()
	local numRaid = GetNumRaidMembers()
	local size = numRaid > 0 and numRaid or GetNumPartyMembers() + 1
	if size > groupSize and size > 1 then
		queueAnnounce()
	end
	groupSize = size
end

Misc:RegisterEvent("PARTY_MEMBERS_CHANGED", onGroupChanged)
Misc:RegisterEvent("RAID_ROSTER_UPDATE", onGroupChanged)
local function onEnteringWorld()
	Misc:UnregisterEvent("PLAYER_ENTERING_WORLD", onEnteringWorld)
	Misc:RegisterEvent("PLAYER_ENTERING_WORLD", queueAnnounce)
	ns.Print("v%s, settings: |cffffffff/ui|r", Version.Label(version, build))
	queueAnnounce()
end

Misc:RegisterEvent("PLAYER_ENTERING_WORLD", onEnteringWorld)
