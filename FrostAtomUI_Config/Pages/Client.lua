local _, ns = ...

local L = FrostAtomUI.L

local Section = ns.Section

local NEW = "1.5.0"
local ui = FrostAtomUI
local DIALOG_WIDTH, PADDING, LINE = 460, 20, 24

local dialog

local function itemText(item)
	if item.binding then
		return L["Mouse button 5: focus mouseover set by FrostAtom UI, will be unbound"]
	elseif item.key == "uiScale" then
		return L["UI scale: %s now, %s before"]:format(item.now, tostring(item.was))
	end
	return L["%s (%s): %s now, %s before"]:format(ns.SettingLabel(item.path), item.name, item.now, item.was)
end

local function createDialog()
	dialog = ns.CreateWindow(nil, {
		width = DIALOG_WIDTH,
		height = 200,
		header = true,
		strata = "FULLSCREEN_DIALOG",
		noClose = true,
		movable = false,
	})
	dialog:SetPoint("CENTER")
	dialog.heading:SetText(L["Restore game settings"])
	local shade = dialog:CreateTexture(nil, "BACKGROUND")
	shade:SetTexture(0, 0, 0, 0.92)
	shade:SetPoint("TOPLEFT", 4, -4)
	shade:SetPoint("BOTTOMRIGHT", -4, 4)
	local text = dialog:CreateFontString(nil, "ARTWORK")
	text:SetFontObject(ns.Font("GameFontHighlight"))
	text:SetPoint("TOPLEFT", PADDING, -42)
	text:SetWidth(DIALOG_WIDTH - PADDING * 2)
	text:SetJustifyH("LEFT")
	text:SetText(
		L["Checked settings go back to what they were before FrostAtom UI, and the options that set them are turned off. A backup is saved first."]
	)
	dialog.text = text
	dialog.checks = {}
	local cancel = ns.CreateButton(dialog, CANCEL, 96)
	cancel:SetPoint("BOTTOMRIGHT", -PADDING, 16)
	cancel:SetScript("OnClick", function()
		dialog:Hide()
	end)
	local accept = ns.CreateButton(dialog, L["Restore"], 120)
	accept:SetPoint("RIGHT", cancel, "LEFT", -4, 0)
	accept:SetScript("OnClick", function()
		local keys = {}
		for _, check in ipairs(dialog.checks) do
			if check:IsShown() and check:GetChecked() then
				keys[check.key] = true
			end
		end
		if ui.RestoreGameSettings(keys) then
			dialog:Hide()
		end
	end)
end

local function showRestoreDialog()
	local list = ui.GetGameSettingChanges()
	if #list == 0 then
		ui.Print(L["game settings are already as before FrostAtom UI"])
		return
	end
	if not dialog then
		createDialog()
	end
	for _, check in ipairs(dialog.checks) do
		check:Hide()
	end
	dialog:Show()
	local top = 42 + dialog.text:GetStringHeight() + 10
	for index, item in ipairs(list) do
		local check = dialog.checks[index]
		if not check then
			check = ui.CreateCheckButton(dialog, "", nil, true)
			dialog.checks[index] = check
		end
		check.key = item.key
		check:SetLabel(itemText(item))
		check:SetChecked(true)
		check:ClearAllPoints()
		check:SetPoint("TOPLEFT", PADDING - 4, -top - (index - 1) * LINE)
		check:Show()
	end
	dialog:SetHeight(top + #list * LINE + 60)
end

local schema = {
	{
		path = "tweaks.enabled",
		label = L["Enable tweaks"],
		type = "toggle",
		noReset = true,
		desc = L["Hidden game settings: camera, controls, graphics, sound. Turning this off restores the values you had before FrostAtom UI."],
	},
	{
		path = "tweaks.disableTutorials",
		new = "1.5.0",
		label = L["Disable Blizzard tutorials"],
		type = "toggle",
		enabledBy = "tweaks.enabled",
		desc = L["Turns off the game's tutorial tips. The game keeps this for every character on this computer; unticking turns them back on."],
	},
	{
		label = L["Restore game settings"],
		type = "execute",
		text = L["Restore..."],
		glyph = "clock-rotate-left",
		func = showRestoreDialog,
		desc = L["Game settings (CVars), the UI scale and mouse button 5 go back to what they were before FrostAtom UI. Before removing the addon, press this: the grass, Blizzard tips, the UI scale and the side mouse button come back."],
	},
}

local function cameraKey(binding)
	return {
		type = "keybind",
		binding = binding,
		label = L["Key binding"],
		indent = true,
		new = NEW,
		desc = L["Left-click, then press a key or mouse button to bind it."] .. "\n" .. L["Right-click to clear."],
	}
end

Section(schema, L["Camera"], "tweaks", {
	{
		path = "cameraDistanceMax",
		label = L["Max camera distance"],
		type = "number",
		min = 10,
		max = 50,
		step = 1,
		desc = L["How far the camera can zoom out."],
	},
	{
		path = "cameraZoomSpeed",
		advanced = true,
		new = NEW,
		label = L["Zoom speed"],
		type = "number",
		min = 1,
		max = 50,
		step = 1,
		desc = L["How fast the mouse wheel zooms the camera. 50 is almost instant. Game default: 8.33."],
	},
	{
		path = "cameraYawSpeed",
		advanced = true,
		new = NEW,
		label = L["Mouse look speed: horizontal"],
		type = "number",
		min = 30,
		max = 360,
		step = 5,
		desc = L["Turn speed while holding a mouse button. The game options limit it to 90 - 270. Game default: 180."],
	},
	{
		path = "cameraPitchSpeed",
		advanced = true,
		new = NEW,
		label = L["Mouse look speed: vertical"],
		type = "number",
		min = 30,
		max = 360,
		step = 5,
		desc = L["Up and down speed while holding a mouse button, separate from the horizontal one. Game default: 90."],
	},
	{
		path = "cameraFollowStyle",
		advanced = true,
		new = NEW,
		label = L["Camera following style"],
		type = "select",
		values = {
			{ "", L["Game setting"] },
			{ "1", CAMERA_SMART },
			{ "4", CAMERA_SMARTER },
			{ "2", CAMERA_ALWAYS },
			{ "3", L["Always adjust camera, smoother"] },
			{ "0", CAMERA_NEVER },
		},
		desc = L["How the camera turns behind the character on its own. The last style is hidden in the game options."],
	},
	{
		path = "cameraFollowTime",
		advanced = true,
		new = NEW,
		label = L["Camera following time"],
		type = "number",
		min = 0.1,
		max = 2,
		step = 0.1,
		unit = "s",
		desc = L["Longest time the camera takes to turn behind the character. Game default: 2 s."],
	},
	{
		path = "keepCameraPitch",
		advanced = true,
		new = NEW,
		label = L["Keep camera pitch"],
		type = "toggle",
		desc = L["The camera still turns behind the character but no longer changes the vertical angle you set."],
	},
	{
		path = "instantCameraHeight",
		advanced = true,
		new = NEW,
		label = L["Instant camera height"],
		type = "toggle",
		desc = L["The camera jumps to the new height right away when you shapeshift or mount instead of sliding."],
	},
}, nil, nil, "camera")

local cameraPresets = {
	{
		description = L["Keys that snap the camera to these distances. Also in Key Bindings > FrostAtomUI."],
	},
}
for _, preset in ipairs({
	{ "Close", L["Close camera distance"], L["Distance the Close camera distance key binding snaps to."] },
	{ "Medium", L["Medium camera distance"], L["Distance the Medium camera distance key binding snaps to."] },
	{ "Far", L["Far camera distance"], L["Distance the Far camera distance key binding snaps to."] },
}) do
	cameraPresets[#cameraPresets + 1] = {
		path = "cameraDistance" .. preset[1],
		advanced = true,
		label = preset[2],
		type = "number",
		min = 0,
		max = 50,
		step = 1,
		desc = preset[3],
	}
	local key = cameraKey("FROSTATOMUI_CAMERA_" .. preset[1]:upper())
	key.advanced = true
	cameraPresets[#cameraPresets + 1] = key
end
cameraPresets[#cameraPresets + 1] = {
	path = "instantCameraCollision",
	advanced = true,
	label = L["Instant return after collision"],
	type = "toggle",
	new = NEW,
	desc = L["After a preset key the camera holds that distance: when terrain or a wall stops blocking it, it jumps straight back instead of sliding out over 2 seconds. Mouse wheel zoom, a camera view change or a vehicle ends it until the next preset key. Made for camera following set to Never: smooth turning behind the character gets jerky."],
}

Section(schema, L["Camera distance presets"], "tweaks", cameraPresets, nil, nil, "magnifying-glass-plus")

local function customMouseSpeedOff()
	return FrostAtomUI:GetConfig("tweaks.mouseSpeedMode") ~= "custom"
end

Section(schema, L["Controls"], "tweaks", {
	{
		path = "mouseSpeedMode",
		label = L["Mouse speed"],
		type = "select",
		values = {
			{ "", L["Game setting"], L["The speed from the game's mouse options."] },
			{
				"windows",
				L["Same as Windows"],
				L["Keeps the pointer speed you set in Windows exactly; the game's own slider rounds some values down a step."],
			},
			{ "custom", L["Custom"], L["The speed set below."] },
		},
		desc = L["The game sets the Windows pointer speed while its window is active and puts the Windows one back on Alt+Tab and exit."],
	},
	{
		path = "mouseSpeed",
		label = L["Custom mouse speed"],
		type = "number",
		min = 0.1,
		max = 2,
		step = 0.1,
		disabled = customMouseSpeedOff,
		disabledDesc = L['Pick "Custom" in Mouse speed.'],
		desc = L["1 is the Windows default. The game options limit it to 0.5 - 1.5."],
	},
	{
		path = "keepShapeshift",
		new = NEW,
		label = L["Keep shapeshift form on cast"],
		type = "toggle",
		desc = L["A spell that can't be cast in the current form or stance shows an error instead of leaving the form."],
	},
	{
		path = "keepMount",
		new = NEW,
		label = L["Stay mounted on cast"],
		type = "toggle",
		desc = L["Casting while mounted shows an error instead of dismounting. The game options only have this for flying."],
	},
	{
		path = "keepSitting",
		advanced = true,
		new = NEW,
		label = L["Keep sitting on cast"],
		type = "toggle",
		desc = L["Casting while sitting shows an error instead of standing up, so a misclick doesn't interrupt eating or drinking."],
	},
	{
		type = "keybind",
		binding = FrostAtomUI.FOCUS_BINDING,
		label = L["Focus mouseover"],
		new = NEW,
		desc = L["Sets focus to the unit under the cursor, also in combat."]
			.. "\n"
			.. L["Left-click, then press a key or mouse button to bind it."]
			.. "\n"
			.. L["Right-click to clear."],
	},
}, nil, NEW, "computer-mouse")

Section(schema, L["Graphics"], "tweaks", {
	{
		path = "hideScreenEffects",
		new = NEW,
		label = L["Hide full screen effects"],
		type = "toggle",
		desc = L["Turns off glow, the grey death screen and the invisibility haze at once. Slightly raises FPS."],
	},
	{
		path = "hideInvisibilityEffect",
		advanced = true,
		new = NEW,
		label = L["Hide invisibility haze"],
		type = "toggle",
		desc = L["Only the purple full screen haze while you are invisible, keeping glow."],
	},
	{
		path = "characterAmbient",
		advanced = true,
		new = NEW,
		label = L["Character brightness"],
		type = "number",
		min = 0,
		max = 1,
		step = 0.05,
		percent = true,
		zeroText = L["Off"],
		desc = L["Lights players and creatures up in dark zones and arenas. Off keeps the zone lighting."],
	},
	{
		path = "hideSunGlare",
		label = L["Hide sun glare"],
		type = "toggle",
		desc = L["The bright glare when the camera faces the sun."],
	},
	{
		path = "hideGroundClutter",
		label = L["Hide ground clutter"],
		type = "toggle",
		desc = L["Grass and other ground decorations. Turning it off restores the game default."],
	},
	{
		path = "hideSelectionCircle",
		advanced = true,
		new = NEW,
		label = L["Hide target selection circle"],
		type = "toggle",
		desc = L["The ring on the ground under the target."],
	},
	{
		path = "hideUnitHighlight",
		advanced = true,
		new = NEW,
		label = L["Hide model highlight"],
		type = "toggle",
		desc = L["The glow on the 3D model of the target and the unit under the cursor."],
	},
	{
		path = "allSpellMechanics",
		new = NEW,
		label = L["Crowd control text over every unit"],
		type = "toggle",
		desc = L['Floating "Stunned", "Rooted" and similar text over every unit, not only you and your target.'],
	},
	{
		path = "fullViewDistance",
		advanced = true,
		new = NEW,
		label = L["Full view distance on old maps"],
		type = "toggle",
		desc = L["Without it view distance is capped at 791 yards on old continents and battlegrounds such as Alterac Valley, Warsong Gulch and Arathi Basin."],
	},
}, nil, NEW, "image")

Section(schema, L["Performance"], "tweaks", {
	{
		label = L["Arena performance"],
		type = "execute",
		text = L["Apply"],
		glyph = "bolt",
		new = NEW,
		enabledBy = "tweaks.enabled",
		desc = L["Models load in 25 ms per frame (no freeze when players appear), grass and full screen glow are hidden. One step of Undo; the model loading time needs a game restart."],
		func = function()
			ui.Undo.Run(L["Arena performance"], function()
				ui:SetConfig("tweaks.assetLoadTime", 25)
				ui:SetConfig("tweaks.hideGroundClutter", true)
				ui:SetConfig("tweaks.hideScreenEffects", true)
			end)
		end,
	},
	{
		path = "maxFPS",
		new = NEW,
		label = L["Max FPS"],
		type = "number",
		min = 0,
		max = 300,
		step = 5,
		zeroText = L["Off"],
		desc = L["The cap is rounded to whole milliseconds per frame, so 144 gives about 152. Game default: 200."],
	},
	{
		path = "maxFPSBackground",
		advanced = true,
		new = NEW,
		label = L["Max FPS in background"],
		type = "number",
		min = 0,
		max = 300,
		step = 5,
		zeroText = L["Off"],
		desc = L["Limit while the game window is not focused. Game default: 30."],
	},
	{
		path = "assetLoadTime",
		advanced = true,
		new = NEW,
		label = L["Model loading time per frame"],
		type = "number",
		min = 20,
		max = 250,
		step = 5,
		unit = "ms",
		desc = L["Milliseconds per frame the game spends on freshly loaded models and textures. 20 - 30 avoids freezes when players appear at the start of an arena or battleground. Needs a game restart. Game default: 100."],
	},
	{
		path = "timingMethod",
		advanced = true,
		label = L["Clock source"],
		type = "select",
		values = {
			{ "", L["Game setting"] },
			{ "2", L["High precision"], L["Can fix stutter and uneven movement on some processors."] },
			{ "1", L["System"], L["The fallback when high precision makes things worse."] },
		},
		desc = L["Clock the game runs on. Needs a game restart."],
	},
}, nil, NEW, "gauge-high")

Section(schema, L["Sound"], "tweaks", {
	{
		path = "muteArmorFoley",
		new = NEW,
		label = L["Mute armor rustle"],
		type = "toggle",
		desc = L["The armor sound of you and other players moving."],
	},
	{
		path = "soundAtHead",
		advanced = true,
		label = L["Hear from your character's head"],
		type = "toggle",
		desc = L["The game places your ears 2 yards behind and 4 above your character. This puts them in the head, so footsteps and casts around you come from a more exact direction. Only with the Sound at Character audio option on."],
	},
}, nil, NEW, "volume-high")

schema[#schema + 1] = { header = L["Reliability"], glyph = "screwdriver-wrench", hidden = not ui.IS_WOWCIRCLE }
if ui.IS_WOWCIRCLE then
	schema[#schema + 1] = {
		path = "combatLogFix.enabled",
		label = L["Fix stalled combat log"],
		type = "toggle",
		desc = L["Clear the combat log when it stops delivering events inside instances."],
	}
end

ns.RegisterPage({
	key = "client",
	name = L["Game client"],
	desc = L["Game settings FrostAtom UI can change, and how to bring them back."],
	glyph = "display",
	new = NEW,
	order = 64,
	group = "system",
	schema = schema,
})
