local namespace = select(2,...)

local destroyObject = namespace.destroyObject
local tDeleteItem = namespace.tDeleteItem
local UnitPopupButtons = UnitPopupButtons


local mustRemove = {"SET_FOCUS","CLEAR_FOCUS","LOCK_FOCUS_FRAME","UNLOCK_FOCUS_FRAME"}

local value
for i = 1,#mustRemove do
	value = mustRemove[i]

	UnitPopupButtons[value] = nil

	for _,tbl in pairs(UnitPopupMenus) do
		tDeleteItem(tbl,value)
	end
end


Arena_LoadUI = namespace.null
destroyObject(PlayerFrame,true)
destroyObject(TargetFrame,true)
destroyObject(FocusFrame,true)
destroyObject(RuneFrame,true)
destroyObject(BuffFrame,true)
destroyObject(ComboFrame,true)
destroyObject(CastingBarFrame)
destroyObject(ConsolidatedBuffs,true)
destroyObject(TemporaryEnchantFrame,true)

local button
for i = 1,4 do
	button = _G["PartyMemberFrame"..i]
	destroyObject(button,true)
	hooksecurefunc(button,"Show",button.Hide)
	destroyObject(_G[("PartyMemberFrame%dPetFrame"):format(i)],true)
end
destroyObject(PartyMemberBackground)



namespace:Get("CVars"):SetCVar("hidePartyInRaid","1")
UIPARENT_MANAGED_FRAME_POSITIONS["CastingBarFrame"] = nil