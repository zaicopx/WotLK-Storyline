-- layout.lua
-- The Storyline window, laid out like the Retail Storyline (Total-RP/Storyline):
-- parchment frame, banner with the quest title, the player model on the left and
-- the NPC model on the right, a chat bubble with the typed text, a glowing
-- "objectives" circle (accept / decline) and a "rewards" medallion. Artwork comes
-- from the original 3.3.5a backport (Artwork folder).
--
-- Frame levels are explicit so the choices / objectives / rewards panels are ALWAYS
-- drawn above the chat text and the models are always behind it (issue #7).

local S = _G.Storyline
local L = S.L

local UI = {}
S.UI = UI

local floor, max, min = math.floor, math.max, math.min

local ART = "Interface\\AddOns\\Storyline\\Artwork\\"
local WHITE = "Interface\\Buttons\\WHITE8X8"

local LEVEL = { BG = 11, MODELS = 12, BORDERS = 14, BANNER = 16, CHAT = 18, BUTTONS = 20, CONTROLS = 22, HOVER = 26 }

local PANEL_BACKDROP = {
	bgFile = ART .. "DialogFrame\\UI-DialogBox-Background",
	edgeFile = ART .. "GLUES\\COMMON\\TextPanel-Border",
	tile = false, tileSize = 300, edgeSize = 32,
	insets = { left = 5, right = 5, top = 5, bottom = 5 },
}

local ANIMATION_TEXT_SPEED = 80
local CHAT_MARGIN = 70

UI.LEVEL = LEVEL
UI.ART = ART

------------------------------------------------------------------------
-- Tooltips
------------------------------------------------------------------------
function UI.SetTooltip(frame, title, body, anchor)
	frame:SetScript("OnEnter", function(self)
		if self.hoverHighlight then self.hoverHighlight() end
		if not title then return end
		GameTooltip:SetOwner(self, anchor or "ANCHOR_TOP")
		GameTooltip:SetText(title, 1, 0.82, 0)
		if body then GameTooltip:AddLine(body, 1, 1, 1, 1) end
		GameTooltip:Show()
	end)
	frame:SetScript("OnLeave", function(self)
		if self.hoverLeave then self.hoverLeave() end
		GameTooltip:Hide()
	end)
end

------------------------------------------------------------------------
-- Hover frames (panels attached under a button)
------------------------------------------------------------------------
function UI.CreateHoverFrame(name, parent, width)
	local h = CreateFrame("Frame", name, parent)
	h:SetFrameStrata("HIGH")
	h:SetFrameLevel(LEVEL.HOVER)
	h:SetWidth(width or 325)
	h:SetHeight(100)
	h:SetBackdrop(PANEL_BACKDROP)
	h:EnableMouse(true)
	h.Title = h:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	h.Title:SetPoint("TOPLEFT", h, "TOPLEFT", 10, -12)
	h.Title:SetPoint("TOPRIGHT", h, "TOPRIGHT", -10, -12)
	h.Title:SetHeight(20)
	h.Title:SetJustifyH("CENTER")
	h.Title:SetJustifyV("TOP")
	h:Hide()
	return h
end

-- Pin a hover frame under a button (the original puts it 20px below).
function UI.PinHover(frame, button, x, y)
	frame:ClearAllPoints()
	frame:SetPoint("TOP", button, "BOTTOM", x or 0, -20 + (y or 0))
	frame:Show()
end

------------------------------------------------------------------------
-- Models
------------------------------------------------------------------------
local function getAnimation(modelPath, char)
	local map = modelPath and Storyline_ANIM_MAPPING and Storyline_ANIM_MAPPING[modelPath]
	if map and map[char] then return map[char] end
	return (Storyline_DEFAULT_ANIM_MAPPING and Storyline_DEFAULT_ANIM_MAPPING[char]) or 60
end

local function getDuration(modelPath, sequence)
	sequence = tostring(sequence)
	local timing = S.data and S.data.debug.timing
	if timing and modelPath and timing[modelPath] and timing[modelPath][sequence] then
		return timing[modelPath][sequence]
	end
	local byModel = Storyline_ANIMATION_SEQUENCE_DURATION_BY_MODEL
	if byModel and modelPath and byModel[modelPath] and byModel[modelPath][sequence] then
		return byModel[modelPath][sequence]
	end
	return (Storyline_ANIMATION_SEQUENCE_DURATION and Storyline_ANIMATION_SEQUENCE_DURATION[sequence]) or 4
end

-- 3.3.5a has no SetAnimation(): a sequence is played by feeding SetSequenceTime every frame.
local function playAnim(model, sequence, duration)
	model.animTimer = 0
	model.animDuration = duration
	model:SetScript("OnUpdate", function(self, elapsed)
		self.animTimer = self.animTimer + elapsed
		if self.animTimer > self.animDuration or sequence == 0 or sequence == 3 then
			self:SetScript("OnUpdate", nil)
		else
			pcall(self.SetSequenceTime, self, sequence, self.animTimer * 1000)
		end
	end)
end

local function playAnimDelayed(model, sequence, duration, delay, token)
	if delay == 0 then
		playAnim(model, sequence, duration)
	else
		S.After(delay, function()
			if model.animToken == token then playAnim(model, sequence, duration) end
		end)
	end
	return delay + duration
end

-- Calling SetSequenceTime with a sequence the model does not have can crash the client
-- (ACCESS_VIOLATION), so only sequences listed for this exact model in structures.lua are played.
local function canPlay(model, sequence)
	if sequence == 0 or sequence == 3 then return true end
	local byModel = Storyline_ANIMATION_SEQUENCE_DURATION_BY_MODEL
	byModel = model.model and byModel and byModel[model.model]
	return byModel ~= nil and byModel[tostring(sequence)] ~= nil
end

-- Plays one animation, then goes back to standing.
function UI.PlayAnimation(model, sequence)
	if not S.db.modelAnimations or not model or not model:IsShown() then return end
	if not canPlay(model, sequence) then return end
	model.animToken = (model.animToken or 0) + 1
	local token = model.animToken
	local duration = getDuration(model.model, sequence)
	playAnim(model, sequence, duration)
	S.After(duration, function()
		if model.animToken == token then playAnim(model, 0, 1) end
	end)
end

-- Talk / exclaim / ask animations following the punctuation of the text.
function UI.PlayTalk(model, text)
	if not S.db.modelAnimations or not model or not model:IsShown() then return end
	model.animToken = (model.animToken or 0) + 1
	local token = model.animToken
	local tab = {}
	if text and text:byte() ~= 60 then -- "<" starts an emote: no talking
		text:gsub("[%.%?%!]+", function(found)
			local sequence = getAnimation(model.model, found:sub(1, 1))
			if canPlay(model, sequence) then
				tab[#tab + 1] = sequence
				tab[#tab + 1] = 3
			end
		end)
	end
	if #tab == 0 then tab[1] = 3 end
	local delay = 0
	for _, sequence in ipairs(tab) do
		delay = playAnimDelayed(model, sequence, getDuration(model.model, sequence), delay, token)
	end
end

local function resizeModels(scale)
	local me, you, point = UI.me, UI.you, UI.modelsPoint
	local margin = scale < 0 and -scale or 0
	me:ClearAllPoints()
	me:SetPoint("TOP", 0, -(margin * 2))
	me:SetPoint("LEFT", margin, 0)
	me:SetPoint("BOTTOM", 0, 0)
	me:SetPoint("RIGHT", point, "LEFT", -margin, 0)

	margin = scale > 0 and scale or 0
	you:ClearAllPoints()
	you:SetPoint("TOP", 0, -(margin * 2))
	you:SetPoint("RIGHT", -margin, 0)
	you:SetPoint("BOTTOM", 0, 0)
	you:SetPoint("LEFT", point, "RIGHT", margin, 0)
end

local function currentScaleKeys()
	local a, b = UI.me.model, UI.you.model
	if a and b then return a .. "~" .. b, b .. "~" .. a end
end

-- Size hints for big creatures that have no entry in structures.lua (path fragment -> margin,
-- same unit as Storyline_SCALE_MAPPING: higher = the NPC model is drawn smaller).
local SIZE_HINTS = {
	{ "gronn", 130 }, { "giant", 120 }, { "ettin", 110 }, { "colossus", 120 }, { "behemoth", 120 },
	{ "mammoth", 110 }, { "kraken", 140 }, { "hydra", 130 }, { "wyrm", 150 }, { "dragon", 150 },
	{ "proto", 120 }, { "drake", 120 }, { "golem", 100 }, { "infernal", 100 }, { "doomguard", 100 },
	{ "treant", 90 }, { "ogre", 80 }, { "yeti", 80 }, { "abomination", 70 }, { "furbolg", 55 },
}

local function guessScale()
	local you = UI.you
	if not you:IsShown() or you.cameraUsed == 0 then return 0 end   -- camera 0 already fits the model
	local path = you.model and tostring(you.model):lower()
	if path then
		for _, hint in ipairs(SIZE_HINTS) do
			if path:find(hint[1], 1, true) then return hint[2] end
		end
	end
	local kind = you.unit and UnitCreatureType(you.unit)
	if kind == "Giant" then return 120 end
	if kind == "Dragonkin" then return 110 end
	return 0
end

UI.currentScaleKeys = currentScaleKeys

function UI.ApplyScale()
	local key, inverted = currentScaleKeys()
	local scale
	if key then
		local saved, mapping = S.scaling, Storyline_SCALE_MAPPING or {}
		scale = saved[key] or mapping[key]
		if not scale then
			local inv = saved[inverted] or mapping[inverted]
			if inv then scale = -inv end
		end
	end
	UI.scaleSaved = scale ~= nil
	UI.scale = scale or guessScale()
	resizeModels(UI.scale)
end

-- Mouse wheel over the models: make the NPC model smaller / bigger relative to yours.
-- Saved per pair of models.
local function onModelsScroll(_, delta)
	local key = currentScaleKeys()
	if not key then return end
	local scale = max(-190, min(190, (UI.scale or 0) + delta * 10))
	S.scaling[key] = scale
	UI.scale, UI.scaleSaved = scale, true
	resizeModels(scale)
end

function UI.ResetScale()
	local key = currentScaleKeys()
	if key then S.scaling[key] = nil end
	UI.ApplyScale()
end

function UI.RefreshModelTransforms()
	if UI.refreshModels then UI.refreshModels() end
end

local LIGHT_ME = { 1, 0, 0, -1, -1, 1, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0 }
local LIGHT_YOU = { 1, 0, 0, 1, 1, 1, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0 }

local function prepareModel(m, facing, light, camera)
	pcall(m.SetLight, m, unpack(light))
	if camera then pcall(m.SetCamera, m, camera) end
	if m.SetRotation then pcall(m.SetRotation, m, facing) end
	if m.SetFacing then pcall(m.SetFacing, m, facing) end
end

-- Every model has its own cameras: for character models (humans, elves, dwarves...) camera 1
-- shows the whole body, for creatures (treants, bears...) camera 0 does.
local function cameraFor(path)
	local overrides = S.cameras
	if path and overrides[path] ~= nil then return overrides[path] end
	local mode = tonumber(S.db.cameraMode)
	if mode then return mode end
	if path and not tostring(path):lower():find("^character") then return 0 end
	return 1
end
UI.cameraFor = cameraFor

-- The client resets camera / facing while a model is still loading, so everything is
-- applied again a moment later (and the model paths, needed for the scale data, are read then).
local function refreshModels(final)
	local angle = S.db.facingAngle or 0.75
	local flip = S.db.flipFacing and -1 or 1
	local me, you = UI.me, UI.you
	if me:IsShown() then
		me.model = me:GetModel() or me.model
		prepareModel(me, angle * flip, LIGHT_ME, 1)
		pcall(me.SetPosition, me, 0, 0, 0)
	end
	if you:IsShown() then
		you.model = you:GetModel() or you.model
		you.cameraUsed = cameraFor(you.model)
		prepareModel(you, -angle * flip, LIGHT_YOU, you.cameraUsed)
		local pos = you.model and Storyline_C_POSITION and Storyline_C_POSITION[you.model]
		if pos then pcall(you.SetPosition, you, pos[1], pos[2], pos[3]) else pcall(you.SetPosition, you, 0, 0, 0) end
		-- hidden until the model is known, so the wrong camera is never seen
		if you.model or final then you:SetAlpha(1) end
	end
	UI.ApplyScale()
end

UI.refreshModels = function() refreshModels(true) end

-- Must be called once the window is shown (models are not set up on hidden frames).
function UI.SetupModels(unit)
	local me, you = UI.me, UI.you
	local flip = S.db.flipFacing and -1 or 1
	me.model, you.model, you.unit = nil, nil, nil
	for _, m in ipairs({ me, you }) do
		m:SetScript("OnUpdate", nil)
		m.animToken = (m.animToken or 0) + 1
	end

	if not S.db.showModels then
		me:Hide()
		you:Hide()
		UI.tail:Hide()
		UI.ApplyScale()
		return
	end

	me:Show()
	prepareModel(me, (S.db.facingAngle or 0.75) * flip, LIGHT_ME, 1)
	pcall(me.SetUnit, me, "player")
	me.model = me:GetModel()

	if unit and UnitExists(unit) and not UnitIsUnit("player", unit) then
		you:Show()
		UI.tail:Show()
		you.unit = unit
		you:SetAlpha(0)
		prepareModel(you, -(S.db.facingAngle or 0.75) * flip, LIGHT_YOU, 1)
		pcall(you.SetUnit, you, unit)
		you.model = you:GetModel()
	else
		-- Nobody to talk to: only your character is shown.
		you:Hide()
		UI.tail:Hide()
	end

	refreshModels(false)
	UI.setupToken = (UI.setupToken or 0) + 1
	local token = UI.setupToken
	for i, delay in ipairs({ 0.1, 0.25, 0.6 }) do
		S.After(delay, function()
			if UI.setupToken == token and S.session then refreshModels(i == 3) end
		end)
	end
end

------------------------------------------------------------------------
-- Chat text (typed with an alpha gradient, as in the original)
------------------------------------------------------------------------
function UI.IsTyping()
	return UI.chat and UI.chat.start ~= nil
end

function UI.FinishTyping()
	local chat = UI.chat
	if chat.start then
		chat.start = nil
		local len = (UI.chatText:GetText() or ""):len()
		if UI.chatText.SetAlphaGradient then UI.chatText:SetAlphaGradient(len, 1) end
	end
end

function UI.ApplyTextSize()
	local path, _, flags = GameFontNormalLarge:GetFont()
	UI.chatText:SetFont(path, S.db.textSize or 16, flags)
	UI.ResizeChat()
end

function UI.UpdateDim()
	if not UI.dim then return end
	if S.db.dimWorld and UI.frame:IsShown() then UI.dim:Show() else UI.dim:Hide() end
end

function UI.ResizeChat()
	local f = UI.frame
	UI.chatText:SetWidth(f:GetWidth() - 150)
	UI.chat:SetHeight(UI.chatText:GetHeight() + UI.chatName:GetHeight() + UI.nextText:GetHeight() + CHAT_MARGIN - 20)
end

function UI.StartText(text, r, g, b)
	local say = ChatTypeInfo and ChatTypeInfo["MONSTER_SAY"]
	UI.chatText:SetTextColor(r or (say and say.r) or 1, g or (say and say.g) or 1, b or (say and say.b) or 0.62)
	UI.chatText:SetText(text or "")
	UI.ResizeChat()
	if S.db.textSpeedFactor <= 0 or not UI.chatText.SetAlphaGradient then
		UI.chat.start = nil
		if UI.chatText.SetAlphaGradient then UI.chatText:SetAlphaGradient((text or ""):len(), 1) end
	else
		UI.chatText:SetAlphaGradient(0, 30)
		UI.chat.start = 0
	end
end

local function onUpdateChat(self, elapsed)
	if self.start then
		local text = UI.chatText:GetText()
		if text and text:len() > 0 then
			self.start = self.start + elapsed * ANIMATION_TEXT_SPEED * (S.db.textSpeedFactor or 0.5)
			if S.db.textSpeedFactor == 0 or self.start >= text:len() then
				UI.FinishTyping()
			else
				UI.chatText:SetAlphaGradient(self.start, 30)
			end
		end
	end
end

function UI.SetNext(text, enabled)
	UI.nextText:SetText(text or "")
	if enabled == false then UI.nextButton:Disable() else UI.nextButton:Enable() end
end

function UI.SetCount(index, total)
	if total and total > 0 then
		UI.countText:SetText(math.min(index, total) .. "/" .. total)
		UI.countText:Show()
	else
		UI.countText:Hide()
	end
	if total and total > 1 then UI.previous:Show() else UI.previous:Hide() end
end

function UI.SetBanner(title, r, g, b)
	if title and title ~= "" then
		UI.bannerTitle:SetText(title)
		UI.bannerTitle:SetTextColor(r or 0.95, g or 0.95, b or 0.95)
		UI.banner:Show()
	else
		UI.bannerTitle:SetText("")
		UI.banner:Hide()
	end
end

------------------------------------------------------------------------
-- Choices (gossip options / quests), shown in a hover frame
------------------------------------------------------------------------
local choiceButtons = {}
local ROW_ICON, ROW_NUM = 18, 12

local function createChoiceButton(i)
	local b = CreateFrame("Button", "StorylineChoiceButton" .. i, UI.choices)
	b:SetHeight(22)
	b:RegisterForClicks("LeftButtonUp")
	b:SetFrameLevel(LEVEL.HOVER + 2)

	b.hl = b:CreateTexture(nil, "HIGHLIGHT")
	b.hl:SetAllPoints(b)
	b.hl:SetTexture(ART .. "QuestFrame\\UI-QuestTitleHighlight")
	b.hl:SetBlendMode("ADD")

	b.num = b:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	b.num:SetPoint("LEFT", b, "LEFT", 4, 0)
	b.num:SetWidth(ROW_NUM)
	b.num:SetJustifyH("LEFT")
	b.num:SetTextColor(0.55, 0.55, 0.55)

	b.icon = b:CreateTexture(nil, "ARTWORK")
	b.icon:SetWidth(ROW_ICON)
	b.icon:SetHeight(ROW_ICON)
	b.icon:SetPoint("LEFT", b, "LEFT", 4 + ROW_NUM + 2, 0)

	b.text = b:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	b.text:SetPoint("LEFT", b.icon, "RIGHT", 5, 0)
	b.text:SetJustifyH("LEFT")
	b.text:SetJustifyV("MIDDLE")
	b.text:SetTextColor(1, 0.82, 0)

	b:SetScript("OnEnter", function(self) self.text:SetTextColor(1, 1, 1) end)
	b:SetScript("OnLeave", function(self)
		local c = self.def and self.def.color or { 1, 0.82, 0 }
		self.text:SetTextColor(c[1], c[2], c[3])
	end)
	b:SetScript("OnClick", function(self)
		if self.def and self.def.onClick then
			PlaySound("igMainMenuOptionCheckBoxOn")
			self.def.onClick()
		end
	end)
	return b
end

-- A small box between the two models, as wide as its longest line (no title, no big frame).
function UI.ShowChoices(list)
	local panel = UI.choices
	local frame = UI.frame
	local maxWidth = max(220, min(340, floor(frame:GetWidth() * 0.4)))
	local chrome = 12 + 4 + ROW_NUM + 2 + ROW_ICON + 5 + 8   -- paddings + number + icon

	local widest = 0
	for i, def in ipairs(list) do
		local b = choiceButtons[i] or createChoiceButton(i)
		choiceButtons[i] = b
		b.def = def
		b.text:SetWidth(0)
		b.text:SetText(def.text or "")
		widest = max(widest, b.text:GetStringWidth())
	end
	local width = max(200, min(maxWidth, widest + chrome))
	panel:SetWidth(width)

	local y = 8
	for i, def in ipairs(list) do
		local b = choiceButtons[i]
		b:SetWidth(width - 12)
		b.text:SetWidth(width - 12 - (4 + ROW_NUM + 2 + ROW_ICON + 5) - 4)
		local c = def.color or { 1, 0.82, 0 }
		b.text:SetTextColor(c[1], c[2], c[3])
		b.icon:SetTexture(def.icon or "Interface\\GossipFrame\\GossipGossipIcon")
		if def.iconColor then b.icon:SetVertexColor(def.iconColor[1], def.iconColor[2], def.iconColor[3]) else b.icon:SetVertexColor(1, 1, 1) end
		b.num:SetText(i <= 9 and tostring(i) or "")
		local h = max(22, b.text:GetStringHeight() + 8)
		b:SetHeight(h)
		b:ClearAllPoints()
		b:SetPoint("TOPLEFT", panel, "TOPLEFT", 6, -y)
		b:Show()
		y = y + h + 1
	end
	for i = #list + 1, #choiceButtons do choiceButtons[i]:Hide() end

	panel:SetHeight(y + 8)
	UI.numChoices = #list
	panel:ClearAllPoints()
	panel:SetPoint("TOP", frame, "TOP", 0, -floor(frame:GetHeight() * 0.24))
	panel:Show()
	UI.RefreshBindings()
end

------------------------------------------------------------------------
-- Show / hide, bindings, saving
------------------------------------------------------------------------
function UI.HideHovers()
	UI.choices:Hide()
	UI.objContent:Hide()
	UI.rewContent:Hide()
	UI.objButton:Hide()
	UI.objYes:Hide()
	UI.objNo:Hide()
	UI.objOK:Hide()
	UI.rewFrame:Hide()
	UI.numChoices = 0
end

function UI.RefreshBindings()
	local f = UI.frame
	if not f then return end
	pcall(ClearOverrideBindings, f)
	if not (S.session and f:IsShown() and S.db.keyShortcuts) then return end
	pcall(SetOverrideBindingClick, f, true, "SPACE", "StorylineAdvanceButton")
	if UI.choices:IsShown() then
		for i = 1, min(9, UI.numChoices or 0) do
			pcall(SetOverrideBindingClick, f, true, tostring(i), "StorylineChoiceButton" .. i)
		end
	end
end

-- Key icon: bright = window locked, grey = free to move.
function UI.UpdateLock()
	if not UI.lock then return end
	UI.lock.icon:SetDesaturated(not S.db.lockFrame)
	UI.lock.icon:SetAlpha(S.db.lockFrame and 1 or 0.6)
end

function UI.RefreshBackground()
	local art = UI.bgArt
	local r, g, b = 1, 1, 1
	if S.db.tintBackground then
		local faction = UnitFactionGroup("player")
		if faction == "Alliance" then r, g, b = 0.55, 0.72, 1
		elseif faction == "Horde" then r, g, b = 1, 0.55, 0.50 end
	end
	art:SetVertexColor(r, g, b)
end

function UI.Show()
	local f = UI.frame
	S.CancelFade(f)
	if not f:IsShown() then
		f:SetAlpha(0)
		f:Show()
		PlaySound("igQuestLogOpen")
		S.Fade(f, 1, 0.25)
	else
		f:SetAlpha(1)
	end
	UI.UpdateDim()
	UI.RefreshBindings()
end

function UI.Hide()
	local f = UI.frame
	if not f or not f:IsShown() then return end
	pcall(ClearOverrideBindings, f)
	PlaySound("igQuestLogClose")
	S.Fade(f, 0, 0.2, true)
end

local function saveFrame()
	local f, c = UI.frame, S.db
	local x, y = f:GetLeft(), f:GetBottom()
	if x then
		f:ClearAllPoints()
		f:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", x, y)
		c.point, c.x, c.y = "BOTTOMLEFT", x, y
	end
	c.width, c.height = f:GetWidth(), f:GetHeight()
end

function UI.ApplyFrameDB()
	local f, c = UI.frame, S.db
	f:ClearAllPoints()
	f:SetWidth(c.width)
	f:SetHeight(c.height)
	if c.point then f:SetPoint(c.point, UIParent, c.point, c.x, c.y) else f:SetPoint("CENTER", UIParent, "CENTER", 0, 0) end
	UI.ResizeChat()
end

------------------------------------------------------------------------
-- Build
------------------------------------------------------------------------
local function createIconButton(name, parent)
	-- Round medallion button (original "IconButton" template, rebuilt in Lua)
	local b = CreateFrame("Button", name, parent)
	b:SetWidth(26)
	b:SetHeight(26)
	b.Icon = b:CreateTexture(nil, "OVERLAY")
	b.Icon:SetWidth(26)
	b.Icon:SetHeight(26)
	b.Icon:SetPoint("CENTER", b, "CENTER", 0, 0)
	b.Icon:SetTexture(ART .. "ICONS\\INV_Misc_QuestionMark")

	b:SetNormalTexture(ART .. "AchievementFrame\\UI-Achievement-IconFrame")
	local n = b:GetNormalTexture()
	n:ClearAllPoints(); n:SetWidth(65); n:SetHeight(65); n:SetPoint("CENTER", b, "CENTER", 14, -14)
	b:SetPushedTexture(ART .. "Buttons\\UI-EmptySlot")
	local p = b:GetPushedTexture()
	p:ClearAllPoints(); p:SetWidth(50); p:SetHeight(50); p:SetPoint("CENTER", b, "CENTER", 0, 0)
	b:SetDisabledTexture(ART .. "Buttons\\UI-EmptySlot-Disabled")
	local d = b:GetDisabledTexture()
	d:ClearAllPoints(); d:SetWidth(47); d:SetHeight(47); d:SetPoint("CENTER", b, "CENTER", 0, 0)
	b:SetHighlightTexture(ART .. "Buttons\\UI-Quickslot-Depress", "ADD")
	return b
end
UI.CreateIconButton = createIconButton

function UI.Create()
	local c = S.db

	---------------- main frame ----------------
	local f = CreateFrame("Frame", "Storyline_NPCFrame", UIParent)
	UI.frame = f
	f:SetFrameStrata("HIGH")
	f:SetFrameLevel(10)
	f:SetWidth(c.width)
	f:SetHeight(c.height)
	if c.point then f:SetPoint(c.point, UIParent, c.point, c.x, c.y) else f:SetPoint("CENTER", UIParent, "CENTER", 0, 0) end
	f:SetClampedToScreen(true)
	f:SetMovable(true)
	f:SetResizable(true)
	f:SetMinResize(700, 450)
	f:SetMaxResize(max(700, GetScreenWidth() * 0.95), max(450, GetScreenHeight() * 0.95))
	f:EnableMouse(true)
	f:RegisterForDrag("LeftButton")
	f:Hide()
	f:SetScript("OnDragStart", function(self) if not S.db.lockFrame then self:StartMoving() end end)
	f:SetScript("OnDragStop", function(self) self:StopMovingOrSizing(); saveFrame() end)
	f:SetScript("OnHide", function() UI.UpdateDim(); S.OnFrameHidden() end)
	f:SetScript("OnSizeChanged", function() if UI.chat then UI.ResizeChat() end end)
	tinsert(UISpecialFrames, "Storyline_NPCFrame")   -- ESC closes the window

	local adv = CreateFrame("Button", "StorylineAdvanceButton", f)   -- target of the SPACE binding
	adv:SetWidth(1); adv:SetHeight(1)
	adv:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 0, 0)
	adv:SetScript("OnClick", function() S.Advance() end)

	---------------- dim layer (darkens only the 3D world, below every UI frame) ----------------
	UI.dim = CreateFrame("Frame", "Storyline_Dim", UIParent)
	UI.dim:SetAllPoints(UIParent)
	UI.dim:SetFrameStrata("BACKGROUND")
	local dimTex = UI.dim:CreateTexture(nil, "BACKGROUND")
	dimTex:SetAllPoints(UI.dim)
	dimTex:SetTexture(0, 0, 0, 0.5)
	UI.dim:Hide()

	---------------- background ----------------
	local bg = CreateFrame("Frame", "Storyline_NPCFrameBackground", f, "Storyline_ParchmentBackground")
	bg:SetAllPoints(f)
	bg:SetFrameLevel(LEVEL.BG)
	UI.bgArt = bg:CreateTexture(nil, "BORDER")
	UI.bgArt:SetPoint("TOPLEFT", f, "TOPLEFT", 20, -20)
	UI.bgArt:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -20, 20)
	UI.bgArt:SetTexture(ART .. "DRESSUPFRAME\\DressUpBackground-NightElf1")
	UI.bgArt:SetAlpha(0.5)
	UI.bgArt:SetDesaturated(true)

	---------------- models ----------------
	local models = CreateFrame("Frame", "Storyline_NPCFrameModels", f)
	models:SetFrameLevel(LEVEL.MODELS)
	models:SetPoint("TOPLEFT", f, "TOPLEFT", 20, -20)
	models:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -20, 20)
	models:EnableMouseWheel(true)
	models:SetScript("OnMouseWheel", onModelsScroll)
	UI.models = models

	UI.modelsPoint = CreateFrame("Frame", "Storyline_NPCFrameModelsPoint", models)
	UI.modelsPoint:SetWidth(10); UI.modelsPoint:SetHeight(10)
	UI.modelsPoint:SetPoint("CENTER", models, "CENTER", 0, 0)

	UI.me = CreateFrame("PlayerModel", "Storyline_NPCFrameModelsMe", models)
	UI.you = CreateFrame("PlayerModel", "Storyline_NPCFrameModelsYou", models)
	UI.me:SetFrameLevel(LEVEL.MODELS + 1)
	UI.you:SetFrameLevel(LEVEL.MODELS + 1)
	resizeModels(0)

	---------------- borders ----------------
	local borders = CreateFrame("Frame", "Storyline_NPCFrameBorders", f, "Storyline_ParchmentBorders")
	borders:SetAllPoints(f)
	borders:SetFrameLevel(LEVEL.BORDERS)

	---------------- banner ----------------
	local banner = CreateFrame("Frame", "Storyline_NPCFrameBanner", f)
	UI.banner = banner
	banner:SetFrameLevel(LEVEL.BANNER)
	banner:SetWidth(384); banner:SetHeight(96)
	banner:SetPoint("TOP", f, "TOP", 0, 0)
	local bannerTex = banner:CreateTexture(nil, "OVERLAY")
	bannerTex:SetAllPoints(banner)
	bannerTex:SetTexture(ART .. "Garrison\\GarrMission_RewardsBanner-Desaturate")
	UI.bannerTitle = banner:CreateFontString("Storyline_NPCFrameTitle", "OVERLAY", "GameFontNormalLarge")
	UI.bannerTitle:SetWidth(230); UI.bannerTitle:SetHeight(50)
	UI.bannerTitle:SetPoint("CENTER", banner, "CENTER", 0, 8)
	UI.bannerTitle:SetJustifyH("CENTER"); UI.bannerTitle:SetJustifyV("MIDDLE")
	banner:Hide()

	---------------- chat bubble ----------------
	local chat = CreateFrame("Frame", "Storyline_NPCFrameChat", f)
	UI.chat = chat
	chat:SetFrameLevel(LEVEL.CHAT)
	chat:SetHeight(150)
	chat:SetPoint("BOTTOM", f, "BOTTOM", 0, 25)
	chat:SetPoint("LEFT", f, "LEFT", 30, 0)
	chat:SetPoint("RIGHT", f, "RIGHT", -30, 0)
	chat:SetBackdrop(PANEL_BACKDROP)
	chat:SetScript("OnUpdate", onUpdateChat)

	local tail = chat:CreateTexture(nil, "BACKGROUND")
	UI.tail = tail
	tail:SetTexture(ART .. "Tooltips\\CHATBUBBLE-TAIL")
	tail:SetWidth(32); tail:SetHeight(32)
	tail:SetPoint("BOTTOMRIGHT", chat, "TOPRIGHT", -40, -3)
	tail:SetTexCoord(1, 0, 1, 0)

	UI.chatName = chat:CreateFontString("Storyline_NPCFrameChatName", "OVERLAY", "GameFontNormalLarge")
	UI.chatName:SetPoint("TOPLEFT", chat, "TOPLEFT", 50, -12)
	UI.chatName:SetPoint("TOPRIGHT", chat, "TOPRIGHT", -50, -12)
	UI.chatName:SetJustifyH("RIGHT"); UI.chatName:SetJustifyV("TOP")
	UI.chatName:SetTextColor(1, 0.75, 0)

	UI.chatText = chat:CreateFontString("Storyline_NPCFrameChatText", "OVERLAY", "GameFontNormalLarge")
	UI.chatText:SetPoint("TOPLEFT", UI.chatName, "BOTTOMLEFT", 0, -10)
	UI.chatText:SetJustifyH("LEFT"); UI.chatText:SetJustifyV("TOP")
	UI.chatText:SetWidth(550)

	UI.nextText = chat:CreateFontString("Storyline_NPCFrameChatNextText", "OVERLAY", "GameFontNormalSmall")
	UI.nextText:SetPoint("BOTTOM", chat, "BOTTOM", 0, 17)
	UI.nextText:SetPoint("LEFT", chat, "LEFT", 60, 0)
	UI.nextText:SetPoint("RIGHT", chat, "RIGHT", -60, 0)
	UI.nextText:SetJustifyH("CENTER"); UI.nextText:SetJustifyV("BOTTOM")
	UI.nextText:SetTextColor(1, 1, 0.4)
	UI.nextText:SetHeight(14)

	UI.countText = chat:CreateFontString("Storyline_NPCFrameChatCountText", "OVERLAY", "GameFontNormal")
	UI.countText:SetPoint("BOTTOMRIGHT", chat, "BOTTOMRIGHT", -40, 17)
	UI.countText:SetJustifyH("RIGHT")
	UI.countText:SetTextColor(0.4, 0.4, 0.4)

	local glow = chat:CreateTexture(nil, "OVERLAY")
	UI.chatGlow = glow
	glow:SetPoint("TOPLEFT", chat, "TOPLEFT", 8, -8)
	glow:SetPoint("BOTTOMRIGHT", chat, "BOTTOMRIGHT", -8, 8)
	glow:SetTexture(ART .. "QuestFrame\\UI-QuestTitleHighlight")
	glow:SetBlendMode("ADD")
	glow:SetAlpha(0.25)
	glow:Hide()

	local nextButton = CreateFrame("Button", "Storyline_NPCFrameChatNext", chat)
	UI.nextButton = nextButton
	nextButton:SetAllPoints(chat)
	nextButton:SetFrameLevel(LEVEL.CHAT + 4)
	nextButton:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	nextButton:SetScript("OnEnter", function() if UI.nextButton:IsEnabled() then glow:Show() end end)
	nextButton:SetScript("OnLeave", function() glow:Hide() end)
	nextButton:SetScript("OnClick", function(_, button)
		if button == "RightButton" then S.Rewind() else S.Advance() end
	end)

	local previous = CreateFrame("Button", "Storyline_NPCFrameChatPrevious", chat)
	UI.previous = previous
	previous:SetWidth(35); previous:SetHeight(35)
	previous:SetPoint("BOTTOMRIGHT", chat, "BOTTOMRIGHT", -5, 5)
	previous:SetFrameLevel(LEVEL.CHAT + 5)
	previous:SetNormalTexture(ART .. "Buttons\\UI-RotationLeft-Button-Up")
	previous:SetPushedTexture(ART .. "Buttons\\UI-RotationLeft-Button-Down")
	previous:SetHighlightTexture(ART .. "Buttons\\ButtonHilight-Round", "ADD")
	previous:SetScript("OnClick", function() S.Rewind() end)
	UI.SetTooltip(previous, L.SL_RESET, L.SL_RESET_TT, "ANCHOR_TOP")
	previous:Hide()

	---------------- objectives medallion ----------------
	local obj = CreateFrame("Button", "Storyline_NPCFrameObjectives", f)
	UI.objButton = obj
	obj:SetFrameLevel(LEVEL.BUTTONS)
	obj:SetWidth(70); obj:SetHeight(70)
	obj:SetPoint("TOP", f, "TOP", 0, -100)
	UI.objHolo = obj:CreateTexture(nil, "BORDER")
	UI.objHolo:SetTexture(ART .. "UNITPOWERBARALT\\PandarenTrainingLarge_Circular_Flash")
	UI.objHolo:SetBlendMode("ADD"); UI.objHolo:SetAlpha(0.5)
	UI.objHolo:SetWidth(108); UI.objHolo:SetHeight(108); UI.objHolo:SetPoint("CENTER", obj, "CENTER", 0, 0)
	UI.objImage = obj:CreateTexture(nil, "ARTWORK")
	UI.objImage:SetTexture(ART .. "FriendsFrame\\FriendsFrameScrollIcon")
	UI.objImage:SetWidth(48); UI.objImage:SetHeight(48); UI.objImage:SetPoint("CENTER", obj, "CENTER", 0, 0)
	local objRing = obj:CreateTexture(nil, "OVERLAY")
	objRing:SetTexture(ART .. "UNITPOWERBARALT\\PandarenTrainingLarge_Circular_Frame")
	objRing:SetWidth(100); objRing:SetHeight(100); objRing:SetPoint("CENTER", obj, "CENTER", 0, 0)
	UI.objOK = obj:CreateTexture(nil, "OVERLAY")
	UI.objOK:SetTexture(ART .. "RAIDFRAME\\ReadyCheck-Ready")
	UI.objOK:SetWidth(40); UI.objOK:SetHeight(40); UI.objOK:SetPoint("CENTER", obj, "CENTER", 0, 0)
	UI.objOK:Hide()
	obj.hoverHighlight = function() UI.objHolo:SetAlpha(0.75) end
	obj.hoverLeave = function() UI.objHolo:SetAlpha(0.5) end
	obj:Hide()

	UI.objYes = CreateFrame("Button", "Storyline_NPCFrameObjectivesYes", obj)
	UI.objYes:SetWidth(40); UI.objYes:SetHeight(40)
	UI.objYes:SetPoint("RIGHT", obj, "LEFT", 0, 0)
	UI.objYes:SetNormalTexture(ART .. "RAIDFRAME\\ReadyCheck-Ready")
	UI.objYes:SetHighlightTexture(ART .. "PETBATTLES\\PetBattle-SelectedPetGlow", "ADD")
	UI.objYes:Hide()
	UI.objNo = CreateFrame("Button", "Storyline_NPCFrameObjectivesNo", obj)
	UI.objNo:SetWidth(40); UI.objNo:SetHeight(40)
	UI.objNo:SetPoint("LEFT", obj, "RIGHT", 0, 0)
	UI.objNo:SetNormalTexture(ART .. "RAIDFRAME\\ReadyCheck-NotReady")
	UI.objNo:SetHighlightTexture(ART .. "PETBATTLES\\PetBattle-SelectedPetGlow", "ADD")
	UI.objNo:Hide()

	UI.objContent = UI.CreateHoverFrame("Storyline_NPCFrameObjectivesContent", f, 325)

	---------------- rewards medallion ----------------
	local rew = CreateFrame("Frame", "Storyline_NPCFrameRewards", f)
	UI.rewFrame = rew
	rew:SetFrameLevel(LEVEL.BUTTONS)
	rew:SetWidth(70); rew:SetHeight(70)
	rew:SetPoint("TOP", f, "TOP", 0, -200)
	UI.rewHolo = rew:CreateTexture(nil, "BORDER")
	UI.rewHolo:SetTexture(ART .. "UNITPOWERBARALT\\PandarenTrainingLarge_Circular_Flash")
	UI.rewHolo:SetBlendMode("ADD"); UI.rewHolo:SetAlpha(0.5)
	UI.rewHolo:SetWidth(256); UI.rewHolo:SetHeight(256); UI.rewHolo:SetPoint("CENTER", rew, "CENTER", -3, 100)
	local rewArt = rew:CreateTexture(nil, "ARTWORK")
	rewArt:SetTexture(ART .. "ExtraButton\\GarrZoneAbility-TradingPost")
	rewArt:SetWidth(256); rewArt:SetHeight(128); rewArt:SetPoint("CENTER", rew, "CENTER", -3, 100)

	UI.rewItem = createIconButton("Storyline_NPCFrameRewardsItem", rew)
	UI.rewItem:SetFrameLevel(LEVEL.BUTTONS + 1)
	UI.rewItem:SetPoint("CENTER", rew, "CENTER", 0, 66)
	UI.rewItem:SetScale(1.5)
	UI.rewItem.hoverHighlight = function() UI.rewHolo:SetAlpha(0.75) end
	UI.rewItem.hoverLeave = function() UI.rewHolo:SetAlpha(0.5) end
	rew:Hide()

	UI.rewContent = UI.CreateHoverFrame("Storyline_NPCFrameRewardsContent", f, 325)

	---------------- gossip choices ----------------
	UI.choices = UI.CreateHoverFrame("Storyline_NPCFrameGossipChoices", f, 260)
	UI.choices:SetBackdrop({
		bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
		edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
		tile = true, tileSize = 16, edgeSize = 14,
		insets = { left = 3, right = 3, top = 3, bottom = 3 },
	})
	UI.choices:SetBackdropColor(0, 0, 0, 0.85)
	UI.choices:SetBackdropBorderColor(0.75, 0.62, 0.15, 1)
	UI.choices.Title:Hide()

	---------------- close / lock / config / resize ----------------
	local close = CreateFrame("Button", "Storyline_NPCFrameClose", f, "UIPanelCloseButton")
	close:SetFrameLevel(LEVEL.CONTROLS)
	close:SetPoint("TOPRIGHT", f, "TOPRIGHT", -5, -10)
	close:SetScript("OnClick", function() S.Close() end)

	local lock = CreateFrame("Button", "Storyline_NPCFrameLock", f)
	UI.lock = lock
	lock:SetFrameLevel(LEVEL.CONTROLS)
	lock:SetWidth(32); lock:SetHeight(32)
	lock:SetPoint("TOPRIGHT", close, "TOPLEFT", 4, 0)
	lock:SetNormalTexture(ART .. "Buttons\\UI-SquareButton-Up")
	lock:SetPushedTexture(ART .. "Buttons\\UI-SquareButton-Down")
	lock:SetHighlightTexture(ART .. "Buttons\\UI-Common-MouseHilight", "ADD")
	lock.icon = lock:CreateTexture(nil, "OVERLAY")
	lock.icon:SetTexture("Interface\\Icons\\INV_Misc_Key_03")
	lock.icon:SetWidth(18); lock.icon:SetHeight(18)
	lock.icon:SetPoint("CENTER", lock, "CENTER", 0, 0)
	lock:SetScript("OnClick", function()
		S.db.lockFrame = not S.db.lockFrame
		PlaySound("igMainMenuOptionCheckBoxOn")
		UI.UpdateLock()
		if S.Options.Refresh then S.Options.Refresh() end
	end)
	UI.SetTooltip(lock, L.SL_CONFIG_LOCKFRAME, L.SL_CONFIG_LOCKFRAME_TT, "ANCHOR_TOP")
	UI.UpdateLock()

	local config = CreateFrame("Button", "Storyline_NPCFrameConfigButton", f)
	config:SetFrameLevel(LEVEL.CONTROLS)
	config:SetWidth(32); config:SetHeight(32)
	config:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 5, 10)
	config:SetNormalTexture(ART .. "Buttons\\UI-SquareButton-Up")
	config:SetPushedTexture(ART .. "Buttons\\UI-SquareButton-Down")
	config:SetDisabledTexture(ART .. "Buttons\\UI-SquareButton-Disabled")
	config:SetHighlightTexture(ART .. "Buttons\\UI-Common-MouseHilight", "ADD")
	local gear = config:CreateTexture(nil, "OVERLAY")
	gear:SetTexture(ART .. "Buttons\\UI-OptionsButton")
	gear:SetWidth(16); gear:SetHeight(16); gear:SetPoint("CENTER", config, "CENTER", 0, 0)
	config:SetScript("OnClick", function() S.Options.Open() end)
	UI.SetTooltip(config, L.SL_CONFIG, nil, "ANCHOR_TOP")

	local grip = CreateFrame("Button", "Storyline_NPCFrameResizeButton", f)
	grip:SetFrameLevel(LEVEL.CONTROLS)
	grip:SetWidth(16); grip:SetHeight(16)
	grip:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -5, 10)
	grip:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
	grip:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
	grip:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
	grip:SetScript("OnMouseDown", function() if not S.db.lockFrame then f:StartSizing("BOTTOMRIGHT") end end)
	grip:SetScript("OnMouseUp", function()
		f:StopMovingOrSizing()
		saveFrame()
		UI.ResizeChat()
		if S.OnResized then S.OnResized() end
	end)
	UI.SetTooltip(grip, L.SL_RESIZE, L.SL_RESIZE_TT, "ANCHOR_TOP")

	UI.HideHovers()
	UI.RefreshBackground()
	UI.ApplyTextSize()
end
