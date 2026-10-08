local _, ns = ...

local ui = FrostAtomUI
local L = ui.L

local sort = table.sort

local P = ns.private
local GLYPH_SIZE = P.GLYPH_SIZE
local RELOAD_COLOR = P.RELOAD_COLOR
local SCROLL = P.SCROLL
local createButton = P.createButton
local createGlyph = P.createGlyph
local elements = P.elements
local font = P.font
local pages = P.pages
local refreshPage = P.refreshPage

local reload = { BANNER_HEIGHT = 44 }

do
	local index

	local function scan(schema, page)
		local header
		for _, entry in ipairs(schema or {}) do
			if entry.header then
				header = entry.header
			elseif entry.path and not index[entry.path] and ui.RequiresReload(entry.path) then
				local label = entry.label
				if header and header ~= label then
					label = ("%s: %s"):format(header, label)
				elseif page then
					label = ("%s: %s"):format(page.name, label)
				end
				index[entry.path] = label
			end
		end
	end

	local function reloadIndex()
		if not index then
			index = {}
			for _, page in ipairs(pages) do
				scan(page.schema, page)
				for _, tab in ipairs(page.tabs or {}) do
					scan(tab.schema, page)
				end
			end
			for _, element in ipairs(elements) do
				scan(element.schema, element)
			end
		end
		return index
	end

	reload.InPreparation = ui.InArenaPreparation

	function reload.Pending()
		local list = {}
		local paths, extras = ui.PendingReload()
		for _, path in ipairs(paths) do
			list[#list + 1] = reloadIndex()[path] or ns.SettingLabel(path)
		end
		for label in pairs(extras or {}) do
			list[#list + 1] = label
		end
		sort(list)
		return list
	end

	function ns.ReloadLabel(path)
		return ui.RequiresReload(path) and (reloadIndex()[path] or ns.SettingLabel(path)) or nil
	end

	function reload.Require(label)
		ui.RequireReload(label)
		reload.Update()
	end
	local function createBanner()
		local banner = CreateFrame("Frame", nil, P.frame.panel)
		banner:SetPoint("BOTTOMLEFT", 4, 4)
		banner:SetPoint("BOTTOMRIGHT", -4, 4)
		banner:SetHeight(reload.BANNER_HEIGHT)
		banner:SetFrameLevel(P.frame.panel:GetFrameLevel() + 10)
		local shade = banner:CreateTexture(nil, "BACKGROUND")
		shade:SetTexture(0.25, 0.12, 0.02, 0.9)
		shade:SetAllPoints()
		local glyph = createGlyph(banner, "rotate", GLYPH_SIZE, RELOAD_COLOR)
		glyph:SetPoint("TOPLEFT", 10, -9)
		local later = createButton(banner, L["Later"], 70, true)
		later:SetPoint("RIGHT", -8, 0)
		later:SetScript("OnClick", function()
			reload.dismissed = table.concat(reload.Pending(), "\n")
			reload.Update()
		end)
		local now = createButton(banner, L["Reload now"], 110, nil, nil, "rotate")
		now:SetPoint("RIGHT", later, "LEFT", -4, 0)
		now:SetScript("OnClick", ReloadUI)
		local text = banner:CreateFontString(nil, "ARTWORK")
		text:SetFontObject(font("GameFontHighlightSmall"))
		text:SetPoint("TOPLEFT", glyph, "TOPRIGHT", 6, 1)
		text:SetPoint("RIGHT", now, "LEFT", -8, 0)
		text:SetHeight(reload.BANNER_HEIGHT - 12)
		text:SetJustifyH("LEFT")
		text:SetJustifyV("TOP")
		banner.text = text
		P.frame.banner = banner
		return banner
	end

	function reload.Update()
		if not P.frame then
			return
		end
		local list = reload.Pending()
		local button = P.frame.reloadButton
		button:SetText(#list > 0 and L["Reload (%d)"]:format(#list) or L["Reload UI"])
		ui.SetShown(button, #list > 0)
		local text = table.concat(list, "\n")
		local shown = #list > 0 and reload.dismissed ~= text
		local banner = P.frame.banner or (shown and createBanner())
		if banner then
			ui.SetShown(banner, shown)
			if shown then
				local names = table.concat(list, ", ")
				if reload.InPreparation() then
					banner.text:SetText(L["Reload after the match: %s."]:format(names))
				else
					banner.text:SetText(
						L["Some changes take effect after a UI reload (5-10 seconds, your character stays in place): %s."]:format(
							names
						)
					)
				end
			end
		end
		P.frame.scroll:SetPoint("BOTTOMRIGHT", SCROLL.RIGHT, SCROLL.BOTTOM + (shown and reload.BANNER_HEIGHT or 0))
	end

	StaticPopupDialogs.FROSTATOMUI_CONFIG_RELOAD = {
		text = L["Reload the UI now? Otherwise the changes take effect at the next login."],
		button1 = L["Reload now"],
		button2 = L["Later"],
		OnAccept = function()
			ReloadUI()
		end,
		timeout = 0,
		whileDead = 1,
		hideOnEscape = 1,
		preferredIndex = 3,
	}

	function reload.OnClose()
		local list = reload.Pending()
		local text = table.concat(list, "\n")
		if #list == 0 or reload.asked == text then
			return
		end
		reload.asked = text
		if reload.InPreparation() then
			ui.Print(L["some changes take effect after a UI reload; reload after the match"])
		else
			StaticPopup_Show("FROSTATOMUI_CONFIG_RELOAD")
		end
	end
end

function ns.ShowReloadButton(label)
	reload.Require(label or L["Reload UI"])
end

function ns.RefreshPage()
	if P.frame and P.frame:IsShown() then
		refreshPage(P.currentPage)
	end
end

local resetPlan

do
	local ANCHOR_POINTS = {
		TOPLEFT = true,
		TOP = true,
		TOPRIGHT = true,
		LEFT = true,
		CENTER = true,
		RIGHT = true,
		BOTTOMLEFT = true,
		BOTTOM = true,
		BOTTOMRIGHT = true,
	}

	local function defaultConfig(path)
		local _, value = ui.API.FactoryValue(path)
		return value
	end

	local function isPosition(value)
		return type(value) == "table" and ANCHOR_POINTS[value[1]] == true
	end

	local function isSection(value)
		return type(value) == "table" and value[1] == nil and next(value) ~= nil
	end

	local function within(path, prefix)
		return path == prefix or path:sub(1, #prefix + 1) == prefix .. "."
	end

	local function isKept(plan, path)
		for kept in pairs(plan.keep) do
			if within(path, kept) then
				return true
			end
		end
		return false
	end

	local function planPath(plan, path)
		if plan.seen[path] or isKept(plan, path) then
			return
		end
		plan.seen[path] = true
		local default, value = defaultConfig(path), ui:GetConfig(path)
		local listed = path:find("%.%d+%.") or path:find("%.%d+$")
		if isPosition(default) or isPosition(value) then
			if not ui.Movers.IsAtHome(path) then
				plan.positions[#plan.positions + 1] = path
			end
		elseif isSection(default) and type(value) == "table" and not listed then
			local keys = {}
			for key in pairs(default) do
				keys[key] = true
			end
			for key in pairs(value) do
				keys[key] = true
			end
			for key in pairs(keys) do
				planPath(plan, path .. "." .. key)
			end
		elseif not ui:IsDefaultConfig(path) then
			plan.settings[#plan.settings + 1] = path
		end
	end

	function resetPlan(page)
		local plan = { keep = {}, seen = {}, settings = {}, positions = {}, custom = {}, lists = {} }
		local schemas = { page.schema }
		for _, tab in ipairs(page.tabs or {}) do
			schemas[#schemas + 1] = tab.schema
		end
		local owned = {}
		for _, element in ipairs(elements) do
			if element.page == page.key then
				schemas[#schemas + 1] = element.schema
				owned[#owned + 1] = element
			end
		end
		for _, schema in ipairs(schemas) do
			for _, entry in ipairs(schema) do
				if entry.userContent and entry.path and not plan.keep[entry.path] then
					plan.keep[entry.path] = true
					plan.lists[#plan.lists + 1] = entry
				end
			end
		end
		for _, schema in ipairs(schemas) do
			for _, entry in ipairs(schema) do
				local resettable = not entry.noReset and not entry.userContent
				if resettable and entry.path then
					planPath(plan, entry.path)
					if entry.pathY then
						planPath(plan, entry.pathY)
					end
				elseif resettable and entry.reset and entry.isDefault and not entry.isDefault() then
					plan.custom[#plan.custom + 1] = entry
				end
			end
		end
		for _, element in ipairs(owned) do
			planPath(plan, element.path)
		end
		return plan
	end
end

P.reload = reload
P.resetPlan = resetPlan
