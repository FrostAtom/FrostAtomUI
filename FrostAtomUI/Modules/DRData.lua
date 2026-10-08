local _, ns = ...

local Data = {}
ns.DRData = Data

Data.RESET_TIME = 15
Data.AURA_TIMEOUT = 10
Data.RECONCILE_GRACE = 0.5

Data.CATEGORY_NAMES = {
	stun = "Stuns",
	openingstun = "Opening stuns",
	randomstun = "Random stuns",
	charge = "Charge",
	silence = "Silences",
	disorient = "Incapacitates",
	fear = "Fears",
	horror = "Horrors",
	cyclone = "Cyclone",
	root = "Roots",
	randomroot = "Random roots",
	disarm = "Disarms",
	mindcontrol = "Mind control",
	banish = "Banish",
	sleep = "Sleeps",
	scatter = "Scatter Shot",
	dragonsbreath = "Dragon's Breath",
}

Data.CATEGORY_ORDER = {
	"stun",
	"openingstun",
	"randomstun",
	"charge",
	"cyclone",
	"disorient",
	"sleep",
	"scatter",
	"dragonsbreath",
	"fear",
	"horror",
	"mindcontrol",
	"banish",
	"silence",
	"disarm",
	"root",
	"randomroot",
}

Data.FILTER_GROUPS = {
	stun = "stuns",
	openingstun = "stuns",
	randomstun = "stuns",
	charge = "stuns",
	cyclone = "incapacitates",
	disorient = "incapacitates",
	sleep = "incapacitates",
	scatter = "incapacitates",
	dragonsbreath = "incapacitates",
	banish = "incapacitates",
	fear = "fears",
	horror = "fears",
	mindcontrol = "fears",
	silence = "silences",
	disarm = "disarms",
	root = "roots",
	randomroot = "roots",
}

Data.SPELLS = ns.SpellDB.DRSpells()

Data.TEST_SPELLS = { 853, 1833, 12355, 15487, 118, 6770, 5782, 6789, 33786, 122, 12494, 676, 19503, 31661, 2637 }
