local ADDON_NAME, ns = ...

local MEDIA_PATH = "Interface\\AddOns\\" .. ADDON_NAME .. "\\Media\\"

local Media = {
	buttonNormal = MEDIA_PATH .. "textureNormal",
	mapArrow = MEDIA_PATH .. "mapArrow",
	mapUnit = MEDIA_PATH .. "mapUnit",
	buttonHighlight = "Interface\\Buttons\\ButtonHilight-Square",
	blank = "Interface\\Buttons\\WHITE8x8",
	border = "Interface\\Tooltips\\UI-Tooltip-Border",
	font = "Fonts\\ARIALN.ttf",
	fontBold = "Fonts\\FRIZQT__.ttf",
	emptySlot = "Interface\\PaperDoll\\UI-Backpack-EmptySlot",
	questionMark = "Interface\\Icons\\INV_Misc_QuestionMark",
}
ns.Media = Media

function ns.CreateBackdrop(edgeSize, inset)
	inset = inset or ns.PixelPerfect(1)
	return {
		edgeFile = Media.border,
		edgeSize = edgeSize or 8,
		bgFile = Media.blank,
		insets = { top = inset, bottom = inset, left = inset, right = inset },
	}
end
