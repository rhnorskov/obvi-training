-- Obvi Training. A training plan says which class spells (and which ranks) are worth the gold; the "Train
-- plan" button on the class trainer buys just those. Plans: ObviTraining.Plan in Plans\*.lua (one per class and
-- spec). Right-click the button to pick another plan for your class. The button's tooltip lists what it buys.
local _, ns = ...

---@alias ObviTrainingRule "all"|"first"|"skip"|{upto?: integer, from?: string}
--- "all": every rank; "first": rank 1 only; "skip": none (as a spell not in the plan); a table: the ranks the
--- trainer asks level `upto` or less for, and every rank once you know the spell (or talent) `from`.

---@class ObviTrainingPlan
---@field title string
---@field class string                              the class file name ("PALADIN")
---@field spells table<string, ObviTrainingRule>    by the spell's name as the trainer lists it

---@class ObviTrainingCharDB
---@field plan? string   the chosen plan's title (nil: the first plan for the class)

local plans = {} ---@type ObviTrainingPlan[]

ObviTraining = ObviTraining or {}

--- Adds a training plan.
---@param plan ObviTrainingPlan
function ObviTraining.Plan(plan) table.insert(plans, plan) end

local function Class() return select(2, UnitClass("player")) end

--- The plans for this character's class.
---@return ObviTrainingPlan[]
local function ClassPlans()
	local list = {}
	for _, p in ipairs(plans) do if p.class == Class() then table.insert(list, p) end end
	return list
end

--- The plan in use: the one chosen for this character, or the first for its class.
---@return ObviTrainingPlan?
local function Current()
	local list = ClassPlans()
	local chosen = ObviTrainingCharDB and ObviTrainingCharDB.plan
	for _, p in ipairs(list) do if p.title == chosen then return p end end
	return list[1]
end

--- Whether the player knows a spell or talent, by name (talents with a spell of their own are in the spellbook).
---@param name string
local function Knows(name)
	local info = C_Spell.GetSpellInfo(name)
	return info ~= nil and C_SpellBook.IsSpellKnown(info.spellID)
end

--- Whether the plan buys the trainer's service i.
---@param plan ObviTrainingPlan
---@param i integer
---@return boolean
local function Wanted(plan, i)
	local name, rankText = GetTrainerServiceInfo(i)
	local rule = name and plan.spells[name]
	if not rule or rule == "skip" then return false end
	if rule == "all" then return true end
	local rank = tonumber(rankText and rankText:match("(%d+)")) or 1
	if rule == "first" then return rank == 1 end
	if type(rule) == "table" then
		if rule.from and Knows(rule.from) then return true end
		return rule.upto ~= nil and GetTrainerServiceLevelReq(i) <= rule.upto
	end
	return false
end

--- The services the plan buys that can be bought now, and what they cost together.
---@param plan ObviTrainingPlan
---@return integer[] services, integer cost
local function ToBuy(plan)
	local list, cost = {}, 0
	for i = 1, GetNumTrainerServices() do
		local _, _, category = GetTrainerServiceInfo(i)
		if category == "available" and Wanted(plan, i) then
			table.insert(list, i)
			cost = cost + GetTrainerServiceCost(i)
		end
	end
	return list, cost
end

local button ---@type Button?
local buyingUntil = 0   -- buying goes on as new ranks open up (rank 2 is listed once rank 1 is learnt), until then

--- Buys what the plan wants and the gold allows (later services first, so their index stays right).
local function Buy()
	local plan = Current()
	if not plan then return end
	local list = ToBuy(plan)
	local money = GetMoney()
	for k = #list, 1, -1 do
		local cost = GetTrainerServiceCost(list[k])
		if cost <= money then
			BuyTrainerService(list[k])
			money = money - cost
		end
	end
end

local function Coins(copper) return C_CurrencyInfo.GetCoinTextureString(copper) end

local function ShowTooltip(self)
	local plan = Current()
	GameTooltip:SetOwner(self, "ANCHOR_TOP", 0, 4)
	if not plan then
		GameTooltip:SetText("No training plan for your class")
	else
		local list, cost = ToBuy(plan)
		GameTooltip:SetText(plan.title)
		if #list == 0 then
			GameTooltip:AddLine("Nothing to train from the plan here.", 1, 1, 1)
		else
			GameTooltip:AddLine(("Trains %d for %s:"):format(#list, Coins(cost)), 1, 1, 1)
			for _, i in ipairs(list) do
				local name, rankText = GetTrainerServiceInfo(i)
				GameTooltip:AddDoubleLine(name .. (rankText and rankText ~= "" and (" (" .. rankText .. ")") or ""),
					Coins(GetTrainerServiceCost(i)), 1, 0.82, 0, 1, 1, 1)
			end
		end
		local skipped = 0
		for i = 1, GetNumTrainerServices() do
			local _, _, category = GetTrainerServiceInfo(i)
			if category == "available" and not Wanted(plan, i) then skipped = skipped + 1 end
		end
		if skipped > 0 then GameTooltip:AddLine(("Leaves %d not in the plan."):format(skipped), 0.6, 0.6, 0.6) end
	end
	if #ClassPlans() > 1 then GameTooltip:AddLine("Right-click: choose another plan", 0.6, 0.6, 0.6) end
	GameTooltip:Show()
end

local function Refresh()
	if not button then return end
	-- class trainers only: a profession trainer uses the same window
	local plan = Current()
	button:SetShown(plan ~= nil and not IsTradeskillTrainer())
	button:SetEnabled(plan ~= nil and #(ToBuy(plan)) > 0)
	if button:IsMouseOver() then ShowTooltip(button) end
end

local function ChoosePlan(owner)
	MenuUtil.CreateContextMenu(owner, function(_, root)
		root:CreateTitle("Training plan")
		for _, p in ipairs(ClassPlans()) do
			root:CreateRadio(p.title, function() return Current() == p end, function()
				ObviTrainingCharDB.plan = p.title
				Refresh()
			end)
		end
	end)
end

local function Setup()
	if button then return end
	local frame = _G["ClassTrainerFrame"] ---@type Frame
	local train = _G["ClassTrainerTrainButton"] ---@type Button
	button = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate") --[[@as Button]]
	button:SetSize(90, 22)
	button:SetText("Train plan")
	-- left of the Train button, or of Leatrix Plus's Train All when it's there
	local leatrix = _G["LeaPlusGlobalTrainAllButton"] ---@type Button?
	button:SetPoint("RIGHT", (leatrix and leatrix:IsShown()) and leatrix or train, "LEFT", -1, 0)
	button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	button:SetScript("OnClick", function(self, which)
		if which == "RightButton" then ChoosePlan(self) return end
		buyingUntil = GetTime() + 5
		Buy()
	end)
	button:SetScript("OnEnter", ShowTooltip)
	button:SetScript("OnLeave", function() GameTooltip:Hide() end)
	frame:HookScript("OnShow", Refresh)
	Refresh()
end

local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("TRAINER_UPDATE")
events:SetScript("OnEvent", function(_, event, name)
	if event == "ADDON_LOADED" and name == "ObviTraining" then
		ObviTrainingCharDB = ObviTrainingCharDB or {}
		-- the trainer window is an addon of its own, loaded the first time a trainer is opened
		if C_AddOns.IsAddOnLoaded("Blizzard_TrainerUI") then Setup() end
	elseif event == "ADDON_LOADED" and name == "Blizzard_TrainerUI" then
		Setup()
	elseif event == "TRAINER_UPDATE" then
		if GetTime() < buyingUntil then Buy() end
		Refresh()
	end
end)
