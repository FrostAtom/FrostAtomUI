local _, ns = ...

local ui = FrostAtomUI
local L = ui.L

local tinsert = tinsert

local P = ns.private
local INLINE_FLAT_CONTROLS = P.INLINE_FLAT_CONTROLS
local POPUP_STRATA = P.POPUP_STRATA
local adoptEntries = P.adoptEntries
local elementButton = P.elementButton
local elementFor = P.elementFor
local elements = P.elements
local pages = P.pages

local function listsElement(view, element)
	local tab = view.tab
	if not tab then
		return element.tab == nil
	end
	return element.tab == tab.key or tab.elements == "all" or (tab.elements == "untabbed" and element.tab == nil)
end

local function copyWith(entry, key, value)
	local copy = {}
	for k, v in pairs(entry) do
		copy[k] = v
	end
	copy[key] = value
	return copy
end

local function inlineSchema(element, enabledBy)
	if element.inline then
		return element.inline
	end
	local inline = {}
	local first = element.schema[1]
	local title = {
		header = element.name,
		glyph = element.glyph,
		new = element.new,
		element = element,
		keep = true,
		page = element,
		enabledBy = enabledBy,
	}
	if first and first.header then
		title.advanced, title.hidden = first.advanced, first.hidden
		title.toggles, title.toggleDesc = first.toggles, first.toggleDesc
	end
	inline[1] = title
	local controls = 0
	for _, entry in ipairs(element.schema) do
		if entry.path or entry.type then
			controls = controls + 1
		end
	end
	local flat = controls <= INLINE_FLAT_CONTROLS
	local advanced = title.advanced
	if flat then
		title.advanced = nil
	end
	for index, entry in ipairs(element.schema) do
		if flat and entry.header then
			advanced = entry.advanced
		elseif flat and advanced and not entry.advanced then
			inline[#inline + 1] = copyWith(entry, "advanced", true)
		elseif not entry.header then
			inline[#inline + 1] = entry
		elseif index > 1 then
			inline[#inline + 1] = copyWith(entry, "header", element.name .. ": " .. entry.header)
		end
	end
	element.inline = inline
	return inline
end

function ns.InlineElement(path, name)
	local inline = inlineSchema(elementFor(path))
	if name then
		inline[1].header = name
	end
	return inline
end

local aliasIndex
local aliasCopies = setmetatable({}, { __mode = "k" })

local function canonicalEntry(path)
	if not aliasIndex then
		aliasIndex = {}
		local function scan(schema, place)
			for _, entry in ipairs(schema or {}) do
				if entry.path and not entry.header and not entry.hidden and not aliasIndex[entry.path] then
					aliasIndex[entry.path] = { entry = entry, place = place }
				end
			end
		end
		for _, page in ipairs(pages) do
			scan(page.schema, page.name)
			for _, tab in ipairs(page.tabs or {}) do
				scan(tab.schema, P.placeName(page, tab))
			end
		end
	end
	return aliasIndex[path]
end

local function resolveAlias(placeholder)
	local copy = aliasCopies[placeholder]
	if copy then
		return copy
	end
	local found = canonicalEntry(placeholder.alias)
	if not found then
		return nil
	end
	copy = {}
	for key, value in pairs(found.entry) do
		copy[key] = value
	end
	for key, value in pairs(placeholder) do
		if key ~= "alias" then
			copy[key] = value
		end
	end
	copy.aliasPlace = found.place
	aliasCopies[placeholder] = copy
	return copy
end

local function expandSchema(page)
	local schema = {}
	local owner = page.owner or page
	local source = page.schema
	if page.buildSchema then
		source = page.buildSchema()
		page.lastSignature = page.signature()
		adoptEntries(source, owner, page.tab and page.tab.key)
	end
	local listed, headers = {}, {}
	for _, entry in ipairs(source) do
		if entry.path then
			listed[entry.path] = true
		elseif entry.header then
			headers[entry.header] = entry
		end
	end
	local placed, attached = {}, {}
	for _, entry in ipairs(source) do
		if entry.type == "elements" then
			local list, buttons = {}, 0
			for _, element in ipairs(elements) do
				if element.page == owner.key and not element.hidden and listsElement(page, element) then
					local inline = inlineSchema(element, entry.enabledBy)
					local rest, controls = {}, false
					for i = 2, #inline do
						local inlined = inline[i]
						if not (inlined.path and listed[inlined.path]) then
							rest[#rest + 1] = inlined
							controls = controls or not inlined.header and not inlined.description
							if inlined.path then
								listed[inlined.path] = true
							end
						end
					end
					local header = headers[element.name]
					if header then
						header.element = element
						attached[header] = rest
					elseif controls then
						list[#list + 1] = inline[1]
						for _, inlined in ipairs(rest) do
							list[#list + 1] = inlined
						end
					else
						buttons = buttons + 1
						tinsert(list, buttons, elementButton(element, owner, entry.enabledBy))
					end
				end
			end
			placed[entry] = list
		end
	end
	local pending
	local function flush()
		for _, inlined in ipairs(pending or {}) do
			schema[#schema + 1] = inlined
		end
		pending = nil
	end
	for _, entry in ipairs(source) do
		if entry.header or placed[entry] then
			flush()
		end
		if placed[entry] then
			for _, inlined in ipairs(placed[entry]) do
				schema[#schema + 1] = inlined
			end
		elseif entry.alias then
			schema[#schema + 1] = resolveAlias(entry)
		else
			schema[#schema + 1] = entry
			pending = attached[entry] or pending
		end
	end
	flush()
	return schema
end

local confirmAction

StaticPopupDialogs["FROSTATOMUI_CONFIG_CONFIRM"] = {
	text = "%s",
	button1 = YES,
	button2 = NO,
	OnAccept = function()
		confirmAction()
	end,
	OnHide = function(dialog)
		dialog:SetFrameStrata("DIALOG")
	end,
	timeout = 0,
	whileDead = 1,
	hideOnEscape = 1,
	preferredIndex = 3,
}

function ns.Confirm(text, action)
	confirmAction = action
	local dialog = StaticPopup_Show("FROSTATOMUI_CONFIG_CONFIRM", text)
	if dialog then
		dialog:SetFrameStrata(POPUP_STRATA)
	end
end

local function isEnabledBy(enabledBy)
	if type(enabledBy) == "table" then
		for i = 1, #enabledBy do
			if not isEnabledBy(enabledBy[i]) then
				return false
			end
		end
		return true
	end
	return ui:GetConfig(enabledBy) and true or false
end

local function isEnabledByAny(paths)
	for i = 1, #paths do
		if ui:GetConfig(paths[i]) then
			return true
		end
	end
	return false
end

local pageByKey, isEntryEnabled

do
	local function listPaths(paths, list)
		list = list or {}
		if type(paths) == "table" then
			for i = 1, #paths do
				listPaths(paths[i], list)
			end
		elseif paths then
			list[#list + 1] = paths
		end
		return list
	end

	local function contains(list, value)
		for i = 1, #list do
			if list[i] == value then
				return true
			end
		end
		return false
	end

	function pageByKey(key)
		for _, page in ipairs(pages) do
			if page.key == key then
				return page
			end
		end
	end

	local NO_REQUIREMENTS = {}
	local SHARED_SECTIONS = { theme = true, castbar = true }

	local requirementCache = setmetatable({}, { __mode = "k" })

	local function computeRequirements(entry)
		local owner = entry.page
		local section = type(entry.path) == "string" and entry.path:match("^[^.]+")
		if not owner or owner.element or SHARED_SECTIONS[section] then
			return NO_REQUIREMENTS
		end
		local paths = {}
		if owner.enable then
			paths[1] = owner.enable
		elseif owner.path and owner.key == "element:" .. owner.path then
			local page = pageByKey(owner.page)
			if page and page.enable then
				paths[1] = page.enable
			end
			listPaths(owner.enabledBy, paths)
		end
		local result = {}
		for i = 1, #paths do
			if paths[i] ~= entry.path and not contains(result, paths[i]) then
				result[#result + 1] = paths[i]
			end
		end
		return result
	end

	local function ownerRequirements(entry)
		local cached = requirementCache[entry]
		if not cached or cached.owner ~= entry.page then
			cached = { owner = entry.page, result = computeRequirements(entry) }
			requirementCache[entry] = cached
		end
		return cached.result
	end

	function isEntryEnabled(entry)
		if entry.disabled and entry.disabled() then
			return false
		end
		if entry.enabledBy and not isEnabledBy(entry.enabledBy) then
			return false
		end
		if entry.enabledByAny and not isEnabledByAny(entry.enabledByAny) then
			return false
		end
		local owner = ownerRequirements(entry)
		return #owner == 0 or isEnabledBy(owner)
	end

	local pathOwners

	function P.placeName(page, tab)
		return L["%s › %s"]:format(page.name, tab.name)
	end

	local function indexSchema(schema, pageName)
		local header
		for _, entry in ipairs(schema) do
			if entry.header then
				header = entry.header
			elseif entry.type == "multiselect" and entry.path then
				for _, option in ipairs(entry.values) do
					local path = entry.path .. "." .. option[1]
					if not pathOwners[path] then
						pathOwners[path] = { name = ("%s: %s"):format(entry.label, option[2]), page = pageName }
					end
				end
			elseif entry.path and entry.label and not pathOwners[entry.path] then
				local name = entry.label
				if name == L["Enable"] or name == L["Show"] then
					name = header or pageName
				end
				pathOwners[entry.path] = { name = name, page = pageName }
			end
		end
	end

	local function pathName(path, entry)
		if not pathOwners then
			pathOwners = {}
			for _, page in ipairs(pages) do
				indexSchema(page.buildSchema and page.buildSchema() or page.schema, page.name)
				for _, tab in ipairs(page.tabs or {}) do
					indexSchema(tab.buildSchema and tab.buildSchema() or tab.schema, P.placeName(page, tab))
				end
			end
			for _, element in ipairs(elements) do
				indexSchema(element.schema, element.name)
			end
		end
		local owner = pathOwners[path]
		if not owner then
			return nil
		end
		local page = entry.page
		local here = page and (page.element or page).name
		if page and not page.element and entry.seenTab then
			for _, tab in ipairs(page.tabs or {}) do
				if tab.key == entry.seenTab then
					here = P.placeName(page, tab)
				end
			end
		end
		if owner.page ~= here and owner.name ~= owner.page then
			return ("%s (%s)"):format(owner.name, owner.page)
		end
		return owner.name
	end

	local function unmetNames(paths, entry, names)
		for _, path in ipairs(listPaths(paths)) do
			if not ui:GetConfig(path) then
				local name = pathName(path, entry)
				if name and not contains(names, name) then
					names[#names + 1] = name
				end
			end
		end
		return names
	end

	function P.requirementText(entry)
		if entry.disabled and entry.disabled() and entry.disabledDesc then
			return entry.disabledDesc
		end
		local names = unmetNames(ownerRequirements(entry), entry, {})
		unmetNames(entry.enabledBy, entry, names)
		if entry.enabledByAny and not isEnabledByAny(entry.enabledByAny) then
			local any = {}
			for _, path in ipairs(entry.enabledByAny) do
				local name = pathName(path, entry)
				if name and not contains(any, name) then
					any[#any + 1] = name
				end
			end
			if #any > 0 then
				names[#names + 1] = table.concat(any, L[" or "])
			end
		end
		if #names == 0 then
			return nil
		end
		return L["Requires: %s"]:format(table.concat(names, ", "))
	end
end

P.expandSchema = expandSchema
P.isEntryEnabled = isEntryEnabled
P.pageByKey = pageByKey
