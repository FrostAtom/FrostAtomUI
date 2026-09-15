local _, ns = ...

-- Mouse wheel flips pages in Blizzard frames that have prev/next buttons:
-- wheel down = next page, wheel up = previous page.

local WheelPaging = ns:NewModule("WheelPaging")

-- frame -> its page buttons. Frames from load-on-demand addons are picked up
-- once they exist.
local PAGED_FRAMES = {
	MerchantFrame = { prev = "MerchantPrevPageButton", next = "MerchantNextPageButton" },
	SpellBookFrame = { prev = "SpellBookPrevPageButton", next = "SpellBookNextPageButton" },
	InboxFrame = { prev = "InboxPrevPageButton", next = "InboxNextPageButton" },
	PetPaperDollFrameCompanionFrame = { prev = "CompanionPrevPageButton", next = "CompanionNextPageButton" },
	AuctionFrameBrowse = { prev = "BrowsePrevPageButton", next = "BrowseNextPageButton" }, -- Blizzard_AuctionUI
	CalendarFrame = { prev = "CalendarPrevMonthButton", next = "CalendarNextMonthButton" }, -- Blizzard_Calendar
}

local function onMouseWheel(frame, delta)
	local button = _G[delta < 0 and frame.nextPageButton or frame.prevPageButton]
	if button and button:IsShown() and button:IsEnabled() then
		button:Click()
	end
end

local function setup(frame, buttons)
	frame.prevPageButton = buttons.prev
	frame.nextPageButton = buttons.next
	frame:EnableMouseWheel(true)
	frame:SetScript("OnMouseWheel", onMouseWheel)
end

local function setupAvailable()
	for frameName, buttons in pairs(PAGED_FRAMES) do
		local frame = _G[frameName]
		if frame then
			setup(frame, buttons)
			PAGED_FRAMES[frameName] = nil
		end
	end
	return next(PAGED_FRAMES) == nil
end

function WheelPaging:ADDON_LOADED()
	if setupAvailable() then
		self:UnregisterEvent("ADDON_LOADED")
	end
end

function WheelPaging:Initialize()
	if not setupAvailable() then
		self:RegisterEvent("ADDON_LOADED")
	end
end
