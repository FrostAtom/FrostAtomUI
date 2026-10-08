return function(ns, env, R)
	local test, expect = R.test, R.expect

	local Undo

	local function settle(seconds)
		for _ = 1, 3 do
			env.tick(0)
		end
		if seconds then
			env.tick(seconds)
		end
	end

	local function login(db)
		if not ns.Undo then
			env.loadFile("Core/Undo.lua", ns)
		end
		Undo = ns.Undo
		ns.Storage.Load(db or {})
		ns:Fire(ns.E.DB_LOADED)
		Undo.Clear()
		settle(5)
		local errors = env.takeErrors()
		expect.eq(#errors, 0, "errors on login: " .. tostring(errors[1]))
	end

	test("Undo: a change is one step, undo and redo restore both values", function()
		login()
		local default = ns.Defaults.unitFrames.targetWidth
		ns:SetConfig("unitFrames.targetWidth", default + 40)
		settle()
		expect.truthy(Undo.GetUndo(), "step recorded")
		expect.truthy(Undo.Undo(), "undone")
		expect.eq(ns.Config.unitFrames.targetWidth, default)
		expect.truthy(ns:IsDefaultConfig("unitFrames.targetWidth"), "own value removed")
		expect.truthy(Undo.Redo(), "redone")
		expect.eq(ns.Config.unitFrames.targetWidth, default + 40)
		expect.eq(Undo.GetRedo(), nil)
	end)

	test("Undo: a slider drag and a series of nudges are one step each", function()
		login()
		local default = ns.Defaults.unitFrames.targetWidth
		for i = 1, 5 do
			ns:SetConfig("unitFrames.targetWidth", default + i)
			settle(0.1)
		end
		settle(2)
		ns:SetConfig("unitFrames.targetHeight", 77)
		settle()
		expect.truthy(Undo.Undo(), "height undone")
		expect.eq(ns.Config.unitFrames.targetWidth, default + 5)
		expect.truthy(Undo.Undo(), "the whole drag undone in one step")
		expect.eq(ns.Config.unitFrames.targetWidth, default)
		expect.eq(Undo.GetUndo(), nil, "nothing left")
	end)

	test("Undo: a transaction is one step, a new change drops the redo", function()
		login()
		Undo.Begin("several")
		ns:SetConfig("unitFrames.targetWidth", 300)
		ns:SetConfig("unitFrames.targetHeight", 60)
		ns:SetConfig("unitFrames.targetWidth", 310)
		Undo.End()
		settle()
		local step = Undo.GetUndo()
		expect.eq(Undo.Describe(step), "several")
		Undo.Undo()
		expect.eq(ns.Config.unitFrames.targetWidth, ns.Defaults.unitFrames.targetWidth)
		expect.eq(ns.Config.unitFrames.targetHeight, ns.Defaults.unitFrames.targetHeight)
		expect.truthy(Undo.GetRedo(), "redo available")
		settle()
		ns:SetConfig("unitFrames.focusWidth", 123)
		settle()
		expect.eq(Undo.GetRedo(), nil, "redo dropped")
	end)

	test("Undo: the baseline layer and a whole profile reset come back", function()
		login()
		local path = "unitFrames.targetWidth"
		ns:SetBaselineConfig(path, 250)
		settle(2)
		ns:SetConfig(path, 260)
		settle(2)
		ns:ResetConfig()
		settle()
		expect.eq(ns.Config.unitFrames.targetWidth, ns.Defaults.unitFrames.targetWidth)
		Undo.Undo()
		expect.eq(ns.Config.unitFrames.targetWidth, 260)
		expect.eq(ns:GetBaselineConfig(path), 250, "baseline back")
		Undo.Undo()
		expect.eq(ns.Config.unitFrames.targetWidth, 250)
		Undo.Undo()
		expect.eq(ns:GetBaselineConfig(path), nil)
		expect.eq(ns.Config.unitFrames.targetWidth, ns.Defaults.unitFrames.targetWidth)
	end)

	test("Undo: a list item change is undone as the whole list", function()
		login()
		local groups = ns.Config.trackers.groups
		local count = #groups
		ns:SetConfig("trackers.groups.1.size", 55)
		settle()
		Undo.Undo()
		expect.eq(#ns.Config.trackers.groups, count)
		expect.eq(ns.Config.trackers.groups[1].size, ns.Defaults.trackers.groups[1].size)
		expect.truthy(ns:IsDefaultConfig("trackers.groups"), "list is default again")
	end)

	test("Undo: switching the profile clears the history", function()
		login()
		ns:SetConfig("unitFrames.targetWidth", 300)
		settle()
		ns:SetProfile("Other")
		expect.eq(Undo.GetUndo(), nil)
		ns:SetProfile("Default")
	end)

	test("Undo: changes made while restoring are not recorded", function()
		login()
		ns:SetConfig("unitFrames.targetWidth", 300)
		settle(2)
		Undo.Undo()
		ns:SetConfig("unitFrames.targetHeight", 61)
		settle()
		expect.truthy(Undo.GetRedo(), "redo kept")
		settle(2)
		ns:SetConfig("unitFrames.targetHeight", 62)
		settle()
		expect.eq(Undo.GetRedo(), nil, "a later change is recorded")
	end)

	test("Snapshots: the session copy, ten automatic copies, pinned and manual ones stay", function()
		login()
		ns:SetConfig("unitFrames.targetWidth", 300)
		settle()
		local list = Undo.GetSnapshots()
		expect.eq(#list, 1, "session start")
		expect.eq(list[1].reason, "session")
		expect.eq(list[1].data.unitFrames, nil, "taken before the change")
		local pinned = list[1]
		Undo.PinSnapshot(pinned, true)
		Undo.Snapshot("manual", "mine", true)
		for i = 1, 15 do
			ns:SetConfig("unitFrames.targetWidth", 300 + i)
			Undo.Snapshot("resetPage", "page " .. i)
		end
		local automatic, kept = 0, {}
		for _, item in ipairs(Undo.GetSnapshots()) do
			if item.manual or item.pinned then
				kept[item.reason] = true
			else
				automatic = automatic + 1
			end
		end
		expect.eq(automatic, 10)
		expect.truthy(kept.session and kept.manual, "pinned and manual kept")
		local count = #Undo.GetSnapshots()
		Undo.Snapshot("resetPage", "page 15")
		expect.eq(#Undo.GetSnapshots(), count, "same reason within a minute is not repeated")
	end)

	test("Snapshots: restoring brings the profile and the layout base back and can be undone", function()
		login()
		ns.Storage.Slot("layoutBase"):Set({ Default = "preset:classic" })
		ns:SetBaselineConfig("unitFrames.targetHeight", 70)
		ns:SetConfig("unitFrames.targetWidth", 280)
		settle()
		local item = Undo.Snapshot("manual", "before", true)
		ns:SetConfig("unitFrames.targetWidth", 320)
		ns:ResetConfig()
		settle()
		expect.eq(ns.Storage.Slot("layoutBase"):Get().Default, nil)
		expect.truthy(Undo.RestoreSnapshot(item), "restored")
		settle()
		expect.eq(ns.Config.unitFrames.targetWidth, 280)
		expect.eq(ns:GetBaselineConfig("unitFrames.targetHeight"), 70)
		expect.eq(ns.Storage.Slot("layoutBase"):Get().Default, "preset:classic")
		Undo.Undo()
		expect.eq(ns.Config.unitFrames.targetWidth, ns.Defaults.unitFrames.targetWidth)
		expect.eq(ns.Storage.Slot("layoutBase"):Get().Default, nil)
	end)

	test("CVars: a pin remembers the value it replaced and unpin brings it back", function()
		login()
		local CVars = ns:GetModule("CVars")
		env.cvars.groundEffectDist = "70"
		CVars:Pin("groundEffectDist", "0")
		expect.eq(env.cvars.groundEffectDist, "0")
		expect.eq(ns.Storage.Slot("cvarOriginals"):Get().groundEffectDist, "70")
		CVars:Pin("groundEffectDist", "10")
		expect.eq(ns.Storage.Slot("cvarOriginals"):Get().groundEffectDist, "70", "the first value is kept")
		CVars:Unpin("groundEffectDist")
		expect.eq(env.cvars.groundEffectDist, "70")
		expect.eq(ns.Storage.Slot("cvarOriginals"):Get().groundEffectDist, nil)

		env.cvars.autoStand = "0"
		CVars:Pin("autoStand", "0")
		expect.eq(
			ns.Storage.Slot("cvarOriginals"):Get().autoStand,
			nil,
			"nothing to remember when the value is the same"
		)
		CVars:Unpin("autoStand")
		expect.eq(env.cvars.autoStand, "default")
	end)

	test("Snapshots: an old schema copy runs the migration ladder", function()
		login()
		local item = Undo.Snapshot("manual", "old", true)
		item.schema = 1
		item.data = { general = { useUiScale = true, uiScale = 0.7 } }
		expect.truthy(Undo.RestoreSnapshot(item), "restored")
		expect.eq(ns.Config.general.uiScaleMode, "custom")
		expect.eq(ns.Config.general.uiScale, 0.7)
	end)
end
