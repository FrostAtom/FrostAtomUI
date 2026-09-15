local _, ns = ...

-- Hides Blizzard's unit frames and related bits.

local DestroyFrame = ns.DestroyFrame

-- Focus is set by clicking our frames; drop the menu entries.
for _, key in ipairs({ "SET_FOCUS", "CLEAR_FOCUS", "LOCK_FOCUS_FRAME", "UNLOCK_FOCUS_FRAME" }) do
	UnitPopupButtons[key] = nil
	for _, menu in pairs(UnitPopupMenus) do
		ns.tDeleteItem(menu, key)
	end
end

Arena_LoadUI = ns.noop

DestroyFrame(PlayerFrame, true)
DestroyFrame(TargetFrame, true)
DestroyFrame(FocusFrame, true)
DestroyFrame(RuneFrame, true)
DestroyFrame(BuffFrame, true)
DestroyFrame(ComboFrame, true)
DestroyFrame(CastingBarFrame)
DestroyFrame(ConsolidatedBuffs, true)
DestroyFrame(TemporaryEnchantFrame, true)
DestroyFrame(PartyMemberBackground)

for i = 1, MAX_PARTY_MEMBERS do
	local frame = _G["PartyMemberFrame" .. i]
	DestroyFrame(frame, true)
	hooksecurefunc(frame, "Show", frame.Hide)
	DestroyFrame(_G["PartyMemberFrame" .. i .. "PetFrame"], true)
end

ns:GetModule("CVars"):Pin("hidePartyInRaid", "1")
UIPARENT_MANAGED_FRAME_POSITIONS.CastingBarFrame = nil
