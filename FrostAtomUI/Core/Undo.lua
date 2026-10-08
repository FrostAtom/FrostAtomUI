local ADDON_NAME, ns = ...

local L = ns.L

local Undo = {}
ns.Undo = Undo

local LIMIT = 100
local MERGE_SECONDS = 1
local FIRE_LIMIT = 40
local SNAPSHOT_RING = 10
local SNAPSHOT_REPEAT = 60
local PROFILE, LAYOUT_BASE = "\1profile", "\1layoutBase"
local KEYS = { "CTRL-Z", "CTRL-Y" }
local BUTTON = "FrostAtomUIUndoButton"

local store = ns.ConfigStore
local snapshotsSlot = ns.Storage.Claim("snapshots", "Undo", "state")
local layoutBaseSlot = ns.Storage.Slot("layoutBase")
local steps, position = {}, 0
local open, label
local depth = 0
local muted = false
local sessionSaved = {}
local unmuteKey = {}

local function notify()
	ns:Fire(ns.E.HISTORY_CHANGED)
end

local function same(a, b)
	if a == b then
		return true
	elseif type(a) ~= "table" or type(b) ~= "table" then
		return false
	end
	for key, value in pairs(a) do
		if not same(value, b[key]) then
			return false
		end
	end
	for key in pairs(b) do
		if a[key] == nil then
			return false
		end
	end
	return true
end

local function layoutBases()
	return layoutBaseSlot:Table()
end

local function layoutBase(profile)
	local bases = layoutBaseSlot:Get()
	local value = type(bases) == "table" and bases[profile]
	return type(value) == "string" and value or nil
end

local function capture(key)
	if key == PROFILE then
		return { store.readAll() }
	elseif key == LAYOUT_BASE then
		return { layoutBase(ns:GetActiveProfile()) }
	end
	return { store.read(key) }
end

local function restore(key, value)
	if key == PROFILE then
		store.writeAll(value[1])
	elseif key == LAYOUT_BASE then
		layoutBases()[ns:GetActiveProfile()] = value[1]
	else
		store.write(key, value[1], value[2])
	end
end

local function sameKeys(a, b)
	if #a.keys ~= #b.keys then
		return false
	end
	for _, key in ipairs(a.keys) do
		if not b.old[key] then
			return false
		end
	end
	return true
end

local function unchanged(step)
	for _, key in ipairs(step.keys) do
		if not same(step.old[key], step.new[key]) then
			return false
		end
	end
	return true
end

local function push(step)
	for i = #steps, position + 1, -1 do
		steps[i] = nil
	end
	local last = steps[position]
	if
		last
		and not last.label
		and not step.label
		and last.profile == step.profile
		and step.time - last.time <= MERGE_SECONDS
		and sameKeys(last, step)
	then
		last.new, last.time = step.new, step.time
		if unchanged(last) then
			steps[position] = nil
			position = position - 1
		end
		return
	end
	position = position + 1
	steps[position] = step
	if position > LIMIT then
		tremove(steps, 1)
		position = position - 1
	end
end

local function close()
	local step = open
	open = nil
	if not step then
		return
	end
	step.new = {}
	for _, key in ipairs(step.keys) do
		step.new[key] = capture(key)
	end
	if unchanged(step) then
		return
	end
	step.time = GetTime()
	push(step)
	notify()
end

local function closeIfIdle(step)
	if open == step and depth == 0 then
		close()
	end
end

local function closeLater(step)
	ns.Defer(step, function()
		ns.Defer(step, closeIfIdle)
	end)
end

local function record(key)
	if muted or not ns.Storage.IsLoaded() then
		return
	end
	local profile = ns:GetActiveProfile()
	if not sessionSaved[profile] then
		sessionSaved[profile] = true
		Undo.Snapshot("session")
	end
	local step = open
	if not step then
		step = { keys = {}, old = {}, label = label, profile = profile }
		open = step
		if depth == 0 then
			closeLater(step)
		end
	end
	if not step.old[key] then
		step.keys[#step.keys + 1] = key
		step.old[key] = capture(key)
	end
end

local function unmute()
	ns.Defer(unmuteKey, function()
		muted = false
	end)
end

local function apply(step, values, backwards)
	muted = true
	local keys = step.keys
	local first, last, direction = 1, #keys, 1
	if backwards then
		first, last, direction = #keys, 1, -1
	end
	for i = first, last, direction do
		restore(keys[i], values[keys[i]])
	end
	store.rebuild()
	if step.old[PROFILE] or #keys > FIRE_LIMIT then
		ns:Fire(ns.E.CONFIG_CHANGED)
	else
		for _, key in ipairs(keys) do
			if key ~= LAYOUT_BASE then
				ns:Fire(ns.E.CONFIG_CHANGED, key)
			end
		end
	end
	ns.Defer(unmuteKey, unmute)
end

function Undo.Begin(text)
	if depth == 0 then
		close()
		label = text
	end
	depth = depth + 1
end

function Undo.End()
	if depth == 0 then
		return
	end
	depth = depth - 1
	if depth == 0 then
		label = nil
		if open then
			closeLater(open)
		end
	end
end

function Undo.Run(text, func, ...)
	Undo.Begin(text)
	local ok, a, b = ns.SafeCall(func, ...)
	Undo.End()
	if ok then
		return a, b
	end
end

function Undo.Flush()
	local step = open
	if depth == 0 then
		close()
	end
	return step and steps[position] == step and step or nil
end

function Undo.Undo()
	if depth > 0 then
		return false
	end
	close()
	local step = steps[position]
	if not step or step.profile ~= ns:GetActiveProfile() then
		return false
	end
	position = position - 1
	apply(step, step.old, true)
	notify()
	return true, step
end

function Undo.Redo()
	if depth > 0 then
		return false
	end
	close()
	local step = steps[position + 1]
	if not step or step.profile ~= ns:GetActiveProfile() then
		return false
	end
	position = position + 1
	apply(step, step.new)
	notify()
	return true, step
end

function Undo.GetUndo()
	local step = steps[position]
	return step and step.profile == ns:GetActiveProfile() and step or nil
end

function Undo.GetRedo()
	local step = steps[position + 1]
	return step and step.profile == ns:GetActiveProfile() and step or nil
end

function Undo.IsRestoring()
	return muted
end

function Undo.Clear()
	open = nil
	wipe(steps)
	position = 0
	notify()
end

local describers = {}

function Undo.TrackLayoutBase()
	record(LAYOUT_BASE)
end

function Undo.Describe(step)
	if step.label then
		return step.label
	end
	local key = #step.keys == 1 and step.keys[1]
	for i = 1, #describers do
		local text = key and describers[i](key)
		if text then
			return text
		end
	end
	return nil, key
end

function Undo.RegisterDescriber(describer)
	describers[#describers + 1] = describer
end

function Undo.ChangedValue(step)
	local key = #step.keys == 1 and step.keys[1]
	if not key or key == PROFILE or key == LAYOUT_BASE then
		return nil
	end
	local old, new = step.old[key], step.new[key]
	local before, after = old[1], new[1]
	if before == nil then
		before = old[2]
	end
	if after == nil then
		after = new[2]
	end
	return key, before, after
end

local function snapshotList(profile)
	local all = snapshotsSlot:Table()
	local list = all[profile]
	if type(list) ~= "table" then
		list = {}
		all[profile] = list
	end
	return list
end

local function trimRing(list)
	local count = 0
	for i = 1, #list do
		local item = list[i]
		if item and not item.manual and not item.pinned then
			count = count + 1
		end
	end
	for i = #list, 1, -1 do
		if count <= SNAPSHOT_RING then
			return
		end
		local item = list[i]
		if not item.manual and not item.pinned then
			tremove(list, i)
			count = count - 1
		end
	end
end

function Undo.Snapshot(reason, detail, manual)
	if not ns.Storage.IsLoaded() then
		return nil
	end
	local profile = ns:GetActiveProfile()
	local list = snapshotList(profile)
	local now = time()
	local data, base = store.readAll(), layoutBase(profile)
	if not manual then
		for _, item in ipairs(list) do
			if
				not item.manual
				and item.reason == reason
				and item.detail == detail
				and now - item.time < SNAPSHOT_REPEAT
			then
				return item
			end
		end
		local newest = list[1]
		if newest and newest.layoutBase == base and same(newest.data, data) then
			return newest
		end
	end
	local item = {
		time = now,
		reason = reason,
		detail = detail,
		manual = manual or nil,
		version = GetAddOnMetadata(ADDON_NAME, "Version"),
		schema = store.version(),
		data = data,
		layoutBase = base,
	}
	tinsert(list, 1, item)
	trimRing(list)
	notify()
	return item
end

function Undo.GetSnapshots()
	if not ns.Storage.IsLoaded() then
		return {}
	end
	return snapshotList(ns:GetActiveProfile())
end

function Undo.DeleteSnapshot(item)
	local list = Undo.GetSnapshots()
	for i = #list, 1, -1 do
		if list[i] == item then
			tremove(list, i)
		end
	end
	notify()
end

function Undo.PinSnapshot(item, pinned)
	item.pinned = pinned and true or nil
	trimRing(Undo.GetSnapshots())
	notify()
end

function Undo.RestoreSnapshot(item)
	local data = CopyTable(item.data)
	local schema = tonumber(item.schema) or 0
	if schema < store.version() and not ns.SafeCall(store.upgrade, data, schema) then
		return false
	end
	local profile = ns:GetActiveProfile()
	Undo.Snapshot("restore")
	Undo.Begin(L["Restore a backup"])
	record(PROFILE)
	record(LAYOUT_BASE)
	store.writeAll(data)
	layoutBases()[profile] = item.layoutBase
	store.rebuild()
	Undo.End()
	ns:Fire(ns.E.CONFIG_CHANGED)
	return true
end

local setConfig, resetConfig, setBaseline = ns.SetConfig, ns.ResetConfig, ns.SetBaselineConfig
local keepBaseline, replaceProfile, copyProfile = ns.KeepBaselineAsOwn, ns.ReplaceProfile, ns.CopyProfile
local setProfile, renameProfile = ns.SetProfile, ns.RenameProfile

function ns:SetConfig(path, value)
	record(store.slot(path))
	return setConfig(self, path, value)
end

function ns:ResetConfig(path, factory)
	if path then
		record(store.slot(path))
	else
		record(PROFILE)
		record(LAYOUT_BASE)
	end
	return resetConfig(self, path, factory)
end

function ns:SetBaselineConfig(path, value)
	record(store.slot(path))
	return setBaseline(self, path, value)
end

function ns:KeepBaselineAsOwn(profileName, paths)
	if profileName == ns:GetActiveProfile() then
		for _, path in ipairs(paths) do
			record(store.slot(path))
		end
	end
	return keepBaseline(self, profileName, paths)
end

function ns:ReplaceProfile(profile)
	Undo.Snapshot("import")
	Undo.Begin(L["Import a profile"])
	record(PROFILE)
	record(LAYOUT_BASE)
	ns.SafeCall(replaceProfile, self, profile)
	Undo.End()
end

function ns:CopyProfile(source)
	Undo.Snapshot("copy", source)
	return Undo.Run(L["Copy a profile"], copyProfile, self, source)
end

function ns:SetProfile(name)
	close()
	local before = ns:GetActiveProfile()
	setProfile(self, name)
	if ns:GetActiveProfile() ~= before then
		Undo.Clear()
	end
end

function ns:RenameProfile(old, new)
	close()
	local renamed = renameProfile(self, old, new)
	if renamed then
		for _, step in ipairs(steps) do
			if step.profile == old then
				step.profile = new:trim()
			end
		end
		sessionSaved[new:trim()], sessionSaved[old] = sessionSaved[old], nil
		notify()
	end
	return renamed
end

local button
local owners = {}

local function bindKeys()
	if not button then
		button = CreateFrame("Button", BUTTON, UIParent)
		button:RegisterForClicks("AnyDown")
		button:SetScript("OnClick", function(_, key)
			if key == "CTRL-Y" then
				Undo.Redo()
			else
				Undo.Undo()
			end
		end)
	end
	ClearOverrideBindings(button)
	if not next(owners) or InCombatLockdown() then
		return
	end
	for _, key in ipairs(KEYS) do
		local action = GetBindingAction(key)
		if not action or action == "" then
			SetOverrideBindingClick(button, false, key, BUTTON, key)
		end
	end
end

function Undo.SetKeysOwner(owner, active)
	owners[owner] = active and true or nil
	bindKeys()
end

local watcher = ns.Mixin({}, ns.EventMixin)
watcher:RegisterEvent(ns.E.DB_LOADED, function()
	wipe(sessionSaved)
	Undo.Clear()
end)
watcher:RegisterEvent("PLAYER_REGEN_DISABLED", function()
	if button then
		ClearOverrideBindings(button)
	end
end)
watcher:RegisterEvent("PLAYER_REGEN_ENABLED", function()
	if next(owners) then
		bindKeys()
	end
end)
