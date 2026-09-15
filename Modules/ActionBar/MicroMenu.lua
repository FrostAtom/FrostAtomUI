local UIParent = UIParent


local buttons = {
	CharacterMicroButton,
	SpellbookMicroButton,
	TalentMicroButton,
	AchievementMicroButton,
	QuestLogMicroButton,
	SocialsMicroButton,
	PVPMicroButton,
	LFDMicroButton,
	MainMenuMicroButton,
	HelpMicroButton,
}

for i = 1,#buttons do
	buttons[i]:SetParent(UIParent)
end

CharacterMicroButton:SetPoint("BOTTOMLEFT",UIParent,"BOTTOMRIGHT",-254,2)