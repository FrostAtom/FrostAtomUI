local UIParent = UIParent
local _G = _G

KeyRingButton:SetParent(UIParent)
MainMenuBarBackpackButton:SetParent(UIParent)
MainMenuBarBackpackButton:SetPoint("BOTTOMRIGHT",-2,40)

local prevButton,button = MainMenuBarBackpackButton
for i = 0,3 do
	button = _G[("CharacterBag%dSlot"):format(i)]
	button:SetParent(UIParent)
	button:ClearAllPoints()
	button:SetPoint("BOTTOMRIGHT",prevButton,"BOTTOMLEFT",-3,0)
	prevButton = button
end