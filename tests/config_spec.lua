return function(ns, env, R)
	local test, expect = R.test, R.expect

	math.randomseed(1234)
	local function randomBytes(n, alphabet)
		local t = {}
		for i = 1, n do
			t[i] = string.char(alphabet and alphabet[math.random(#alphabet)] or math.random(0, 255))
		end
		return table.concat(t)
	end

	local function freshLogin(db)
		ns.Storage.Load(db)
		ns:Fire(ns.E.DB_LOADED)
		local errors = env.takeErrors()
		expect.eq(#errors, 0, "errors on login: " .. tostring(errors[1]))
		return db
	end

	local function legacyProfile()
		return {
			namePlates = { nameFont = { size = 14, outline = "THICKOUTLINE" } },
			chat = { fadeMessages = false },
			unitFrames = { castbarHeight = 30 },
		}
	end

	test("Encode/Decode round-trip: empty, short, binary, text", function()
		for _, s in ipairs({ "", "a", "aaaaaaaaaaaaaaaaaaaaaaaaa", "\0\1\2\255", ("Привет, мир! "):rep(50) }) do
			expect.eq(ns.Decode(ns.Encode(s)), s)
		end
		for n = 1, 300 do
			local s = randomBytes(math.random(0, 2000))
			expect.eq(ns.Decode(ns.Encode(s)), s, "random #" .. n)
		end
	end)

	test("Encode/Decode round-trip past the 16-bit LZW dictionary limit", function()
		local s = randomBytes(400000, { 97, 98, 99, 100, 101, 102 })
		local encoded = ns.Encode(s)
		expect.eq(ns.Decode(encoded), s)
		expect.truthy(#encoded < #s, "compresses")
	end)

	test("Decode rejects corrupted strings", function()
		local encoded = ns.Encode(ns.Serialize(ns.Defaults))
		local bad = 0
		for _ = 1, 200 do
			local pos = math.random(2, #encoded)
			local c = encoded:sub(pos, pos)
			local repl = c == "a" and "b" or "a"
			if ns.Decode(encoded:sub(1, pos - 1) .. repl .. encoded:sub(pos + 1)) ~= nil then
				bad = bad + 1
			end
		end
		expect.eq(bad, 0, "corruptions accepted")
		expect.eq(ns.Decode("garbage!"), nil)
		expect.eq(select(2, ns.Decode("")), "malformed string")
	end)

	test("Serialize/Deserialize round-trip of the whole ns.Defaults tree", function()
		expect.deepEq(ns.Deserialize(ns.Serialize(ns.Defaults)), ns.Defaults)
	end)

	test("Serialize/Deserialize: tricky strings, keys, sparse arrays, numbers", function()
		local value = {
			'quote " and \\ backslash',
			"new\nline\r\t",
			"\0nul\1",
			"ünïcödé ЖЖ",
			'\\"',
			"",
			[10] = "sparse",
			[-1] = "negative key",
			[1.5] = "float key",
			[true] = "bool key",
			nested = { { 1, 2, { 3 } }, deep = { deeper = { deepest = false } } },
			n = { 0, -0.5, 1e-7, 123456789012, -1e300, 0.35, 1 / 3 * 3 },
		}
		expect.deepEq(ns.Deserialize(ns.Serialize(value)), value)
	end)

	test("Deserialize rejects trailing garbage and truncated input", function()
		expect.eq(ns.Deserialize("{1,2,3}x"), nil)
		expect.eq(ns.Deserialize("{1,2,"), nil)
		expect.eq(ns.Deserialize('{"abc}'), nil)
	end)

	test("Serialize/Deserialize: non-finite numbers survive a round-trip", function()
		local value = ns.Deserialize(ns.Serialize({ x = 1 / 0, y = -1 / 0 }))
		expect.truthy(value, "inf")
		expect.eq(value.x, 1 / 0)
		expect.eq(value.y, -1 / 0)
		expect.eq(ns.Deserialize(ns.Serialize({ 0 / 0 }))[1], 0, "nan")
	end)

	test("Serialize keeps full double precision", function()
		for _, x in ipairs({ 0.1 + 0.2, 1 / 3, 2 ^ 53 + 1, 1e-300, -123.456 }) do
			expect.eq(ns.Deserialize(ns.Serialize({ x }))[1], x)
		end
		expect.eq(ns.Serialize({ 0.1, 0.35, 12 }), "{0.1,0.35,12,}", "short form when exact")
	end)

	test("legacy SavedVariables (db.config) migrate to profiles and one-time flags", function()
		local db = freshLogin({ config = legacyProfile() })
		local p = db.profiles.Default
		expect.truthy(p, "Default profile created from db.config")
		expect.eq(db.config, nil, "db.config removed")
		expect.deepEq(p.namePlates.castbarFont, { size = 14, outline = "THICKOUTLINE" }, "castbar font")
		expect.eq(p.namePlates.arenaNumberFont.size, 17, "arena number font = name + 3")
		expect.eq(p.chat.fadeTime, 0, "fadeMessages=false -> fadeTime 0")
		expect.eq(p.chat.fadeMessages, nil, "merged toggle removed")
		expect.eq(p.unitFrames.castbarHeight, nil, "shared castbar height split")
		expect.eq(db.namePlateFontsMigrated, true)
		expect.eq(db.schemaVersion, 11)
		expect.deepEq(db.backup.profiles.Default, legacyProfile(), "backup before the upgrade")
		expect.eq(db.backup.schemaVersion, 0)
		expect.eq(ns:GetConfig("namePlates.castbarFont.size"), 14, "live config sees migrated value")
	end)

	test("a new installation gets the schema version and no backup", function()
		local db = freshLogin({})
		expect.eq(db.schemaVersion, 11)
		expect.eq(db.backup, nil)
		expect.eq(db.freshInstall, true)
	end)

	test("shared colors and castbar settings move from unitFrames to theme and castbar", function()
		local db = freshLogin({
			schemaVersion = 5,
			profiles = {
				Default = {
					unitFrames = { castbarColor = { 1, 0, 0 }, castbarInterrupter = false, playerWidth = 250 },
					baseline = { unitFrames = { textColor = { 0.5, 0.5, 0.5 } } },
				},
			},
		})
		local p = db.profiles.Default
		expect.eq(p.unitFrames.castbarColor, nil, "old key removed")
		expect.eq(p.unitFrames.playerWidth, 250, "other keys stay")
		expect.deepEq(ns:GetConfig("castbar.color"), { 1, 0, 0 })
		expect.eq(ns:GetConfig("castbar.interrupter"), false)
		expect.deepEq(ns:GetBaselineConfig("theme.textColor"), { 0.5, 0.5, 0.5 }, "baseline moves too")
		expect.eq(ns:IsDefaultConfig("theme.textColor"), true, "a baseline value stays without a blue dot")
	end)

	test("existing profiles keep every totem nameplate, new ones show the important totems", function()
		freshLogin({ schemaVersion = 6, profiles = { Default = { namePlates = { totemIcons = true } } } })
		expect.eq(ns:GetConfig("namePlates.totemFilter"), "all")
		expect.eq(ns:IsDefaultConfig("namePlates.totemFilter"), true, "kept as a baseline value")
		freshLogin({})
		expect.eq(ns:GetConfig("namePlates.totemFilter"), "important")
	end)

	test(
		"turning off the merchant automation no longer hides the merchant window features, old profiles keep them off",
		function()
			freshLogin({
				schemaVersion = 7,
				profiles = { Default = { merchant = { enabled = false, searchBox = true } } },
			})
			expect.eq(ns:GetConfig("merchant.wideFrame"), false)
			expect.eq(ns:GetConfig("merchant.showItemLevel"), false)
			expect.eq(ns:GetConfig("merchant.searchBox"), true, "an explicit value stays")
			freshLogin({ schemaVersion = 7, profiles = { Default = {} } })
			expect.eq(ns:GetConfig("merchant.wideFrame"), true)
		end
	)

	test("health text choices become tag strings that render the same text", function()
		local db = freshLogin({
			schemaVersion = 8,
			profiles = {
				Default = {
					raidFrames = { healthText = "deficit", width = 80 },
					namePlates = { healthTextFormat = "both", enemyPlayer = { healthText = "all" } },
					playerPlate = { healthText = "value" },
				},
				Plain = {
					raidFrames = { healthText = "none" },
					namePlates = { healthTextFormat = "percent" },
					playerPlate = { healthText = "percent" },
				},
				Kept = {
					raidFrames = { healthText = "percent" },
					namePlates = { healthTextFormat = "value" },
					baseline = { raidFrames = { healthText = "percent" }, playerPlate = { healthText = "value" } },
				},
				Bogus = { raidFrames = { healthText = "nope" } },
			},
		})
		local profiles = db.profiles
		expect.deepEq(profiles.Default.raidFrames, { healthTag = "[misshp:neg]", width = 80 })
		expect.deepEq(
			profiles.Default.namePlates,
			{ healthTag = "[curhp] | [perhp:floor]%", enemyPlayer = { healthText = "all" } }
		)
		expect.deepEq(profiles.Default.playerPlate, { healthTag = "[curhp]" })
		local empty = { raidFrames = {}, namePlates = {}, playerPlate = {} }
		expect.deepEq(profiles.Plain, empty, "old defaults leave nothing")
		expect.eq(profiles.Kept.raidFrames.healthTag, "[perhp]%")
		expect.eq(profiles.Kept.namePlates.healthTag, "[curhp]")
		expect.deepEq(
			profiles.Kept.baseline,
			{ raidFrames = { healthTag = "[perhp]%" }, playerPlate = { healthTag = "[curhp]" } }
		)
		expect.deepEq(profiles.Bogus.raidFrames, {}, "an unknown value falls back to the default")
		expect.eq(ns:GetConfig("raidFrames.healthTag"), "[misshp:neg]")
		expect.eq(ns:GetConfig("namePlates.healthTag"), "[curhp] | [perhp:floor]%")
		expect.eq(ns:GetConfig("namePlates.enemyPlayer.healthText"), "all", "where the text is shown stays")
		expect.eq(ns:GetConfig("playerPlate.healthTag"), "[curhp]")
		expect.eq(ns:GetConfig("raidFrames.healthText"), nil)
		expect.eq(ns:GetConfig("namePlates.healthTextFormat"), nil)
		freshLogin({})
		expect.eq(ns:GetConfig("raidFrames.healthTag"), "")
		expect.eq(ns:GetConfig("namePlates.healthTag"), "[perhp:floor]%")
		expect.eq(ns:GetConfig("playerPlate.healthTag"), "[perhp:floor]%")
	end)

	test("diminishing returns sides become an anchor point and a growth direction", function()
		local db = freshLogin({
			schemaVersion = 9,
			profiles = {
				Default = {
					diminishingReturns = { targetSide = "BOTTOM", partySide = "LEFT", size = 30 },
					baseline = { diminishingReturns = { arenaSide = "RIGHT" } },
				},
			},
		})
		expect.deepEq(db.profiles.Default.diminishingReturns, {
			targetAnchor = "BOTTOMRIGHT",
			targetGrowth = "LEFT",
			partyAnchor = "LEFT",
			partyGrowth = "LEFT",
			size = 30,
		})
		expect.eq(ns:GetConfig("diminishingReturns.arenaAnchor"), "RIGHT", "baseline moves too")
		expect.eq(ns:GetConfig("diminishingReturns.arenaGrowth"), "RIGHT")
		expect.eq(ns:GetConfig("diminishingReturns.arenaSide"), nil)
	end)

	test("tracker groups at the old default rows move up with the new defaults", function()
		local db = freshLogin({
			schemaVersion = 10,
			profiles = {
				Default = {
					trackers = {
						groups = {
							{ name = "Haste proc", point = { "CENTER", 0, -72 } },
							{ name = "Diseases", point = { "CENTER", 0, -42 } },
							{ name = "Moved", point = { "CENTER", 30, -72 } },
							{ name = "Anchored", point = { "CENTER", 0, -36, "minimap.point", "BOTTOM" } },
						},
					},
				},
			},
		})
		local groups = db.profiles.Default.trackers.groups
		expect.deepEq(groups[1].point, { "CENTER", 0, -62 })
		expect.deepEq(groups[2].point, { "CENTER", 0, -32 })
		expect.deepEq(groups[3].point, { "CENTER", 30, -72 }, "a moved group stays")
		expect.deepEq(groups[4].point, { "CENTER", 0, -36, "minimap.point", "BOTTOM" }, "an anchored group stays")
	end)

	test("old export strings bring their health text as tag strings", function()
		freshLogin({})
		local profile = { raidFrames = { healthText = "percent" }, playerPlate = { healthText = "value" } }
		local s = "FAUI2:" .. ns.Encode(ns.Serialize({ schemaVersion = 8, profile = profile }))
		expect.truthy(ns:ImportProfile(s))
		expect.eq(ns:GetConfig("raidFrames.healthTag"), "[perhp]%")
		expect.eq(ns:GetConfig("playerPlate.healthTag"), "[curhp]")
		local legacy = "FAUI1:" .. ns.Encode(ns.Serialize({ namePlates = { healthTextFormat = "value" } }))
		expect.truthy(ns:ImportProfile(legacy))
		expect.eq(ns:GetConfig("namePlates.healthTag"), "[curhp]")
		expect.eq(ns:GetConfig("raidFrames.healthTag"), "")
	end)

	test("a new installation gets the safe defaults", function()
		freshLogin({})
		expect.eq(ns:GetConfig("announce.interrupts"), false)
		expect.eq(ns:GetConfig("popups.fillDeleteConfirm"), false)
		expect.eq(ns:GetConfig("popups.autoAcceptInvites"), false)
		expect.eq(ns:GetConfig("tweaks.disableTutorials"), false)
		expect.eq(ns:GetConfig("actionBar.dragButton"), "LeftButton")
		expect.eq(ns:GetConfig("minimap.showZoneText"), true)
		expect.deepEq(ns:GetConfig("lossOfControl.point"), { "CENTER", 0, 90 })
		expect.deepEq(ns:GetConfig("tweaks.worldStatePoint"), { "TOP", 0, -24 })
		expect.eq(ns:GetConfig("tweaks.errorMessages"), "hidden")
		expect.eq(ns:GetConfig("general.uiScaleMode"), "game")
	end)

	test("an existing profile keeps the old comfort defaults, its own values win", function()
		local db = freshLogin({
			schemaVersion = 1,
			profiles = { Default = { announce = { interrupts = false }, minimap = { size = 180 } } },
		})
		expect.eq(db.freshInstall, nil)
		expect.eq(ns:GetConfig("announce.interrupts"), false, "own value")
		expect.eq(ns:GetConfig("announce.arenaResultToParty"), true)
		expect.eq(ns:GetConfig("popups.fillDeleteConfirm"), true)
		expect.eq(ns:GetConfig("tweaks.disableTutorials"), true)
		expect.eq(ns:GetConfig("actionBar.dragButton"), "RightButton")
		expect.eq(ns:GetConfig("actionBar.dragModifier"), "alt")
		expect.eq(ns:GetConfig("spellAlerts.zones.battleground"), true)
		expect.eq(ns:GetConfig("spellAlerts.zones.arena"), true)
		expect.eq(ns:GetConfig("minimap.showZoneText"), false)
		expect.eq(ns:GetConfig("minimap.size"), 180)
		expect.deepEq(ns:GetConfig("lossOfControl.point"), { "CENTER", 0, 0 })
		expect.eq(ns:GetConfig("tweaks.worldStatePoint")[4], "chat.point")
		expect.deepEq(ns:GetConfig("combatAlert.point"), { "CENTER", 0, 150 })
	end)

	test("paired toggles become one choice: UI scale and red errors", function()
		local db = freshLogin({
			schemaVersion = 2,
			profiles = {
				Default = {
					general = { useUiScale = true, uiScale = 0.8 },
					tweaks = { hideErrors = false },
				},
				Sharp = {
					general = { useUiScale = true, pixelPerfectScale = true },
					tweaks = { hideErrors = false, filterCooldownErrors = false },
				},
				Off = { general = { pixelPerfectScale = true }, tweaks = { filterCooldownErrors = false } },
			},
		})
		expect.deepEq(db.profiles.Default.general, { uiScaleMode = "custom", uiScale = 0.8 })
		expect.deepEq(db.profiles.Sharp.general, { uiScaleMode = "pixel" })
		expect.deepEq(db.profiles.Off.general, {})
		expect.eq(db.profiles.Default.tweaks.errorMessages, "filtered")
		expect.eq(db.profiles.Sharp.tweaks.errorMessages, "all")
		expect.eq(db.profiles.Off.tweaks.errorMessages, nil)
		expect.eq(db.profiles.Off.tweaks.filterCooldownErrors, nil)
		expect.eq(ns:GetConfig("general.uiScaleMode"), "custom")
		expect.eq(ns:GetConfig("tweaks.hideErrors"), nil)
	end)

	test("kept old defaults are the baseline, not own changes", function()
		local db = freshLogin({
			schemaVersion = 2,
			profiles = {
				Default = { announce = { interrupts = true, auraMastery = false }, tweaks = { scriptErrors = true } },
			},
		})
		local profile = db.profiles.Default
		expect.eq(profile.announce.interrupts, nil, "kept value moved")
		expect.eq(profile.announce.auraMastery, false, "own value stays")
		expect.eq(profile.baseline.announce.interrupts, true)
		expect.eq(profile.baseline.tweaks.scriptErrors, true)
		expect.deepEq(profile.baseline.lossOfControl.point, { "CENTER", 0, 0 })
		expect.eq(ns:GetConfig("announce.interrupts"), true)
		expect.truthy(ns:IsDefaultConfig("announce.interrupts"), "no own change")
		expect.eq(ns:GetBaselineConfig("announce.interrupts"), true)
		expect.eq(ns:GetFactoryConfig("announce.interrupts"), false)
	end)

	test("reset goes to the baseline, a factory reset drops it", function()
		freshLogin({ schemaVersion = 3, profiles = { Default = { announce = { interrupts = true } } } })
		ns:SetConfig("announce.interrupts", false)
		expect.eq(ns:IsDefaultConfig("announce.interrupts"), false)
		ns:ResetConfig("announce.interrupts")
		expect.eq(ns:GetConfig("announce.interrupts"), true, "back to the kept value")
		expect.truthy(ns:IsDefaultConfig("announce.interrupts"))
		ns:ResetConfig("announce.interrupts", "factory")
		expect.eq(ns:GetConfig("announce.interrupts"), false)
		expect.eq(ns:GetBaselineConfig("announce.interrupts"), nil)
		ns:ResetConfig("announce")
		expect.deepEq(ns:GetConfig("announce"), ns.Defaults.announce)
	end)

	test("a section reset keeps the baseline values inside it", function()
		freshLogin({ schemaVersion = 3, profiles = { Default = { announce = { interrupts = true } } } })
		ns:SetConfig("announce.arenaResultToParty", false)
		ns:ResetConfig("announce")
		expect.eq(ns:GetConfig("announce.interrupts"), true)
		expect.eq(ns:GetConfig("announce.arenaResultToParty"), ns.Defaults.announce.arenaResultToParty)
	end)

	test("SetBaselineConfig replaces the own value and survives a login", function()
		local db = freshLogin({})
		ns:SetConfig("minimap.size", 200)
		ns:SetBaselineConfig("minimap.size", 180)
		expect.eq(ns:GetConfig("minimap.size"), 180)
		expect.truthy(ns:IsDefaultConfig("minimap.size"))
		ns:SetConfig("minimap.size", 210)
		freshLogin(db)
		expect.eq(ns:GetConfig("minimap.size"), 210, "own value over the baseline")
		ns:ResetConfig("minimap.size")
		expect.eq(ns:GetConfig("minimap.size"), 180)
		ns:SetBaselineConfig("minimap.size", nil)
		expect.eq(ns:GetConfig("minimap.size"), ns.Defaults.minimap.size)
	end)

	test("export keeps the baseline apart, only my changes leaves it out", function()
		freshLogin({})
		ns:SetBaselineConfig("minimap.size", 180)
		ns:SetConfig("chat.fadeTime", 7)
		local full, mine = ns:ExportProfile(), ns:ExportProfile(true)
		freshLogin({})
		expect.truthy(ns:ImportProfile(full))
		expect.eq(ns:GetConfig("minimap.size"), 180)
		expect.truthy(ns:IsDefaultConfig("minimap.size"), "still a baseline value")
		expect.eq(ns:GetConfig("chat.fadeTime"), 7)
		freshLogin({})
		expect.truthy(ns:ImportProfile(mine))
		expect.eq(ns:GetConfig("minimap.size"), ns.Defaults.minimap.size)
		expect.eq(ns:GetConfig("chat.fadeTime"), 7)
	end)

	test("an imported baseline drops unknown keys and wrong types", function()
		freshLogin({})
		local profile =
			{ baseline = { minimap = { size = "big", bogus = 1 }, notAModule = {}, chat = { fadeTime = 3 } } }
		expect.truthy(ns:ImportProfile("FAUI2:" .. ns.Encode(ns.Serialize({ schemaVersion = 4, profile = profile }))))
		expect.eq(ns:GetConfig("minimap.size"), ns.Defaults.minimap.size)
		expect.eq(ns:GetConfig("chat.fadeTime"), 3)
		expect.eq(ns:GetBaselineConfig("minimap.bogus"), nil)
	end)

	test("a FAUI1 string keeps the old comfort defaults too", function()
		freshLogin({})
		expect.truthy(ns:ImportProfile("FAUI1:" .. ns.Encode(ns.Serialize({ minimap = { size = 190 } }))))
		expect.eq(ns:GetConfig("popups.autoAcceptInvites"), true)
		expect.eq(ns:GetConfig("minimap.size"), 190)
	end)

	test("migrations run once: a later login does not touch the profile", function()
		local db = freshLogin({ config = legacyProfile() })
		db.profiles.Default.chat.fadeMessages = false
		freshLogin(db)
		expect.eq(db.profiles.Default.chat.fadeMessages, false)
	end)

	test("settings from a newer schema are not migrated", function()
		local db = freshLogin({ schemaVersion = 99, profiles = { Default = legacyProfile() } })
		expect.eq(db.schemaVersion, 99)
		expect.deepEq(db.profiles.Default, legacyProfile())
		expect.eq(db.backup, nil)
	end)

	test("RestoreBackup brings back the profiles and flags from before the upgrade", function()
		local db = freshLogin({ config = legacyProfile() })
		ns:SetConfig("minimap.size", 205)
		expect.truthy(ns:GetBackupTime(), "backup time")
		expect.truthy(ns:RestoreBackup())
		expect.deepEq(db.profiles.Default, legacyProfile())
		expect.eq(db.schemaVersion, 0)
		expect.eq(db.namePlateFontsMigrated, nil)
		expect.eq(db.backup, nil)
		expect.eq((ns:RestoreBackup()), false, "only once")
		freshLogin(db)
		expect.eq(ns:GetConfig("namePlates.castbarFont.size"), 14, "upgraded again on the next login")
	end)

	test("migrations are idempotent across logins", function()
		local db = freshLogin({ config = legacyProfile() })
		local snapshot = CopyTable(db)
		freshLogin(db)
		expect.deepEq(db, snapshot)
	end)

	test("SetConfig -> ExportProfile -> ImportProfile restores the value", function()
		freshLogin({})
		ns:SetConfig("minimap.size", 222)
		local exported = ns:ExportProfile()
		expect.truthy(exported:find("^FAUI2:"), "prefix")
		ns:SetConfig("minimap.size", 150)
		local ok, err = ns:ImportProfile(exported)
		expect.truthy(ok, err)
		expect.eq(ns:GetConfig("minimap.size"), 222)
	end)

	test("ImportProfile drops unknown keys and rejects foreign strings", function()
		freshLogin({})
		local s = "FAUI1:" .. ns.Encode(ns.Serialize({ minimap = { size = 300, bogus = 1 }, notAModule = {} }))
		expect.truthy(ns:ImportProfile(s))
		expect.eq(ns:GetConfig("minimap.size"), 300)
		expect.eq(ns:GetConfig("minimap.bogus"), nil)
		expect.eq((ns:ImportProfile("hello")), false)
	end)

	local function exportString(data)
		return "FAUI1:" .. ns.Encode(ns.Serialize(data))
	end

	local function schemaString(version, profile)
		return "FAUI2:" .. ns.Encode(ns.Serialize({ schemaVersion = version, profile = profile }))
	end

	test("a profile loaded from SavedVariables and its export imported elsewhere give the same config", function()
		freshLogin({ config = legacyProfile() })
		ns:SetConfig("minimap.size", 233)
		local fromLogin = CopyTable(ns.Config)
		local exported = ns:ExportProfile()
		local payload = ns.Deserialize(ns.Decode(exported:sub(7)))
		expect.eq(payload.schemaVersion, 11)
		freshLogin({})
		local ok, warning = ns:ImportProfile(exported)
		expect.truthy(ok, warning)
		expect.eq(warning, nil)
		expect.deepEq(ns.Config, fromLogin)
	end)

	test("FAUI2 import does not rerun migrations of its own schema version", function()
		freshLogin({})
		local profile = { unitFrames = { playerWidth = 300, targetCastbarWidth = 99 }, chat = { fadeTime = 5 } }
		expect.truthy(ns:ImportProfile(schemaString(2, profile)))
		expect.eq(ns:GetConfig("unitFrames.targetCastbarWidth"), 99)
		expect.deepEq(ns:GetConfig("unitFrames.targetCastbar"), ns.Defaults.unitFrames.targetCastbar)
		expect.eq(ns:GetConfig("chat.fadeTime"), 5)
	end)

	test("FAUI2 import rejects a payload without a profile or a version", function()
		freshLogin({})
		expect.eq((ns:ImportProfile("FAUI2:" .. ns.Encode(ns.Serialize({ profile = {} })))), false)
		expect.eq((ns:ImportProfile("FAUI2:" .. ns.Encode(ns.Serialize({ schemaVersion = 1 })))), false)
		expect.eq((ns:ImportProfile(schemaString(1.5, {}))), false, "fractional version")
	end)

	test("FAUI2 import from a newer schema warns", function()
		freshLogin({})
		local ok, warning = ns:ImportProfile(schemaString(99, { minimap = { size = 240 } }))
		expect.truthy(ok)
		expect.truthy(warning, "warning")
		expect.eq(ns:GetConfig("minimap.size"), 240)
	end)

	test("FAUI1 import runs only the repeatable migrations and warns", function()
		freshLogin({})
		ns:SetConfig("unitFrames.targetCastbarWidth", 77)
		local profile = { unitFrames = { playerWidth = 300, targetCastbarWidth = 99 }, chat = { fadeMessages = false } }
		local ok, warning = ns:ImportProfile(exportString(profile))
		expect.truthy(ok)
		expect.truthy(warning, "warning")
		expect.eq(ns:GetConfig("unitFrames.targetCastbarWidth"), 99)
		expect.eq(ns:GetConfig("chat.fadeTime"), 0, "merged toggle migrated")
	end)

	test("import drops values whose type does not match the defaults", function()
		freshLogin({})
		local s = exportString({ minimap = 5, chat = { fadeTime = "slow" }, tooltip = { showIds = "yes" } })
		expect.truthy(ns:ImportProfile(s))
		expect.eq(type(ns.Config.minimap), "table", "section kept")
		expect.eq(ns:GetConfig("chat.fadeTime"), ns.Defaults.chat.fadeTime, "string in a number")
		expect.eq(ns:GetConfig("tooltip.showIds"), "yes", "booleans may hold sentinels")
	end)

	test("a corrupted saved profile does not replace sections with scalars", function()
		freshLogin({ profiles = { Default = { minimap = 5, chat = { fadeTime = {} } } } })
		expect.eq(type(ns.Config.minimap), "table")
		expect.eq(ns:GetConfig("chat.fadeTime"), ns.Defaults.chat.fadeTime)
	end)

	test("a failing migration of one profile does not stop activation", function()
		local db = {
			profiles = { Default = { minimap = { size = 210 } }, Broken = { unitFrames = 7 } },
		}
		ns.Storage.Load(db)
		ns:Fire(ns.E.DB_LOADED)
		env.takeErrors()
		expect.eq(ns:GetConfig("minimap.size"), 210)
	end)

	test("WatchConfig: an error in one watcher does not silence the others", function()
		freshLogin({})
		local failing = ns:NewModule("TestWatchFailing")
		local healthy = ns:NewModule("TestWatchHealthy")
		local failed, ran = 0, {}
		failing:WatchConfig("minimap", function()
			failed = failed + 1
			error("watcher fails")
		end)
		healthy:WatchConfig("minimap", function(_, path)
			ran[#ran + 1] = path
		end)
		ns:SetConfig("minimap.size", 201)
		env.tick(0)
		ns:SetConfig("minimap.size", 202)
		env.tick(0)
		failing:UnregisterAllEvents()
		healthy:UnregisterAllEvents()
		expect.eq(failed, 2)
		expect.eq(table.concat(ran, ","), "minimap.size,minimap.size")
		expect.eq(#env.takeErrors(), 2)
	end)

	test("NewProfile copies the active profile with its layout base, or starts empty", function()
		local db = freshLogin({ layoutBase = { Default = "preset:classic" } })
		ns:SetConfig("minimap.size", 205)
		ns:SetBaselineConfig("unitFrames.targetWidth", 230)
		expect.truthy(ns:NewProfile("Copy"), "copy created")
		expect.eq(ns:GetActiveProfile(), "Copy")
		expect.eq(ns:GetConfig("minimap.size"), 205)
		expect.eq(ns:GetBaselineConfig("unitFrames.targetWidth"), 230)
		expect.eq(db.layoutBase.Copy, "preset:classic")
		ns:SetConfig("minimap.size", 190)
		expect.eq(db.profiles.Default.minimap.size, 205, "the copy is separate")
		expect.truthy(ns:NewProfile("Empty", true), "empty created")
		expect.eq(ns:GetConfig("minimap.size"), ns.Defaults.minimap.size)
		expect.eq(ns:NewProfile("Copy"), false, "an existing name is refused")
	end)

	test("RenameProfile moves characters, the default profile, the layout base and the backups", function()
		local db = freshLogin({ layoutBase = { Default = "preset:classic" }, snapshots = { Default = { {} } } })
		db.defaultProfile = "Default"
		db.charProfile.Other = "Default"
		expect.truthy(ns:RenameProfile("Default", "Main"), "renamed")
		expect.eq(ns:GetActiveProfile(), "Main")
		expect.eq(db.profiles.Default, nil)
		expect.truthy(db.profiles.Main, "profile moved")
		expect.eq(db.charProfile.Other, "Main")
		expect.eq(db.defaultProfile, "Main")
		expect.eq(db.layoutBase.Main, "preset:classic")
		expect.eq(#db.snapshots.Main, 1)
		ns:SetConfig("minimap.size", 207)
		expect.eq(db.profiles.Main.minimap.size, 207, "still the active profile")
		expect.eq(ns:RenameProfile("Main", "Main"), false)
	end)
end
