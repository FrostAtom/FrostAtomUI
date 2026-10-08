local _, ns = ...

local InCombatLockdown = InCombatLockdown

local function changeAffects(path, prefix)
	return not path or path == prefix or path:sub(1, #prefix + 1) == prefix .. "."
end

local pending = {}
local combatWatcher = ns.Mixin({}, ns.EventMixin)

combatWatcher:RegisterEvent("PLAYER_REGEN_ENABLED", function()
	if not next(pending) then
		return
	end
	for handler, owners in pairs(pending) do
		for owner in pairs(owners) do
			ns.SafeCall(handler, owner)
		end
	end
	wipe(pending)
end)

local function runWatcher(watcher)
	local path = watcher.path
	watcher.path = nil
	if watcher.secure and InCombatLockdown() then
		local owners = pending[watcher.handler]
		if not owners then
			owners = {}
			pending[watcher.handler] = owners
		end
		owners[watcher.owner] = true
	else
		watcher.handler(watcher.owner, path or nil)
	end
end

function ns.ModulePrototype:WatchConfig(prefix, handler, secure)
	local watcher = { owner = self, handler = handler, secure = secure }
	local function onChange(_, path)
		if not changeAffects(path, prefix) then
			return
		end
		if watcher.path == nil then
			watcher.path = path or false
			ns.Defer(watcher, runWatcher)
		elseif watcher.path ~= path then
			watcher.path = false
		end
	end
	self:RegisterEvent(ns.E.CONFIG_CHANGED, onChange)
	self:RegisterEvent(ns.E.POSITION_INVALIDATED, onChange)
end
