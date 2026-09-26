local _, ns = ...

local L = FrostAtomUI.L

local Section = ns.Section

local NEW = "1.4.1"

local schema = {
	{
		path = "tweaks.enabled",
		label = L["Enable tweaks"],
		type = "toggle",
		reload = true,
		noReset = true,
		desc = L["The same switch as Quality of life > Tweaks > Enable. Every setting on this page needs it."],
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

Section(schema, L["Camera distance presets"], "tweaks", {
	{
		description = L["Keys that snap the camera to these distances. Also in Key Bindings > FrostAtomUI."],
	},
	{
		path = "cameraDistanceClose",
		label = L["Close camera distance"],
		type = "number",
		min = 0,
		max = 50,
		step = 1,
		desc = L["Distance the Close camera distance key binding snaps to."],
	},
	cameraKey("FROSTATOMUI_CAMERA_CLOSE"),
	{
		path = "cameraDistanceMedium",
		label = L["Medium camera distance"],
		type = "number",
		min = 0,
		max = 50,
		step = 1,
		desc = L["Distance the Medium camera distance key binding snaps to."],
	},
	cameraKey("FROSTATOMUI_CAMERA_MEDIUM"),
	{
		path = "cameraDistanceFar",
		label = L["Far camera distance"],
		type = "number",
		min = 0,
		max = 50,
		step = 1,
		desc = L["Distance the Far camera distance key binding snaps to."],
	},
	cameraKey("FROSTATOMUI_CAMERA_FAR"),
}, nil, nil, "magnifying-glass-plus")

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
		new = NEW,
		label = L["Keep sitting on cast"],
		type = "toggle",
		desc = L["Casting while sitting shows an error instead of standing up, so a misclick doesn't interrupt eating or drinking."],
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

ns.RegisterPage({
	key = "client",
	name = L["Game client"],
	glyph = "display",
	new = NEW,
	order = 62,
	group = "system",
	schema = schema,
})
