local ADDON_NAME, ns = ...

local MEDIA_PATH = "Interface\\AddOns\\" .. ADDON_NAME .. "\\Media\\"

local Media = {
	buttonNormal = MEDIA_PATH .. "textureNormal",
	mapArrow = MEDIA_PATH .. "mapArrow",
	mapUnit = MEDIA_PATH .. "mapUnit",
	transparent = MEDIA_PATH .. "transparent",
	arenaCountdown = MEDIA_PATH .. "arenaCountdown",
	glowCorner = MEDIA_PATH .. "glowCorner",
	buttonHighlight = "Interface\\Buttons\\ButtonHilight-Square",
	blank = "Interface\\Buttons\\WHITE8x8",
	border = "Interface\\Tooltips\\UI-Tooltip-Border",
	font = "Fonts\\ARIALN.ttf",
	fontBold = "Fonts\\FRIZQT__.ttf",
	glyphFont = MEDIA_PATH .. "Fonts\\fa-solid-900.ttf",
	statusbar = "Interface\\Buttons\\WHITE8x8",
	emptySlot = "Interface\\PaperDoll\\UI-Backpack-EmptySlot",
	questionMark = "Interface\\Icons\\INV_Misc_QuestionMark",
}
ns.Media = Media

local DEFAULT_FONT, DEFAULT_FONT_BOLD = Media.font, Media.fontBold

Media.fonts = {
	{ "Fonts\\ARIALN.ttf", "Arial Narrow" },
	{ "Fonts\\FRIZQT__.ttf", "Friz Quadrata" },
	{ "Fonts\\MORPHEUS.ttf", "Morpheus" },
	{ "Fonts\\skurri.ttf", "Skurri" },
}

Media.statusbars = {
	{ "Interface\\Buttons\\WHITE8x8", "Flat" },
	{ MEDIA_PATH .. "minimalist", "Minimalist" },
	{ "Interface\\TargetingFrame\\UI-StatusBar", "Blizzard" },
	{ "Interface\\TargetingFrame\\UI-TargetingFrame-BarFill", "Glossy" },
	{ "Interface\\TargetingFrame\\BarFill2", "Soft" },
	{ "Interface\\PaperDollInfoFrame\\UI-Character-Skills-Bar", "Skills" },
	{ "Interface\\CharacterFrame\\BarFill", "Shaded" },
	{ "Interface\\Tooltips\\UI-Tooltip-Background", "Matte" },
}

local LSM = LibStub("LibSharedMedia-3.0")
local LSM_TYPES = { fonts = LSM.MediaType.FONT, statusbars = LSM.MediaType.STATUSBAR }
local lower = string.lower

for kind, mediaType in pairs(LSM_TYPES) do
	for _, entry in ipairs(Media[kind]) do
		LSM:Register(mediaType, entry[2], entry[1])
	end
end

function ns.MediaList(kind)
	local list, seen = {}, {}
	for _, entry in ipairs(Media[kind]) do
		list[#list + 1] = { entry[1], entry[2] }
		seen[lower(entry[1])] = true
	end
	local shared = {}
	for name, path in pairs(LSM:HashTable(LSM_TYPES[kind])) do
		if type(path) == "string" and not seen[lower(path)] then
			seen[lower(path)] = true
			shared[#shared + 1] = { path, name }
		end
	end
	table.sort(shared, function(a, b)
		return a[2] < b[2]
	end)
	for i = 1, #shared do
		list[#list + 1] = shared[i]
	end
	return list
end

local function known(kind, path, fallback)
	if type(path) ~= "string" then
		return fallback
	end
	local key = lower(path)
	for _, entry in ipairs(Media[kind]) do
		if lower(entry[1]) == key then
			return path
		end
	end
	for _, shared in pairs(LSM:HashTable(LSM_TYPES[kind])) do
		if type(shared) == "string" and lower(shared) == key then
			return path
		end
	end
	return fallback
end

local statusBars = setmetatable({}, { __mode = "k" })
local fontRegions = setmetatable({}, { __mode = "k" })

function ns.SkinStatusBar(bar)
	bar:SetStatusBarTexture(Media.statusbar)
	statusBars[bar] = true
	return bar
end

function ns.SetFont(region, size, outline, bold)
	region:SetFont(bold and Media.fontBold or Media.font, size, outline)
	fontRegions[region] = bold or false
end

function ns.ApplyMedia(general)
	Media.applied = general
	local font = known("fonts", general.font, DEFAULT_FONT)
	local fontBold = known("fonts", general.fontBold, DEFAULT_FONT_BOLD)
	local statusbar = known("statusbars", general.statusbar, Media.statusbars[1][1])
	local fontChanged = Media.font ~= font or Media.fontBold ~= fontBold
	local statusbarChanged = Media.statusbar ~= statusbar
	Media.font = font
	Media.fontBold = fontBold
	Media.statusbar = statusbar
	if fontChanged then
		for region, bold in pairs(fontRegions) do
			local _, size, outline = region:GetFont()
			region:SetFont(bold and Media.fontBold or Media.font, size, outline)
		end
	end
	if statusbarChanged then
		for bar in pairs(statusBars) do
			local r, g, b, a = bar:GetStatusBarColor()
			bar:SetStatusBarTexture(Media.statusbar)
			bar:SetStatusBarColor(r, g, b, a)
		end
	end
end

LSM.RegisterCallback(Media, "LibSharedMedia_Registered", function(_, mediaType)
	if (mediaType == LSM_TYPES.fonts or mediaType == LSM_TYPES.statusbars) and Media.applied then
		ns.ApplyMedia(Media.applied)
	end
end)

function ns.CreateBackdrop(edgeSize, inset)
	inset = inset or ns.PixelPerfect(1)
	return {
		edgeFile = Media.border,
		edgeSize = edgeSize or 8,
		bgFile = Media.blank,
		insets = { top = inset, bottom = inset, left = inset, right = inset },
	}
end
