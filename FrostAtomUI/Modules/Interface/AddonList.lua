local ADDON_NAME, ns = ...

local L = ns.L

local GetNumAddOns, GetAddOnInfo, GetAddOnMetadata = GetNumAddOns, GetAddOnInfo, GetAddOnMetadata
local GetAddOnDependencies, IsAddOnLoaded, IsAddOnLoadOnDemand =
	GetAddOnDependencies, IsAddOnLoaded, IsAddOnLoadOnDemand
local EnableAddOn, DisableAddOn, EnableAllAddOns, LoadAddOn = EnableAddOn, DisableAddOn, EnableAllAddOns, LoadAddOn
local UpdateAddOnMemoryUsage, GetAddOnMemoryUsage = UpdateAddOnMemoryUsage, GetAddOnMemoryUsage
local UpdateAddOnCPUUsage, GetAddOnCPUUsage = UpdateAddOnCPUUsage, GetAddOnCPUUsage
local GetCVar, SetCVar, GetTime, PlaySound, ReloadUI = GetCVar, SetCVar, GetTime, PlaySound, ReloadUI
local FauxScrollFrame_Update = FauxScrollFrame_Update
local FauxScrollFrame_OnVerticalScroll = FauxScrollFrame_OnVerticalScroll
local FauxScrollFrame_GetOffset = FauxScrollFrame_GetOffset
local FauxScrollFrame_SetOffset = FauxScrollFrame_SetOffset
local UIDropDownMenu_Initialize, UIDropDownMenu_CreateInfo = UIDropDownMenu_Initialize, UIDropDownMenu_CreateInfo
local UIDropDownMenu_AddButton, ToggleDropDownMenu, CloseDropDownMenus =
	UIDropDownMenu_AddButton, ToggleDropDownMenu, CloseDropDownMenus
local GameTooltip = GameTooltip
local format, lower, gsub, find, strtrim = string.format, string.lower, string.gsub, string.find, strtrim
local tconcat, sort, max = table.concat, table.sort, math.max

local AddonList = ns:NewModule("AddonList")

local FRAME_NAME = "FrostAtomUIAddonList"
local WIDTH = 600
local INSET = ns.WINDOW_INSET
local INSET_PADDING = 4
local TOOLBAR_HEIGHT = 22
local SECTION_GAP = 8
local SEARCH_WIDTH = 160
local BUTTON_HEIGHT = 22
local BUTTON_GAP = 1
local BUTTON_PADDING = 24
local SCROLLBAR_WIDTH = 26
local ROW_HEIGHT = 24
local LIST_ROWS = 17
local PERFORMANCE_ROWS = 2
local PERFORMANCE_LINE = 20
local INDENT = 20
local CHECK_SIZE = 24
local CHECK_X = 5
local ARROW_X = 18
local ARROW_SIZE = 12
local TITLE_X = 32
local HIGHLIGHT_X = 40
local HIGHLIGHT_HEIGHT = 22
local STATUS_WIDTH = 170
local ICON_SIZE = 20
local TOOLTIP_X = -270
local TOOLTIP_REFRESH = 1
local MEMORY_INTERVAL = 15
local PERFORMANCE_INTERVAL = 1
local MAX_GROUP_DEPTH = 8
local QUESTION_MARK = "Interface\\Icons\\INV_Misc_QuestionMark"
local ALERT_MARKUP = "|TInterface\\DialogFrame\\UI-Dialog-Icon-AlertNew:16:16|t"
local LOADABLE_COLOR = { 1, 0.78, 0 }
local ERROR_COLOR = { 1, 0.1, 0.1 }
local DISABLED_COLOR = { 0.5, 0.5, 0.5 }
local OWN_PROBLEMS = {
	BANNED = true,
	CORRUPT = true,
	INCOMPATIBLE = true,
	INSECURE = true,
	INTERFACE_VERSION = true,
	MISSING = true,
}

local CONTENT_WIDTH = WIDTH - INSET.left - INSET.right
local LIST_WIDTH = CONTENT_WIDTH - INSET_PADDING * 2 - SCROLLBAR_WIDTH

local profiling = GetCVar("scriptProfile") == "1"
local sessionStart = GetTime()

local addons, sorted, byName, categories = {}, {}, {}, {}
local entries, entryCount = {}, 0
local matched, collapsed, blocked, loadProblems = {}, {}, {}, {}
local startEnabled, startOutOfDate = {}, {}
local startBlocked
local query = ""
local frame, menu, menuAddon, menuCategory
local saving, shouldReload
local lastMemoryUpdate
local cpuTotal, cpuTime, cpuPeak = 0, 0, 0
local refresh

local function metadata(index, field)
	local value = GetAddOnMetadata(index, field)
	value = value and strtrim(value)
	if value ~= "" then
		return value
	end
end

local function plainText(text)
	return (gsub(gsub(text, "|c%x%x%x%x%x%x%x%x", ""), "|r", ""))
end

local function nameStem(name)
	local stem = lower(name):match("^(.-)[%-_%. ]")
	if not stem or stem == "" then
		return lower(name)
	end
	return stem
end

local function groupRoot(addon)
	local root, steps = addon.parent, 0
	while root and root.parent and steps < MAX_GROUP_DEPTH do
		root, steps = root.parent, steps + 1
	end
	if root ~= addon and not (root and root.parent) then
		return root
	end
end

local function compareCategories(a, b)
	return a.key < b.key
end

local function compareAddons(a, b)
	if a.searchTitle ~= b.searchTitle then
		return a.searchTitle < b.searchTitle
	end
	return a.index < b.index
end

local function readAddons()
	for i = 1, GetNumAddOns() do
		local name, title, notes, _, _, _, security = GetAddOnInfo(i)
		title = title or name
		local category = metadata(i, "X-Category")
		local icon = metadata(i, "X-IconTexture") or QUESTION_MARK
		addons[i] = {
			index = i,
			name = name,
			title = title,
			notes = notes,
			security = security,
			version = metadata(i, "Version") or "",
			category = category,
			label = format("|T%s:%d:%d|t %s", icon, ICON_SIZE, ICON_SIZE, title),
			deps = { GetAddOnDependencies(i) },
			stem = nameStem(name),
			children = {},
			searchTitle = ns.Lower(plainText(title)),
			searchCategory = category and ns.Lower(category),
		}
		byName[lower(name)] = addons[i]
		sorted[i] = addons[i]
	end
	sort(sorted, compareAddons)

	for i = 1, #sorted do
		local addon = sorted[i]
		local name, deps = lower(addon.name), addon.deps
		for j = 1, #deps do
			local parent = byName[lower(deps[j])]
			if parent and parent ~= addon and name:sub(1, #parent.stem) == parent.stem then
				addon.parent = parent
				break
			end
		end
	end

	local byCategory = {}
	for i = 1, #sorted do
		local addon = sorted[i]
		local root = groupRoot(addon)
		addon.root = root
		addon.searchGroup = lower((root or addon).name)
		if root then
			root.children[#root.children + 1] = addon
		elseif addon.category then
			local category = byCategory[addon.category]
			if not category then
				category = { name = addon.category, key = ns.Lower(addon.category), addons = {} }
				byCategory[addon.category] = category
				categories[#categories + 1] = category
			end
			category.addons[#category.addons + 1] = addon
			addon.bucket = category
		end
	end
	sort(categories, compareCategories)
end

local function rawState(index)
	local _, _, _, enabled, loadable, reason = GetAddOnInfo(index)
	return not not enabled, loadable, reason
end

local function loadProblem(addon)
	local index = addon.index
	local problem = loadProblems[index]
	if problem ~= nil then
		return problem
	end
	loadProblems[index] = false
	local enabled, _, reason = rawState(index)
	if not enabled then
		problem = "DISABLED"
	elseif OWN_PROBLEMS[reason] then
		problem = reason
	else
		problem = false
		local deps = addon.deps
		for i = 1, #deps do
			local dependency = byName[lower(deps[i])]
			local dependencyProblem = not dependency and "MISSING" or loadProblem(dependency)
			if dependencyProblem then
				problem = find(dependencyProblem, "^DEP_") and dependencyProblem or "DEP_" .. dependencyProblem
				break
			end
		end
	end
	loadProblems[index] = problem
	return problem
end

local function addonState(addon)
	local problem = loadProblem(addon)
	return (rawState(addon.index)), not problem, problem or nil
end

local function versionCheck()
	return GetCVar("checkAddonVersion") == "1"
end

local function hasOutOfDate()
	for i = 1, GetNumAddOns() do
		local enabled, loadable, reason = rawState(i)
		if enabled and not loadable and reason == "INTERFACE_VERSION" then
			return true
		end
	end
	return false
end

local function captureStart()
	for i = 1, GetNumAddOns() do
		local enabled, _, reason = rawState(i)
		startEnabled[i] = enabled
		startOutOfDate[i] = reason == "INTERFACE_VERSION"
	end
	startBlocked = versionCheck() and hasOutOfDate()
end

local function hasChanges()
	local check = versionCheck()
	if startBlocked and not check or not startBlocked and check and hasOutOfDate() then
		return true
	end
	for i = 1, #addons do
		local enabled, _, reason = addonState(addons[i])
		if enabled ~= startEnabled[i] and reason ~= "DEP_DISABLED" then
			return true
		end
	end
	return false
end

local function setEnabled(index, enabled)
	if enabled then
		EnableAddOn(index)
	else
		DisableAddOn(index)
	end
end

local function revert()
	for i = 1, #addons do
		if rawState(i) ~= startEnabled[i] then
			setEnabled(i, startEnabled[i])
		end
	end
end

local function setGroupEnabled(addon, enabled)
	setEnabled(addon.index, enabled)
	local children = addon.children
	for i = 1, #children do
		setEnabled(children[i].index, enabled)
	end
end

local function enableWithDependencies(addon, visited)
	visited[addon] = true
	local deps = addon.deps
	for i = 1, #deps do
		local dep = byName[lower(deps[i])]
		if dep and not visited[dep] then
			enableWithDependencies(dep, visited)
		end
	end
	EnableAddOn(addon.index)
end

local function isOwnAddon(addon)
	return addon.name == ADDON_NAME or addon.root ~= nil and addon.root.name == ADDON_NAME
end

local function canLoadNow(addon)
	if not IsAddOnLoadOnDemand(addon.index) then
		return false
	end
	local deps = addon.deps
	for i = 1, #deps do
		if not IsAddOnLoaded(deps[i]) then
			return false
		end
	end
	return true
end

local function formatPercent(percent)
	if percent >= 1 then
		return format("%.0f%%", percent)
	elseif percent >= 0.1 then
		return format("%.1f%%", percent)
	elseif percent >= 0.01 then
		return format("%.2f%%", percent)
	end
	return "0%"
end

local function sessionMilliseconds()
	return max(GetTime() - sessionStart, 1) * 1000
end

local function totalCPU()
	UpdateAddOnCPUUsage()
	local total = 0
	for i = 1, #addons do
		total = total + GetAddOnCPUUsage(i)
	end
	return total
end

local function updatePerformance()
	local now, total = GetTime(), totalCPU()
	local current = 0
	if now > cpuTime then
		current = (total - cpuTotal) / ((now - cpuTime) * 1000) * 100
	end
	cpuTotal, cpuTime = total, now
	cpuPeak = max(cpuPeak, current)
	local performance = frame.performance
	performance.current:SetFormattedText(L["Current CPU: %s"], formatPercent(current))
	performance.average:SetFormattedText(L["Average CPU: %s"], formatPercent(total / sessionMilliseconds() * 100))
	performance.peak:SetFormattedText(L["Peak CPU: %s"], formatPercent(cpuPeak))
end

local function onFrameUpdate(self, elapsed)
	local left = self.untilPerformance - elapsed
	if left > 0 then
		self.untilPerformance = left
		return
	end
	self.untilPerformance = PERFORMANCE_INTERVAL
	updatePerformance()
end

local function updateMemoryUsage()
	local now = GetTime()
	if not lastMemoryUpdate or now > lastMemoryUpdate + MEMORY_INTERVAL then
		lastMemoryUpdate = now
		UpdateAddOnMemoryUsage()
	end
end

local function fillTooltip(addon)
	local index = addon.index
	GameTooltip:ClearLines()
	if addon.security == "BANNED" then
		GameTooltip:SetText(L["This addon has been disabled. You should install an updated version."])
	else
		GameTooltip:AddDoubleLine(addon.title, addon.version)
		if addon.notes then
			GameTooltip:AddLine(addon.notes, 1, 1, 1, true)
		end
		if #addon.deps > 0 then
			local text, color = format(L["Dependencies: %s"], tconcat(addon.deps, ", ")), NORMAL_FONT_COLOR
			GameTooltip:AddLine(text, color.r, color.g, color.b, true)
		end
	end
	local failures = blocked[addon.name]
	if failures then
		GameTooltip:AddLine(format(L["Interface actions failed because of this AddOn: %d"], failures))
	end
	if IsAddOnLoaded(index) then
		local memory = GetAddOnMemoryUsage(index)
		if profiling or memory > 0 then
			GameTooltip:AddLine(" ")
		end
		if profiling then
			UpdateAddOnCPUUsage()
			local average = GetAddOnCPUUsage(index) / sessionMilliseconds() * 100
			GameTooltip:AddLine(format(L["Average CPU: %s"], formatPercent(average)), 1, 1, 1)
		end
		if memory > 1024 then
			GameTooltip:AddLine(format(L["Memory Usage: %d MB"], memory / 1024), 1, 1, 1)
		elseif memory > 0 then
			GameTooltip:AddLine(format(L["Memory Usage: %d KB"], memory), 1, 1, 1)
		end
	end
	GameTooltip:Show()
end

local function addEntry(addon, category, depth)
	entryCount = entryCount + 1
	local entry = entries[entryCount]
	if not entry then
		entry = {}
		entries[entryCount] = entry
	end
	entry.addon, entry.category, entry.depth = addon, category, depth
end

local function addGroup(addon, depth)
	addEntry(addon, nil, depth)
	local children = addon.children
	for i = 1, #children do
		local child = children[i]
		if matched[child.index] then
			addEntry(child, nil, depth + 1)
		end
	end
end

local function matches(addon)
	return query == ""
		or find(addon.searchTitle, query, 1, true) ~= nil
		or find(addon.searchGroup, query, 1, true) ~= nil
		or addon.searchCategory ~= nil and find(addon.searchCategory, query, 1, true) ~= nil
end

local function firstMatch(list)
	for i = 1, #list do
		if matched[list[i].index] then
			return i
		end
	end
end

local function buildEntries()
	entryCount = 0
	for i = 1, #addons do
		matched[i] = matches(addons[i])
	end
	for i = 1, #categories do
		local category = categories[i]
		local members = category.addons
		local first = firstMatch(members)
		if first then
			addEntry(nil, category, 0)
			if not collapsed[category.name] then
				for j = first, #members do
					if matched[members[j].index] then
						addGroup(members[j], 1)
					end
				end
			end
		end
	end
	for i = 1, #sorted do
		local addon = sorted[i]
		if matched[addon.index] then
			local root = addon.root
			if not root and not addon.bucket then
				addGroup(addon, 0)
			elseif root and not matched[root.index] then
				addEntry(addon, nil, 0)
			end
		end
	end
end

local function indentRow(row, depth)
	local indent = depth * INDENT
	if row.indent == indent then
		return
	end
	row.indent = indent
	row.check:SetPoint("LEFT", indent + CHECK_X, 0)
	row.arrow:SetPoint("CENTER", row, "LEFT", indent + ARROW_X, 0)
	row.title:SetPoint("LEFT", indent + TITLE_X, 0)
	row.highlight:SetPoint("LEFT", indent + HIGHLIGHT_X, 0)
end

local function setStatus(row, load, status, reload)
	ns.SetShown(row.load, load)
	ns.SetShown(row.status, status)
	ns.SetShown(row.reload, reload)
end

local function fillCategoryRow(row, category)
	row.addon, row.category = nil, category
	row.check:Hide()
	setStatus(row, false, false, false)
	ns.SetGlyph(row.arrow, collapsed[category.name] and "caret-right" or "caret-down")
	row.arrow:Show()
	row.title:SetText(category.name)
	row.title:SetTextColor(NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b)
end

local function fillAddonRow(row, addon)
	local index = addon.index
	local enabled, loadable, reason = addonState(addon)
	row.addon, row.category = addon, nil
	row.arrow:Hide()
	row.check:SetChecked(enabled)
	row.check:Show()

	local color = DISABLED_COLOR
	if loadable or enabled and (reason == "DEP_DEMAND_LOADED" or reason == "DEMAND_LOADED") then
		color = LOADABLE_COLOR
	elseif enabled and reason ~= "DEP_DISABLED" then
		color = ERROR_COLOR
	end
	row.title:SetTextColor(color[1], color[2], color[3])
	row.title:SetText(blocked[addon.name] and addon.label .. ALERT_MARKUP or addon.label)
	row.status:SetText(not loadable and reason and (_G["ADDON_" .. reason] or reason) or "")

	local changed = enabled ~= startEnabled[index] and reason ~= "DEP_DISABLED"
		or reason ~= "INTERFACE_VERSION" and startOutOfDate[index]
		or reason == "INTERFACE_VERSION" and not startOutOfDate[index]
	if not changed then
		setStatus(row, false, true, false)
	elseif enabled and canLoadNow(addon) then
		setStatus(row, true, false, false)
	else
		setStatus(row, false, false, true)
	end
end

local function refreshList()
	local rows = frame.rows
	local shown = #rows
	local offset = FauxScrollFrame_GetOffset(frame.scroll)
	local maxOffset = max(entryCount - shown, 0)
	if offset > maxOffset then
		offset = maxOffset
		FauxScrollFrame_SetOffset(frame.scroll, offset)
	end
	for i = 1, shown do
		local row = rows[i]
		local owned = GameTooltip:IsOwned(row)
		if i + offset <= entryCount then
			local entry = entries[i + offset]
			indentRow(row, entry.depth)
			if entry.category then
				fillCategoryRow(row, entry.category)
			else
				fillAddonRow(row, entry.addon)
			end
			row:Show()
			if owned then
				if row.addon then
					fillTooltip(row.addon)
				else
					GameTooltip:Hide()
				end
			end
		else
			row:Hide()
			if owned then
				GameTooltip:Hide()
			end
		end
	end
	FauxScrollFrame_Update(frame.scroll, entryCount, shown, ROW_HEIGHT)
end

function refresh()
	if not frame or not frame:IsShown() then
		return
	end
	wipe(loadProblems)
	buildEntries()
	refreshList()
	shouldReload = hasChanges()
	frame.okay:SetText(shouldReload and L["Reload UI"] or OKAY)
	ns.FitButton(frame.okay, BUTTON_PADDING, frame.okay.minWidth)
end

local function onRowUpdate(row, elapsed)
	local left = row.untilRefresh - elapsed
	if left > 0 then
		row.untilRefresh = left
		return
	end
	row.untilRefresh = TOOLTIP_REFRESH
	if row.addon and GameTooltip:IsOwned(row) then
		fillTooltip(row.addon)
	end
end

local function onRowEnter(row)
	if not row.addon then
		return
	end
	updateMemoryUsage()
	GameTooltip:SetOwner(row, "ANCHOR_RIGHT", TOOLTIP_X, 0)
	fillTooltip(row.addon)
	row.untilRefresh = TOOLTIP_REFRESH
	row:SetScript("OnUpdate", onRowUpdate)
end

local function onRowLeave(row)
	row:SetScript("OnUpdate", nil)
	GameTooltip:Hide()
end

local function onRowClick(row, button)
	if button == "RightButton" then
		menuAddon, menuCategory = row.addon, row.category
		CloseDropDownMenus()
		ToggleDropDownMenu(1, nil, menu, "cursor")
	elseif row.category then
		local name = row.category.name
		collapsed[name] = not collapsed[name] or nil
		refresh()
	else
		row.check:Click()
	end
end

local function onCheckClick(check)
	setEnabled(check:GetParent().addon.index, check:GetChecked())
	refresh()
end

local function onLoadClick(button)
	local addon = button:GetParent().addon
	if not canLoadNow(addon) then
		return
	end
	LoadAddOn(addon.index)
	if IsAddOnLoaded(addon.index) then
		startEnabled[addon.index] = true
	end
	refresh()
end

local function createRow(parent, index)
	local row = CreateFrame("Button", nil, parent)
	row:SetHeight(ROW_HEIGHT)
	row:SetPoint("TOPLEFT", 0, -(index - 1) * ROW_HEIGHT)
	row:SetPoint("RIGHT")
	row:RegisterForClicks("LeftButtonUp", "RightButtonUp")

	local highlight = ns.AddHighlight(row)
	highlight:ClearAllPoints()
	highlight:SetPoint("RIGHT")
	highlight:SetHeight(HIGHLIGHT_HEIGHT)
	row.highlight = highlight

	local check = ns.CreateCheckButton(row)
	check:SetSize(CHECK_SIZE, CHECK_SIZE)
	check:SetScript("OnClick", onCheckClick)
	row.check = check

	local arrow = ns.CreateGlyph(row, "caret-down", ARROW_SIZE, "ARTWORK")
	arrow:SetTextColor(NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b)
	row.arrow = arrow

	local title = row:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	title:SetPoint("RIGHT", -STATUS_WIDTH, 0)
	title:SetHeight(ICON_SIZE)
	title:SetJustifyH("LEFT")
	row.title = title

	local status = row:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
	status:SetPoint("RIGHT", -INSET_PADDING, 0)
	status:SetSize(STATUS_WIDTH - INSET_PADDING * 2, ICON_SIZE)
	status:SetJustifyH("RIGHT")
	row.status = status

	local reload = row:CreateFontString(nil, "ARTWORK", "GameFontRed")
	reload:SetPoint("RIGHT", -INSET_PADDING, 0)
	reload:SetText(L["Requires Reload"])
	row.reload = reload

	local load = ns.CreateButton(row, L["Load AddOn"], 100, BUTTON_HEIGHT)
	ns.FitButton(load, BUTTON_PADDING, 100)
	load:SetPoint("RIGHT", -INSET_PADDING, 0)
	load:SetScript("OnClick", onLoadClick)
	load:Hide()
	row.load = load

	indentRow(row, 0)
	row:SetScript("OnClick", onRowClick)
	row:SetScript("OnEnter", onRowEnter)
	row:SetScript("OnLeave", onRowLeave)
	return row
end

local function addMenuButton(text, func, isTitle)
	local info = UIDropDownMenu_CreateInfo()
	info.text, info.func, info.isTitle, info.notCheckable = text, func, isTitle, true
	UIDropDownMenu_AddButton(info)
end

local function setMenuTargetEnabled(enabled)
	if menuCategory then
		local members = menuCategory.addons
		for i = 1, #members do
			setGroupEnabled(members[i], enabled)
		end
	else
		setGroupEnabled(menuAddon, enabled)
	end
	PlaySound(enabled and "igMainMenuOptionCheckBoxOn" or "igMainMenuOptionCheckBoxOff")
	refresh()
end

local function enableMenuTarget()
	setMenuTargetEnabled(true)
end

local function disableMenuTarget()
	setMenuTargetEnabled(false)
end

local function enableMenuDependencies()
	enableWithDependencies(menuAddon, {})
	PlaySound("igMainMenuOptionCheckBoxOn")
	refresh()
end

local function initMenu()
	if not menuAddon and not menuCategory then
		return
	end
	addMenuButton(menuCategory and menuCategory.name or menuAddon.title, nil, true)
	if menuAddon then
		addMenuButton(L["Enable All Dependencies"], enableMenuDependencies)
	end
	if menuCategory or #menuAddon.children > 0 then
		addMenuButton(menuCategory and L["Enable All AddOns"] or L["Enable AddOn Group"], enableMenuTarget)
		addMenuButton(menuCategory and L["Disable All AddOns"] or L["Disable AddOn Group"], disableMenuTarget)
	end
end

local function resetScroll()
	FauxScrollFrame_SetOffset(frame.scroll, 0)
	frame.scrollBar:SetValue(0)
end

local function onSearchChanged(box)
	local text = ns.Lower(strtrim(box:GetText()))
	if text ~= query then
		query = text
		resetScroll()
		refresh()
	end
end

local function onSearchEscape(box)
	box:SetText("")
	box:ClearFocus()
end

local function onForceLoadClick(check)
	SetCVar("checkAddonVersion", check:GetChecked() and "0" or "1")
	refresh()
end

local function onEnableAll()
	EnableAllAddOns()
	refresh()
end

local function onDisableAll()
	for i = 1, #addons do
		if not isOwnAddon(addons[i]) then
			DisableAddOn(i)
		end
	end
	refresh()
end

local function onOkay()
	PlaySound("gsLoginChangeRealmOK")
	saving = true
	frame:Hide()
	if shouldReload then
		ReloadUI()
	end
end

local function onCancel()
	PlaySound("gsLoginChangeRealmCancel")
	frame:Hide()
end

local function onShow()
	frame.forceLoad:SetChecked(not versionCheck())
	refresh()
	if profiling then
		cpuTotal, cpuTime = totalCPU(), GetTime()
		frame.untilPerformance = PERFORMANCE_INTERVAL
		updatePerformance()
	end
end

local function onHide()
	frame.search:ClearFocus()
	if UIDROPDOWNMENU_OPEN_MENU == menu then
		CloseDropDownMenus()
	end
	if not saving then
		revert()
	end
	saving = false
end

local function createButton(text, minWidth)
	local button = ns.CreateButton(frame, text, minWidth, BUTTON_HEIGHT)
	button.minWidth = minWidth
	ns.FitButton(button, BUTTON_PADDING, minWidth)
	return button
end

local function createPerformance(top)
	local performance = CreateFrame("Frame", nil, frame)
	performance:SetPoint("TOPLEFT", INSET.left + INSET_PADDING, -top)
	performance:SetSize(CONTENT_WIDTH - INSET_PADDING * 2, PERFORMANCE_ROWS * ROW_HEIGHT)

	local header = performance:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	header:SetPoint("TOPLEFT")
	header:SetText(L["AddOn Usage"])

	local function readout(point)
		local text = performance:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
		text:SetPoint(point, 0, -PERFORMANCE_LINE)
		return text
	end
	performance.current = readout("TOPLEFT")
	performance.average = readout("TOP")
	performance.peak = readout("TOPRIGHT")
	frame.performance = performance
	frame:SetScript("OnUpdate", onFrameUpdate)
end

local function createFrame()
	frame = ns.CreateWindow(FRAME_NAME, { width = WIDTH, title = L["AddOn List"], movable = false })
	frame:SetPoint("CENTER", 0, 24)
	frame:SetScript("OnShow", onShow)
	frame:SetScript("OnHide", onHide)

	local toolbarY = -(INSET.top + TOOLBAR_HEIGHT / 2)
	local forceLoad = ns.CreateCheckButton(frame)
	forceLoad.text:SetFontObject(GameFontNormalSmall)
	forceLoad:SetLabel(L["Load out of date AddOns"])
	forceLoad:SetPoint("LEFT", frame, "TOPLEFT", INSET.left, toolbarY)
	forceLoad:SetScript("OnClick", onForceLoadClick)
	frame.forceLoad = forceLoad

	local search = ns.CreateEditBox(frame, SEARCH_WIDTH, 20, FRAME_NAME .. "Search", L["Search"])
	search:SetPoint("RIGHT", frame, "TOPRIGHT", -(INSET.right + INSET_PADDING), toolbarY)
	search.placeholder:SetFontObject(GameFontDisableSmall)
	search:HookScript("OnTextChanged", onSearchChanged)
	search:SetScript("OnEscapePressed", onSearchEscape)
	search:SetScript("OnEnterPressed", search.ClearFocus)
	frame.search = search

	local listTop = INSET.top + TOOLBAR_HEIGHT + SECTION_GAP
	local rowCount = LIST_ROWS
	if profiling then
		createPerformance(listTop)
		listTop = listTop + PERFORMANCE_ROWS * ROW_HEIGHT
		rowCount = rowCount - PERFORMANCE_ROWS
	end

	local listHeight = rowCount * ROW_HEIGHT
	local listInset = ns.CreateInset(frame, "tooltip")
	listInset:SetPoint("TOPLEFT", INSET.left, -listTop)
	listInset:SetSize(CONTENT_WIDTH, listHeight + INSET_PADDING * 2)

	local list = CreateFrame("Frame", nil, listInset)
	list:SetPoint("TOPLEFT", INSET_PADDING, -INSET_PADDING)
	list:SetSize(LIST_WIDTH, listHeight)

	local scroll = ns.CreateFauxScrollFrame(list, FRAME_NAME .. "Scroll", true)
	scroll:SetAllPoints()
	scroll:SetScript("OnVerticalScroll", function(self, offset)
		FauxScrollFrame_OnVerticalScroll(self, offset, ROW_HEIGHT, refreshList)
	end)
	frame.scroll = scroll
	frame.scrollBar = scroll.scrollBar

	local rows = {}
	for i = 1, rowCount do
		rows[i] = createRow(list, i)
	end
	frame.rows = rows

	local enableAll = createButton(L["Enable All"], 120)
	enableAll:SetPoint("BOTTOMLEFT", INSET.left, INSET.bottom)
	enableAll:SetScript("OnClick", onEnableAll)

	local disableAll = createButton(L["Disable All"], 120)
	disableAll:SetPoint("LEFT", enableAll, "RIGHT", BUTTON_GAP, 0)
	disableAll:SetScript("OnClick", onDisableAll)

	local cancel = createButton(CANCEL, 80)
	cancel:SetPoint("BOTTOMRIGHT", -INSET.right, INSET.bottom)
	cancel:SetScript("OnClick", onCancel)

	local okay = createButton(OKAY, 80)
	okay:SetPoint("RIGHT", cancel, "LEFT", -BUTTON_GAP, 0)
	okay:SetScript("OnClick", onOkay)
	frame.okay = okay

	frame:SetHeight(listTop + listInset:GetHeight() + SECTION_GAP + BUTTON_HEIGHT + INSET.bottom)

	menu = CreateFrame("Frame", FRAME_NAME .. "Menu", UIParent, "UIDropDownMenuTemplate")
	UIDropDownMenu_Initialize(menu, initMenu, "MENU")
end

local function show()
	if not frame then
		readAddons()
		createFrame()
	end
	frame:Show()
end

local function onActionBlocked(_, addon)
	if addon then
		blocked[addon] = (blocked[addon] or 0) + 1
		refresh()
	end
end

AddonList:RegisterEvent("ADDON_ACTION_BLOCKED", onActionBlocked)
AddonList:RegisterEvent("ADDON_ACTION_FORBIDDEN", onActionBlocked)

AddonList:RegisterEvent("ADDON_LOADED", function(_, name)
	for i = 1, #startEnabled do
		if GetAddOnInfo(i) == name then
			startEnabled[i] = true
			refresh()
			return
		end
	end
end)

AddonList:OnInitialize(captureStart)

local MENU_BUTTON_TEMPLATE = "GameMenuButtonTemplate,SecureActionButtonTemplate"
local menuButton = CreateFrame("Button", "FrostAtomUIAddonsMenuButton", GameMenuFrame, MENU_BUTTON_TEMPLATE)
menuButton:SetText(ADDONS)
menuButton:SetPoint("TOP", FrostAtomUIMenuButton, "BOTTOM", 0, -1)
-- FrameXML: hiding the game menu from addon code taints it; a secure click on Continue closes it cleanly
menuButton:SetAttribute("type", "click")
menuButton:SetAttribute("clickbutton", GameMenuButtonContinue)
menuButton:SetScript("PostClick", show)

GameMenuButtonKeybindings:SetPoint("TOP", menuButton, "BOTTOM", 0, -1)
GameMenuFrame:SetHeight(GameMenuFrame:GetHeight() + menuButton:GetHeight() + 1)
