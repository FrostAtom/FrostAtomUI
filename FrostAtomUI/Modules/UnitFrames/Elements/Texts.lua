local _, ns = ...
local UF = ns:GetModule("UnitFrames")

local renderTags = UF.RenderTags
local templateUses = UF.TemplateUses
local config = ns.Config.unitFrames

local BARS = {
	{
		key = "health",
		settings = "healthTexts",
		points = { "TOPLEFT", "TOP", "TOPRIGHT", "LEFT", "CENTER", "RIGHT", "BOTTOMLEFT", "BOTTOM", "BOTTOMRIGHT" },
	},
	{ key = "power", settings = "powerTexts", points = { "LEFT", "RIGHT" } },
}

local function placeText(text, bar, point)
	local horizontal = point:match("LEFT") or point:match("RIGHT") or "CENTER"
	local vertical = point:match("^TOP") or point:match("^BOTTOM") or ""
	text:SetPoint(vertical .. "LEFT", bar)
	text:SetPoint(vertical .. "RIGHT", bar)
	text:SetJustifyH(horizontal)
	text:SetJustifyV(vertical == "" and "MIDDLE" or vertical)
	text:SetWordWrap(false)
end

function UF.CreateTexts(owner)
	local texts = {}
	for _, bar in ipairs(BARS) do
		local parent = owner[bar.key]
		for _, point in ipairs(bar.points) do
			local text = UF.CreateText(parent)
			placeText(text, parent, point)
			text.bar = bar.key
			text.settings = bar.settings
			text.point = point
			texts[#texts + 1] = text
		end
	end
	return texts
end

local function textTemplate(text, hovered)
	local slot = config[text.settings][text.point]
	if hovered and slot.hover ~= "" then
		return slot.hover
	end
	return slot.text
end

function UF.UpdateTexts(owner, key, data)
	local texts = owner.texts
	if not texts then
		return
	end
	data = data or owner.test
	local placeholder, empty = owner.health.placeholder, owner.power.empty
	for i = 1, #texts do
		local text = texts[i]
		local template = textTemplate(text, owner.hovered)
		if not key or text.bar == key or templateUses(template, key) then
			if template == "" or text.bar == "power" and empty then
				text:SetText(nil)
			elseif placeholder and text.bar == "health" and templateUses(template, "health") then
				text:SetText(placeholder)
			else
				text:SetText(renderTags(template, owner.unit, data))
			end
		end
	end
end

local function update(frame)
	UF.UpdateTexts(frame)
end

local function create(frame)
	local texts = UF.CreateTexts(frame)
	for i = 1, #UF.NAME_EVENTS do
		frame:RegisterUnitEvent(UF.NAME_EVENTS[i], update)
	end
	return texts
end

UF:RegisterElement("texts", create, update, update)
