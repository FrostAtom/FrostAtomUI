local _, ns = ...

local GetCVarBool = GetCVarBool
local GetTime = GetTime
local gsub = string.gsub
local remove = table.remove

local BubbleLayer = {}
ns.BubbleLayer = BubbleLayer

local TAIL_TEXTURE = "Interface\\Tooltips\\ChatBubble-Tail"
local PENDING_LIFETIME = 10
local PENDING_LIMIT = 30

local BUBBLE_EVENTS = {
	CHAT_MSG_SAY = { chatType = "SAY", cvar = "chatBubbles" },
	CHAT_MSG_YELL = { chatType = "YELL", cvar = "chatBubbles" },
	CHAT_MSG_MONSTER_SAY = { chatType = "MONSTER_SAY", cvar = "chatBubbles", monster = true },
	CHAT_MSG_MONSTER_YELL = { chatType = "MONSTER_YELL", cvar = "chatBubbles", monster = true },
	CHAT_MSG_PARTY = { chatType = "PARTY", cvar = "chatBubblesParty" },
	CHAT_MSG_PARTY_LEADER = { chatType = "PARTY_LEADER", cvar = "chatBubblesParty" },
}

local bubbles = {}
local infos = {}
local handlers = {}
local pending = {}
BubbleLayer.bubbles = bubbles

local function fire(event, bubble, info)
	for i = 1, #handlers do
		local callback = handlers[i][event]
		if callback then
			callback(bubble, info)
		end
	end
end

local function stripBrackets(text)
	return (gsub(text, "[%[%]]", ""))
end

local function normalize(text)
	text = gsub(text, "|c........", "")
	text = gsub(text, "|r", "")
	text = gsub(text, "|H.-|h(.-)|h", stripBrackets)
	text = gsub(text, "|T.-|t", "")
	return text
end
BubbleLayer.Normalize = normalize

local function takePending(message, now)
	local i = 1
	while i <= #pending do
		local entry = pending[i]
		if now - entry.time > PENDING_LIFETIME then
			remove(pending, i)
		elseif entry.text == message then
			remove(pending, i)
			return entry
		else
			i = i + 1
		end
	end
end

local function onShow(bubble)
	local info = infos[bubble]
	local message = info.text:GetText()
	local entry = message and takePending(message, GetTime())
	if entry or message ~= info.shownMessage then
		info.message = message
		info.r, info.g, info.b = info.text:GetTextColor()
		info.chatType = entry and entry.chatType
		info.sender = entry and entry.sender
		info.guid = entry and entry.guid
		info.isNew = true
	else
		info.isNew = false
	end
	info.shown = true
	fire("shown", bubble, info)
	info.shownMessage = info.text:GetText()
end

local function onHide(bubble)
	local info = infos[bubble]
	info.shown = false
	fire("hidden", bubble, info)
end

local function capture(bubble)
	local info = { frame = bubble, edges = {}, shown = false }
	for i = 1, bubble:GetNumRegions() do
		local region = select(i, bubble:GetRegions())
		if region:GetObjectType() == "FontString" then
			info.text = region
		elseif not info.background then
			info.background = region
		elseif region:GetTexture() == TAIL_TEXTURE then
			info.tail = region
		else
			info.edges[#info.edges + 1] = region
		end
	end
	if not info.text then
		return
	end
	infos[bubble] = info
	bubbles[#bubbles + 1] = bubble
	fire("created", bubble, info)
	bubble:SetScript("OnShow", onShow)
	bubble:SetScript("OnHide", onHide)
	if bubble:IsShown() then
		onShow(bubble)
	end
end

local function addPending(kind, message, sender, ...)
	if not (message and GetCVarBool(kind.cvar)) then
		return
	end
	local text = normalize(message)
	if kind.monster then
		text = gsub(text, "%%%%", "%%")
	end
	if #pending >= PENDING_LIMIT then
		remove(pending, 1)
	end
	pending[#pending + 1] = {
		text = text,
		chatType = kind.chatType,
		sender = sender,
		guid = select(10, ...),
		time = GetTime(),
	}
end

local events = ns.Mixin({}, ns.EventMixin)
local started = false

function BubbleLayer.Register(handler)
	handlers[#handlers + 1] = handler
	if not started then
		started = true
		for event, kind in pairs(BUBBLE_EVENTS) do
			events:RegisterEvent(event, function(_, ...)
				addPending(kind, ...)
			end)
		end
		ns.WorldChildren.Register("ChatBubble", capture)
		return
	end
	for i = 1, #bubbles do
		local bubble = bubbles[i]
		local info = infos[bubble]
		if handler.created then
			handler.created(bubble, info)
		end
		if info.shown and handler.shown then
			handler.shown(bubble, info)
		end
	end
end

function BubbleLayer.GetInfo(bubble)
	return infos[bubble]
end
