local _, ns = ...

local InCombatLockdown, SetCVar = InCombatLockdown, SetCVar

local originalsSlot = ns.Storage.Slot("cvarOriginals")

local CVAR_MIN_SCALE, CVAR_MAX_SCALE = 0.64, 1
local MIN_UI_SCALE, MAX_UI_SCALE = 0.4, 1.15

local function clamp(value, low, high)
	return math.max(low, math.min(high, value))
end

function ns.GetTargetUiScale()
	local general = ns.Storage.IsLoaded() and ns.Config.general
	local mode = general and general.uiScaleMode
	local scale
	if mode == "pixel" then
		scale = ns.PixelPerfectScale()
	elseif mode == "custom" then
		scale = general.uiScale
	else
		return nil
	end
	return clamp(scale, MIN_UI_SCALE, MAX_UI_SCALE)
end

local SCALE_CVARS = { "useUiScale", "uiScale" }
local settingScaleCVars = false
local scaleApplied = false

local function rememberGameScale()
	local originals = originalsSlot:Table()
	for _, name in ipairs(SCALE_CVARS) do
		if originals[name] == nil then
			originals[name] = GetCVar(name)
		end
	end
end

local function restoreGameScale()
	local originals = originalsSlot:Get()
	settingScaleCVars = true
	for _, name in ipairs(SCALE_CVARS) do
		SetCVar(name, originals and originals[name] or GetCVar(name))
		if originals then
			originals[name] = nil
		end
	end
	settingScaleCVars = false
	if originals and not next(originals) then
		originalsSlot:Set(nil)
	end
end

local function applyUiScale()
	if settingScaleCVars or InCombatLockdown() then
		return
	end
	local scale = ns.GetTargetUiScale()
	if scale then
		rememberGameScale()
		scaleApplied = true
		-- 3.3.5: the uiScale CVar only takes 0.64..1, the rest is reached with UIParent:SetScale
		local cvarScale = clamp(scale, CVAR_MIN_SCALE, CVAR_MAX_SCALE)
		-- 3.3.5: the scale CVars exist only after the addons load unless Config.wtf has them; SetCVar errors
		local useUiScale, uiScale = GetCVar("useUiScale"), tonumber(GetCVar("uiScale"))
		-- 3.3.5: SetCVar of a scale CVar fires UPDATE_FLOATING_CHAT_WINDOWS synchronously: endless recursion
		settingScaleCVars = true
		if useUiScale and useUiScale ~= "1" then
			SetCVar("useUiScale", 1)
		end
		if uiScale and math.abs(uiScale - cvarScale) > 0.001 then
			SetCVar("uiScale", cvarScale)
		end
		settingScaleCVars = false
		if math.abs(UIParent:GetScale() - scale) > 0.001 then
			UIParent:SetScale(scale)
		end
	elseif ns.Storage.IsLoaded() and (scaleApplied or originalsSlot:Get() and originalsSlot:Get().uiScale) then
		scaleApplied = false
		restoreGameScale()
	end
	if ns.Pixel.AlignUIParent() then
		ns:Fire(ns.E.PIXEL_CHANGED)
	end
end

local function applyGeneral()
	ns.ApplyMedia(ns.Config.general)
	applyUiScale()
end

local scaleWatcher = ns.Mixin({}, ns.EventMixin)
scaleWatcher:RegisterEvent("UI_SCALE_CHANGED", applyUiScale)
scaleWatcher:RegisterEvent("DISPLAY_SIZE_CHANGED", applyUiScale)
-- 3.3.5: a window resize with useUiScale=1 resets the UIParent scale and fires only this event
scaleWatcher:RegisterEvent("UPDATE_FLOATING_CHAT_WINDOWS", applyUiScale)
scaleWatcher:RegisterEvent("PLAYER_REGEN_ENABLED", applyUiScale)
scaleWatcher:RegisterEvent("PLAYER_ENTERING_WORLD", applyUiScale)
scaleWatcher:RegisterEvent(ns.E.PIXEL_CHANGED, applyUiScale)
scaleWatcher:RegisterEvent(ns.E.CONFIG_CHANGED, function(_, path)
	if not path or path == "general" or path:sub(1, 8) == "general." then
		applyGeneral()
	end
end)

ns.ApplyGeneralConfig = applyGeneral
