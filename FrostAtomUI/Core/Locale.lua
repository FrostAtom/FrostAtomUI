local _, ns = ...

local GetLocale = GetLocale
local rawset, pairs, type, sort = rawset, pairs, type, table.sort

local NAMES = {
	enUS = "English",
	ruRU = "Русский",
	deDE = "Deutsch",
	esES = "Español",
	frFR = "Français",
	koKR = "한국어",
	zhCN = "中文",
}

local L = setmetatable({}, {
	__index = function(self, key)
		rawset(self, key, key)
		return key
	end,
})

ns.L = L
ns.CLIENT_LOCALE = GetLocale()

local translations = {}
local handlers = {}

function ns.SetLocale(locale, entries)
	translations[locale] = entries
end

function ns.OnLocaleReady(handler)
	handlers[#handlers + 1] = handler
end

local function isAvailable(locale)
	return locale == "enUS" or translations[locale] ~= nil
end

function ns.ApplyLocale(locale)
	local active = locale and isAvailable(locale) and locale or ns.CLIENT_LOCALE
	local entries = translations[active]
	if entries then
		for key, value in pairs(entries) do
			if type(value) == "string" then
				rawset(L, key, value)
			end
		end
	end
	for i = 1, #handlers do
		handlers[i]()
	end
end

function ns.GetLocaleOverride()
	return ns.db and ns.db.locale or ""
end

function ns.SetLocaleOverride(locale)
	ns:SaveVariable("locale", locale ~= "" and locale or nil)
end

function ns.GetLocaleOptions()
	local options = { { "", ("%s (%s)"):format(L["Auto"], NAMES[ns.CLIENT_LOCALE] or ns.CLIENT_LOCALE) } }
	local codes = { "enUS" }
	for code in pairs(translations) do
		if code ~= "enUS" then
			codes[#codes + 1] = code
		end
	end
	sort(codes)
	for i = 1, #codes do
		options[i + 1] = { codes[i], NAMES[codes[i]] or codes[i] }
	end
	return options
end
