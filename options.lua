-- options.lua
-- Interface Options panel (Esc > Interface > AddOns > Storyline) and slash commands.

local S = _G.Storyline
local L = S.L

local O = {}
S.Options = O

local floor = math.floor

local checks, sliders = {}, {}

local CHECKS = {
	{ key = "hideOriginalFrames", label = "SL_CONFIG_HIDEORIGINALFRAMES", tip = "SL_CONFIG_HIDEORIGINALFRAMES_TT",
	  onChange = function()
		S.Compat.Suppress(false)
		if S.session then S.Compat.Suppress(true) end
	  end },
	{ key = "forceGossip", label = "SL_CONFIG_FORCEGOSSIP", tip = "SL_CONFIG_FORCEGOSSIP_TT" },
	{ key = "autoEquip", label = "SL_CONFIG_AUTOEQUIP", tip = "SL_CONFIG_AUTOEQUIP_TT" },
	{ key = "keyShortcuts", label = "SL_CONFIG_KEYS", tip = "SL_CONFIG_KEYS_TT",
	  onChange = function() S.UI.RefreshBindings() end },
	{ key = "disableInInstances", label = "SL_CONFIG_DISABLEINSTANCES", tip = "SL_CONFIG_DISABLEINSTANCES_TT" },
	{ key = "lockFrame", label = "SL_CONFIG_LOCKFRAME", tip = "SL_CONFIG_LOCKFRAME_TT",
	  onChange = function() S.UI.UpdateLock() end },
	{ key = "showModels", label = "SL_CONFIG_MODELS", tip = "SL_CONFIG_MODELS_TT" },
	{ key = "modelAnimations", label = "SL_CONFIG_ANIM", tip = "SL_CONFIG_ANIM_TT" },
	{ key = "flipFacing", label = "SL_CONFIG_FLIP", tip = "SL_CONFIG_FLIP_TT",
	  onChange = function() S.UI.RefreshModelTransforms() end },
	{ key = "tintBackground", label = "SL_CONFIG_TINT", tip = "SL_CONFIG_TINT_TT",
	  onChange = function() S.UI.RefreshBackground() end },
	{ key = "locationBackground", label = "SL_CONFIG_LOCATION", tip = "SL_CONFIG_LOCATION_TT",
	  onChange = function() S.UI.UpdateLocationBackground() end },
	{ key = "timeTint", label = "SL_CONFIG_TIMETINT", tip = "SL_CONFIG_TIMETINT_TT",
	  onChange = function() S.UI.UpdateLocationTint() end },
	{ key = "cinematicMode", label = "SL_CONFIG_CINE", tip = "SL_CONFIG_CINE_TT",
	  onChange = function() S.ApplyCinematic() end },
	{ key = "emoteAnimations", label = "SL_CONFIG_EMOTE", tip = "SL_CONFIG_EMOTE_TT" },
	{ key = "voiceSyncText", label = "SL_CONFIG_VOICESYNC", tip = "SL_CONFIG_VOICESYNC_TT" },
	{ key = "voiceWait", label = "SL_CONFIG_VOICEWAIT", tip = "SL_CONFIG_VOICEWAIT_TT" },
	{ key = "voiceAuto", label = "SL_CONFIG_VOICEAUTO", tip = "SL_CONFIG_VOICEAUTO_TT" },
	{ key = "dimWorld", label = "SL_CONFIG_DIM", tip = "SL_CONFIG_DIM_TT",
	  onChange = function()
		if S.db.dimWorld and (S.db.dimAmount or 0) <= 0 then S.db.dimAmount = 0.5; O.Refresh() end
		S.UI.UpdateDim()
		if S.db.dimWorld and not S.UI.frame:IsShown() then S.UI.PreviewDim() end
	  end },
	{ key = "scrollScale", label = "SL_CONFIG_WHEEL", tip = "SL_CONFIG_WHEEL_TT",
	  onChange = function() S.UI.ApplyWheelMode() end },
}

local SLIDERS = {
	{ key = "textSpeedFactor", min = 0, max = 1.5, step = 0.1, low = "SL_CONFIG_TEXTSPEED_INSTANT", high = "SL_CONFIG_TEXTSPEED_HIGH",
	  text = function(v) return v <= 0 and L.SL_CONFIG_TEXTSPEED_INSTANT or string.format(L.SL_CONFIG_TEXTSPEED, v) end },
	{ key = "textSize", min = 11, max = 24, step = 1, low = "11", high = "24",
	  text = function(v) return string.format(L.SL_CONFIG_TEXTSIZE, floor(v + 0.5)) end,
	  onChange = function() S.UI.ApplyTextSize() end },
	{ key = "facingAngle", min = 0, max = 1.3, step = 0.05, low = "0", high = "75°",
	  text = function(v) return string.format(L.SL_CONFIG_ANGLE, floor(v / 1.3 * 75 + 0.5)) end,
	  onChange = function() S.UI.RefreshModelTransforms() end },
	{ key = "dimAmount", min = 0, max = 1, step = 0.05, low = "0%", high = "100%",
	  text = function(v) return string.format(L.SL_CONFIG_DIMAMOUNT, floor(v * 100 + 0.5)) end,
	  onChange = function()
		-- moving the slider means "I want the world dimmed": switch the option on
		if not S.db.dimWorld and (S.db.dimAmount or 0) > 0 then
			S.db.dimWorld = true
			O.Refresh()
		end
		S.UI.UpdateDim()
		if not S.UI.frame:IsShown() then S.UI.PreviewDim() end
	  end },
	{ key = "cinematicStrength", min = 0, max = 1, step = 0.05, low = "0%", high = "100%",
	  text = function(v) return string.format(L.SL_CONFIG_CINEZOOM, floor(v * 100 + 0.5)) end,
	  onChange = function()
		-- moving the slider means "I want the cinematic zoom": switch the mode on
		if not S.db.cinematicMode and (S.db.cinematicStrength or 0) > 0 then
			S.db.cinematicMode = true
			O.Refresh()
		end
		S.ApplyCinematic()
	  end },
}

local function Tooltip(frame, text)
	frame:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:SetText(text, 1, 1, 1, 1, 1)
		GameTooltip:Show()
	end)
	frame:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

function O.Refresh()
	for _, cb in ipairs(checks) do cb:SetChecked(S.db[cb.key]) end
	for _, slider in ipairs(sliders) do
		slider.refreshing = true
		slider:SetValue(S.db[slider.def.key])
		slider.refreshing = false
		_G[slider:GetName() .. "Text"]:SetText(slider.def.text(S.db[slider.def.key]))
	end
end

function O.Create()
	local panel = CreateFrame("Frame", "StorylineOptionsPanel", UIParent)
	panel.name = "Storyline"
	O.panel = panel

	local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
	title:SetPoint("TOPLEFT", panel, "TOPLEFT", 16, -16)
	title:SetText("Storyline  |cff888888v" .. S.VERSION .. "|r")

	local about = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	about:SetPoint("TOPLEFT", panel, "TOPLEFT", 16, -42)
	about:SetWidth(560)
	about:SetJustifyH("LEFT")
	about:SetText(L.SL_CONFIG_ABOUT)

	-- Sliders: two in the left column, one in the right column
	local slots = { { 28, -100 }, { 28, -160 }, { 318, -100 }, { 318, -160 }, { 28, -220 } }
	for i, def in ipairs(SLIDERS) do
		local name = "StorylineOptionSlider_" .. def.key
		local slider = CreateFrame("Slider", name, panel, "OptionsSliderTemplate")
		slider.def = def
		slider:SetPoint("TOPLEFT", panel, "TOPLEFT", slots[i][1], slots[i][2])
		slider:SetWidth(240)
		slider:SetMinMaxValues(def.min, def.max)
		slider:SetValueStep(def.step)
		_G[name .. "Low"]:SetText(L[def.low] ~= def.low and L[def.low] or def.low)
		_G[name .. "High"]:SetText(L[def.high] ~= def.high and L[def.high] or def.high)
		slider:SetScript("OnValueChanged", function(self, value)
			if self.refreshing then return end
			value = floor(value / def.step + 0.5) * def.step
			S.db[def.key] = value
			_G[name .. "Text"]:SetText(def.text(value))
			if def.onChange then def.onChange() end
		end)
		sliders[#sliders + 1] = slider
	end

	-- Check boxes in two columns
	local perColumn = math.ceil(#CHECKS / 2)
	for i, def in ipairs(CHECKS) do
		local name = "StorylineOption_" .. def.key
		local cb = CreateFrame("CheckButton", name, panel, "InterfaceOptionsCheckButtonTemplate")
		local column = i <= perColumn and 0 or 1
		local row = (i - 1) % perColumn
		cb:SetPoint("TOPLEFT", panel, "TOPLEFT", 16 + column * 290, -276 - row * 24)
		_G[name .. "Text"]:SetText(L[def.label])
		_G[name .. "Text"]:SetWidth(240)
		_G[name .. "Text"]:SetJustifyH("LEFT")
		cb.key = def.key
		cb:SetScript("OnClick", function(self)
			S.db[def.key] = self:GetChecked() and true or false
			if def.onChange then def.onChange() end
		end)
		Tooltip(cb, L[def.tip])
		checks[#checks + 1] = cb
	end

	-- Buttons
	local y = -276 - perColumn * 24 - 14
	local preview = CreateFrame("Button", "StorylineOptionPreview", panel, "UIPanelButtonTemplate")
	preview:SetWidth(140)
	preview:SetHeight(24)
	preview:SetPoint("TOPLEFT", panel, "TOPLEFT", 20, y)
	preview:SetText(L.SL_CONFIG_PREVIEW)
	preview:SetScript("OnClick", function() S.Demo() end)

	local reset = CreateFrame("Button", "StorylineOptionReset", panel, "UIPanelButtonTemplate")
	reset:SetWidth(260)
	reset:SetHeight(24)
	reset:SetPoint("LEFT", preview, "RIGHT", 10, 0)
	reset:SetText(L.SL_CONFIG_RESETFRAME)
	reset:SetScript("OnClick", function()
		S.ResetFrameDB()
		S.UI.ApplyFrameDB()
	end)

	panel.refresh = O.Refresh
	panel:SetScript("OnShow", O.Refresh)
	InterfaceOptions_AddCategory(panel)
end

function O.Open()
	if not O.panel then return end
	-- Called twice on purpose: the first call of InterfaceOptionsFrame_OpenToCategory
	-- only opens the window in 3.3.5a.
	InterfaceOptionsFrame_OpenToCategory(O.panel)
	InterfaceOptionsFrame_OpenToCategory(O.panel)
end

------------------------------------------------------------------------
-- Slash commands
------------------------------------------------------------------------
local function currentModel()
	return S.UI.you and S.UI.you.model
end

SLASH_STORYLINE1 = "/storyline"
SLASH_STORYLINE2 = "/stl"
SlashCmdList["STORYLINE"] = function(msg)
	msg = strlower(strtrim(msg or ""))
	if msg == "test" or msg == "preview" then
		S.Demo()
	elseif msg == "info" then
		local you, me = S.UI.you, S.UI.me
		S.Print("NPC model: " .. tostring(you.model) .. " | creature type: " .. tostring(you.unit and UnitCreatureType(you.unit)))
		S.Print("your model: " .. tostring(me.model))
		S.Print("camera: " .. tostring(you.cameraUsed) .. " (mode " .. tostring(S.db.cameraMode) .. ") | scale: "
			.. tostring(S.UI.scale) .. (S.UI.scaleSaved and " (saved)" or " (guessed)") .. " | angle: " .. tostring(S.db.facingAngle))
	elseif msg:find("^camera") then
		-- /storyline camera free|0|1|2|auto   -> for the NPC model you are talking to
		-- /storyline camera all free|auto|0|1|2 -> for every NPC
		-- ("free" = characters can turn, "auto" = old behaviour: character models use camera 1)
		local arg, value = msg:match("^camera%s+(%S+)%s*(%S*)")
		local path = currentModel()
		if arg == "all" then
			value = (value == "" and "free") or value
			S.db.cameraMode = tonumber(value) or value
			S.UI.RefreshModelTransforms()
			S.Print("camera mode for all NPCs: " .. tostring(S.db.cameraMode))
		elseif path and (arg == "free" or arg == "auto" or tonumber(arg)) then
			if arg == "auto" then S.cameras[path] = nil else S.cameras[path] = tonumber(arg) or false end
			S.UI.RefreshModelTransforms()
			S.Print("camera for this model: " .. tostring(arg))
		else
			S.Print("usage: /storyline camera free|0|1|2|auto (this NPC model)  |  /storyline camera all free|auto|0|1|2")
		end
	elseif msg:find("^angle") then
		local value = tonumber(msg:match("angle%s+(%S+)"))
		if value then
			S.db.facingAngle = math.max(0, math.min(1.3, value))
			S.UI.RefreshModelTransforms()
		end
		S.Print("angle = " .. tostring(S.db.facingAngle) .. " (0..1.3, /storyline flip swaps the direction)")
	elseif msg:find("^scale") then
		local arg = msg:match("scale%s+(%S+)")
		if arg == "reset" then
			S.UI.ResetScale()
			S.Print("model scale reset for this pair")
		elseif tonumber(arg) then
			local key = S.UI.currentScaleKeys and S.UI.currentScaleKeys()
			if key then S.scaling[key] = tonumber(arg); S.UI.ApplyScale() end
		else
			S.Print("usage: /storyline scale <-190..190> | reset   (positive = smaller NPC, negative = smaller you)")
		end
	elseif msg == "models" then
		S.db.showModels = not S.db.showModels
		S.Print(L.SL_CONFIG_MODELS .. ": " .. tostring(S.db.showModels))
	elseif msg == "flip" then
		S.db.flipFacing = not S.db.flipFacing
		S.UI.RefreshModelTransforms()
		S.Print("flipFacing = " .. tostring(S.db.flipFacing))
	elseif msg:find("^cine") then
		-- /storyline cine            on / off
		-- /storyline cine <0-100>    how far the camera moves (0 = off)
		-- /storyline cine flip       reverse the zoom direction (if it moves the wrong way)
		local arg = msg:match("^cine%s+(%S+)")
		if arg == "flip" then
			S.db.cinematicSign = (S.db.cinematicSign == -1) and 1 or -1
			S.db.cinematicMode = true
		elseif tonumber(arg) then
			S.db.cinematicStrength = math.max(0, math.min(1, tonumber(arg) / 100))
			S.db.cinematicMode = S.db.cinematicStrength > 0
		else
			S.db.cinematicMode = not S.db.cinematicMode
		end
		S.ApplyCinematic()
		if O.Refresh then O.Refresh() end
		S.Print("cinematic mode: " .. (S.db.cinematicMode and "on" or "off") .. " | strength "
			.. floor((S.db.cinematicStrength or 0) * 100 + 0.5) .. "% | direction "
			.. (S.db.cinematicSign == -1 and "reversed" or "normal") .. "  (usage: /storyline cine, cine 0-100, cine flip)")
	elseif msg:find("^voice") then
		-- /storyline voice          shows the VoiceOver status
		-- /storyline voice text     text follows the voice on / off
		-- /storyline voice wait     wait for the voice on / off
		-- /storyline voice auto     continue automatically on / off
		local arg = msg:match("^voice%s+(%S+)")
		if arg == "text" then
			S.db.voiceSyncText = not S.db.voiceSyncText
		elseif arg == "wait" then
			S.db.voiceWait = not S.db.voiceWait
		elseif arg == "auto" then
			S.db.voiceAuto = not S.db.voiceAuto
		end
		if O.Refresh then O.Refresh() end
		S.Print(S.Voice.Status())
	elseif msg == "emote" then
		S.db.emoteAnimations = not S.db.emoteAnimations
		if O.Refresh then O.Refresh() end
		S.Print("NPC emote animations: " .. (S.db.emoteAnimations and "on" or "off"))
	elseif msg == "tint" then
		S.db.timeTint = not S.db.timeTint
		S.UI.UpdateLocationTint()
		if O.Refresh then O.Refresh() end
		S.Print("background tint by game time: " .. (S.db.timeTint and "on" or "off"))
	elseif msg == "bg" then
		-- /storyline bg : location background on / off
		S.db.locationBackground = not S.db.locationBackground
		S.UI.UpdateLocationBackground()
		if O.Refresh then O.Refresh() end
		S.Print("location background: " .. (S.db.locationBackground and "on" or "off")
			.. (S.LocationArtInstalled and "" or "  (pictures are not installed)"))
	elseif msg == "zone" then
		-- what the location background sees
		local zone = (GetRealZoneText and GetRealZoneText()) or ""
		S.Print("zone: '" .. tostring(zone) .. "' | sub zone: '" .. tostring(GetSubZoneText and GetSubZoneText() or "")
			.. "' | picture: " .. tostring(S.GetLocationArt and S.GetLocationArt() or "none")
			.. " | pictures installed: " .. tostring(S.LocationArtInstalled and true or false))
	elseif msg == "close" then
		-- emergency exit: closes the window and the original dialog no matter what state they are in
		S.ForceClose()
		S.Print("closed")
	elseif msg:find("^dim") then
		-- /storyline dim <0-100>  (0 = off)
		local value = tonumber(msg:match("dim%s+(%S+)"))
		if value then
			S.db.dimAmount = math.max(0, math.min(1, value / 100))
			S.db.dimWorld = S.db.dimAmount > 0
			S.UI.UpdateDim()
			if not S.UI.frame:IsShown() then S.UI.PreviewDim() end
			if O.Refresh then O.Refresh() end
		end
		S.Print("dim = " .. floor((S.db.dimWorld and S.db.dimAmount or 0) * 100 + 0.5) .. "%  (usage: /storyline dim 0-100)")
	elseif msg == "wheel" then
		S.db.scrollScale = not S.db.scrollScale
		S.UI.ApplyWheelMode()
		if O.Refresh then O.Refresh() end
		S.Print(L.SL_CONFIG_WHEEL .. ": " .. tostring(S.db.scrollScale))
	elseif msg == "debug" then
		local s = S.session
		S.Print("session: " .. (s and tostring(s.kind) or "none")
			.. " | Storyline window shown: " .. tostring(S.UI.frame:IsShown()) .. " (alpha " .. string.format("%.2f", S.UI.frame:GetAlpha()) .. ")"
			.. " | QuestFrame shown: " .. tostring(QuestFrame and QuestFrame:IsShown() or false)
			.. " | GossipFrame shown: " .. tostring(GossipFrame and GossipFrame:IsShown() or false))
		local ab = _G.QuestFrameAcceptButton
		S.Print("Accept button: " .. (ab and ("visible=" .. tostring(ab:IsVisible() and true or false) .. " IsEnabled()=" .. tostring(ab:IsEnabled())) or "missing")
			.. " (1 = enabled, 0 = disabled)")
	elseif msg == "focus" then
		-- /storyline focus, then hold the mouse over the button that does not react: after 4 seconds
		-- the name of the frame under the mouse is printed (tells which frame is in the way).
		S.Print("hold the mouse over the button that does not react... (4 seconds)")
		S.After(4, function()
			local f = GetMouseFocus and GetMouseFocus()
			local names = {}
			while f and #names < 6 do
				names[#names + 1] = f:GetName() or ("<" .. tostring(f:GetObjectType()) .. ">")
				f = f:GetParent()
			end
			S.Print("under the mouse: " .. (#names > 0 and table.concat(names, "  <  ") or "nothing"))
		end)
	elseif msg == "reset" then
		S.ResetFrameDB()
		S.UI.ApplyFrameDB()
		S.Print(L.SL_CONFIG_RESETFRAME)
	elseif msg == "lock" or msg == "unlock" then
		S.db.lockFrame = (msg == "lock")
		S.UI.UpdateLock()
		S.Print(L.SL_CONFIG_LOCKFRAME .. ": " .. tostring(S.db.lockFrame))
	else
		O.Open()
	end
end
