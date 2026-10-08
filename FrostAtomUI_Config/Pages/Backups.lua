local _, ns = ...

local ui = FrostAtomUI
local L = ui.L

local PIN_COLOR = { 1, 0.82, 0 }
local UNPINNED_COLOR = { 0.45, 0.45, 0.45 }

local REASONS = {
	session = L["Session start"],
	resetPage = L['Before resetting "%s"'],
	resetProfile = L["Before resetting the profile"],
	positions = L["Before moving all frames back"],
	import = L["Before importing a profile"],
	copy = L['Before copying the "%s" profile'],
	layout = L['Before applying the "%s" layout'],
	restore = L["Before restoring a backup"],
	gameSettings = L["Before restoring game settings"],
	setup = L["Before setup"],
	style = L['Before applying the "%s" style'],
	whatsNew = L["Before the recommended values"],
	blizzardUI = L["Before bringing back the Blizzard interface"],
}

local function reasonText(item)
	if item.reason == "manual" then
		return item.detail and L['Saved by hand: "%s"']:format(item.detail) or L["Saved by hand"]
	end
	local text = REASONS[item.reason] or tostring(item.reason)
	return text:find("%%s") and text:format(item.detail or "?") or text
end

local function timeText(stamp)
	if date("%Y-%m-%d", stamp) == date("%Y-%m-%d") then
		return date("%H:%M", stamp)
	end
	return date("%d.%m %H:%M", stamp)
end

local function restore(item)
	ns.Confirm(L["Restore this copy of the profile? The current settings are saved as a backup first."], function()
		if ui.Undo.RestoreSnapshot(item) then
			ui.Print(L["profile restored from the copy made at %s"], timeText(item.time))
		else
			ui.Print(L["this copy cannot be restored"])
		end
	end)
end

local function remove(item)
	if item.manual or item.pinned then
		ns.Confirm(L['Delete the copy "%s"?']:format(reasonText(item)), function()
			ui.Undo.DeleteSnapshot(item)
		end)
	else
		ui.Undo.DeleteSnapshot(item)
	end
end

local function paintPin(button, item)
	local color = item.pinned and PIN_COLOR or UNPINNED_COLOR
	button.color = color
	button:Paint()
end

local function snapshotEntry(item)
	return {
		type = "custom",
		label = ("%s   %s"):format(timeText(item.time), reasonText(item)),
		desc = item.version and L["FrostAtom UI %s"]:format(item.version) or nil,
		build = function(row)
			local button = ns.CreateButton(row, L["Restore"], 110, nil, nil, "clock-rotate-left")
			button:SetPoint("LEFT", row, "LEFT", ns.CONTROL_X + 6, 0)
			button:SetScript("OnClick", function()
				restore(item)
			end)

			local pin = ui.CreateGlyphButton(row, "thumbtack", 12, L["Pin"])
			pin.tooltipText = L["A pinned copy is kept until you delete it; automatic copies keep only the last 10."]
			pin:SetPoint("LEFT", button, "RIGHT", 12, 0)
			pin:SetScript("OnClick", function()
				ui.Undo.PinSnapshot(item, not item.pinned)
			end)
			paintPin(pin, item)

			local delete = ui.CreateGlyphButton(row, "xmark", 12, DELETE)
			delete:SetPoint("LEFT", pin, "RIGHT", 10, 0)
			delete:SetScript("OnClick", function()
				remove(item)
			end)
		end,
	}
end

local function buildSchema()
	local schema = {
		{ header = L['Backups of the "%s" profile']:format(ui:GetActiveProfile()), glyph = "clock-rotate-left" },
		{
			description = L["A copy of the profile is saved before a reset, an import, a layout and before the first change in each session. The last 10 automatic copies are kept; pinned copies and copies saved by hand stay until you delete them."],
		},
		{
			label = L["Save a copy now"],
			type = "input",
			text = L["Save"],
			glyph = "floppy-disk",
			width = 160,
			maxLetters = 32,
			func = function(name)
				ui.Undo.Snapshot("manual", name, true)
			end,
			desc = L["Type a name and press Enter to keep a copy of the profile as it is now."],
		},
	}
	local list = ui.Undo.GetSnapshots()
	if #list == 0 then
		schema[#schema + 1] = { description = L["No copies yet."] }
	end
	for _, item in ipairs(list) do
		schema[#schema + 1] = snapshotEntry(item)
	end

	local layout, deleted, replaced = ui.Movers.GetLayoutTrash()
	local backupTime = ui:GetBackupTime()
	if layout or backupTime then
		schema[#schema + 1] = { header = L["Other copies"], glyph = "box-archive" }
	end
	if layout then
		local text = replaced and L['Layout "%s", replaced at %s'] or L['Layout "%s", deleted at %s']
		schema[#schema + 1] = {
			label = text:format(layout, timeText(deleted or time())),
			type = "execute",
			text = L["Restore"],
			glyph = "trash-arrow-up",
			func = function()
				local ok, name = ui.Movers.RestoreLayoutTrash()
				if ok then
					ui.Print(L["layout %q restored"], name)
					ns.RefreshPage()
				end
			end,
			desc = L["The last deleted or replaced saved layout. Restoring puts it back into the list of saved layouts."],
		}
	end
	if backupTime then
		schema[#schema + 1] = {
			label = L["All profiles before the settings upgrade (%s)"]:format(date("%Y-%m-%d %H:%M", backupTime)),
			type = "execute",
			text = L["Restore"],
			glyph = "clock-rotate-left",
			func = ui.ConfirmRestoreBackup,
			desc = L["Made once before a new FrostAtom UI version upgraded the saved settings. Restoring brings back every profile and reloads the UI."],
		}
	end
	return schema
end

local function signature()
	local parts = { ui:GetActiveProfile(), tostring((ui.Movers.GetLayoutTrash())), tostring((ui:GetBackupTime())) }
	for _, item in ipairs(ui.Undo.GetSnapshots()) do
		parts[#parts + 1] = ("%d:%s"):format(item.time, item.pinned and "p" or "")
	end
	return table.concat(parts, ",")
end

ns.AddTab("profiles", {
	key = "backups",
	order = 3,
	name = L["Backups"],
	glyph = "clock-rotate-left",
	buildSchema = buildSchema,
	signature = signature,
})
