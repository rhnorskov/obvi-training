-- The "Train plan" button on the class trainer: trains what the plan wants and the gold allows. Hover: what it trains
-- and costs; right-click: choose a plan, or open the plan window. Opening the trainer also remembers its spell list
-- (Core.lua's ns.Record), for the plan window.
local _, ns = ...
---@cast ns ObviTrainingNS

local button ---@type Button?
local buyingUntil = 0   -- buying goes on as new ranks open up (rank 2 is listed once rank 1 is learnt), until then
local recording = false

--- The services the plan trains that can be bought now, and what they cost together.
---@param plan ObviTrainingPlan
---@return integer[] services, integer cost
local function ToBuy(plan)
	local list, cost = {}, 0
	for i = 1, GetNumTrainerServices() do
		local name, rankText, category = GetTrainerServiceInfo(i)
		if category == "available" and name and ns.Wants(plan, name, ns.RankOf(rankText), GetTrainerServiceLevelReq(i)) then
			table.insert(list, i)
			cost = cost + GetTrainerServiceCost(i)
		end
	end
	return list, cost
end

--- Buys what the plan wants and the gold allows (later services first, so their index stays right).
local function Buy()
	local plan = ns.Current()
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

local function ShowTooltip(self)
	local plan = ns.Current()
	GameTooltip:SetOwner(self, "ANCHOR_TOP", 0, 4)
	if not plan then
		GameTooltip:SetText("No training plan for your class")
	else
		local list, cost = ToBuy(plan)
		GameTooltip:SetText(plan.title)
		if #list == 0 then
			GameTooltip:AddLine("Nothing to train from the plan here.", 1, 1, 1)
		else
			GameTooltip:AddLine(("Trains %d for %s:"):format(#list, ns.Coins(cost)), 1, 1, 1)
			for _, i in ipairs(list) do
				local name, rankText = GetTrainerServiceInfo(i)
				GameTooltip:AddDoubleLine(name .. (rankText and rankText ~= "" and (" (" .. rankText .. ")") or ""),
					ns.Coins(GetTrainerServiceCost(i)), 1, 0.82, 0, 1, 1, 1)
			end
		end
		local skipped = 0
		for i = 1, GetNumTrainerServices() do
			local name, rankText, category = GetTrainerServiceInfo(i)
			if category == "available" and name and not ns.Wants(plan, name, ns.RankOf(rankText), GetTrainerServiceLevelReq(i)) then
				skipped = skipped + 1
			end
		end
		if skipped > 0 then GameTooltip:AddLine(("Leaves %d not in the plan."):format(skipped), 0.6, 0.6, 0.6) end
	end
	GameTooltip:AddLine("Right-click: choose a plan, or edit it", 0.6, 0.6, 0.6)
	GameTooltip:Show()
end

local function Refresh()
	if not button then return end
	-- class trainers only: a profession trainer uses the same window
	local plan = ns.Current()
	button:SetShown(not IsTradeskillTrainer())
	button:SetEnabled(plan ~= nil and #(ToBuy(plan)) > 0)
	if button:IsMouseOver() then ShowTooltip(button) end
end

local function Menu(owner)
	MenuUtil.CreateContextMenu(owner, function(_, root)
		root:CreateTitle("Training plan")
		for _, p in ipairs(ns.Plans()) do
			root:CreateRadio(p.title, function() return ns.Current() == p end, function() ns.Choose(p) end)
		end
		root:CreateDivider()
		root:CreateButton("Plans...", function() ns.OpenWindow() end)
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
		if which == "RightButton" then Menu(self) return end
		buyingUntil = GetTime() + 5
		Buy()
	end)
	button:SetScript("OnEnter", ShowTooltip)
	button:SetScript("OnLeave", function() GameTooltip:Hide() end)
	frame:HookScript("OnShow", Refresh)
	Refresh()
end

local refreshWindow = ns.Refresh
ns.Refresh = function() Refresh() refreshWindow() end

local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("TRAINER_SHOW")
events:RegisterEvent("TRAINER_UPDATE")
events:SetScript("OnEvent", function(_, event, name)
	if event == "ADDON_LOADED" then
		-- the trainer window is an addon of its own, loaded the first time a trainer is opened
		if name == "Blizzard_TrainerUI" or (name == "ObviTraining" and C_AddOns.IsAddOnLoaded("Blizzard_TrainerUI")) then Setup() end
	elseif event == "TRAINER_SHOW" then
		recording = true
		ns.Record()
		recording = false
		ns.Refresh()
	elseif event == "TRAINER_UPDATE" and not recording then
		if GetTime() < buyingUntil then Buy() end
		Refresh()
	end
end)
