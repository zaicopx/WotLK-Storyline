-- compat.lua
-- Everything that touches the original Blizzard frames or other addons.
--
-- Fixes issue #8 ("While using Questie for 3.3.5a it leaves completed quests in
-- the tracker"). Questie learns that a quest was handed in by watching the
-- original UI: hooks on GetQuestReward() and/or on the original "Complete Quest"
-- button. The old Storyline called a cached local copy of GetQuestReward(), which
-- bypasses every hook installed after it was cached, and never touched the
-- original button at all. Now:
--   1. a turn-in goes through the original "Complete Quest" button, which calls
--      the *global* GetQuestReward() (so hooks on both fire);
--   2. if that did not complete the quest, GetQuestReward() is called directly
--      after a short delay;
--   3. after the quest is handed in, Questie is asked to redraw its tracker and
--      map icons (best effort, only if Questie is installed).

local S = _G.Storyline

local C = {}
S.Compat = C

local ORIGINAL_FRAMES = { "GossipFrame", "QuestFrame" }
local suppressed = false

------------------------------------------------------------------------
-- Original frames
------------------------------------------------------------------------
-- The original frames must stay "shown" (hiding QuestFrame closes the quest
-- dialog), so they are made invisible and too small to click instead.
function C.Suppress(on)
	if on and not S.db.hideOriginalFrames then on = false end
	if on == suppressed then return end
	suppressed = on
	for _, name in ipairs(ORIGINAL_FRAMES) do
		local f = _G[name]
		if f then
			if on then
				f:SetAlpha(0)
				f:SetScale(0.001)
			else
				f:SetAlpha(1)
				f:SetScale(1)
			end
		end
	end
end

local function ReadyButton(name)
	local b = _G[name]
	if b and b.IsVisible and b:IsVisible() and b:IsEnabled() then return b end
end

-- Click the original button when it is usable (keeps other addons' hooks
-- working), otherwise call the API function directly. The function is looked
-- up by name at call time on purpose.
function C.ClickOrCall(buttonName, funcName)
	local b = ReadyButton(buttonName)
	if b then
		b:Click()
	else
		S.API(funcName)
	end
end

------------------------------------------------------------------------
-- Quest turn-in
------------------------------------------------------------------------
function C.TurnInQuest(choice)
	local panel = _G.QuestFrameRewardPanel
	local button = ReadyButton("QuestFrameCompleteQuestButton")
	C.turnedIn = true

	if panel and button then
		C.pendingTurnIn = { choice = choice }
		panel.itemChoice = choice
		if _G.QuestFrame then _G.QuestFrame.itemChoice = choice end
		if _G.QuestInfoFrame then _G.QuestInfoFrame.itemChoice = choice end
		button:Click()
		-- Safety net: QUEST_FINISHED clears pendingTurnIn. If it is still set the
		-- original handler did not hand the quest in, so do it directly.
		S.After(1.2, function()
			local p = C.pendingTurnIn
			if p and S.session and S.session.kind == "complete" then
				C.pendingTurnIn = nil
				S.API("GetQuestReward", p.choice)
			end
		end)
	else
		C.pendingTurnIn = nil
		S.API("GetQuestReward", choice)
	end
end

function C.OnQuestFinished()
	C.pendingTurnIn = nil
	if C.turnedIn then
		C.turnedIn = false
		S.After(0.5, C.RefreshQuestie)
		S.After(1.5, C.RefreshQuestie)
	end
end

------------------------------------------------------------------------
-- Questie
------------------------------------------------------------------------
local function try(object, method)
	if type(object) == "table" and type(object[method]) == "function" then
		return pcall(object[method], object)
	end
end

function C.RefreshQuestie()
	if not (_G.Questie or _G.QuestieQuest or _G.QuestieTracker) then return end
	try(_G.QuestieQuest, "SmoothReset")   -- redraw map icons (? marks)
	try(_G.QuestieTracker, "Update")      -- redraw the quest tracker
end
