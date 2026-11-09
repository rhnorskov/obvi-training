-- The plan window (/otr, or "Plans..." in the Train plan button's menu): the plan for your class, spell by spell,
-- in the order the trainer teaches them, with a box per rank (its level) coloured by what the plan does with it:
-- green trained, grey skipped, gold trained once you know the spell the rule waits for. Click a spell's rule to
-- change it; the plan's menu switches plans and makes new ones; Export and Import as text.
local _, ns = ...
---@cast ns ObviTrainingNS

local WIDTH, HEIGHT, ROW = 660, 520, 22
local CHIP = 24
local COLOURS = { train = { 0.2, 0.7, 0.25 }, skip = { 0.3, 0.3, 0.3 }, later = { 0.8, 0.65, 0.15 } }

local frame ---@type Frame?
local content ---@type Frame
local planButton ---@type Button
local summary ---@type FontString
local hint ---@type FontString
local resetButton ---@type Button
---@class ObviTrainingChip: Frame
---@field bg Texture
---@field text FontString
---@field title string
---@field lines string[]

---@class ObviTrainingRow: Frame
---@field icon Texture
---@field name FontString
---@field rule Button
---@field chips ObviTrainingChip[]
---@field note FontString

local rows = {} ---@type ObviTrainingRow[]

-- a question with a box to type in (StaticPopup); `accept` gets the text
local StaticPopupDialogs = _G["StaticPopupDialogs"] ---@type table
local StaticPopup_Show = _G["StaticPopup_Show"] ---@type fun(which: string, a?: string, b?: string, data?: any): Frame?
StaticPopupDialogs.OBVITRAINING_ASK = {
	text = "%s",
	button1 = "OK",
	button2 = "Cancel",
	hasEditBox = 1,
	OnShow = function(self, data)
		local box = self.editBox or self.EditBox
		if box then box:SetText(data.value or "") box:HighlightText() end
	end,
	OnAccept = function(self, data)
		local box = self.editBox or self.EditBox
		if box then data.accept(box:GetText()) end
	end,
	EditBoxOnEnterPressed = function(self)
		local popup = self:GetParent()
		local data = popup.data
		data.accept(self:GetText())
		popup:Hide()
	end,
	EditBoxOnEscapePressed = function(self) self:GetParent():Hide() end,
	hideOnEscape = 1,
	timeout = 0,
	whileDead = 1,
}
StaticPopupDialogs.OBVITRAINING_CONFIRM = {
	text = "%s",
	button1 = "Yes",
	button2 = "No",
	OnAccept = function(_, data) data.accept() end,
	hideOnEscape = 1,
	timeout = 0,
	whileDead = 1,
}
local function Ask(question, value, accept) StaticPopup_Show("OBVITRAINING_ASK", question, nil, { value = value, accept = accept }) end
local function Confirm(question, accept) StaticPopup_Show("OBVITRAINING_CONFIRM", question, nil, { accept = accept }) end

local function Print(fmt, ...) print("|cff33bbffObvi Training:|r " .. fmt:format(...)) end

---------------------------------------------------------------------------------------------------------------------
-- the text window: export (the text, selected to copy) and import (paste, then Import)

---@class ObviTrainingTextFrame: Frame
---@field title FontString

local textFrame ---@type ObviTrainingTextFrame?
local textBox ---@type EditBox
local textAction ---@type Button

local function TextWindow(title, text, action)
	if not textFrame then
		local f = CreateFrame("Frame", "ObviTrainingTextFrame", UIParent, "BasicFrameTemplateWithInset") --[[@as ObviTrainingTextFrame]]
		textFrame = f
		f:SetSize(460, 380)
		f:SetPoint("CENTER")
		f:SetFrameStrata("DIALOG")
		f:SetMovable(true)
		f:EnableMouse(true)
		f:RegisterForDrag("LeftButton")
		f:SetScript("OnDragStart", f.StartMoving)
		f:SetScript("OnDragStop", f.StopMovingOrSizing)
		f.title = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
		f.title:SetPoint("TOP", 0, -5)
		local scroll = CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate") --[[@as ScrollFrame]]
		scroll:SetPoint("TOPLEFT", 12, -32)
		scroll:SetPoint("BOTTOMRIGHT", -32, 42)
		textBox = CreateFrame("EditBox", nil, scroll) --[[@as EditBox]]
		textBox:SetMultiLine(true)
		textBox:SetFontObject("ChatFontNormal")
		textBox:SetWidth(410)
		textBox:SetAutoFocus(false)
		textBox:SetScript("OnEscapePressed", function() f:Hide() end)
		scroll:SetScrollChild(textBox)
		scroll:SetScript("OnMouseDown", function() textBox:SetFocus() end)
		textAction = CreateFrame("Button", nil, f, "UIPanelButtonTemplate") --[[@as Button]]
		textAction:SetSize(100, 22)
		textAction:SetPoint("BOTTOMRIGHT", -12, 12)
		tinsert(_G["UISpecialFrames"], "ObviTrainingTextFrame")
	end
	local f = textFrame
	f.title:SetText(title)
	textBox:SetText(text)
	textAction:SetText(action and "Import" or "Close")
	textAction:SetScript("OnClick", function()
		if action then action(textBox:GetText()) else f:Hide() end
	end)
	f:Show()
	textBox:SetFocus()
	if text ~= "" then textBox:HighlightText() end
end

---------------------------------------------------------------------------------------------------------------------
-- the plan window

--- The spells to show: what the trainer lists for your class (remembered), and any others the plan names; in the
--- order the trainer teaches them (first rank's level), then by name.
local function Spells(plan)
	local seen = ns.db.trainer and ns.db.trainer[ns.Class()] or {}
	local list = {}
	for name, spell in pairs(seen) do table.insert(list, { name = name, spell = spell }) end
	for name in pairs(plan and plan.spells or {}) do
		if not seen[name] then table.insert(list, { name = name }) end
	end
	local function first(e)
		local low = 999
		for _, r in pairs(e.spell and e.spell.ranks or {}) do low = math.min(low, r.level) end
		return low
	end
	for _, e in ipairs(list) do e.level = first(e) end
	table.sort(list, function(a, b)
		if a.level ~= b.level then return a.level < b.level end
		return a.name < b.name
	end)
	return list
end

--- A rule's menu for one spell: the choices, each changing your copy of the plan.
local function RuleMenu(owner, plan, name)
	local function set(rule)
		local mine = ns.Editable(plan)
		mine.spells[name] = rule
		ns.Refresh()
	end
	local rule = plan.spells[name]
	MenuUtil.CreateContextMenu(owner, function(_, root)
		root:CreateTitle(name)
		root:CreateRadio("All ranks", function() return rule == "all" end, function() set("all") end)
		root:CreateRadio("First rank", function() return rule == "first" end, function() set("first") end)
		root:CreateRadio("Skip", function() return rule == nil or rule == "skip" end, function() set(nil) end)
		root:CreateRadio("Up to level...", function() return type(rule) == "table" end, function()
			Ask(("%s: train the ranks up to which level?"):format(name), type(rule) == "table" and tostring(rule.upto or "") or "",
				function(text)
					local level = tonumber(text)
					if not level then return end
					set({ upto = level, from = type(rule) == "table" and rule.from or nil })
				end)
		end)
		root:CreateDivider()
		root:CreateButton(type(rule) == "table" and rule.from and ("All once you know: " .. rule.from .. "...") or "All once you know a spell...", function()
			Ask(("%s: train every rank once you know which spell or talent? (empty: none)"):format(name),
				type(rule) == "table" and rule.from or "",
				function(text)
					text = text:match("^%s*(.-)%s*$")
					local upto = type(rule) == "table" and rule.upto or nil
					if text == "" then set(upto and { upto = upto } or nil) else set({ upto = upto, from = text }) end
				end)
		end)
	end)
end

local function Row(i)
	if rows[i] then return rows[i] end
	local r = CreateFrame("Frame", nil, content) --[[@as ObviTrainingRow]]
	r:SetSize(WIDTH - 50, ROW)
	r:SetPoint("TOPLEFT", 0, -(i - 1) * ROW)
	r.icon = r:CreateTexture(nil, "ARTWORK")
	r.icon:SetSize(18, 18)
	r.icon:SetPoint("LEFT", 2, 0)
	r.name = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	r.name:SetPoint("LEFT", r.icon, "RIGHT", 6, 0)
	r.name:SetWidth(150)
	r.name:SetJustifyH("LEFT")
	r.name:SetWordWrap(false)
	r.rule = CreateFrame("Button", nil, r, "UIPanelButtonTemplate") --[[@as Button]]
	r.rule:SetSize(140, 20)
	r.rule:SetPoint("LEFT", 182, 0)
	r.rule:SetNormalFontObject("GameFontHighlightSmall")
	r.chips = {}
	r.note = r:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	r.note:SetPoint("LEFT", 330, 0)
	rows[i] = r
	return r
end

local function Chip(r, k)
	if r.chips[k] then return r.chips[k] end
	local c = CreateFrame("Frame", nil, r) --[[@as ObviTrainingChip]]
	c:SetSize(CHIP - 2, ROW - 6)
	c:SetPoint("LEFT", 330 + (k - 1) * CHIP, 0)
	c.bg = c:CreateTexture(nil, "BACKGROUND")
	c.bg:SetAllPoints()
	c.text = c:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	c.text:SetPoint("CENTER")
	c:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_TOP")
		GameTooltip:SetText(self.title)
		for _, line in ipairs(self.lines) do GameTooltip:AddLine(line, 1, 1, 1) end
		GameTooltip:Show()
	end)
	c:SetScript("OnLeave", function() GameTooltip:Hide() end)
	r.chips[k] = c
	return c
end

local function Fill()
	if not (frame and frame:IsShown()) then return end
	local plan = ns.Current()
	planButton:SetText(plan and plan.title or "No plan: make one")
	resetButton:SetShown(plan ~= nil and (ns.IsEdited(plan) or not ns.IsBuiltin(plan)))
	resetButton:SetText(plan and ns.IsBuiltin(plan) and "Reset" or "Delete")
	local list = Spells(plan)
	local seen = ns.db.trainer and ns.db.trainer[ns.Class()]
	hint:SetShown(not seen)
	local planCost, laterCost, allCost = 0, 0, 0
	for i, e in ipairs(list) do
		local r = Row(i)
		r:Show()
		r.icon:SetTexture(e.spell and e.spell.icon or 134400)
		r.name:SetText(e.name)
		local rule = plan and plan.spells[e.name]
		r.rule:SetText(ns.Describe(rule))
		r.rule:SetEnabled(plan ~= nil)
		r.rule:SetScript("OnClick", function(self) if plan then RuleMenu(self, plan, e.name) end end)
		for _, c in ipairs(r.chips) do c:Hide() end
		r.note:SetText(e.spell and "" or "not seen at your trainer yet")
		local ranks = {}
		for rank in pairs(e.spell and e.spell.ranks or {}) do table.insert(ranks, rank) end
		table.sort(ranks)
		for k, rank in ipairs(ranks) do
			local info = e.spell.ranks[rank]
			local v = ns.Verdict(rule, rank, info.level)
			local c = Chip(r, k)
			c.bg:SetColorTexture(unpack(COLOURS[v]))
			c.text:SetText(info.level)
			c.title = ("%s, rank %d"):format(e.name, rank)
			c.lines = {
				("Level %d, %s"):format(info.level, ns.Coins(info.cost)),
				v == "train" and "The plan trains it." or v == "later" and ("Trained once you know " .. tostring(type(rule) == "table" and rule.from) .. ".")
					or "The plan skips it.",
			}
			c:Show()
			allCost = allCost + info.cost
			if v == "train" then planCost = planCost + info.cost elseif v == "later" then laterCost = laterCost + info.cost end
		end
	end
	for i = #list + 1, #rows do rows[i]:Hide() end
	content:SetHeight(math.max(1, #list * ROW))
	if seen and plan then
		summary:SetText(("The plan costs %s%s; every rank: %s."):format(ns.Coins(planCost),
			laterCost > 0 and (" (+ " .. ns.Coins(laterCost) .. " later)") or "", ns.Coins(allCost)))
	else
		summary:SetText("")
	end
end

local function PlanMenu(owner)
	MenuUtil.CreateContextMenu(owner, function(_, root)
		root:CreateTitle("Plans for your class")
		for _, p in ipairs(ns.Plans()) do
			root:CreateRadio(p.title .. (ns.IsEdited(p) and " (edited)" or ""), function() return ns.Current() == p end,
				function() ns.Choose(p) end)
		end
		root:CreateDivider()
		root:CreateButton("New plan...", function()
			Ask("Name the new plan:", "", function(title)
				title = title:match("^%s*(.-)%s*$")
				if title == "" then return end
				local plan = { title = title, class = ns.Class(), spells = {} }
				ns.Save(plan)
				ns.Choose(plan)
			end)
		end)
		local current = ns.Current()
		if current then
			root:CreateButton("Copy this plan...", function()
				Ask("Name the copy:", current.title .. " (copy)", function(title)
					title = title:match("^%s*(.-)%s*$")
					if title == "" then return end
					local plan = ns.Import(ns.Export(current)) --[[@as ObviTrainingPlan]]
					plan.title = title
					ns.Save(plan)
					ns.Choose(plan)
				end)
			end)
		end
	end)
end

local function Build()
	local f = CreateFrame("Frame", "ObviTrainingFrame", UIParent, "BasicFrameTemplateWithInset") --[[@as Frame]]
	frame = f
	f:SetSize(WIDTH, HEIGHT)
	f:SetPoint("CENTER")
	f:SetFrameStrata("HIGH")
	f:SetMovable(true)
	f:EnableMouse(true)
	f:RegisterForDrag("LeftButton")
	f:SetScript("OnDragStart", f.StartMoving)
	f:SetScript("OnDragStop", f.StopMovingOrSizing)
	f:SetClampedToScreen(true)
	tinsert(_G["UISpecialFrames"], "ObviTrainingFrame")
	local title = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	title:SetPoint("TOP", 0, -5)
	title:SetText("Obvi Training")

	planButton = CreateFrame("Button", nil, f, "UIPanelButtonTemplate") --[[@as Button]]
	planButton:SetSize(260, 24)
	planButton:SetPoint("TOPLEFT", 14, -32)
	planButton:SetScript("OnClick", PlanMenu)

	local export = CreateFrame("Button", nil, f, "UIPanelButtonTemplate") --[[@as Button]]
	export:SetSize(80, 24)
	export:SetPoint("LEFT", planButton, "RIGHT", 8, 0)
	export:SetText("Export")
	export:SetScript("OnClick", function()
		local plan = ns.Current()
		if plan then TextWindow("Export: " .. plan.title, ns.Export(plan)) end
	end)

	local import = CreateFrame("Button", nil, f, "UIPanelButtonTemplate") --[[@as Button]]
	import:SetSize(80, 24)
	import:SetPoint("LEFT", export, "RIGHT", 4, 0)
	import:SetText("Import")
	import:SetScript("OnClick", function()
		TextWindow("Import: paste a plan", "", function(text)
			local plan, why = ns.Import(text)
			if not plan then Print("couldn't import: %s", why or "?") return end
			ns.Save(plan)
			if textFrame then textFrame:Hide() end
			if plan.class == ns.Class() then
				ns.Choose(plan)
				Print("imported %s", plan.title)
			else
				Print("imported %s; it's for %s, so it shows on characters of that class", plan.title, plan.class)
			end
		end)
	end)

	resetButton = CreateFrame("Button", nil, f, "UIPanelButtonTemplate") --[[@as Button]]
	resetButton:SetSize(80, 24)
	resetButton:SetPoint("LEFT", import, "RIGHT", 4, 0)
	resetButton:SetScript("OnClick", function()
		local plan = ns.Current()
		if not plan then return end
		local question = ns.IsBuiltin(plan) and ("Undo your changes to %s?"):format(plan.title)
			or ("Delete %s?"):format(plan.title)
		Confirm(question, function() ns.Delete(plan) ns.Refresh() end)
	end)

	summary = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	summary:SetPoint("TOPLEFT", 16, -64)
	summary:SetPoint("RIGHT", -16, 0)
	summary:SetJustifyH("LEFT")

	local legend = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	legend:SetPoint("BOTTOMLEFT", 16, 12)
	legend:SetText("Boxes are ranks (the level to learn them): |cff33b340green|r trained, |cff888888grey|r skipped, "
		.. "|cffcca626gold|r trained once you know the spell the rule waits for. Click a rule to change it.")
	legend:SetPoint("RIGHT", -16, 0)
	legend:SetJustifyH("LEFT")

	local scroll = CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate") --[[@as ScrollFrame]]
	scroll:SetPoint("TOPLEFT", 12, -84)
	scroll:SetPoint("BOTTOMRIGHT", -32, 44)
	content = CreateFrame("Frame", nil, scroll) --[[@as Frame]]
	content:SetSize(WIDTH - 50, 1)
	scroll:SetScrollChild(content)

	hint = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	hint:SetPoint("CENTER", scroll, "CENTER")
	hint:SetWidth(WIDTH - 120)
	hint:SetText("Talk to your class trainer once: Obvi Training remembers every spell and rank it teaches, to show the whole plan here.")

	f:SetScript("OnShow", Fill)
end

function ns.OpenWindow()
	if not frame then Build() end
	if frame then frame:Show() Fill() end
end

local previous = ns.Refresh
ns.Refresh = function() previous() Fill() end

SLASH_OBVITRAINING1 = "/otr"
SLASH_OBVITRAINING2 = "/obvitraining"
local slashCmdList = _G["SlashCmdList"] ---@type table<string, fun(msg: string)>
slashCmdList.OBVITRAINING = function()
	if frame and frame:IsShown() then frame:Hide() else ns.OpenWindow() end
end
