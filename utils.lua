-- utils.lua
-- Text helpers (cleaning, paragraph splitting) and a few small formatting helpers.

local S = _G.Storyline

local floor, max = math.floor, math.max

------------------------------------------------------------------------
-- Text cleaning
------------------------------------------------------------------------
-- The 3.3.5a client normally expands $n / $b / <name> itself. A few servers
-- send them raw, so replace what is left over.
function S.CleanText(text)
	if not text then return "" end
	text = tostring(text)
	text = text:gsub("\r", "")
	if text:find("$", 1, true) then
		local name = UnitName("player") or ""
		local class = UnitClass("player") or ""
		local race = UnitRace("player") or ""
		local sex = UnitSex("player")
		text = text:gsub("%$[Bb]", "\n")
		text = text:gsub("%$[Nn]", function() return name end)
		text = text:gsub("%$[Rr]", function() return race end)
		text = text:gsub("%$[Cc]", function() return class end)
		text = text:gsub("%$[Gg]%s*([^:;]*):([^;]*);", function(male, female)
			if sex == 3 then return female end
			return male
		end)
	end
	return strtrim(text)
end

-- One entry per non-empty line (the client sends one paragraph per line).
function S.SplitParagraphs(text)
	text = S.CleanText(text)
	local texts = {}
	for line in (text .. "\n"):gmatch("([^\n]*)\n") do
		line = strtrim(line)
		if line ~= "" then texts[#texts + 1] = line end
	end
	return texts
end

------------------------------------------------------------------------
-- Misc helpers
------------------------------------------------------------------------
function S.Pack(...)
	return { n = select("#", ...), ... }
end

function S.FormatNumber(n)
	local s = tostring(floor((n or 0) + 0.5))
	local k
	repeat
		s, k = s:gsub("^(-?%d+)(%d%d%d)", "%1,%2")
	until k == 0
	return s
end

function S.MoneyString(copper)
	if not copper or copper <= 0 then return nil end
	if GetCoinTextureString then return GetCoinTextureString(copper, 14) end
	if GetCoinText then return GetCoinText(copper, " ") end
	return tostring(copper)
end

function S.LevelColorHex(level)
	local color
	if GetQuestDifficultyColor then
		color = GetQuestDifficultyColor(level)
	elseif GetDifficultyColor then
		color = GetDifficultyColor(level)
	end
	if type(color) == "table" then
		return string.format("%02x%02x%02x",
			floor((color.r or 1) * 255 + 0.5),
			floor((color.g or 1) * 255 + 0.5),
			floor((color.b or 1) * 255 + 0.5))
	end
	return "ffd200"
end

-- The unit token of whoever we are talking to.
function S.GetNPCUnit()
	if UnitExists("npc") then return "npc" end
	if UnitExists("target") and not UnitIsPlayer("target") then return "target" end
	return nil
end

function S.GetNPCName()
	local unit = S.GetNPCUnit()
	return unit and UnitName(unit) or nil
end

-- Calls a global API function by name, at call time. Looking the function up
-- late (instead of caching it in a local when the file loads) matters: other
-- addons such as Questie hook these globals with hooksecurefunc.
function S.API(name, ...)
	local fn = _G[name]
	if type(fn) == "function" then return fn(...) end
end

-- In 3.3.5a Button:IsEnabled() returns 1 or 0 (not true / false), and 0 is "true" in Lua, so
-- `if button:IsEnabled() then` is ALWAYS true. Use this instead.
function S.IsOn(button)
	if not button or not button.IsEnabled then return false end
	local enabled = button:IsEnabled()
	return (enabled and enabled ~= 0) and true or false
end
