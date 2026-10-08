local HERE = arg[0]:match("^(.*)[/\\]") or "."
local ROOT = arg[1] or (HERE .. "/..")
package.path = HERE .. "/?.lua;" .. package.path

local env = require("stubs")
local R = require("runner")

local SPECS = {
	"init_spec",
	"events_spec",
	"combatlog_spec",
	"util_spec",
	"scheduler_spec",
	"bootstrap_spec",
	"config_spec",
	"encode_spec",
	"macro_parser_spec",
	"tags_spec",
	"bag_search_spec",
	"talent_code_spec",
	"pvp_accuracy_spec",
	"undo_spec",
	"movers_spec",
	"setup_presets_spec",
	"api_spec",
	"search_spec",
	"slash_spec",
}

env.root = ROOT
os.setlocale("C", "ctype")
local ns = env.loadToc(ROOT, "FrostAtomUI", "Core\\API.lua")
assert(loadfile(ROOT .. "/FrostAtomUI/Core/Bootstrap.lua"))("FrostAtomUI", ns)

for _, name in ipairs(SPECS) do
	require(name)(ns, env, R)
end

local ok = R.run(function()
	env.inCombat = false
	env.takeErrors()
end)

local unexpected = {}
for key in pairs(env.autoStubbed) do
	unexpected[#unexpected + 1] = key
end
table.sort(unexpected)
print("auto-stubbed globals: " .. table.concat(unexpected, ", "))

os.exit(ok and 0 or 1)
