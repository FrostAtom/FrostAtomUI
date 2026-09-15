local namespace = select(2,...)

local FRAME_NAME = namespace.AddOnName.."%sUnitFrame"

local math,string = math,string
local select = select
local pairs = pairs
local UIParent = UIParent
local CreateFrame = CreateFrame
local setmetatable = setmetatable
local RegisterUnitWatch = RegisterUnitWatch


local UnitFrames = namespace:New("UnitFrames")
local pixelPerfect = namespace.pixelPerfect
local moduleCreateFuncs,moduleUpdateFuncs = {},{}

-- classColors
do
	local math = math
	local classColors = {}
	for class,colors in pairs(RAID_CLASS_COLORS) do
		classColors[class] = {math.min(colors.r*1.25,1),math.min(colors.g*1.25,1),math.min(colors.b*1.25,1)}
	end
	UnitFrames.classColors = classColors
end


-- powerColors
do
	local PowerBarColor = PowerBarColor
	local powerColors = {}
	local colors
	for i = 0,#PowerBarColor do
		colors = PowerBarColor[i]

		powerColors[i] = {colors.r*0.66,colors.g*0.66,colors.b*0.66}
	end
	UnitFrames.powerColors = powerColors
end


local menuFunc
do
	local dropDownMenus = setmetatable({},{
		__index = function(tbl,unit)
			local menu
			local partyId = unit:match("^party(%d)$")
			if partyId then
				menu = _G[("PartyMemberFrame%dDropDown"):format(partyId)]
			else
				menu = _G[unit:gsub("^%l",string.upper).."FrameDropDown"]
			end
			--[[
			if not menu then
				counstructMenu(unit)
			end
			]]
			tbl[unit] = menu or false
			return menu
		end
	})

	menuFunc = function(self,unit,button,down)
		local dropdown = dropDownMenus[unit]
		if dropdown then
			ToggleDropDownMenu(1,nil,dropdown,self,0,0)
		end
	end
end

do
	local huge = math.huge
	function UnitFrames.ColorGradient(perc, ...)
		if(perc ~= perc or perc == inf) then perc = 0 end

		if perc >= 1 then
			local r, g, b = select(select('#', ...) - 2, ...)
			return r, g, b
		elseif perc <= 0 then
			local r, g, b = ...
			return r, g, b
		end
		
		local num = select('#', ...) / 3

		local segment, relperc = math.modf(perc*(num-1))
		local r1, g1, b1, r2, g2, b2 = select((segment*3)+1, ...)

		return r1 + (r2-r1)*relperc, g1 + (g2-g1)*relperc, b1 + (b2-b1)*relperc
	end
end


function UnitFrames:AddModule(name,createFunc,updateFunc)
	moduleUpdateFuncs[name] = updateFunc
	moduleCreateFuncs[name] = createFunc
end

function UnitFrames:CreateModule(object,name,...)
	assert(moduleCreateFuncs[name],"createFunc for module ["..name.."] isn't exists")
	assert(not object[name],"module ["..name.."] alredy exists")

	local module = moduleCreateFuncs[name](object,...)
	if module then
		object[name] = module
		return module
	end
end



local framePrototype = setmetatable(CopyTable(namespace:GetObjectPrototype()),getmetatable(PlayerFrame))
local frameMT = {__index = framePrototype}

function framePrototype:UpdateAllModules()
	if not self:IsShown() then
		return
	end

	for name,updateFoo in pairs(moduleUpdateFuncs) do
		if self[name] then
			updateFoo(self)
		end
	end
end

function UnitFrames:CreateBase(unit)
	local frame = setmetatable(CreateFrame("Button",FRAME_NAME:format(unit:gsub("^%l",string.upper)),UIParent,"SecureUnitButtonTemplate"),frameMT)
	frame:RegisterForClicks("AnyDown")
	frame:SetBackdrop({
		edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
		edgeSize = 8,
		
		bgFile = "Interface\\Buttons\\WHITE8x8",
		insets = {
			top = pixelPerfect(1),
			bottom = pixelPerfect(1),
			left = pixelPerfect(1),
			right = pixelPerfect(1),
		}
	})
	frame:SetBackdropColor(0.137,0.137,0.137)
	frame:SetBackdropBorderColor(0.2,0.2,0.2)

	frame.unit = unit
	frame:SetAttribute("unit",unit)
	frame:SetAttribute("*type1","target")
	if unit:find("^arena.-%d$") then
		frame:SetAttribute("*type2","focus")
	elseif unit == "focus" then
		frame:SetAttribute("*type3","macro")
		frame:SetAttribute("macrotext","/clearfocus")
	else
		frame:SetAttribute("*type3","focus")
	end

	frame:SetScript("OnEnter",UnitFrame_OnEnter)
	frame:SetScript("OnLeave",UnitFrame_OnLeave)
	frame:SetScript("OnShow",frame.UpdateAllModules)
	frame:RegisterEvent("PLAYER_ENTERING_WORLD",frame.UpdateAllModules)
	RegisterUnitWatch(frame)


	return frame
end

function UnitFrames:CreateFrame_Rectangle(unit,width,height)
	local frame = self:CreateBase(unit)
	frame:SetSize(width,height)

	local health = self:CreateModule(frame,"health",true)
	health:SetPoint("TOPRIGHT",-2,-2)
	health:SetPoint("BOTTOMLEFT",2,2+(height-(2+2))/3*1)
	health.text:SetPoint("BOTTOMRIGHT")

	local power = self:CreateModule(frame,"power")
	power:SetPoint("TOPRIGHT",health,"BOTTOMRIGHT")
	power:SetPoint("BOTTOMLEFT",2,2)
	power.text:SetPoint("BOTTOMRIGHT")

	local name = self:CreateModule(frame,"name")
	name:SetJustifyH("RIGHT")
	name:SetPoint("BOTTOMLEFT",health)

	local combat = self:CreateModule(frame,"combat")
	combat:SetPoint("TOPLEFT",health,6,6)


	return frame
end

function UnitFrames:CreateFrame_Square(unit,width)
	local frame = self:CreateBase(unit)
	frame:SetSize(width,width)

	local health = self:CreateModule(frame,"health")
	health:SetPoint("TOPRIGHT",-2,-2)
	health:SetPoint("BOTTOMLEFT",2,2)
	health.text:SetPoint("CENTER")


	return frame
end

do
	local unitPetHander = function(self,unit)
		if unit == "player" then
			if self.unit == "pet" then
				self:UpdateAllModules()
			end
		else
			if unit:gsub("([ap][ra][er][nt][ay])pet(%d)","%1%2") == self.unit then
				self:UpdateAllModules()
			end
		end
	end

	function UnitFrames:CreateFrame_Pet(unit,width)
		local frame = self:CreateFrame_Square(unit,width)
		frame:RegisterEvent("UNIT_PET",unitPetHander)


		return frame
	end
end

do
	local unitTargetHandler = function(self,unit)
		if self.unit:match("^(.+)target$") == unit then
			self:UpdateAllModules()
		end
	end

	function UnitFrames:CreateFrame_TargetTarget(unit,width)
		local frame = self:CreateFrame_Square(unit,width)
		frame:RegisterEvent("UNIT_TARGET",unitTargetHandler)

		local name = self:CreateModule(frame,"name",3)
		name:SetPoint("TOP",0,-2)


		return frame
	end
end

function UnitFrames:CreateFrame_Target(unit,width,height)
	local frame = self:CreateFrame_Rectangle(unit,width,height)

	local targetframe = self:CreateFrame_TargetTarget(unit.."target",height)
	targetframe:SetPoint("LEFT",frame,"RIGHT",20)

	local buffs = self:CreateModule(frame,"buffs")
	buffs:SetPoint("TOPLEFT",frame,"BOTTOMLEFT")
	buffs.size = width/8
	local debuffs = self:CreateModule(frame,"debuffs")
	debuffs:SetPoint("TOPLEFT",frame.buffs,"BOTTOMLEFT")
	debuffs.size = width/8

	local castbar = self:CreateModule(frame,"castbar")
	castbar:SetSize(width,width*0.1)
	castbar:SetPoint("TOPLEFT",debuffs,"BOTTOMLEFT")
	castbar.icon:SetSize(width*0.1+2,width*0.1+2)

	local losecontrol = self:CreateModule(frame,"losecontrol")
	losecontrol:SetSize(30,30)
	losecontrol:SetPoint("CENTER")


	return frame,targetframe
end


function UnitFrames:Initialize()
	-- player
	local player
	do
		local floor = floor
		local calculatePoint = function(i,inRow,size)
			i = i - 1
			return "TOPRIGHT",
					-(i%inRow*(size+2)),
					-floor(i/inRow)*(size+2)
		end

		player = self:CreateFrame_Rectangle("player",200,45)
		player:SetPoint("TOPLEFT",150,-40)

		local leader = self:CreateModule(player,"leader")
		leader:SetPoint("TOPLEFT",player.health,24,8)

		local buffs = self:CreateModule(player,"buffs")
		buffs:SetPoint("TOPRIGHT",Minimap,"TOPLEFT",-15,0)
		buffs.size = 34
		buffs.realSize = 36
		buffs.calculatePoint = calculatePoint
		local debuffs = self:CreateModule(player,"debuffs")
		debuffs:SetPoint("TOPRIGHT",buffs,"BOTTOMRIGHT")
		debuffs.size = 34
		debuffs.realSize = 36
		debuffs.calculatePoint = calculatePoint

		local castbar = self:CreateModule(player,"castbar")
		castbar:SetSize(240,22)
		castbar:SetPoint("CENTER",UIParent,0,-270)
		castbar.icon:SetSize(22+2,22+2)

		local pet = self:CreateFrame_Pet("pet",45)
		pet:SetPoint("RIGHT",player,"LEFT",-2,0)

		local losecontrol = self:CreateModule(player,"losecontrol")
		losecontrol:SetSize(32,32)
		losecontrol:SetPoint("CENTER",UIParent)
	end

	local target,targettarget = self:CreateFrame_Target("target",200,45)
	target:SetPoint("LEFT",player,"RIGHT",2,0)
	target:RegisterEvent("PLAYER_TARGET_CHANGED",target.UpdateAllModules)
	targettarget:RegisterEvent("PLAYER_TARGET_CHANGED",targettarget.UpdateAllModules)

	local focus,focustarget = self:CreateFrame_Target("focus",200,45)
	focus:SetPoint("LEFT",targettarget,"RIGHT",2,0)
	focus:RegisterEvent("PLAYER_FOCUS_CHANGED",focus.UpdateAllModules)
	focustarget:RegisterEvent("PLAYER_FOCUS_CHANGED",focustarget.UpdateAllModules)


	-- party
	do
		local frame,petframe,leader,buffs,debuffs,castbar,losecontrol
		for i = 1,4 do
			frame = self:CreateFrame_Rectangle("party"..i,180,40)
			frame:SetPoint("TOPLEFT",50,-150-(i-1)*(40+72))
			frame:RegisterEvent("PARTY_MEMBERS_CHANGED",frame.UpdateAllModules)

			leader = self:CreateModule(frame,"leader")
			leader:SetPoint("TOPLEFT",frame.health,24,8)

			buffs = self:CreateModule(frame,"buffs")
			buffs:SetPoint("TOPLEFT",frame,"BOTTOMLEFT")
			buffs.size = 180/8
			buffs.max = 16

			debuffs = self:CreateModule(frame,"debuffs")
			debuffs:SetPoint("LEFT",frame,"RIGHT")
			debuffs.size = 180/8
			debuffs.max = 16

			castbar = self:CreateModule(frame,"castbar")
			castbar:SetPoint("BOTTOM",frame,"TOP")
			castbar:SetSize(176,20)
			castbar.icon:SetSize(22,22)

			losecontrol = self:CreateModule(frame,"losecontrol")
			losecontrol:SetSize(30,30)
			losecontrol:SetPoint("CENTER")

			petframe = self:CreateFrame_Pet("partypet"..i,40)
			petframe:SetPoint("RIGHT",frame,"LEFT",-2,0)
			petframe:RegisterEvent("PARTY_MEMBERS_CHANGED",petframe.UpdateAllModules)
		end
	end

	-- arena
	do
		local frame,petframe,castbar,debuffs,losecontrol
		for i = 1,3 do
			frame = self:CreateFrame_Rectangle("arena"..i,200,50)
			frame:SetPoint("RIGHT",-150,(i-3)*(-(50+54)))

			debuffs = self:CreateModule(frame,"debuffs")
			debuffs:SetPoint("TOPLEFT",frame,"BOTTOMLEFT")
			debuffs.size = 200/8
			debuffs.max = 16

			castbar = self:CreateModule(frame,"castbar")
			castbar:SetPoint("TOPRIGHT",frame,"TOPLEFT",0,-2)
			castbar:SetSize(160,35)
			castbar.icon:SetSize(37,37)

			losecontrol = self:CreateModule(frame,"losecontrol")
			losecontrol:SetSize(32,32)
			losecontrol:SetPoint("CENTER")

			petframe = self:CreateFrame_Pet("arenapet"..i,50)
			petframe:SetPoint("LEFT",frame,"RIGHT",2,0)
		end
	end


	self.CreateFrame_Base = nil
	self.CreateFrame_Rectangle = nil
	self.CreateFrame_Square = nil
	self.CreateFrame_Pet = nil
	self.CreateFrame_TargetTarget = nil
end