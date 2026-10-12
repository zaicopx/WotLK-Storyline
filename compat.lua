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
	-- S.IsOn: IsEnabled() returns 1 / 0 in 3.3.5a and 0 is "true" in Lua. A disabled button
	-- ignores Click(), so the old check silently did nothing for a disabled Accept button.
	if b and b.IsVisible and b:IsVisible() and S.IsOn(b) then return b end
end
C.ReadyButton = ReadyButton

-- Click the original button when it is usable (keeps other addons' hooks
-- working), otherwise call the API function directly. The function is looked
-- up by name at call time on purpose.
function C.ClickOrCall(buttonName, funcName)
	local b = ReadyButton(buttonName)
	if b then
		local ok, err = pcall(b.Click, b)
		if ok then return end
		S.Print("|cffff5555" .. buttonName .. " click failed:|r " .. tostring(err))
	end
	S.API(funcName)
end

------------------------------------------------------------------------
-- Accepting a quest
------------------------------------------------------------------------
-- What the original Accept button does (PvP quests ask for confirmation, auto-accept quests
-- are acknowledged), without needing the button.
local function acceptDirect()
	local frame = _G.QuestFrame
	if S.API("QuestFlagsPVP") then
		if frame then frame.dialog = S.API("StaticPopup_Show", "CONFIRM_ACCEPT_PVP_QUEST") end
	elseif frame and frame.autoQuest then
		S.API("AcknowledgeAutoAcceptQuest")
	else
		S.API("AcceptQuest")
	end
end

local function questInLog(title)
	if not title or title == "" then return false end
	for i = 1, (S.API("GetNumQuestLogEntries") or 0) do
		local name, _, _, _, isHeader = S.API("GetQuestLogTitle", i)
		if name and not isHeader and name == title then return true end
	end
	return false
end

local function detailStillOpen()
	local q, p = _G.QuestFrame, _G.QuestFrameDetailPanel
	return q and q:IsShown() and p and p:IsShown()
end

-- Click the original Accept button; if it is disabled / missing / did nothing, accept directly.
-- The result is checked: when the dialog is still open and the quest is not in the log a moment
-- later, the quest is accepted directly, and if even that fails the state is printed in the chat.
function C.AcceptQuest()
	local title = S.API("GetTitleText")
	local button = ReadyButton("QuestFrameAcceptButton")
	local clicked = false
	if button then
		local ok, err = pcall(button.Click, button)
		clicked = ok
		if not ok then S.Print("|cffff5555Accept button click failed:|r " .. tostring(err)) end
	end
	if not clicked then acceptDirect() end

	S.After(0.3, function()
		if detailStillOpen() and not questInLog(title) then acceptDirect() end
	end)
	S.After(0.85, function()
		if detailStillOpen() and not questInLog(title) then
			local b = _G.QuestFrameAcceptButton
			S.Print("|cffff5555the quest was not accepted.|r Please send this line: accept button: "
				.. (b and ("shown=" .. tostring(b:IsVisible() and true or false) .. " enabled=" .. tostring(b:IsEnabled())) or "missing")
				.. " | PvP quest: " .. tostring(S.API("QuestFlagsPVP") and true or false)
				.. " | auto quest: " .. tostring(_G.QuestFrame and _G.QuestFrame.autoQuest and true or false))
		end
	end)
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
