local _, ns = ...

local ui = FrostAtomUI
local L = ui.L

local max = math.max
local min = math.min
local ceil = math.ceil

local P = ns.private
local CONTROL_X = P.CONTROL_X
local GLYPH_BOX = P.GLYPH_BOX
local GLYPH_GAP = P.GLYPH_GAP
local GLYPH_SIZE = P.GLYPH_SIZE
local OUTLINES = P.OUTLINES
local REVERT_SECONDS = P.REVERT_SECONDS
local VALUE_BOX_WIDTH = P.VALUE_BOX_WIDTH
local bindHighlight = P.bindHighlight
local bindRow = P.bindRow
local changes = P.changes
local createEditBox = P.createEditBox
local createGlyph = P.createGlyph
local elements = P.elements
local font = P.font
local formatValue = P.formatValue
local forwardWheel = P.forwardWheel
local get = P.get
local nextName = P.nextName
local pages = P.pages
local parseValue = P.parseValue
local round = P.round
local setControlEnabled = P.setControlEnabled
local setEditBoxEnabled = P.setEditBoxEnabled

local confirmRevert

do
	local function applyValue(entry, value)
		if entry.set then
			entry.set(value)
		else
			ui:SetConfig(entry.path, value)
		end
	end

	local revertEntry, revertValue

	local function revertText(seconds)
		return L["Keep these settings? Reverting in %d s."]:format(seconds)
	end

	StaticPopupDialogs["FROSTATOMUI_CONFIG_REVERT"] = {
		text = "%s",
		button1 = L["Keep"],
		button2 = L["Revert"],
		OnAccept = function()
			revertEntry, revertValue = nil, nil
		end,
		OnUpdate = function(dialog)
			_G[dialog:GetName() .. "Text"]:SetText(revertText(ceil(dialog.timeleft)))
		end,
		OnHide = function()
			local entry, value = revertEntry, revertValue
			revertEntry, revertValue = nil, nil
			if entry then
				applyValue(entry, value)
			end
		end,
		timeout = REVERT_SECONDS,
		whileDead = 1,
		hideOnEscape = 1,
		preferredIndex = 3,
	}

	function confirmRevert(entry, previous)
		local name = StaticPopup_Visible("FROSTATOMUI_CONFIG_REVERT")
		if name and revertEntry == entry then
			_G[name].timeleft = REVERT_SECONDS
			return
		end
		if name then
			revertEntry = nil
			StaticPopup_Hide("FROSTATOMUI_CONFIG_REVERT")
		end
		revertEntry, revertValue = entry, previous
		StaticPopup_Show("FROSTATOMUI_CONFIG_REVERT", revertText(REVERT_SECONDS))
	end
end

local function set(entry, value, reset)
	local previous = get(entry)
	if previous == value and not reset then
		return
	end
	if entry.blizzard and not reset and ns.blizzardSwap and ns.blizzardSwap(entry, value) then
		ns.RefreshPage()
		return
	end
	if entry.confirmRevert then
		confirmRevert(entry, type(previous) == "table" and CopyTable(previous) or previous)
	end
	if entry.set then
		entry.set(value)
		return
	end
	if reset then
		reset()
	else
		ui:SetConfig(entry.path, value)
	end
end

do
	local TRACKED = {
		toggle = true,
		number = true,
		string = true,
		select = true,
		multiselect = true,
		font = true,
		color = true,
		point = true,
		offset = true,
	}
	local CHANGED_COLOR = { r = 0.35, g = 0.75, b = 1 }
	local BASELINE_COLOR = { r = 0.55, g = 0.55, b = 0.55 }
	local DOT_SIZE = 6
	local EPSILON = 0.0001
	local NAV_DELAY = 0.2
	local pathCache = setmetatable({}, { __mode = "k" })
	local trackCache = setmetatable({}, { __mode = "k" })
	local navToken = 0

	local function defaultOf(path)
		if path:find("%.%d+%.") or path:find("%.%d+$") then
			return false
		end
		local exists, factory = ui.API.FactoryValue(path)
		if not exists then
			return false
		end
		local base = ui:GetBaselineConfig(path)
		if base ~= nil then
			return true, ui:GetDefaultConfig(path)
		end
		return true, factory
	end

	local function same(a, b)
		if type(a) == "number" and type(b) == "number" then
			return math.abs(a - b) < EPSILON
		end
		if type(a) ~= "table" or type(b) ~= "table" then
			return a == b
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

	local function sameColor(a, b)
		if type(a) ~= "table" or type(b) ~= "table" then
			return a == b
		end
		for i = 1, 4 do
			if not same(a[i] or 1, b[i] or 1) then
				return false
			end
		end
		return true
	end

	local function optionsOf(values)
		if type(values) == "function" then
			return values() or {}
		end
		return values or {}
	end

	local function pathsOf(entry)
		local paths = pathCache[entry]
		if paths then
			return paths
		end
		paths = {}
		if entry.type == "multiselect" then
			for i, option in ipairs(optionsOf(entry.values)) do
				paths[i] = entry.path .. "." .. option[1]
			end
		elseif entry.type == "font" then
			paths[1], paths[2] = entry.path .. ".size", entry.path .. ".outline"
		elseif entry.type == "offset" then
			paths[1], paths[2] = entry.path, entry.pathY
		else
			paths[1] = entry.path
		end
		pathCache[entry] = paths
		return paths
	end

	local function tracks(entry)
		local tracked = trackCache[entry]
		if tracked ~= nil then
			return tracked
		end
		tracked = false
		if entry.isDefault then
			tracked = not entry.noReset
		elseif not entry.noReset and type(entry.path) == "string" and TRACKED[entry.type] then
			for _, path in ipairs(pathsOf(entry)) do
				if defaultOf(path) then
					tracked = true
					break
				end
			end
		end
		trackCache[entry] = tracked
		return tracked
	end

	local function isModified(entry)
		if not tracks(entry) then
			return false
		end
		if entry.isDefault then
			return not entry.isDefault()
		elseif entry.type == "point" then
			return not ui.Movers.IsAtHome(entry.path)
		end
		local compare = entry.type == "color" and sameColor or same
		for _, path in ipairs(pathsOf(entry)) do
			local known, default = defaultOf(path)
			if known and not compare(ui:GetConfig(path), default) then
				return true
			end
		end
		return false
	end

	local function baselineNote(entry)
		if not tracks(entry) or entry.isDefault then
			return nil
		end
		for _, path in ipairs(pathsOf(entry)) do
			local base = ui:GetBaselineConfig(path)
			if base ~= nil and not same(base, ui:GetFactoryConfig(path)) then
				local layoutValue, layoutName = ui.Movers.GetBaseLayoutValue(path)
				if layoutValue ~= nil and same(layoutValue, base) then
					return L['Set by the "%s" layout.']:format(layoutName)
				end
				return L["Kept from your previous FrostAtom UI version."]
			end
		end
	end

	changes.IsModified = isModified

	function changes.IsPreset(entry)
		return not isModified(entry) and baselineNote(entry) ~= nil
	end

	function changes.Reset(entry)
		PlaySound("igMainMenuOptionCheckBoxOff")
		if entry.reset then
			entry.reset()
			return
		elseif entry.type == "point" then
			ui.Movers.ResetPosition(entry.path)
			return
		end
		if entry.set then
			local _, default = defaultOf(entry.path)
			set(entry, type(default) == "table" and CopyTable(default) or default)
			return
		end
		set(entry, nil, function()
			for _, path in ipairs(pathsOf(entry)) do
				if defaultOf(path) then
					ui:ResetConfig(path)
				end
			end
		end)
	end

	local function optionText(values, value)
		for _, option in ipairs(optionsOf(values)) do
			if option[1] == value then
				return option[2]
			end
		end
	end

	function changes.DefaultText(entry)
		if entry.defaultText or not tracks(entry) or entry.isDefault then
			local text = entry.defaultText
			if type(text) == "function" then
				return text()
			end
			return text
		end
		local kind = entry.type
		if kind == "point" then
			return L['the "%s" layout']:format(ui.Movers.GetBaseLayoutName())
		elseif kind == "multiselect" then
			local names = {}
			for _, option in ipairs(optionsOf(entry.values)) do
				local _, value = defaultOf(entry.path .. "." .. option[1])
				if value then
					names[#names + 1] = option[2]
				end
			end
			return #names > 0 and table.concat(names, ", ") or L["None"]
		elseif kind == "font" then
			local _, size = defaultOf(entry.path .. ".size")
			local _, outline = defaultOf(entry.path .. ".outline")
			return ("%s, %s"):format(tostring(size), optionText(OUTLINES, outline or "") or "")
		elseif kind == "offset" then
			local _, x = defaultOf(entry.path)
			local _, y = defaultOf(entry.pathY)
			return ("X %s, Y %s"):format(tostring(x), tostring(y))
		end
		local _, value = defaultOf(entry.path)
		if kind == "toggle" then
			return value and L["On"] or L["Off"]
		elseif kind == "number" and type(value) == "number" then
			return formatValue(entry, value)
		elseif kind == "select" then
			return optionText(entry.values, value)
		elseif kind == "color" and type(value) == "table" then
			return ("%02x%02x%02x"):format(value[1] * 255, value[2] * 255, value[3] * 255)
		elseif kind == "string" and type(value) == "string" then
			return value == "" and L["(empty)"] or ('"%s"'):format(value)
		end
	end

	function changes.CreateDot(parent)
		local dot = createGlyph(parent, "circle", DOT_SIZE, CHANGED_COLOR)
		dot:Hide()
		return dot
	end

	function changes.Attach(row, entry)
		if not tracks(entry) then
			return
		end
		local dot = changes.CreateDot(row)
		dot:SetPoint("CENTER", row.label, "LEFT", -4, 0)
		row.changedDot = dot
		if not entry.reset and not entry.path then
			return
		end
		local title = entry.type == "point" and L["Move back"] or L["Reset to default"]
		local reset = ui.CreateGlyphButton(row, "rotate-left", GLYPH_SIZE, title)
		reset:SetPoint("RIGHT", -4, 0)
		reset:SetScript("OnClick", function()
			changes.Reset(entry)
		end)
		bindHighlight(reset, row)
		reset:Hide()
		row.resetButton = reset
	end

	function changes.Update(row, enabled)
		if not row.changedDot then
			return
		end
		local modified = isModified(row.entry)
		row.modified = modified
		row.baselineNote = not modified and baselineNote(row.entry) or nil
		local color = modified and CHANGED_COLOR or BASELINE_COLOR
		row.changedDot:SetTextColor(color.r, color.g, color.b)
		ui.SetShown(row.changedDot, modified or row.baselineNote ~= nil)
		local reset = row.resetButton
		if reset then
			ui.SetShown(reset, modified)
			setControlEnabled(reset, enabled)
			local text = modified and changes.DefaultText(row.entry)
			reset.tooltipText = text and L["Default: %s"]:format(text) or nil
		end
	end

	function changes.Validate(row, box, text, pending)
		local ok, message = true, nil
		if text and row.entry.validate then
			ok, message = row.entry.validate(text)
		end
		local problem
		if message then
			problem = {
				text = message,
				color = ok and NORMAL_FONT_COLOR or RED_FONT_COLOR,
				rejected = pending and not ok,
			}
		end
		row.problem = problem
		local glyph = box.problemGlyph
		if problem and not glyph then
			glyph = createGlyph(box, "circle-exclamation", GLYPH_SIZE, problem.color)
			glyph:SetPoint("RIGHT", -2, 0)
			box.problemGlyph = glyph
		end
		if glyph then
			if problem then
				glyph:SetTextColor(problem.color.r, problem.color.g, problem.color.b)
			end
			ui.SetShown(glyph, problem)
			box:SetTextInsets(0, problem and GLYPH_BOX or 0, 0, 0)
		end
		return ok and true or false
	end

	function changes.Count(schema, counted)
		local count, hidden = 0, false
		for _, entry in ipairs(schema or {}) do
			if entry.header then
				hidden = entry.hidden
			elseif not hidden and not entry.hidden and tracks(entry) then
				local key = entry.path or entry
				if not (counted and counted[key]) and isModified(entry) then
					count = count + 1
				end
				if counted then
					counted[key] = true
				end
			end
		end
		return count
	end

	local function countPage(page)
		local counted = {}
		local count = changes.Count(page.schema, counted)
		for _, tab in ipairs(page.tabs or {}) do
			count = count + changes.Count(tab.schema, counted)
		end
		for _, element in ipairs(elements) do
			if element.page == page.key and not element.hidden then
				count = count + changes.Count(element.schema, counted)
			end
		end
		return count
	end
	changes.CountPage = countPage

	function changes.PlaceNav(button)
		local reserved = 0
		local count = button.changedText
		if button.changedDot:IsShown() then
			reserved = count:GetStringWidth() + 2 + button.changedDot:GetStringWidth() + GLYPH_GAP
		end
		local badge = button.newBadge
		badge:ClearAllPoints()
		badge:SetPoint("RIGHT", -8 - reserved, 2)
		if badge:IsShown() then
			reserved = reserved + badge:GetStringWidth() + GLYPH_GAP
		end
		button.label:SetPoint("RIGHT", -8 - reserved, 2)
	end

	function changes.AttachNav(button)
		local count = button:CreateFontString(nil, "OVERLAY")
		count:SetFontObject(font("GameFontDisableSmall"))
		count:SetPoint("RIGHT", -8, 2)
		local dot = changes.CreateDot(button)
		dot:SetPoint("RIGHT", count, "LEFT", -2, 0)
		button.changedText = count
		button.changedDot = dot
	end

	function changes.UpdateNav()
		for _, page in ipairs(pages) do
			local button = page.button
			if button then
				local count = countPage(page)
				button.off = page.enable and ui:GetConfig(page.enable) == false or nil
				if button.off then
					button.changedText:SetText(L["off"])
					count = 0
				else
					button.changedText:SetText(count > 0 and count or "")
				end
				ui.SetShown(button.changedDot, count > 0)
				P.paintNavGlyph(button)
				changes.PlaceNav(button)
			end
		end
	end

	function changes.ScheduleNav()
		navToken = navToken + 1
		local token = navToken
		ui.After(NAV_DELAY, function()
			if token == navToken and P.frame and P.frame:IsShown() then
				changes.UpdateNav()
			end
		end)
	end
end

local function createSliderBox(row, entry, sliderWidth)
	local slider = ui.CreateSlider(row, sliderWidth, entry.min, entry.max, entry.step, nextName())
	slider:SetPoint("LEFT", CONTROL_X, 0)
	slider.low:SetText("")
	slider.high:SetText("")
	bindRow(slider, row)

	local box = createEditBox(row, P.unitOf(entry) and VALUE_BOX_WIDTH + 8 or VALUE_BOX_WIDTH, true)
	box:SetPoint("LEFT", slider, "RIGHT", 12, 0)
	bindRow(box, row)

	local function commit(value)
		set(entry, round(max(entry.min, min(entry.max, value)), entry.step))
	end

	slider:SetScript("OnValueChanged", function(_, value)
		if P.refreshing then
			return
		end
		if entry.applyOnRelease and IsMouseButtonDown("LeftButton") then
			box:SetText(formatValue(entry, round(value, entry.step)))
			return
		end
		commit(value)
	end)
	if entry.applyOnRelease then
		slider:SetScript("OnMouseUp", function(self)
			commit(self:GetValue())
		end)
	end
	slider:EnableMouseWheel(true)
	slider:SetScript("OnMouseWheel", function(self, delta)
		if IsShiftKeyDown() or box.editing then
			if self:IsEnabled() then
				commit(self:GetValue() + delta * entry.step)
			end
			return
		end
		forwardWheel(self, delta)
	end)
	box.OnCommit = function(self)
		local value = parseValue(entry, self:GetText())
		if value then
			commit(value)
		else
			row.Refresh()
		end
	end

	local function refresh()
		local value = get(entry)
		slider:SetValue(value)
		box:SetText(formatValue(entry, value))
		box:SetCursorPosition(0)
	end
	local function setEnabled(enabled)
		setControlEnabled(slider, enabled)
		local shade = enabled and 1 or 0.5
		slider:GetThumbTexture():SetVertexColor(shade, shade, shade)
		setEditBoxEnabled(box, enabled)
	end
	return box, refresh, setEnabled
end

P.createSliderBox = createSliderBox
P.set = set
