-- events.lua
-- Registers the WoW events and routes them to logic.lua. Every handler runs
-- protected: if our code ever errors, the original Blizzard windows are given
-- back (S.FailOpen) so the player can still talk to the NPC.

local S = _G.Storyline

local handlers = {}
local frame = CreateFrame("Frame")

frame:SetScript("OnEvent", function(_, event, ...)
	local handler = handlers[event]
	if not handler then return end
	local ok, err = pcall(handler, ...)
	if not ok then
		geterrorhandler()(err)
		S.Print("|cffff5555error in " .. tostring(event) .. ":|r " .. tostring(err))
		if S.db then S.FailOpen() end
	end
end)

function handlers.ADDON_LOADED(name)
	if name ~= "Storyline" then return end
	frame:UnregisterEvent("ADDON_LOADED")

	S.InitDB()
	S.UI.Create()
	S.InitLogic()
	S.Options.Create()

	frame:RegisterEvent("GOSSIP_SHOW")
	frame:RegisterEvent("GOSSIP_CLOSED")
	frame:RegisterEvent("QUEST_GREETING")
	frame:RegisterEvent("QUEST_DETAIL")
	frame:RegisterEvent("QUEST_PROGRESS")
	frame:RegisterEvent("QUEST_COMPLETE")
	frame:RegisterEvent("QUEST_FINISHED")
	frame:RegisterEvent("QUEST_ITEM_UPDATE")
	frame:RegisterEvent("BAG_UPDATE")
end

-- Dialog-opening events: optionally leave dialogs inside instances to the original frames.
local function enabledHere()
	if S.IsClosing() then return false end   -- events of the dialog the player just closed
	if S.db.disableInInstances and IsInInstance() then
		S.Compat.Suppress(false)
		return false
	end
	return true
end

function handlers.GOSSIP_SHOW() if enabledHere() then S.OnGossipShow() end end
function handlers.GOSSIP_CLOSED() S.OnGossipClosed() end
function handlers.QUEST_GREETING() if enabledHere() then S.OnQuestGreeting() end end
function handlers.QUEST_DETAIL() if enabledHere() then S.OnQuestDetail() end end
function handlers.QUEST_PROGRESS() if enabledHere() then S.OnQuestProgress() end end
function handlers.QUEST_COMPLETE() if enabledHere() then S.OnQuestComplete() end end
function handlers.QUEST_FINISHED() S.OnQuestFinished() end
function handlers.QUEST_ITEM_UPDATE() S.OnQuestItemUpdate() end
function handlers.BAG_UPDATE() S.Rewards.OnBagUpdate() end

frame:RegisterEvent("ADDON_LOADED")
