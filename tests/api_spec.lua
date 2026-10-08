return function(ns, env, R)
	local test, expect = R.test, R.expect

	local function login(db)
		if not ns.RequiresReload then
			env.loadFile("Core/Reload.lua", ns)
		end
		ns.Storage.Load(db or {})
		ns:Fire(ns.E.DB_LOADED)
		local errors = env.takeErrors()
		expect.eq(#errors, 0, "errors on login: " .. tostring(errors[1]))
	end

	test("Reload contract: module switches, registered paths and prefixes need a reload", function()
		login()
		ns:RegisterReloadPaths("chat.skin", "hideBlizzard.")
		expect.truthy(ns.RequiresReload("chat.skin"))
		expect.truthy(ns.RequiresReload("hideBlizzard.actionBars"))
		expect.truthy(not ns.RequiresReload("chat.width"))
		expect.truthy(not ns.RequiresReload(nil))
	end)

	test("Reload contract: a profile switch that changes a reload path fires RELOAD_REQUIRED once", function()
		ns:RegisterReloadPaths("chat.skin")
		login({ profiles = { Default = {}, Other = { chat = { skin = false } } } })
		local fired = {}
		local listener = ns.Mixin({}, ns.EventMixin)
		listener:RegisterEvent(ns.E.RELOAD_REQUIRED, function(_, list)
			fired[#fired + 1] = table.concat(list, ",")
		end)
		ns:SetConfig("chat.width", 300)
		expect.eq(#fired, 0, "a plain change asks nothing")
		ns:SetProfile("Other")
		expect.eq(#fired, 1)
		expect.eq(fired[1], "chat.skin")
		expect.deepEq((ns.PendingReload()), { "chat.skin" })
		ns:SetProfile("Default")
		expect.eq(#(ns.PendingReload()), 0, "back to the loaded value")
		listener:UnregisterAllEvents()
		env.takeErrors()
	end)

	test("API: previews register, report and announce their state", function()
		local active = false
		local changes = {}
		local listener = ns.Mixin({}, ns.EventMixin)
		listener:RegisterEvent(ns.E.PREVIEW_CHANGED, function(_, name, state)
			changes[#changes + 1] = name .. "=" .. tostring(state)
		end)
		ns.API.RegisterPreview("demo", {
			Set = function(value)
				active = value
				ns.API.PreviewChanged("demo")
			end,
			IsActive = function()
				return active
			end,
		})
		ns.API.RegisterPreview("hidden", {
			Set = function() end,
			IsActive = function()
				return false
			end,
			IsAvailable = function()
				return false
			end,
		})
		expect.truthy(ns.API.GetPreview("demo"))
		expect.eq(ns.API.GetPreview("hidden"), nil, "unavailable previews are not offered")
		ns.API.SetPreview("demo", true)
		expect.truthy(ns.API.IsPreviewActive("demo"))
		expect.deepEq(changes, { "demo=true" })
		local names = {}
		for name in ns.API.IteratePreviews() do
			names[#names + 1] = name
		end
		expect.truthy(table.concat(names, ","):find("demo"), "listed")
		expect.truthy(not table.concat(names, ","):find("hidden"), "hidden one not listed")
		listener:UnregisterAllEvents()
		ns.API.RegisterAction("demoAction", function(a, b)
			return a + b
		end)
		expect.eq(ns.API.RunAction("demoAction", 2, 3), 5)
		expect.eq(ns.API.RunAction("missing"), nil)
	end)
end
