-- effects.lua
-- Three extras on top of the dialog window:
--   1. Cinematic mode   - slow zoom on the model that is "talking"; the focus moves to your character when
--                         the dialog asks something of you (choices, objectives, rewards).
--   2. NPC emotes       - "<Name bows.>" plays the bow / laugh / cry / salute / wave animation.
--   3. Time tint        - the location picture follows the game time (dark blue at night, warm at dawn / dusk).

local S = _G.Storyline
local UI = S.UI

local max, min, abs, exp, floor = math.max, math.min, math.abs, math.exp, math.floor

------------------------------------------------------------------------
-- 1. Cinematic camera
------------------------------------------------------------------------
-- Depth units at 100 % strength (the default is 40 %). Depth is the first value of
-- Model:SetPosition (positive = towards the camera). No new API: the models are moved with
-- SetPosition from an OnUpdate, the same call the dialog already uses to place them.
-- In 3.5.0 these were 1.2 / -0.5 / 0.5 and a human NPC filled the whole window (head cut off), so one
-- unit of depth is a lot: a model is about 1.5 units from the camera, and the zoom factor is
-- roughly 1 / (1 - depth / 1.5).
local ZOOM_IN = 0.45     -- the model that is talking comes closer
local ZOOM_OUT = -0.20   -- the other model steps back a little
local DRIFT = 0.15       -- extra slow push-in while the focus stays on the same model
local DRIFT_TIME = 9     -- seconds the push-in takes
local SMOOTH = 2.2       -- higher = faster easing between positions (2.2: about 1.5 s to settle)

local cine = { focus = nil, time = 0 }
local driver = CreateFrame("Frame")
driver:Hide()

-- Only models drawn with the free camera are moved: a model camera is attached to the model.
local function eligible(m)
	return m and m:IsShown() and m.cameraUsed == nil and m.basePos ~= nil
end

local function goalFor(m)
	if not S.db.cinematicMode or not cine.focus then return 0 end
	local strength = max(0, min(1, S.db.cinematicStrength or 0.5))
	local sign = S.db.cinematicSign == -1 and -1 or 1
	local focused = (cine.focus == "you" and m == UI.you) or (cine.focus == "me" and m == UI.me)
	local value
	if focused then
		value = ZOOM_IN + DRIFT * min(1, cine.time / DRIFT_TIME)
	else
		value = ZOOM_OUT
	end
	return value * strength * sign
end

local function place(m, offset)
	m.cineOffset = offset
	local base = m.basePos
	pcall(m.SetPosition, m, base[1] + offset, base[2], base[3])
end

driver:SetScript("OnUpdate", function(self, elapsed)
	if not UI.frame or not UI.frame:IsShown() then self:Hide() return end
	cine.time = cine.time + elapsed
	local k = 1 - exp(-SMOOTH * elapsed)
	local moving = false
	for _, m in ipairs({ UI.me, UI.you }) do
		if eligible(m) then
			local goal = goalFor(m)
			local current = m.cineOffset or 0
			local value = current + (goal - current) * k
			if abs(goal - value) < 0.002 then value = goal end
			if value ~= current then place(m, value) end
			if value ~= goal then moving = true end
		end
	end
	-- stop when everything has settled (and the slow push-in is over)
	if not moving and (not cine.focus or cine.time >= DRIFT_TIME) then self:Hide() end
end)

-- which = "you" (the NPC is talking), "me" (the player has to answer) or nil (nobody)
function UI.CineFocus(which)
	if not S.db.cinematicMode then
		if cine.focus then UI.CineReset() end
		return
	end
	if cine.focus ~= which or which == nil then
		cine.focus = which
		cine.time = 0
	end
	driver:Show()
end

-- Back to the base positions (new dialog, option switched off).
function UI.CineReset()
	cine.focus, cine.time = nil, 0
	for _, m in ipairs({ UI.me, UI.you }) do
		if m then
			local had = (m.cineOffset or 0) ~= 0
			m.cineOffset = 0
			if had and m.basePos and m:IsShown() then
				pcall(m.SetPosition, m, m.basePos[1], m.basePos[2], m.basePos[3])
			end
		end
	end
	driver:Hide()
end

-- Applies the cinematic settings to the dialog that is open right now.
function S.ApplyCinematic()
	if not S.db.cinematicMode then
		UI.CineReset()
	elseif S.session and UI.frame:IsShown() then
		UI.CineFocus(UI.you:IsShown() and "you" or nil)
	end
end

-- Panels that ask something of the player: the focus moves to the player's model while one is open
-- and goes back to the NPC when they close.
function UI.CineBack()
	if not UI.choices or UI.choices:IsShown() or UI.objContent:IsShown() or UI.rewContent:IsShown() then return end
	if not S.session then return end
	UI.CineFocus(UI.you and UI.you:IsShown() and "you" or nil)
end

function UI.HookCineFocus(frame)
	frame:HookScript("OnShow", function()
		if S.session and UI.CineFocus then UI.CineFocus("me") end
	end)
	frame:HookScript("OnHide", function()
		if UI.CineBack then UI.CineBack() end
	end)
end

------------------------------------------------------------------------
-- 2. NPC emotes -> animations
------------------------------------------------------------------------
-- Animation ids of the emotes. A sequence the model does not have can crash the 3.3.5a client, so
-- they are only played on models that are known to have them: the player race models (every playable
-- race can /bow, /laugh, /cry, /salute and /wave). Other models just stand.
local EMOTE_SEQUENCE = { bow = 66, wave = 67, laugh = 70, cry = 77, salute = 113 }
local EMOTE_DURATION = { [66] = 2.0, [67] = 2.0, [70] = 2.5, [77] = 3.0, [113] = 1.5 }

-- English verbs in emote texts ("<Thrall bows.>", "<The orc laughs heartily.>")
local EMOTE_WORDS = {
	bow = "bow", bows = "bow", bowing = "bow", bowed = "bow",
	wave = "wave", waves = "wave", waving = "wave", waved = "wave",
	laugh = "laugh", laughs = "laugh", laughing = "laugh", laughed = "laugh", chuckle = "laugh", chuckles = "laugh",
	chuckling = "laugh", giggle = "laugh", giggles = "laugh", snickers = "laugh", cackles = "laugh", guffaws = "laugh",
	cry = "cry", cries = "cry", crying = "cry", weep = "cry", weeps = "cry", weeping = "cry", sob = "cry",
	sobs = "cry", sobbing = "cry", sniffles = "cry",
	salute = "salute", salutes = "salute", saluting = "salute", saluted = "salute",
}

local EMOTE_RACES = {
	human = true, orc = true, dwarf = true, nightelf = true, scourge = true,
	tauren = true, gnome = true, troll = true, bloodelf = true, draenei = true,
}

-- "character\<race>\<male|female>\<race><male|female>.m2" (not the "...npc.m2" variants)
local function hasEmotes(path)
	if not path then return false end
	local race, gender, file = tostring(path):lower():match("^character\\(%a+)\\(%a+)\\(%a+)%.m2$")
	return race ~= nil and EMOTE_RACES[race] == true and (gender == "male" or gender == "female")
		and file == race .. gender
end
S.ModelHasEmotes = hasEmotes

-- Returns the emote ("bow", "laugh"...) described by an emote text, or nil. Only texts that start with "<".
function S.EmoteFromText(text)
	if not text or text:byte() ~= 60 then return nil end
	for word in text:lower():gmatch("%a+") do
		if EMOTE_WORDS[word] then return EMOTE_WORDS[word] end
	end
	return nil
end

function UI.PlayEmote(model, text)
	if not S.db.emoteAnimations or not S.db.modelAnimations then return end
	if not model or not model:IsShown() then return end
	local emote = S.EmoteFromText(text)
	if not emote or not hasEmotes(model.model) then return end
	local sequence = EMOTE_SEQUENCE[emote]
	UI.PlayAnimation(model, sequence, EMOTE_DURATION[sequence], true)
end

------------------------------------------------------------------------
-- 3. Tint of the location picture by game time
------------------------------------------------------------------------
-- hour -> colour; in between the colour is blended. Multiplied with the picture, so night is darker.
local NIGHT = { 0.38, 0.46, 0.80 }
local DAWN = { 1.00, 0.80, 0.62 }
local DAY = { 1.00, 1.00, 1.00 }
local DUSK = { 1.00, 0.72, 0.55 }
local KEYS = {
	{ 0, NIGHT }, { 4.5, NIGHT }, { 6, DAWN }, { 8, DAY }, { 16.5, DAY }, { 18.5, DUSK }, { 21, NIGHT }, { 24, NIGHT },
}

function S.TimeTint(hour)
	hour = (tonumber(hour) or 12) % 24
	for i = 2, #KEYS do
		local h1, c1 = KEYS[i - 1][1], KEYS[i - 1][2]
		local h2, c2 = KEYS[i][1], KEYS[i][2]
		if hour <= h2 then
			local t = (h2 == h1) and 0 or (hour - h1) / (h2 - h1)
			return c1[1] + (c2[1] - c1[1]) * t, c1[2] + (c2[2] - c1[2]) * t, c1[3] + (c2[3] - c1[3]) * t
		end
	end
	return NIGHT[1], NIGHT[2], NIGHT[3]
end

function UI.UpdateLocationTint()
	local art = UI.locArt
	if not art or not UI.currentLocationArt then return end
	if S.db.timeTint and GetGameTime then
		local hour, minute = GetGameTime()
		art:SetVertexColor(S.TimeTint((hour or 12) + (minute or 0) / 60))
	else
		art:SetVertexColor(1, 1, 1)
	end
end
