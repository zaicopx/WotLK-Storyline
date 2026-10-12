-- rewards.lua
-- Quest rewards / required items: data gathering, the icon grid shown inside the
-- hover panels, reward tooltips, and the (experimental) auto-equip feature.
--
-- Fixes issue #4 (lua error on class quests that teach a spell): every reward button
-- is created here, in code, with its own .Icon texture - there is no template field
-- that can be missing - and GetRewardSpell() is read defensively.

local S = _G.Storyline
local L = S.L
local UI = S.UI

local R = {}
S.Rewards = R

local floor, ceil, max = math.floor, math.ceil, math.max
local tinsert = table.insert

local ART = "Interface\\AddOns\\Storyline\\Artwork\\"
local WHITE = "Interface\\Buttons\\WHITE8X8"
local XP_ICON = ART .. "ICONS\\xp_icon"
local QUESTION = ART .. "ICONS\\INV_Misc_QuestionMark"
local COIN_ICON = "Interface\\Icons\\INV_Misc_Coin_01"

local BTN, GAP, PAD = 40, 8, 14

local buttonCount = 0
local pools = {}   -- per hover frame: { buttons = {}, texts = {} }

------------------------------------------------------------------------
-- Reward button
------------------------------------------------------------------------
local function onEnter(self)
	local e = self.entry
	if not e then return end
	GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
	if e.kind == "spell" then
		local ok = GameTooltip.SetQuestRewardSpell and pcall(GameTooltip.SetQuestRewardSpell, GameTooltip)
		if not ok then GameTooltip:SetText(e.name or L.SL_SPELL_LEARN, 1, 1, 1) end
	else
		GameTooltip:SetQuestItem(e.kind, e.index)
		if e.bestPrice then
			GameTooltip:AddLine(" ")
			GameTooltip:AddLine(L.SL_BEST_PRICE, 1, 0.82, 0)
		end
		if self.chooses and e.kind == "choice" then
			GameTooltip:AddLine(" ")
			GameTooltip:AddLine(L.SL_GET_REWARD, 0.2, 1, 0.2)
		end
		if GameTooltip_ShowCompareItem then pcall(GameTooltip_ShowCompareItem, GameTooltip) end
	end
	GameTooltip:Show()
end

local function onLeave()
	GameTooltip:Hide()
	if ShoppingTooltip1 then ShoppingTooltip1:Hide() end
	if ShoppingTooltip2 then ShoppingTooltip2:Hide() end
end

local function onClick(self)
	local e = self.entry
	if not e then return end
	if e.link then
		if IsModifiedClick("CHATLINK") and ChatEdit_InsertLink and ChatEdit_InsertLink(e.link) then return end
		if IsModifiedClick("DRESSUP") and DressUpItemLink then DressUpItemLink(e.link); return end
	end
	-- Like the original: clicking a reward you can choose hands the quest in with it.
	if self.chooses and e.kind == "choice" and S.session and S.session.kind == "complete" then
		S.TurnIn(e.index)
	end
end

local function createButton(parent)
	buttonCount = buttonCount + 1
	local b = CreateFrame("Button", "StorylineRewardButton" .. buttonCount, parent)
	b:SetWidth(BTN)
	b:SetHeight(BTN)
	b:RegisterForClicks("LeftButtonUp")

	b.Icon = b:CreateTexture(nil, "ARTWORK")
	b.Icon:SetPoint("TOPLEFT", b, "TOPLEFT", 2, -2)
	b.Icon:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -2, 2)
	b.Icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)

	b.hl = b:CreateTexture(nil, "HIGHLIGHT")
	b.hl:SetPoint("TOPLEFT", b, "TOPLEFT", 2, -2)
	b.hl:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -2, 2)
	b.hl:SetTexture(WHITE)
	b.hl:SetVertexColor(1, 1, 1, 0.22)

	b.Border = CreateFrame("Frame", nil, b)
	b.Border:SetAllPoints(b)
	b.Border:SetBackdrop({ edgeFile = WHITE, edgeSize = 1 })
	b.Border:SetBackdropBorderColor(0.45, 0.45, 0.45, 1)

	b.Count = b.Border:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
	b.Count:SetJustifyH("RIGHT")
	b.Count:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -3, 3)

	b.Coin = b.Border:CreateTexture(nil, "OVERLAY")
	b.Coin:SetWidth(14)
	b.Coin:SetHeight(14)
	b.Coin:SetPoint("TOPRIGHT", b, "TOPRIGHT", 3, 3)
	b.Coin:SetTexture(COIN_ICON)
	b.Coin:Hide()

	b:SetScript("OnEnter", onEnter)
	b:SetScript("OnLeave", onLeave)
	b:SetScript("OnClick", onClick)
	return b
end

local function decorate(b, e)
	b.entry = e
	b.Icon:SetTexture(e.icon or QUESTION)
	if (e.kind == "choice" or e.kind == "reward") and (e.usable == false or e.usable == 0) then
		b.Icon:SetVertexColor(0.9, 0.25, 0.25)
	else
		b.Icon:SetVertexColor(1, 1, 1)
	end
	if e.count and e.count > 1 then b.Count:SetText(tostring(e.count)) else b.Count:SetText("") end

	local r, g, bl = 0.45, 0.45, 0.45
	local c = e.quality and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[e.quality]
	if c then r, g, bl = c.r, c.g, c.b end
	if e.kind == "spell" then r, g, bl = 0.4, 0.7, 1 end
	b.Border:SetBackdropBorderColor(r, g, bl, 1)
	if e.bestPrice then b.Coin:Show() else b.Coin:Hide() end
end

------------------------------------------------------------------------
-- Data
------------------------------------------------------------------------
local function item(kind, i)
	local name, texture, count, quality, usable = GetQuestItemInfo(kind, i)
	return {
		kind = kind, index = i, name = name, icon = texture, count = count,
		quality = quality, usable = usable, link = S.API("GetQuestItemLink", kind, i),
	}
end

local function markBestPrice(choices)
	if #choices < 2 then return end
	local best, bestValue = nil, 0
	for _, c in ipairs(choices) do
		if c.link then
			local price = select(11, GetItemInfo(c.link))
			if price and price > 0 then
				local total = price * (c.count or 1)
				if total > bestValue then best, bestValue = c, total end
			end
		end
	end
	if best then best.bestPrice = true end
end

-- kind = "detail" | "complete" (rewards) or "progress" (required items)
function R.Gather(kind)
	local data = { choices = {}, items = {}, required = {}, xp = 0, money = 0, talents = 0, honor = 0, arena = 0 }

	if kind == "progress" then
		for i = 1, (GetNumQuestItems() or 0) do tinsert(data.required, item("required", i)) end
		data.requiredMoney = S.API("GetQuestMoneyToGet") or 0
		data.total = #data.required
		return data
	end

	for i = 1, (GetNumQuestChoices() or 0) do tinsert(data.choices, item("choice", i)) end
	for i = 1, (GetNumQuestRewards() or 0) do tinsert(data.items, item("reward", i)) end
	markBestPrice(data.choices)

	-- Spell reward (class quests that teach a spell...). Never assume anything exists.
	local texture, name, isTradeskill, isLearned = S.API("GetRewardSpell")
	if texture or name then
		data.spell = { kind = "spell", icon = texture, name = name, tradeskill = isTradeskill, learned = isLearned }
	end

	data.xp = S.API("GetRewardXP") or 0
	data.money = S.API("GetRewardMoney") or 0
	data.talents = S.API("GetRewardTalents") or 0
	data.title = S.API("GetRewardTitle")
	data.honor = S.API("GetRewardHonor") or 0
	data.arena = S.API("GetRewardArenaPoints") or 0

	data.total = #data.choices + #data.items + (data.spell and 1 or 0)
		+ (data.xp > 0 and 1 or 0) + (data.money > 0 and 1 or 0)
		+ (data.talents > 0 and 1 or 0) + (data.title and 1 or 0) + (data.honor > 0 and 1 or 0) + (data.arena > 0 and 1 or 0)
	return data
end

-- Icon shown in the middle of the rewards medallion: the most valuable choice, else the first item.
function R.BestIcon(data)
	for _, c in ipairs(data.choices) do
		if c.bestPrice and c.icon then return c.icon end
	end
	local first = data.choices[1] or data.items[1] or data.spell
	if first and first.icon then return first.icon end
	if data.xp and data.xp > 0 then return XP_ICON end
	if data.money and data.money > 0 then return COIN_ICON end
	return QUESTION
end

------------------------------------------------------------------------
-- Layout inside a hover frame
------------------------------------------------------------------------
-- Builds the rewards (or required items) of `data` inside `content`, starting at
-- vertical offset startY. `chooses` = clicking a choice item hands the quest in with it.
-- Returns the vertical offset below the last element.
function R.Layout(content, data, kind, startY, chooses)
	local pool = pools[content]
	if not pool then
		pool = { buttons = {}, texts = {} }
		pools[content] = pool
	end
	local width = content:GetWidth() - 2 * PAD
	local cols = max(1, floor((width + GAP) / (BTN + GAP)))
	local y = startY
	local usedButtons, usedTexts = 0, 0

	local function line(str, header)
		usedTexts = usedTexts + 1
		local fs = pool.texts[usedTexts]
		if not fs then
			fs = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
			fs:SetJustifyH("LEFT")
			fs:SetJustifyV("TOP")
			pool.texts[usedTexts] = fs
		end
		if header then
			fs:SetFontObject(GameFontNormal)
			fs:SetTextColor(1, 0.82, 0)
		else
			fs:SetFontObject(GameFontHighlight)
			fs:SetTextColor(0.95, 0.95, 0.95)
		end
		fs:SetWidth(width)
		fs:SetText(str)
		fs:ClearAllPoints()
		fs:SetPoint("TOPLEFT", content, "TOPLEFT", PAD, -y)
		fs:Show()
		y = y + max(14, fs:GetStringHeight()) + (header and 8 or 6)
	end

	local function grid(list, canChoose)
		local top = y
		for idx, entry in ipairs(list) do
			usedButtons = usedButtons + 1
			local b = pool.buttons[usedButtons]
			if not b then
				b = createButton(content)
				b:SetFrameLevel(content:GetFrameLevel() + 2)
				pool.buttons[usedButtons] = b
			end
			b.chooses = canChoose and entry.kind == "choice"
			local col = (idx - 1) % cols
			local row = floor((idx - 1) / cols)
			b:ClearAllPoints()
			b:SetPoint("TOPLEFT", content, "TOPLEFT", PAD + col * (BTN + GAP), -(top + row * (BTN + GAP)))
			decorate(b, entry)
			b:Show()
		end
		y = top + ceil(#list / cols) * (BTN + GAP) + 2
	end

	if kind == "progress" then
		if #data.required > 0 then
			line(L.SL_REQUIRED_ITEMS, true)
			grid(data.required, false)
		end
		local money = S.MoneyString(data.requiredMoney)
		if money then line(L.SL_REQUIRED_MONEY .. ":  " .. money) end
	else
		if #data.choices > 0 then
			line(L.SL_SELECT_REWARD, true)
			grid(data.choices, chooses)
		end
		local hasExtras = (#data.items > 0) or data.spell or data.xp > 0 or data.money > 0
			or data.talents > 0 or data.title or data.honor > 0 or data.arena > 0
		if hasExtras then line(#data.choices > 0 and L.SL_REWARD_MORE or L.SL_REWARDS, true) end
		if #data.items > 0 or data.spell then
			local list = {}
			for _, it in ipairs(data.items) do tinsert(list, it) end
			if data.spell then tinsert(list, data.spell) end
			grid(list, false)
		end
		if data.xp > 0 then
			line("|T" .. XP_ICON .. ":16:16:0:-2|t  |cffffffff" .. S.FormatNumber(data.xp) .. "|r  " .. L.SL_XP)
		end
		local money = S.MoneyString(data.money)
		if money then line(money) end
		if data.talents > 0 then line(L.SL_TALENTS .. ":  |cffffffff" .. data.talents .. "|r") end
		if data.title then line(L.SL_TITLE .. ":  |cffffffff" .. tostring(data.title) .. "|r") end
		if data.honor > 0 then line(L.SL_HONOR .. ":  |cffffffff" .. S.FormatNumber(data.honor) .. "|r") end
		if data.arena > 0 then line(L.SL_ARENA .. ":  |cffffffff" .. S.FormatNumber(data.arena) .. "|r") end
	end

	for i = usedButtons + 1, #pool.buttons do
		pool.buttons[i]:Hide()
		pool.buttons[i].entry = nil
	end
	for i = usedTexts + 1, #pool.texts do pool.texts[i]:Hide() end
	return y
end

function R.Clear(content)
	local pool = pools[content]
	if not pool then return end
	for _, b in ipairs(pool.buttons) do b:Hide(); b.entry = nil end
	for _, t in ipairs(pool.texts) do t:Hide() end
end

------------------------------------------------------------------------
-- Auto-equip (experimental)
------------------------------------------------------------------------
local EQUIP_SLOTS = {
	INVTYPE_HEAD = { 1 }, INVTYPE_NECK = { 2 }, INVTYPE_SHOULDER = { 3 },
	INVTYPE_CHEST = { 5 }, INVTYPE_ROBE = { 5 }, INVTYPE_WAIST = { 6 },
	INVTYPE_LEGS = { 7 }, INVTYPE_FEET = { 8 }, INVTYPE_WRIST = { 9 },
	INVTYPE_HAND = { 10 }, INVTYPE_FINGER = { 11, 12 }, INVTYPE_TRINKET = { 13, 14 },
	INVTYPE_CLOAK = { 15 },
}

local pendingEquip

function R.PrepareAutoEquip(choice)
	pendingEquip = nil
	if not S.db.autoEquip or not choice or choice < 1 then return end
	local link = S.API("GetQuestItemLink", "choice", choice)
	if not link then return end
	local _, _, _, ilvl, _, _, _, _, equipLoc = GetItemInfo(link)
	local slots = equipLoc and EQUIP_SLOTS[equipLoc]
	if not slots or not ilvl then return end
	local _, _, _, _, usable = GetQuestItemInfo("choice", choice)
	if usable == false or usable == 0 then return end

	local targetSlot, lowest
	for _, slot in ipairs(slots) do
		local current = GetInventoryItemLink("player", slot)
		local currentLevel = 0
		if current then currentLevel = select(4, GetItemInfo(current)) or 0 end
		if not lowest or currentLevel < lowest then lowest, targetSlot = currentLevel, slot end
	end
	if lowest and ilvl > lowest then
		pendingEquip = { itemID = tonumber(link:match("item:(%d+)")), slot = targetSlot, expires = GetTime() + 20 }
	end
end

function R.OnBagUpdate()
	if not pendingEquip then return end
	if GetTime() > pendingEquip.expires then pendingEquip = nil; return end
	if InCombatLockdown() or not pendingEquip.itemID then return end
	for bag = 0, 4 do
		for slot = 1, (GetContainerNumSlots(bag) or 0) do
			local link = GetContainerItemLink(bag, slot)
			if link and tonumber(link:match("item:(%d+)")) == pendingEquip.itemID then
				local target = pendingEquip.slot
				pendingEquip = nil
				EquipItemByName(link, target)
				return
			end
		end
	end
end
