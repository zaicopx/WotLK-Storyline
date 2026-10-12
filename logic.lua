-- logic.lua
-- Dialog flow, following the Retail Storyline:
--   * the NPC text is cut in paragraphs shown one after the other in the chat bubble;
--   * on the LAST paragraph the "next" line of the bubble becomes the finishing action
--     (check objectives -> accept, complete quest, get reward, first dialog choice...);
--   * gossip options / quests are listed in a panel, objectives and rewards live in
--     panels attached to the glowing medallions.

local S = _G.Storyline
local L = S.L
local UI = S.UI
local R = S.Rewards

local floor, max = math.floor, math.max

local ART = UI.ART
local ICON = "Interface\\GossipFrame\\"
local GRAY = { 0.6, 0.6, 0.6 }
local ANIM = { CHEER = 68, YES = 185, NO = 186 }

local function stripColors(text)
	return ((text or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""))
end

------------------------------------------------------------------------
-- Session lifecycle
------------------------------------------------------------------------
local pendingClose

function S.CancelPendingClose()
	if pendingClose then
		S.Cancel(pendingClose)
		pendingClose = nil
	end
end

-- The server often sends "closed" and "open" events back to back when moving from one
-- dialog to the next, so closing is debounced.
function S.SchedulePendingClose()
	S.CancelPendingClose()
	pendingClose = S.After(0.25, function()
		pendingClose = nil
		S.EndSession(false)
	end)
end

function S.EndSession(callServer)
	S.CancelPendingClose()
	local s = S.session
	S.session = nil
	if s and callServer then
		if s.kind == "gossip" then
			S.API("CloseGossip")
		elseif s.kind ~= "demo" then
			S.API("CloseQuest")
		end
	end
	UI.Hide()
	S.After(0.3, function()
		if not S.session then S.Compat.Suppress(false) end
	end)
end

function S.Close()
	S.EndSession(true)
end

-- Called by the frame's OnHide (ESC key, close button, fade finished).
function S.OnFrameHidden()
	UI.chat.start = nil
	pcall(ClearOverrideBindings, UI.frame)
	if S.session then S.EndSession(true) end
end

-- If anything in our code errors, hand the original Blizzard windows back so the player
-- is never stuck with an invisible dialog.
function S.FailOpen()
	S.session = nil
	S.CancelPendingClose()
	if UI.frame then
		UI.chat.start = nil
		UI.frame:Hide()
	end
	S.Compat.Suppress(false)
end

function S.OnResized()
	local s = S.session
	if s and s.choices and UI.choices:IsShown() then UI.ShowChoices(s.choices) end
end

------------------------------------------------------------------------
-- Text flow
------------------------------------------------------------------------
function S.StartDialog(s)
	S.CancelPendingClose()
	s.npcUnit = s.npcUnit or S.GetNPCUnit()
	local name = s.npcName or (s.npcUnit and UnitName(s.npcUnit)) or ""
	s.texts = S.SplitParagraphs(s.text)
	if #s.texts == 0 then s.texts = { "" } end
	s.index = 0
	S.session = s

	S.Compat.Suppress(true)
	UI.HideHovers()
	UI.chatName:SetText(stripColors(name))
	UI.SetBanner(s.title)
	UI.RefreshBackground()
	UI.Show()
	-- Models are set up after the window has been shown and drawn once; doing it earlier
	-- (on a hidden frame) can crash the 3.3.5a client.
	S.After(0.05, function()
		if S.session ~= s then return end
		UI.SetupModels(s.npcUnit)
		S.PlayNext()
	end)
end

function S.PlayText(i)
	local s = S.session
	local text = s.texts[i]
	UI.HideHovers()

	local r, g, b
	if text:byte() == 60 then   -- "<" starts an emote
		local emote = ChatTypeInfo and ChatTypeInfo["MONSTER_EMOTE"]
		if emote then r, g, b = emote.r, emote.g, emote.b end
	end
	UI.StartText(text, r, g, b)

	local npcDead = s.npcUnit and UnitIsDead(s.npcUnit)
	if UI.you:IsShown() and not UI.you.isBook and not npcDead then UI.PlayTalk(UI.you, text) end

	if i == #s.texts and s.onLast then s.onLast(s) end
	UI.ResizeChat()
end

function S.PlayNext()
	local s = S.session
	if not s then return end
	UI.nextButton:Enable()
	s.index = s.index + 1
	local count = #s.texts

	UI.SetNext(L.SL_NEXT)
	if s.index >= count then
		local finish = s.finishText
		if type(finish) == "function" then finish = finish() end
		if finish then UI.SetNext(finish) end
	end
	UI.SetCount(s.index, count)

	if s.index <= count then
		S.PlayText(s.index)
	elseif s.finishMethod then
		s.finishMethod()
	else
		S.Close()
	end
end

-- Click on the bubble (or SPACE).
function S.Advance()
	if not S.session then return end
	if UI.IsTyping() then
		UI.FinishTyping()
	elseif UI.nextButton:IsEnabled() then   -- disabled while a reward has to be picked
		S.PlayNext()
	end
end

-- Previous button / right click: start the dialog again.
function S.Rewind()
	local s = S.session
	if not s then return end
	UI.HideHovers()
	s.index = 0
	S.PlayNext()
end

------------------------------------------------------------------------
-- Quest actions (through the original buttons, see compat.lua)
------------------------------------------------------------------------
function S.Accept()
	S.Compat.ClickOrCall("QuestFrameAcceptButton", "AcceptQuest")
	S.SchedulePendingClose()   -- some quests do not close the dialog by themselves
end

function S.Decline()
	S.Compat.ClickOrCall("QuestFrameDeclineButton", "DeclineQuest")
	S.SchedulePendingClose()
end

function S.CompleteProgress()
	S.Compat.ClickOrCall("QuestFrameCompleteButton", "CompleteQuest")
end

function S.TurnIn(choice)
	local s = S.session
	if not s or s.kind ~= "complete" then return end
	choice = choice or 0
	R.PrepareAutoEquip(choice)
	S.Compat.TurnInQuest(choice)
end

------------------------------------------------------------------------
-- Objectives panel (quest detail / progress)
------------------------------------------------------------------------
local function buildObjectives(kind)
	local c = UI.objContent
	c.Title:SetText(QUEST_OBJECTIVES or L.SL_OBJECTIVES)
	if not c.objective then
		c.objective = c:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
		c.objective:SetJustifyH("LEFT"); c.objective:SetJustifyV("TOP")
		c.group = c:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		c.group:SetJustifyH("LEFT"); c.group:SetJustifyV("TOP")
	end
	local width = c:GetWidth() - 28
	local y = 40

	local objectives = S.CleanText(GetObjectiveText())
	if objectives ~= "" then
		if kind == "progress" then
			if IsQuestCompletable() then
				objectives = "|T" .. ART .. "RAIDFRAME\\ReadyCheck-Ready:15|t |cff00ff00" .. objectives
			else
				objectives = "|T" .. ART .. "RAIDFRAME\\ReadyCheck-NotReady:15|t |cffff0000" .. objectives
			end
		end
		c.objective:SetWidth(width)
		c.objective:SetText(objectives)
		c.objective:ClearAllPoints()
		c.objective:SetPoint("TOPLEFT", c, "TOPLEFT", 14, -y)
		c.objective:Show()
		y = y + c.objective:GetHeight() + 8
	else
		c.objective:SetText("")
		c.objective:Hide()
	end

	local group = S.API("GetSuggestedGroupNum") or 0
	if group > 0 and QUEST_SUGGESTED_GROUP_NUM then
		c.group:SetWidth(width)
		c.group:SetText(string.format(QUEST_SUGGESTED_GROUP_NUM, group))
		c.group:ClearAllPoints()
		c.group:SetPoint("TOPLEFT", c, "TOPLEFT", 14, -y)
		c.group:Show()
		y = y + c.group:GetHeight() + 8
	else
		c.group:Hide()
	end

	y = R.Layout(c, R.Gather(kind == "progress" and "progress" or "detail"),
		kind == "progress" and "progress" or "detail", y, false)
	c:SetHeight(y + 12)
end

local function showObjectives(kind)
	UI.objButton:Show()
	UI.objImage:SetTexture(ART .. "FriendsFrame\\FriendsFrameScrollIcon")
	UI.objImage:SetDesaturated(false)
	UI.SetTooltip(UI.objButton, QUEST_OBJECTIVES or L.SL_OBJECTIVES, L.SL_CHECK_OBJ, "ANCHOR_TOP")
	buildObjectives(kind)
	if kind == "detail" and (GetNumQuestItems() or 0) > 0 then
		local _, icon = GetQuestItemInfo("required", 1)
		if icon then UI.objImage:SetTexture(icon) end
	elseif kind == "progress" then
		UI.objImage:SetDesaturated(not IsQuestCompletable())
	end
end

local function pinObjectives()
	UI.SetTooltip(UI.objButton, nil)
	GameTooltip:Hide()
	UI.PinHover(UI.objContent, UI.objButton)
end

------------------------------------------------------------------------
-- Rewards panel (quest complete)
------------------------------------------------------------------------
local function buildRewards(data)
	local c = UI.rewContent
	c.Title:SetText(REWARDS or L.SL_REWARDS)
	local y = R.Layout(c, data, "complete", 40, true)
	c:SetHeight(y + 12)
end

------------------------------------------------------------------------
-- Choices (gossip options / quests)
------------------------------------------------------------------------
local function questLabel(title, level, daily)
	local text = title or "?"
	if level and level > 0 then
		text = "|cff" .. S.LevelColorHex(level) .. "[" .. level .. "]|r " .. text
	end
	if daily then text = text .. "  |cff66ccff(" .. L.SL_DAILY .. ")|r" end
	return text
end

local function gossipChoices()
	local list = {}
	local hasQuests, hasPlain = false, false

	local numActive = GetNumGossipActiveQuests() or 0
	if numActive > 0 then
		local d = S.Pack(GetGossipActiveQuests())
		local stride = max(3, floor(d.n / numActive))
		for i = 1, numActive do
			local base = (i - 1) * stride
			local title, level = d[base + 1], d[base + 2]
			local trivial = stride >= 4 and d[base + 3]
			local complete = d[base + stride]
			local index = i
			hasQuests = true
			list[#list + 1] = {
				text = questLabel(title, level),
				icon = ICON .. (complete and "ActiveQuestIcon" or "IncompleteQuestIcon"),
				color = trivial and GRAY or nil,
				onClick = function() S.API("SelectGossipActiveQuest", index) end,
			}
		end
	end

	local numAvailable = GetNumGossipAvailableQuests() or 0
	if numAvailable > 0 then
		local d = S.Pack(GetGossipAvailableQuests())
		local stride = max(3, floor(d.n / numAvailable))   -- 5 on 3.3.5a: title, level, trivial, daily, repeatable
		for i = 1, numAvailable do
			local base = (i - 1) * stride
			local title, level, trivial = d[base + 1], d[base + 2], d[base + 3]
			local daily = stride >= 4 and d[base + 4]
			local repeatable = stride >= 5 and d[base + 5]
			local index = i
			hasQuests = true
			local icon = "AvailableQuestIcon"
			if daily then icon = "DailyQuestIcon" elseif repeatable then icon = "DailyActiveQuestIcon" end
			list[#list + 1] = {
				text = questLabel(title, level, daily),
				icon = ICON .. icon,
				color = trivial and GRAY or nil,
				onClick = function() S.API("SelectGossipAvailableQuest", index) end,
			}
		end
	end

	local numOptions = GetNumGossipOptions() or 0
	if numOptions > 0 then
		local d = S.Pack(GetGossipOptions())
		local stride = max(2, floor(d.n / numOptions))
		for i = 1, numOptions do
			local base = (i - 1) * stride
			local text, kind = d[base + 1], d[base + 2] or "gossip"
			local index = i
			if kind == "gossip" then hasPlain = true end
			list[#list + 1] = {
				text = text or "...",
				icon = ICON .. kind .. "GossipIcon",
				onClick = function() S.API("SelectGossipOption", index) end,
			}
		end
	end
	return list, hasQuests, hasPlain
end

local function greetingChoices()
	local list = {}
	for i = 1, (GetNumActiveQuests() or 0) do
		local index = i
		local trivial = S.API("IsActiveQuestTrivial", i)
		list[#list + 1] = {
			text = questLabel(GetActiveTitle(i), S.API("GetActiveLevel", i)),
			icon = ICON .. "ActiveQuestIcon",
			color = trivial and GRAY or nil,
			onClick = function() S.API("SelectActiveQuest", index) end,
		}
	end
	for i = 1, (GetNumAvailableQuests() or 0) do
		local index = i
		local trivial = S.API("IsAvailableQuestTrivial", i)
		list[#list + 1] = {
			text = questLabel(GetAvailableTitle(i), S.API("GetAvailableLevel", i)),
			icon = ICON .. "AvailableQuestIcon",
			color = trivial and GRAY or nil,
			onClick = function() S.API("SelectAvailableQuest", index) end,
		}
	end
	return list
end

-- On the last paragraph the choices appear, and the "next" line offers the first one.
local function attachChoiceFlow(s)
	s.onLast = function()
		if #s.choices > 0 then UI.ShowChoices(s.choices) end
	end
	s.finishText = function()
		local first = s.choices[1]
		return first and stripColors(first.text) or GOODBYE or L.SL_WELL
	end
	s.finishMethod = function()
		local first = s.choices[1]
		if first then first.onClick() else S.Close() end
	end
end

------------------------------------------------------------------------
-- Event entry points
------------------------------------------------------------------------
function S.OnGossipShow()
	local choices, hasQuests, hasPlain = gossipChoices()
	if not (hasQuests or hasPlain or S.db.forceGossip) then
		-- Vendor, flight master, ...: let the original frame do its job.
		if S.session then S.EndSession(false) end
		S.Compat.Suppress(false)
		return
	end
	local s = {
		kind = "gossip",
		text = GetGossipText(),
		choices = choices,
		choiceHeader = hasQuests and L.SL_SELECT_AVAILABLE_QUEST or L.SL_SELECT_DIALOG_OPTION,
	}
	attachChoiceFlow(s)
	S.StartDialog(s)
end

function S.OnQuestGreeting()
	local s = {
		kind = "greeting",
		text = GetGreetingText(),
		title = GetTitleText(),
		choices = greetingChoices(),
		choiceHeader = L.SL_SELECT_AVAILABLE_QUEST,
	}
	attachChoiceFlow(s)
	S.StartDialog(s)
end

function S.OnQuestDetail()
	local s = { kind = "detail", text = GetQuestText(), title = GetTitleText() }
	s.onLast = function() showObjectives("detail") end
	s.finishText = L.SL_CHECK_OBJ
	s.finishMethod = function()
		if not UI.objContent:IsShown() then
			pinObjectives()
			UI.objYes:Show()
			UI.objNo:Show()
			UI.SetNext(L.SL_ACCEPTANCE)
		else
			S.Accept()
		end
	end
	S.StartDialog(s)
end

function S.OnQuestProgress()
	local s = { kind = "progress", text = GetProgressText(), title = GetTitleText() }
	s.onLast = function() showObjectives("progress") end
	s.finishText = L.SL_CHECK_OBJ
	s.finishMethod = function()
		if not UI.objContent:IsShown() then
			pinObjectives()
			if IsQuestCompletable() then
				UI.objOK:Show()
				UI.SetNext(L.SL_CONTINUE)
				UI.PlayAnimation(UI.me, ANIM.YES)
			else
				UI.SetNext(L.SL_NOT_YET)
				UI.PlayAnimation(UI.me, ANIM.NO)
			end
		elseif IsQuestCompletable() then
			S.CompleteProgress()
		else
			S.Close()
		end
	end
	S.StartDialog(s)
end

function S.OnQuestComplete()
	local s = { kind = "complete", text = GetRewardText(), title = GetTitleText() }
	s.onLast = function()
		local data = R.Gather("complete")
		if data.total > 0 then
			UI.rewFrame:Show()
			UI.rewItem.Icon:SetTexture(R.BestIcon(data))
			UI.SetTooltip(UI.rewItem, REWARDS or L.SL_REWARDS, L.SL_GET_REWARD, "ANCHOR_TOP")
			buildRewards(data)
		else
			UI.rewFrame:Hide()
		end
	end
	s.finishText = function()
		return R.Gather("complete").total > 0 and L.SL_GET_REWARD or L.SL_CONTINUE
	end
	s.finishMethod = function()
		local data = R.Gather("complete")
		local numChoices = #data.choices
		if not UI.rewContent:IsShown() and data.total > 0 then
			UI.SetTooltip(UI.rewItem, nil)
			GameTooltip:Hide()
			buildRewards(data)
			UI.PinHover(UI.rewContent, UI.rewItem, 0, -20)
			if numChoices > 1 then
				UI.SetNext(L.SL_SELECT_REWARD, false)   -- click one of the rewards instead
			else
				UI.SetNext(L.SL_CONTINUE)
			end
		elseif numChoices == 1 then
			S.TurnIn(1)
		elseif numChoices == 0 then
			S.TurnIn(0)
		end
	end
	S.StartDialog(s)
end

function S.OnGossipClosed()
	local s = S.session
	if s and s.kind == "gossip" then S.SchedulePendingClose() end
end

function S.OnQuestFinished()
	S.Compat.OnQuestFinished()
	local s = S.session
	if s and s.kind ~= "gossip" and s.kind ~= "demo" then S.SchedulePendingClose() end
end

-- Item information (icons, names) arrives asynchronously: redraw the panels.
function S.OnQuestItemUpdate()
	local s = S.session
	if not s or s.index < #s.texts then return end
	if s.kind == "complete" then
		local data = R.Gather("complete")
		if data.total > 0 then
			UI.rewItem.Icon:SetTexture(R.BestIcon(data))
			buildRewards(data)
		end
	elseif s.kind == "detail" or s.kind == "progress" then
		buildObjectives(s.kind)
	end
end

-- /storyline test
function S.Demo()
	local unit = S.GetNPCUnit() or (UnitExists("target") and not UnitIsUnit("player", "target") and "target") or nil
	local s = {
		kind = "demo",
		npcUnit = unit,
		npcName = unit and UnitName(unit) or L.SL_DEMO_NAME,
		title = L.SL_STORYLINE,
		text = L.SL_DEMO_TEXT,
		choiceHeader = L.SL_SELECT_DIALOG_OPTION,
		choices = {
			{ text = L.SL_DEMO_CHOICE1, icon = ICON .. "GossipGossipIcon", onClick = function() S.Close() end },
			{ text = L.SL_DEMO_CHOICE2, icon = ICON .. "AvailableQuestIcon", onClick = function() S.Close() end },
		},
	}
	attachChoiceFlow(s)
	S.StartDialog(s)
end

------------------------------------------------------------------------
-- Wiring of the medallion buttons (after UI.Create)
------------------------------------------------------------------------
function S.InitLogic()
	UI.objButton:SetScript("OnClick", function()
		local s = S.session
		if s and s.finishMethod then s.finishMethod() end
	end)
	UI.rewItem:SetScript("OnClick", function()
		local s = S.session
		if s and s.finishMethod then s.finishMethod() end
	end)

	UI.objYes:SetScript("OnClick", function() S.Accept() end)
	UI.objYes:SetScript("OnEnter", function(self)
		UI.PlayAnimation(UI.me, ANIM.CHEER)
		GameTooltip:SetOwner(self, "ANCHOR_TOP")
		GameTooltip:SetText(L.SL_ACCEPTANCE, 1, 0.82, 0)
		GameTooltip:Show()
	end)
	UI.objYes:SetScript("OnLeave", function() GameTooltip:Hide() end)

	UI.objNo:SetScript("OnClick", function() S.Decline() end)
	UI.objNo:SetScript("OnEnter", function(self)
		UI.PlayAnimation(UI.me, ANIM.NO)
		GameTooltip:SetOwner(self, "ANCHOR_TOP")
		GameTooltip:SetText(L.SL_DECLINE, 1, 0.82, 0)
		GameTooltip:Show()
	end)
	UI.objNo:SetScript("OnLeave", function() GameTooltip:Hide() end)
end
