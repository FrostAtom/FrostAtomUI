local _, ns = ...

ns.Config = {
	nickname = "Cute Boy",

	unitFrames = {
		player = { "LEFT", 240, 456 },
		playerCastbar = { "CENTER", 0, -270 },
		party = { "LEFT", 150, 230 },
		arena = { "RIGHT", -150, 230 },
		groupSpacing = 146,
		boss = { "RIGHT", -150, 300 },
		bossSpacing = 60,
		outOfRangeAlpha = 0.45,
		partyCooldownSize = 22,
		arenaCooldownSize = 24,
	},

	playerPlate = { "CENTER", 0, -120 },
	shieldIndicator = { "CENTER", -160, -120 },

	runes = { "CENTER", 0, -294 },
	totems = { "CENTER", 0, -294 },

	dispelHighlightAlpha = 0.5,

	durabilityWarning = 0.2,

	experienceBar = { width = 456, height = 5, point = { "TOP", 0, 0 } },

	arenaTrinket = { size = 30 },

	arenaHistory = { "CENTER", 0, 40 },

	combatAlert = { "CENTER", 0, 150 },

	performance = { "TOPLEFT", 12, -10 },

	tooltip = { "BOTTOMRIGHT", -13, 64 },

	bags = {
		buttonSize = 34,
		spacing = 4,
		inventoryColumns = 10,
		bankColumns = 16,
		inventory = { "BOTTOMRIGHT", -13, 64 },
		bank = { "LEFT", 60, 0 },
	},
}
