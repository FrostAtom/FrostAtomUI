return function(ns, env, R)
	local test, expect = R.test, R.expect

	test("InitializeModules: a broken config section disables only its module", function()
		local broken = ns:NewModule("TestBrokenSection")
		broken.configKey = "testBrokenSection"
		local healthy = ns:NewModule("TestHealthy")
		healthy.configKey = "testHealthy"
		local failing = ns:NewModule("TestFailing")
		local calls = {}
		function broken:Initialize()
			calls.broken = true
		end
		function healthy:Initialize()
			calls.healthy = true
		end
		healthy:OnInitialize(function()
			calls.healthyExtra = true
		end)
		function failing:Initialize()
			error("init fails")
		end
		ns.Config.testBrokenSection = 5
		ns.Config.testHealthy = { enabled = true }
		ns.InitializeModules()
		ns.Config.testBrokenSection, ns.Config.testHealthy = nil, nil
		expect.eq(calls.broken, nil)
		expect.eq(calls.healthy, true)
		expect.eq(calls.healthyExtra, true)
		local errors = env.takeErrors()
		expect.eq(#errors, 1)
		expect.truthy(errors[1]:find("init fails"), "error text")
	end)

	test("InitializeModules: registration order, initializers right after their module", function()
		local order = {}
		local names = { "TestOrderZ", "TestOrderA", "TestOrderM", "TestOrderB" }
		local created = {}
		for _, name in ipairs(names) do
			local module = ns:NewModule(name)
			created[#created + 1] = module
			function module:Initialize()
				order[#order + 1] = self.name
			end
		end
		created[1]:OnInitialize(function()
			order[#order + 1] = "TestOrderZ+"
		end)
		ns.InitializeModules()
		expect.eq(table.concat(order, ","), "TestOrderZ,TestOrderZ+,TestOrderA,TestOrderM,TestOrderB")
	end)

	test("modules see prototype methods added after they were created", function()
		local module = ns:NewModule("TestLatePrototype")
		function ns.ModulePrototype:TestLateMethod()
			return self.name
		end
		expect.eq(module:TestLateMethod(), "TestLatePrototype")
		ns.ModulePrototype.TestLateMethod = nil
	end)
end
