local _, ns = ...

-- Personal settings that are not derived from the game: names and screen
-- positions. Positions are SetPoint arguments relative to UIParent unless a
-- module says otherwise.

ns.Config = {
	-- Shown on the player's own unit frame instead of the character name.
	-- nil keeps the character name.
	nickname = "Cute Boy",

	unitFrames = {
		player = { "TOPLEFT", 150, -40 },
		playerCastbar = { "CENTER", 0, -270 },
		party = { "TOPLEFT", 50, -150 }, -- first member; the rest go below
		partySpacing = 112,
		arena = { "RIGHT", -150, 0 }, -- last (bottom) frame; the rest go above
		arenaSpacing = 104,
		boss = { "RIGHT", -150, 300 }, -- first frame; the rest go below
		bossSpacing = 60,
		-- Party/arena frames fade to this alpha when the unit is out of range.
		outOfRangeAlpha = 0.45,
	},

	runes = { "CENTER", 0, -294 },

	-- Experience/reputation bar at the top edge; only shown below the level cap
	-- (reputation is shown at the cap when a faction is being watched).
	experienceBar = { width = 456, height = 5, point = { "TOP", 0, 0 } },

	-- Arena trinket icon next to each arena frame.
	arenaTrinket = { size = 30 },
}
