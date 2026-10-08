local _, ns = ...

ns.Defaults = {}
ns.DefaultsKit = {}

function ns:RegisterDefaults(section, defaults)
	assert(ns.Defaults[section] == nil, ("defaults [%s] are already registered"):format(section))
	ns.Defaults[section] = defaults
end
