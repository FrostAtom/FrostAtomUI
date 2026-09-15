local AddOnName,namespace = ...

local PATTERN = ("Interface\\AddOns\\%s\\Media\\%%s"):format(AddOnName)

local tbl = {
	["textureNormal"] = PATTERN:format("textureNormal"),
	["classIcons"] = PATTERN:format("UI-CLASSES-CIRCLES.blp"),
}

function namespace:GetMedia(mediaName)
	return tbl[mediaName]
end

--/run local f=UIParent:CreateTexture();f:SetPoint("CENTER");f:SetSize(512,512);f:SetTexture(FrostAtomUI:GetMediaPath("classIcons"))