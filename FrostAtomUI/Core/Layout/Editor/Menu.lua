local _, ns = ...
local L = ns.L

local GameTooltip = GameTooltip
local InCombatLockdown = InCombatLockdown

local Movers = ns.Movers
local home = Movers.home
local attach = home.attach
local detach = home.detach
local selectMover = home.selectMover
local showTooltip = home.showTooltip
local updateVisibility = home.updateVisibility

do
	local menu, menuMover

	local function canChange(mover)
		if mover.secure and InCombatLockdown() then
			ns.Print(L["cannot move frames in combat"])
			return false
		end
		return true
	end

	local function afterChange(mover)
		if not home.unlocked then
			return
		end
		attach(mover)
		home.updateConflicts()
		if mover.overlay:IsMouseOver() then
			showTooltip(mover.overlay)
		end
	end

	function home.moveBack(mover, announce)
		if not canChange(mover) then
			return
		end
		Movers.ResetPosition(mover.path)
		afterChange(mover)
		if announce then
			ns.Print(L['frame "%s" moved back to the "%s" layout'], L[mover.label], Movers.GetBaseLayoutName())
		end
	end

	function home.hide(mover)
		mover.hiddenWhileUnlocked = true
		if mover == home.selected then
			selectMover(nil)
		end
		if mover.overlay:IsMouseOver() then
			GameTooltip:Hide()
		end
		updateVisibility(mover)
		home.updateConflicts()
	end

	local function detachMover(mover)
		if canChange(mover) then
			detach(mover)
			afterChange(mover)
		end
	end

	local function addMenuButton(text, func, disabled, isTitle)
		local info = UIDropDownMenu_CreateInfo()
		info.text, info.func, info.disabled, info.isTitle, info.notCheckable = text, func, disabled, isTitle, true
		UIDropDownMenu_AddButton(info)
	end

	local function menuAction(action)
		return function()
			local mover = menuMover
			menuMover = nil
			if mover and home.unlocked and mover.overlay and mover.overlay:IsShown() then
				action(mover)
			end
		end
	end

	local menuSettings = menuAction(function(mover)
		Movers.Select(mover.path)
	end)
	local menuMoveBack = menuAction(home.moveBack)
	local menuDetach = menuAction(detachMover)
	local menuHide = menuAction(home.hide)

	local function initMenu()
		local mover = menuMover
		if not mover then
			return
		end
		local value = ns:GetConfig(mover.path)
		local anchored = type(value) == "table" and value[4] ~= nil
		addMenuButton(L[mover.label], nil, nil, true)
		addMenuButton(L["Frame settings"], menuSettings)
		addMenuButton(
			L['Move back (the "%s" layout)']:format(Movers.GetBaseLayoutName()),
			menuMoveBack,
			Movers.IsAtHome(mover.path)
		)
		addMenuButton(L["Detach from frame"], menuDetach, not anchored)
		addMenuButton(L["Hide while moving frames"], menuHide)
		addMenuButton(CANCEL)
	end

	function home.showMenu(mover)
		if not menu then
			menu = CreateFrame("Frame", "FrostAtomUIMoverMenu", UIParent, "UIDropDownMenuTemplate")
			UIDropDownMenu_Initialize(menu, initMenu, "MENU")
		end
		GameTooltip:Hide()
		CloseDropDownMenus()
		menuMover = mover
		ToggleDropDownMenu(1, nil, menu, "cursor")
	end

	function home.closeMenu()
		menuMover = nil
		if menu and UIDROPDOWNMENU_OPEN_MENU == menu then
			CloseDropDownMenus()
		end
	end
end
