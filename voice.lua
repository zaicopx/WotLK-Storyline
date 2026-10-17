-- voice.lua
-- Compatibility with VoiceOver (AI_VoiceOver, the voice-over addon for 3.3.5 private servers).
--
-- VoiceOver plays ONE sound file for the whole quest / gossip text and knows its length
-- (SoundData.length). Storyline splits that text into paragraphs, so the paragraph borders inside the sound are
-- estimated from the number of characters (an emote "<...>" is not spoken and takes no time). With that:
--
--   * "Text follows the voice": the typing of a paragraph is driven by the audio clock instead of the normal
--     typing speed, so the text appears at the pace of the voice.
--   * "Wait for the voice": the next paragraph (and the action after the last one) is locked until the voice has
--     reached the end of the current paragraph. SHIFT + click skips the voice (it is stopped) and goes on.
--
--   * "Continue automatically": when the voice has finished a paragraph, the next one starts by itself (after a short
--     pause), so the dialog can be listened to without clicking. After the last paragraph the action (check
--     objectives, show the choices) is also done for quests being offered and for gossip, but NEVER for a quest that is
--     being completed: handing in a quest always needs a click.
--
-- Nothing in VoiceOver is changed. The addon is found through its single global `VoiceOver` (its sound queue
-- is hooked with hooksecurefunc). Without VoiceOver, without a voice for the current dialog, when its queue is
-- paused, or after the player went ahead of the voice (rewind, skipping), everything works as before.

local S = _G.Storyline
local UI = S.UI
local L = S.L

local V = {}
S.Voice = V

local max, min = math.max, math.min

local started = setmetatable({}, { __mode = "k" })    -- sound -> GetTime() at which its audio starts
local finished = setmetatable({}, { __mode = "k" })   -- sound -> true (played to the end) / false (cut off)
local current                                         -- the voice of the dialog on screen

local TYPING_LEAD = 12        -- characters: the text is a little ahead of the voice (the end of the fade)
local WAIT_FOR_START = 4      -- seconds to wait for a queued voice to start before giving up on it
local UNLOCK_EARLY = 0.05     -- seconds
local AUTO_PAUSE = 0.35       -- seconds of silence after a paragraph before the next one starts by itself
local AUTO_MIN_READ = 1.2     -- seconds a paragraph stays on screen at least (+ 0.02 s per character) before it
                              -- is replaced automatically; keeps the pace sane if the voice ended early

local function voiceOver()
	local ns = _G.VoiceOver
	if type(ns) == "table" and type(ns.SoundQueue) == "table" and type(ns.SoundQueue.sounds) == "table" then
		return ns
	end
end

function V.IsInstalled()
	return voiceOver() ~= nil
end

local function queuePaused(ns)
	local addon = ns.Addon
	return addon and addon.db and addon.db.char and addon.db.char.IsPaused
end

------------------------------------------------------------------------
-- Hooks on VoiceOver's sound queue
------------------------------------------------------------------------
function V.Init()
	if V.hooked then return end
	local ns = voiceOver()
	if not ns then return end
	V.hooked = true
	local queue = ns.SoundQueue

	hooksecurefunc(queue, "PlaySound", function(_, sound)
		if type(sound) ~= "table" then return end
		-- played a second time (resumed after a pause): VoiceOver starts it from the beginning again
		if started[sound] and current and current.sound == sound then current.restarted = true end
		started[sound] = GetTime() + (sound.delay or 0)   -- 3.3.5: the music fades out first (sound.delay)
	end)

	hooksecurefunc(queue, "RemoveSoundFromQueue", function(_, sound, playedToTheEnd)
		if type(sound) ~= "table" then return end
		finished[sound] = playedToTheEnd and true or false
	end)

	hooksecurefunc(queue, "PauseQueue", function()
		if current then current.stopped = true end
	end)

	-- VoiceOver's handler may run after Storyline's first paragraph has started: pick the voice up late.
	hooksecurefunc(queue, "AddSoundToQueue", function(_, sound)
		if S.session and not current and type(sound) == "table" and queue:Contains(sound) then
			V.Attach(S.session)
			local s = S.session
			if s and current and s.index and s.index >= 1 then V.OnText(s.index, true) end
		end
	end)
end

------------------------------------------------------------------------
-- Finding the voice of the dialog and estimating the paragraph borders
------------------------------------------------------------------------
local function findSound(s)
	local ns = voiceOver()
	if not ns or not s.text or s.text == "" then return end
	local sounds = ns.SoundQueue.sounds
	for i = #sounds, 1, -1 do
		if sounds[i].text == s.text then return sounds[i], i end
	end
end

-- {startSeconds, endSeconds} of every paragraph inside the sound, by number of characters.
local function buildWindows(s, length)
	local weights, total = {}, 0
	for i, text in ipairs(s.texts) do
		local w = (text:byte() == 60) and 0 or text:len()   -- "<" starts an emote: not spoken
		weights[i] = w
		total = total + w
	end
	if total <= 0 then return nil end
	local windows, t = {}, 0
	for i, w in ipairs(weights) do
		local duration = length * w / total
		windows[i] = { t, t + duration }
		t = t + duration
	end
	return windows
end

-- Connects the dialog to its voice. Returns true when there is one to follow.
function V.Attach(s)
	if not s then return false end
	if current and current.session == s then return true end
	if not (S.db.voiceSyncText or S.db.voiceWait or S.db.voiceAuto) then return false end
	if s.kind ~= "detail" and s.kind ~= "complete" and s.kind ~= "gossip" and s.kind ~= "greeting" then return false end
	local ns = voiceOver()
	if not ns or queuePaused(ns) then return false end
	V.Init()

	local sound, index = findSound(s)
	if not sound or type(sound.length) ~= "number" or sound.length <= 0 then return false end
	local windows = buildWindows(s, sound.length)
	if not windows then return false end

	-- An older voice is still speaking (the previous dialog): cut it, this dialog is the one on screen.
	if index > 1 then
		local queue = ns.SoundQueue
		for i = index - 1, 1, -1 do
			local older = queue.sounds[i]
			if older then pcall(queue.RemoveSoundFromQueue, queue, older) end
		end
	end
	-- Already playing, but the start was not seen (first dialog right after login).
	if not started[sound] and sound.nextSoundTimer then started[sound] = GetTime() end

	current = { session = s, sound = sound, windows = windows, length = sound.length, attached = GetTime() }
	V.driver:Show()
	return true
end

function V.Reset()
	current = nil
	if UI.chat then UI.chat.sync = nil end
	V.lockShown = false
end

-- The player went ahead of the voice (rewind, skipping): no more following or waiting for this dialog.
function V.Desync()
	if current then current.desync = true end
	if UI.chat then UI.chat.sync = nil end
end

------------------------------------------------------------------------
-- The audio clock
------------------------------------------------------------------------
-- Seconds since the audio started (negative while it has not started yet), or nil when there is nothing to
-- follow (no voice, stopped, cut off, resumed, player ahead of the voice).
local function elapsed()
	local c = current
	if not c or c.session ~= S.session then return nil end
	if c.stopped or c.desync or c.skipped or c.restarted then return nil end
	local sound = c.sound
	local done = finished[sound]
	if done == true then return c.length + 10 end      -- played to the end: everything is unlocked
	if done == false then return nil end               -- cut off (another dialog, pause, abandoned quest)
	local ns = voiceOver()
	if ns and queuePaused(ns) then return nil end
	local t0 = started[sound]
	if not t0 then
		if GetTime() - c.attached > WAIT_FOR_START then c.desync = true return nil end
		return -1                                      -- still queued / music fading out
	end
	return GetTime() - t0
end

-- 0..1: how much of paragraph i the voice has spoken, or nil (nothing to follow).
function V.Progress(i)
	local e = elapsed()
	if e == nil then return nil end
	local w = current.windows[i]
	if not w then return nil end
	-- the player is ahead of the voice (went on before it got there): stop following it
	if i > 1 and e < w[1] - 0.5 then current.desync = true return nil end
	local duration = w[2] - w[1]
	if duration <= 0 then return 1 end
	return max(0, min(1, (e - w[1]) / duration))
end

-- True while the voice is still speaking the current paragraph and waiting is switched on.
function V.Locked()
	if not S.db.voiceWait then return false end
	local s = S.session
	if not s or not current or current.session ~= s then return false end
	local e = elapsed()
	if e == nil then return false end
	local w = current.windows[min(max(s.index or 1, 1), #current.windows)]
	if not w then return false end
	return e < w[2] - UNLOCK_EARLY
end

-- SHIFT + click: stop the voice and go on.
function V.Skip()
	local c = current
	if not c then return end
	c.skipped = true
	if UI.chat then UI.chat.sync = nil end
	local ns = voiceOver()
	if ns then pcall(ns.SoundQueue.RemoveSoundFromQueue, ns.SoundQueue, c.sound) end
end

-- Called when a paragraph starts being typed (logic.lua, S.PlayText).
function V.OnText(i, late)
	local s = S.session
	if not late then V.lockShown = false end
	if UI.chat then UI.chat.sync = nil end
	if not s or not V.Attach(s) then return end
	if not late and current and current.session == s then current.paragraphAt = GetTime() end
	if elapsed() == nil then return end   -- stopped, skipped, rewound...: nothing to follow
	if S.db.voiceSyncText and UI.IsTyping() then
		UI.chat.sync = function() return V.Progress(i) end
	end
end

-- Typing position (in characters) for a progress value; used by the chat OnUpdate (layout.lua).
function V.TypingPosition(progress, length)
	return progress * (length + TYPING_LEAD)
end

------------------------------------------------------------------------
-- "Voice is speaking" label on the next line while the next paragraph is locked
------------------------------------------------------------------------
-- The voice has finished the current paragraph: go on by itself.
local function autoAdvance()
	if not S.db.voiceAuto then return end
	local s, c = S.session, current
	if not s or not c or c.session ~= s then return end
	local i = s.index
	local count = #s.texts
	if not i or i < 1 or i > count then return end
	-- the action after the last paragraph is only done for quests that are offered and for gossip
	if i == count and s.kind ~= "detail" and s.kind ~= "gossip" and s.kind ~= "greeting" then return end
	if c.autoIndex == i then return end
	if UI.IsTyping() then return end
	local e = elapsed()
	if e == nil then return end
	local w = c.windows[i]
	if not w or e < w[2] + AUTO_PAUSE then return end
	if GetTime() - (c.paragraphAt or 0) < AUTO_MIN_READ + 0.02 * #s.texts[i] then return end
	c.autoIndex = i
	S.PlayNext()
end

V.driver = CreateFrame("Frame")
V.driver:Hide()
local sinceCheck = 0
V.driver:SetScript("OnUpdate", function(self, elapsedTime)
	sinceCheck = sinceCheck + elapsedTime
	if sinceCheck < 0.1 then return end
	sinceCheck = 0
	if not S.session or not current or current.session ~= S.session then
		if V.lockShown and UI.nextText and V.savedNext then UI.nextText:SetText(V.savedNext) end
		V.lockShown = false
		self:Hide()
		return
	end
	autoAdvance()
	if S.session ~= current.session then return end   -- the dialog changed (or ended) by itself
	local locked = V.Locked()
	if locked and not V.lockShown then
		V.savedNext = UI.nextText:GetText()
		UI.nextText:SetText(L.SL_VOICE_WAIT)
		UI.nextText:SetAlpha(0.6)
		V.lockShown = true
	elseif not locked and V.lockShown then
		UI.nextText:SetText(V.savedNext or "")
		UI.nextText:SetAlpha(1)
		V.lockShown = false
	end
end)

------------------------------------------------------------------------
-- Status (/storyline voice)
------------------------------------------------------------------------
function V.Status()
	local ns = voiceOver()
	if not ns then return "VoiceOver was not found (addon folder AI_VoiceOver)." end
	local text = "VoiceOver found | text follows the voice: " .. tostring(S.db.voiceSyncText and true or false)
		.. " | wait for the voice: " .. tostring(S.db.voiceWait and true or false)
		.. " | continue automatically: " .. tostring(S.db.voiceAuto and true or false)
	local sounds = ns.SoundQueue.sounds
	text = text .. " | sounds in the queue: " .. #sounds
	if current and current.session == S.session then
		local e = elapsed()
		text = text .. " | this dialog has a voice (" .. string.format("%.1f", current.length) .. " s), "
			.. (e == nil and "no longer followed" or string.format("%.1f s played", max(e, 0)))
	else
		text = text .. " | this dialog has no voice that can be followed"
	end
	return text
end
