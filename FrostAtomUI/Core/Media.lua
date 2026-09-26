local ADDON_NAME, ns = ...

local MEDIA_PATH = "Interface\\AddOns\\" .. ADDON_NAME .. "\\Media\\"

local Media = {
	buttonNormal = MEDIA_PATH .. "textureNormal",
	mapArrow = MEDIA_PATH .. "mapArrow",
	mapUnit = MEDIA_PATH .. "mapUnit",
	transparent = MEDIA_PATH .. "transparent",
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

local function knownStatusbar(path)
	for _, statusbar in ipairs(Media.statusbars) do
		if statusbar[1] == path then
			return path
		end
	end
	return Media.statusbars[1][1]
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
	local fontChanged = Media.font ~= general.font or Media.fontBold ~= general.fontBold
	local statusbar = knownStatusbar(general.statusbar)
	local statusbarChanged = Media.statusbar ~= statusbar
	Media.font = general.font
	Media.fontBold = general.fontBold
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

function ns.CreateBackdrop(edgeSize, inset)
	inset = inset or ns.PixelPerfect(1)
	return {
		edgeFile = Media.border,
		edgeSize = edgeSize or 8,
		bgFile = Media.blank,
		insets = { top = inset, bottom = inset, left = inset, right = inset },
	}
end
