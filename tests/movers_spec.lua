return function(ns, env, R)
	local test, expect = R.test, R.expect

	local Movers

	local function login()
		if not ns.Movers then
			if not ns.Undo then
				env.loadFile("Core/Undo.lua", ns)
			end
			env.loadFile("Core/LayoutPresets.lua", ns)
			env.loadLayout(ns)
		end
		Movers = ns.Movers
		ns.Storage.Load({})
		ns:Fire(ns.E.DB_LOADED)
		local errors = env.takeErrors()
		expect.eq(#errors, 0, "errors on login: " .. tostring(errors[1]))
	end

	local function frame(width, height)
		local widget = env.newWidget()
		widget.GetWidth = function()
			return width
		end
		widget.GetHeight = function()
			return height
		end
		return widget
	end

	local function samePoint(actual, expected, message)
		for i = 1, 5 do
			expect.eq(actual[i], expected[i], (message or "point") .. " [" .. i .. "]")
		end
	end

	local function copy(point)
		return { point[1], point[2], point[3], point[4], point[5] }
	end

	test("Movers: move back after a layout preset goes to that preset", function()
		login()
		local path = "unitFrames.player"
		Movers.Register(frame(200, 50), path, "Player")
		expect.truthy(Movers.ApplyPreset("classic"), "preset applied")
		local preset = copy(Movers.GetPresetLayout("classic")[path])
		samePoint(ns:GetBaselineConfig(path), preset, "preset point is the baseline")
		expect.truthy(ns:IsDefaultConfig(path), "preset point is not an own change")
		ns:SetConfig(path, { "CENTER", 1, 2 })
		expect.truthy(not Movers.IsAtHome(path), "moved away")
		Movers.ResetPosition(path)
		samePoint(ns:GetConfig(path), preset, "single frame")
		expect.truthy(Movers.IsAtHome(path), "at home")
		expect.eq(Movers.GetBaseLayoutName(), "Classic")

		ns:SetConfig(path, { "CENTER", 1, 2 })
		Movers.ResetPositions()
		samePoint(ns:GetConfig(path), preset, "all frames")

		Movers.ApplyPreset("default")
		ns:SetConfig(path, { "CENTER", 1, 2 })
		Movers.ResetPosition(path)
		samePoint(ns:GetConfig(path), ns.Defaults.unitFrames.player, "default preset")
		expect.truthy(ns:IsDefaultConfig(path), "stored as default")
	end)

	test("Movers: move back after loading a saved layout goes to that layout", function()
		login()
		local path = "unitFrames.player"
		Movers.Register(frame(200, 50), path, "Player")
		ns:SetConfig(path, { "TOP", 11, -22 })
		expect.truthy(Movers.SaveLayout("Mine"), "saved")
		ns:SetConfig(path, { "CENTER", 1, 2 })
		expect.truthy(Movers.LoadLayout("Mine"), "loaded")
		ns:SetConfig(path, { "CENTER", 1, 2 })
		Movers.ResetPosition(path)
		samePoint(ns:GetConfig(path), { "TOP", 11, -22 }, "saved layout")
		expect.eq(Movers.GetBaseLayoutName(), "Mine")

		Movers.DeleteLayout("Mine")
		samePoint(ns:GetConfig(path), { "TOP", 11, -22 }, "deleting the layout keeps the frame")
		expect.eq(ns:GetBaselineConfig(path), nil)
		expect.eq(ns:IsDefaultConfig(path), false, "the position becomes an own change")
		Movers.ResetPosition(path)
		samePoint(ns:GetConfig(path), ns.Defaults.unitFrames.player, "deleted layout")
	end)

	test("Movers: a layout preset is undone in one step with its layout base", function()
		login()
		local path = "unitFrames.player"
		Movers.Register(frame(200, 50), path, "Player")
		ns:SetConfig(path, { "TOP", 5, -5 })
		for _ = 1, 3 do
			env.tick(0)
		end
		env.tick(5)
		Movers.ApplyPreset("classic")
		for _ = 1, 3 do
			env.tick(0)
		end
		expect.eq(Movers.GetBaseLayoutName(), "Classic")
		expect.truthy(ns.Undo.Undo(), "undone")
		samePoint(ns:GetConfig(path), { "TOP", 5, -5 }, "own point back")
		expect.eq(ns:GetBaselineConfig(path), nil, "preset baseline gone")
		expect.eq(Movers.GetBaseLayoutName(), "Standard", "layout base back")
		local snapshots = ns.Undo.GetSnapshots()
		expect.eq(snapshots[1].reason, "layout")
	end)

	test("Movers: changing the point keeps the frame in place", function()
		login()
		Movers.Register(frame(200, 50), "unitFrames.player", "Player")
		Movers.Register(frame(100, 40), "unitFrames.target", "Target")

		ns:SetConfig("unitFrames.target", { "CENTER", 10, 20 })
		Movers.ChangePoint("unitFrames.target", "TOPLEFT")
		samePoint(ns:GetConfig("unitFrames.target"), { "TOPLEFT", -40, 40, nil, "CENTER" }, "on screen")
		Movers.ChangePoint("unitFrames.target", "CENTER")
		samePoint(ns:GetConfig("unitFrames.target"), { "CENTER", 10, 20 }, "back")

		ns:SetConfig("unitFrames.target", { "LEFT", 5, 0, "unitFrames.player", "RIGHT" })
		Movers.ChangePoint("unitFrames.target", "BOTTOMRIGHT")
		samePoint(
			ns:GetConfig("unitFrames.target"),
			{ "BOTTOMRIGHT", 105, -20, "unitFrames.player", "RIGHT" },
			"attached"
		)
	end)

	test("Movers: registering the same frame again does not invalidate positions", function()
		login()
		local player, target = frame(200, 50), frame(100, 40)
		Movers.Register(player, "unitFrames.player", "Player")
		ns:SetConfig("unitFrames.target", { "LEFT", 5, 0, "unitFrames.player", "RIGHT" })
		local fired = 0
		local listener = ns.Mixin({}, ns.EventMixin)
		listener:RegisterEvent(ns.E.POSITION_INVALIDATED, function()
			fired = fired + 1
		end)
		Movers.Register(target, "unitFrames.target", "Target")
		expect.eq(fired, 1, "first registration")
		Movers.Register(target, "unitFrames.target", "Target")
		Movers.Register(player, "unitFrames.player", "Player")
		expect.eq(fired, 1, "same frames again")
	end)
end
