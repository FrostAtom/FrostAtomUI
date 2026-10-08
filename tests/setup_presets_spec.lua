return function(ns, env, R)
	local test, expect = R.test, R.expect

	local Presets

	local function settle()
		for _ = 1, 3 do
			env.tick(0)
		end
		env.tick(2)
	end

	local function login(db)
		if not ns.Movers then
			if not ns.Undo then
				env.loadFile("Core/Undo.lua", ns)
			end
			env.loadFile("Core/LayoutPresets.lua", ns)
			env.loadLayout(ns)
		end
		if not ns.SetupPresets then
			env.loadFile("Core/SetupPresets.lua", ns)
		end
		Presets = ns.SetupPresets
		ns.Storage.Load(db or {})
		ns:Fire(ns.E.DB_LOADED)
		ns.Undo.Clear()
		settle()
		local errors = env.takeErrors()
		expect.eq(#errors, 0, "errors on login: " .. tostring(errors[1]))
	end

	local function factory(path)
		local node = ns.Defaults
		for key in path:gmatch("[^.]+") do
			if type(node) ~= "table" then
				return nil
			end
			node = node[key]
		end
		return node
	end

	test("Setup presets: every path exists in the defaults, has a label and is not a game setting", function()
		login()
		local lists = {}
		for _, style in ipairs(Presets.STYLES) do
			lists[#lists + 1] = style.values
		end
		for _, experience in ipairs(Presets.EXPERIENCE) do
			lists[#lists + 1] = experience.values
		end
		for _, role in ipairs(Presets.ROLES) do
			lists[#lists + 1] = role.values
		end
		for _, values in ipairs(lists) do
			for path, value in pairs(values) do
				local default = factory(path)
				expect.truthy(default ~= nil, path .. " exists in the defaults")
				expect.eq(type(value), type(default), path .. " has the default's type")
				expect.truthy(Presets.LABELS[path], path .. " has a label")
				expect.truthy(
					not path:find("^tweaks%.") or path == "tweaks.assetLoadTime",
					path .. " is not a game setting"
				)
			end
		end
		for path in pairs(Presets.LABELS) do
			expect.truthy(factory(path) ~= nil, path .. " label points to a setting")
		end
	end)

	test("Setup presets: apply writes the baseline in one step and a second plan is empty", function()
		login()
		for path in pairs(ns.Movers.GetPresetLayout("arena")) do
			if not ns.Movers.HasMover(path) then
				local widget = env.newWidget()
				widget.GetWidth = function()
					return 100
				end
				widget.GetHeight = function()
					return 40
				end
				ns.Movers.Register(widget, path, path)
			end
		end
		local plan = Presets.Plan("arena", "expert")
		expect.truthy(#plan > 0, "arena changes settings")
		expect.eq(plan.layout, "arena")
		local applied = Presets.Apply(plan, "setup")
		settle()
		expect.eq(applied.layout, "arena")
		expect.eq(#applied, #plan)
		for _, item in ipairs(plan) do
			expect.eq(ns:GetConfig(item.path), item.value, item.path)
			expect.truthy(ns:IsDefaultConfig(item.path), item.path .. " is not an own change")
			expect.eq(ns:GetBaselineConfig(item.path), item.value, item.path .. " baseline")
		end
		expect.eq(Presets.GetActiveStyle(), "arena")
		local again = Presets.Plan("arena", "expert")
		expect.eq(#again, 0, "nothing left to change")
		expect.eq(again.layout, nil, "layout already active")
		expect.eq(#Presets.Apply(again), 0)

		settle()
		expect.eq(ns.Undo.Describe(ns.Undo.GetUndo()), "setup")
		expect.truthy(ns.Undo.Undo(), "undone")
		for _, item in ipairs(plan) do
			expect.eq(ns:GetConfig(item.path), factory(item.path), item.path .. " back")
		end
	end)

	test("Setup presets: the scale is applied before the layout, a healer gets the healer layout", function()
		login()
		for path in pairs(ns.Movers.GetPresetLayout("healer")) do
			if not ns.Movers.HasMover(path) then
				local widget = env.newWidget()
				widget.GetWidth = function()
					return 100
				end
				widget.GetHeight = function()
					return 40
				end
				ns.Movers.Register(widget, path, path)
			end
		end
		local plan = Presets.Plan("pvp", "returning", { ["general.uiScaleMode"] = "custom" }, "healer")
		expect.eq(plan.layout, "healer")
		expect.eq(plan.role, "healer")
		local applyPreset, mode = ns.Movers.ApplyPreset, nil
		ns.Movers.ApplyPreset = function(key)
			mode = ns:GetConfig("general.uiScaleMode")
			return applyPreset(key)
		end
		local applied = Presets.Apply(plan, "setup")
		ns.Movers.ApplyPreset = applyPreset
		settle()
		expect.eq(applied.layout, "healer")
		expect.eq(mode, "custom", "the scale is set when the layout is chosen")
		expect.eq(ns:GetConfig("diminishingReturns.party"), true)
		expect.eq(ns:GetConfig("dispelHighlightMode"), "all")
		expect.eq(Presets.Plan("arena", nil, nil, "damage").layout, "arena")
	end)

	test("Setup presets: the role comes from the talent tree with the most points", function()
		login()
		local group, tabs, info, unitClass = GetActiveTalentGroup, GetNumTalentTabs, GetTalentTabInfo, UnitClass
		local points, class = { 13, 0, 58 }, "DRUID"
		GetActiveTalentGroup = function()
			return 1
		end
		GetNumTalentTabs = function()
			return 3
		end
		GetTalentTabInfo = function(tab)
			return "Tree" .. tab, nil, points[tab]
		end
		UnitClass = function()
			return class, class
		end
		local role, tree = Presets.DetectRole()
		expect.eq(role, "healer")
		expect.eq(tree, "Tree3")
		class = "MAGE"
		expect.eq((Presets.DetectRole()), "damage")
		points = { 0, 0, 0 }
		expect.eq(Presets.DetectRole(), nil)
		GetActiveTalentGroup, GetNumTalentTabs, GetTalentTabInfo, UnitClass = group, tabs, info, unitClass
	end)

	test("Setup presets: an own value is unchecked and stays", function()
		login()
		ns:SetConfig("namePlates.nonTargetAlpha", 0.6)
		local plan = Presets.Plan("arena")
		local found
		for _, item in ipairs(plan) do
			if item.path == "namePlates.nonTargetAlpha" then
				found = item
			end
		end
		expect.truthy(found and found.mine and not found.checked, "own value is unchecked")
		Presets.Apply(plan)
		expect.eq(ns:GetConfig("namePlates.nonTargetAlpha"), 0.6)
		expect.truthy(not ns:IsDefaultConfig("namePlates.nonTargetAlpha"), "still an own change")
		found.checked = true
		Presets.Apply(plan)
		expect.eq(ns:GetConfig("namePlates.nonTargetAlpha"), 1)
		expect.truthy(ns:IsDefaultConfig("namePlates.nonTargetAlpha"), "checked: the own value is replaced")
	end)

	test("What's new: old comfort values are recommended and go to the new defaults in one step", function()
		login({ profiles = { Default = { tooltip = { showIds = false } } }, schemaVersion = 1 })
		local list = ns:GetLegacyRecommendations()
		local paths = {}
		for _, item in ipairs(list) do
			paths[item.path] = item
			expect.truthy(Presets.LABELS[item.path] or item.point, item.path .. " has a label")
		end
		expect.truthy(paths["tweaks.hideGroundClutter"], "grass is recommended")
		expect.eq(paths["tooltip.showIds"], nil, "an own value is not recommended")
		expect.truthy(paths["lossOfControl.point"] and paths["lossOfControl.point"].point, "a point is recommended")
		ns.ApplyRecommendations(list)
		settle()
		expect.eq(ns:GetConfig("tweaks.hideGroundClutter"), false)
		expect.eq(#ns:GetLegacyRecommendations(), 0)
		expect.truthy(ns.Undo.Undo(), "undone")
		expect.eq(ns:GetConfig("tweaks.hideGroundClutter"), true)
	end)

	test("What's new: a style value equal to an old default is not recommended back", function()
		login()
		Presets.Apply(Presets.Plan("pvp"))
		expect.eq(ns:GetBaselineConfig("spellAlerts.zones.battleground"), true)
		expect.eq(#ns:GetLegacyRecommendations(), 0)
	end)

	test("What's new: an experience value equal to an old default is not recommended back", function()
		login()
		Presets.Apply(Presets.Plan("arena", "expert"))
		ns.Storage.Slot("setup"):Table().experience = "expert"
		expect.eq(ns:GetBaselineConfig("tooltip.showIds"), true)
		expect.eq(#ns:GetLegacyRecommendations(), 0)
	end)

	test("Spec icons: every specialization has its own icon", function()
		local file = assert(io.open(env.root .. "/FrostAtomUI/Core/UIKit.lua"))
		local text = file:read("*a")
		file:close()
		local block = text:match("local SPEC_ICONS = (%b{})")
		local seen, count = {}, 0
		for icon in block:gmatch('"([%w_]+)"') do
			expect.eq(seen[icon], nil, icon .. " is used twice")
			seen[icon] = true
			count = count + 1
		end
		expect.eq(count, 30)
	end)

	test("Setup presets: a fresh install waits for the setup, an upgrade does not", function()
		login()
		expect.eq(ns.SetupState(), "pending")
		login({ profiles = { Default = { unitFrames = { targetWidth = 250 } } }, schemaVersion = 4 })
		expect.eq(ns.SetupState(), "legacy")
		login({ profiles = {}, setup = { state = "done" } })
		expect.eq(ns.SetupState(), "done")
	end)
end
