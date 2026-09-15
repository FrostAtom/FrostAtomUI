local AddOnName,namespace = ...

local setmetatable = setmetatable
local CreateFrame = CreateFrame

local CooldownFrame_SetTimer = CooldownFrame_SetTimer
local GetActionTexture = GetActionTexture
local GetActionCooldown = GetActionCooldown
local GetBindingKey = GetBindingKey
local IsActionInRange = IsActionInRange
local IsUsableAction = IsUsableAction
local IsEquippedAction = IsEquippedAction
local IsCurrentAction = IsCurrentAction
local IsAutoRepeatAction = IsAutoRepeatAction
local IsAltKeyDown = IsAltKeyDown
local InCombatLockdown = InCombatLockdown
local PickupAction = PickupAction
local PlaceAction = PlaceAction
local HasAction = HasAction
local IsConsumableAction = IsConsumableAction
local IsStackableAction = IsStackableAction
local GetActionText = GetActionText


local ActionBar = namespace:Get("ActionBar")
local CooldownTimer = namespace:Get("CooldownTimer")
local NAME = AddOnName.."ActionButton"
local TEXTURE = namespace:GetMedia("textureNormal")

local prototype = setmetatable(CopyTable(namespace:GetObjectPrototype()),getmetatable(PlayerFrame))
local buttonMT = {__index = prototype}


local function UpdateColors_inner(self,...)
	self.icon:SetVertexColor(...)

	if self.checked then
		self:GetNormalTexture():SetVertexColor(1,0.8,0)
	elseif self.equipped then
		self:GetNormalTexture():SetVertexColor(0.2,0.8,0.2)
	else
		self:GetNormalTexture():SetVertexColor(...)
	end
end

function prototype:UpdateColors()
	if self.notMana then
		UpdateColors_inner(self,0.5,0.5,1)
	elseif self.outOfRange then
		UpdateColors_inner(self,1,0,0)
	elseif self.usable then
		UpdateColors_inner(self,1,1,1)
	else
		UpdateColors_inner(self,0.4,0.4,0.4)
	end
end

function prototype:OnUpdate(elapsed)
	self.onUpdateTimer = self.onUpdateTimer - elapsed
	if self.onUpdateTimer < 0 then
		local outOfRange = IsActionInRange(self.action) == 0
		if outOfRange ~= self.outOfRange then
			self.outOfRange = outOfRange

			self:UpdateColors()
		end
		self.onUpdateTimer = 0.1
	end
end

function prototype:OnAttributeChanged(attr,val)
	if attr == "action" then
		self.action = val
		self:Update()
	end
end

function prototype:OnDragStart()
	if IsAltKeyDown() and not InCombatLockdown() then
		PickupAction(self.action)
	end
end

function prototype:OnReceiveDrag()
	if not InCombatLockdown() then
		PlaceAction(self.action)
	end
end

function prototype:UpdateUsable()
	self.usable,self.notMana = IsUsableAction(self.action)
	self:UpdateColors()
end

function prototype:UpdateEquipped()
	self.equipped = IsEquippedAction(self.action)
	self:UpdateColors()
end

function prototype:UpdateState()
	self.checked = IsCurrentAction(self.action) or IsAutoRepeatAction(self.action)
	self:UpdateColors()
end

function prototype:UpdateBindings()
	local bind = GetBindingKey(("CLICK %s:LeftButton"):format(self:GetName()))
	if bind then
		self.hotkey:SetText(
	        bind:gsub("(BUTTON)","B")
	        	:gsub("(ALT%-)","A")
	        	:gsub("(CTRL%-)","C")
	        	:gsub("(SHIFT%-)","S")
	        	:gsub("(MOUSEWHEELUP)","WU")
	        	:gsub("(MOUSEWHEELDOWN)","WD")
	        	:gsub("(CAPSLOCK)","Caps\nLock")
			)
		self.hotkey:Show()
	else
		self.hotkey:Hide()
	end
end

function prototype:UpdateName()
	local action = self.action
	if (IsConsumableAction(action) or IsStackableAction(action)) then
		local count = GetActionCount(action)
		count = count > 999 and "*" or count
		self.name:SetText(count)
	else
		self.name:SetText(GetActionText(action))
	end
end

function prototype:UpdateIcon()
	local texture = GetActionTexture(self.action)
	if not texture then
		texture = "Interface\\PaperDoll\\UI-Backpack-EmptySlot"
	elseif texture == "" then
		texture = "Interface\\Icons\\INV_MIsc_QuestionMark"
	end
	self.icon:SetTexture(texture)
end

function prototype:UpdateCooldown()
	CooldownFrame_SetTimer(self.cooldown,GetActionCooldown(self.action))
end

function prototype:Update()
	local action = self.action

	if HasAction(action) then
		self:RegisterEvent("UPDATE_BINDINGS","UpdateBindings")
		self:RegisterEvent("UPDATE_SHAPESHIFT_FORM","Update")
		self:RegisterEvent("PLAYER_ENTERING_WORLD","Update")
		self:RegisterEvent("ACTIONBAR_UPDATE_USABLE","UpdateUsable")
		self:RegisterEvent("ACTIONBAR_UPDATE_COOLDOWN","UpdateCooldown")
		self:RegisterEvent("UNIT_ENTERED_VEHICLE","UpdateState_UnitIsPlayer")
		self:RegisterEvent("UNIT_EXITED_VEHICLE","UpdateState_UnitIsPlayer")
		self:RegisterEvent("TRADE_SKILL_SHOW","UpdateState")
		self:RegisterEvent("TRADE_SKILL_CLOSE","UpdateState")
		self:SetScript("OnUpdate",self.OnUpdate)


		self.usable,self.notMana = IsUsableAction(action)
		self.equipped = IsEquippedAction(action)
		self.checked = IsCurrentAction(action) or IsAutoRepeatAction(action)
		self.outOfRange = IsActionInRange(action) == 0

		self.onUpdateTimer = -1
		self.eventsRegistered = true
	elseif self.eventsRegistered then
		self:UnregisterEvent("UPDATE_BINDINGS","UpdateBindings")
		self:UnregisterEvent("UPDATE_SHAPESHIFT_FORM","Update")
		self:UnregisterEvent("PLAYER_ENTERING_WORLD","Update")
		self:UnregisterEvent("ACTIONBAR_UPDATE_USABLE","UpdateUsable")
		self:UnregisterEvent("ACTIONBAR_UPDATE_COOLDOWN","UpdateCooldown")
		self:UnregisterEvent("UNIT_ENTERED_VEHICLE","UpdateState_UnitIsPlayer")
		self:UnregisterEvent("UNIT_EXITED_VEHICLE","UpdateState_UnitIsPlayer")
		self:UnregisterEvent("TRADE_SKILL_SHOW","UpdateState")
		self:UnregisterEvent("TRADE_SKILL_CLOSE","UpdateState")
		self:SetScript("OnUpdate",nil)

		self.usable,self.notMana,self.equipped,self.checked,self.outOfRange = true

		self.eventsRegistered = nil
	end

	self:UpdateColors()
	self:UpdateBindings()
	self:UpdateIcon()
	self:UpdateCooldown()
	self:UpdateName()
end

function prototype:ACTIONBAR_SLOT_CHANGED(slot)
	if slot == 0 or slot == self.action then
		self:Update()
	end
end

function prototype:COMPANION_UPDATE(arg1)
	if arg1 == "MOUNT" then
		self:UpdateState()
	end
end

function prototype:UpdateState_UnitIsPlayer(unit)
	if unit == "player" then
		self:UpdateState()
	end
end

function ActionBar:CreateButton(action,parent)
	local button = setmetatable(CreateFrame("Button",NAME..action,parent,"SecureActionButtonTemplate"),buttonMT)
	button:SetAttribute("checkselfcast",true)
	button:SetAttribute("type","action")
	button:SetAttribute("action",action)
	button.action = action

	button:SetNormalTexture(TEXTURE)
	button:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square")

	button.cooldown = CreateFrame("Cooldown",nil,button)
	button.cooldown:SetAllPoints()
	CooldownTimer:Create(button.cooldown)

	button.icon = button:CreateTexture(nil,"BORDER")
	button.icon:SetAllPoints()

	button.hotkey = button:CreateFontString(nil,"ARTWORK")
	button.hotkey:SetFont("Fonts\\ARIALN.ttf",9,"OUTLINE")
	button.hotkey:SetPoint("TOPRIGHT")
	button.hotkey:SetJustifyH("LEFT")
	button.hotkey:SetJustifyV("BOTTOM")

	button.name = button:CreateFontString(nil,"ARTWORK")
	button.name:SetPoint("BOTTOM",0,2)
	button.name:SetFont("Fonts\\ARIALN.ttf",9,"OUTLINE")

	button:RegisterForClicks("LeftButtonDown")
	button:RegisterForDrag("RightButton")
	button:HookScript("OnClick",self.PlayAnimation)
	button:SetScript("OnDragStart",button.OnDragStart)
	button:SetScript("OnReceiveDrag",button.OnReceiveDrag)
	button:SetScript("OnAttributeChanged",button.OnAttributeChanged)
	button:RegisterEvent("ACTIONBAR_SLOT_CHANGED")

	button.onUpdateTimer = 0.2
	button.usable = true
	button:Update()

	return button
end