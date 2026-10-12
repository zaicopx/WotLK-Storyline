-- core.lua
-- Namespace, saved variables, timers and fade helpers.
-- (WotLK 3.3.5a has no C_Timer, so everything here is built on OnUpdate.)

local S = _G.Storyline or {}
_G.Storyline = S

S.VERSION = "3.3.1"

local tinsert, tremove = table.insert, table.remove
local GetTime = GetTime

------------------------------------------------------------------------
-- Saved variables
-- Same saved variable and layout as the original addon (Storyline_Data.config /
-- Storyline_Data.debug.scaling), so existing settings and per-model scales carry over.
------------------------------------------------------------------------
local DEFAULTS = {
	textSpeedFactor = 0.5,     -- 0 = instant, 1.5 = fast (same scale as the original addon)
	autoEquip = false,
	forceGossip = false,       -- also take over vendors / flight masters / ...
	hideOriginalFrames = true,
	lockFrame = false,
	disableInInstances = false,
	showModels = true,
	cameraMode = "free",       -- "free": characters use the free camera (they can turn), creatures camera 0;
	                           -- "auto": character models camera 1 (no turning); or a fixed camera 0 / 1 / 2
	facingAngle = 0.75,        -- how far the models turn towards each other (radians)
	textSize = 16,
	dimWorld = false,
	dimAmount = 0.5,           -- how dark the world gets behind the window (0 = not at all, 1 = black)
	scrollScale = false,       -- mouse wheel over the models resizes the NPC (off: it was easy to trigger by accident)
	modelAnimations = true,
	keyShortcuts = true,
	flipFacing = false,
	tintBackground = true,
	width = 700,
	height = 450,
}

local function mergeDefaults(dst, src)
	for k, v in pairs(src) do
		if dst[k] == nil then dst[k] = v end
	end
end

function S.InitDB()
	if type(Storyline_Data) ~= "table" then Storyline_Data = {} end
	local d = Storyline_Data
	d.config = type(d.config) == "table" and d.config or {}
	d.debug = type(d.debug) == "table" and d.debug or {}
	d.debug.scaling = type(d.debug.scaling) == "table" and d.debug.scaling or {}
	d.debug.timing = type(d.debug.timing) == "table" and d.debug.timing or {}
	d.debug.cameras = type(d.debug.cameras) == "table" and d.debug.cameras or {}
	-- 3.2: characters now use the free camera so that they can turn towards each other
	if (d.config.layoutVersion or 0) < 2 then
		d.config.cameraMode = nil
		d.config.layoutVersion = 2
	end
	-- 3.3: the mouse wheel no longer resizes the models unless the player turns it on
	if (d.config.layoutVersion or 0) < 3 then
		d.config.scrollScale = false
		d.config.layoutVersion = 3
	end
	mergeDefaults(d.config, DEFAULTS)
	local dim = tonumber(d.config.dimAmount) or DEFAULTS.dimAmount
	d.config.dimAmount = math.max(0, math.min(1, dim))
	S.data = d
	S.db = d.config
	S.scaling = d.debug.scaling
	S.cameras = d.debug.cameras
end

function S.ResetFrameDB()
	local c = S.db
	c.width, c.height = DEFAULTS.width, DEFAULTS.height
	c.point, c.x, c.y = nil, nil, nil
end

function S.Print(msg)
	DEFAULT_CHAT_FRAME:AddMessage("|cffffd200Storyline:|r " .. tostring(msg))
end

------------------------------------------------------------------------
-- Timers
------------------------------------------------------------------------
local timers = {}
local timerFrame = CreateFrame("Frame")
timerFrame:Hide()
timerFrame:SetScript("OnUpdate", function(self)
	local now = GetTime()
	for i = #timers, 1, -1 do
		local t = timers[i]
		if t then
			if t.cancelled then
				tremove(timers, i)
			elseif now >= t.at then
				tremove(timers, i)
				local ok, err = pcall(t.func)
				if not ok then geterrorhandler()(err) end
			end
		end
	end
	if #timers == 0 then self:Hide() end
end)

function S.After(delay, func)
	local t = { at = GetTime() + delay, func = func }
	tinsert(timers, t)
	timerFrame:Show()
	return t
end

function S.Cancel(handle)
	if handle then handle.cancelled = true end
end

------------------------------------------------------------------------
-- Fades
------------------------------------------------------------------------
local fades = {}
local fadeFrame = CreateFrame("Frame")
fadeFrame:Hide()
fadeFrame:SetScript("OnUpdate", function(self, elapsed)
	for i = #fades, 1, -1 do
		local f = fades[i]
		if f then
			f.t = f.t + elapsed
			if f.t >= f.d then
				tremove(fades, i)
				f.frame:SetAlpha(f.to)
				if f.hideAtEnd and f.to <= 0 then f.frame:Hide() end
				if f.done then f.done(f.frame) end
			else
				f.frame:SetAlpha(f.from + (f.to - f.from) * (f.t / f.d))
			end
		end
	end
	if #fades == 0 then self:Hide() end
end)

function S.CancelFade(frame)
	for i = #fades, 1, -1 do
		if fades[i].frame == frame then tremove(fades, i) end
	end
end

function S.Fade(frame, to, duration, hideAtEnd, done)
	S.CancelFade(frame)
	if not duration or duration <= 0 then
		frame:SetAlpha(to)
		if hideAtEnd and to <= 0 then frame:Hide() end
		if done then done(frame) end
		return
	end
	if to > 0 and not frame:IsShown() then
		frame:SetAlpha(0)
		frame:Show()
	end
	tinsert(fades, {
		frame = frame, from = frame:GetAlpha(), to = to,
		d = duration, t = 0, hideAtEnd = hideAtEnd, done = done,
	})
	fadeFrame:Show()
end
