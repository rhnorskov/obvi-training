-- The "Train plan" button on the class trainer: lists what the plan trains here and asks before training it. Hover:
-- the same list; right-click: choose a plan, or open the plan window. Opening the trainer also remembers its spell
-- list (Core.lua's ns.Record), for the plan window.
local _, ns = ...
---@cast ns ObviTrainingNS

local button ---@type Button?
local buyingUntil = 0   -- buying goes on as new ranks open up (rank 2 is listed once rank 1 is learnt), until then
local approved = {} ---@type table<string, boolean>   what the player said yes to: "name|rank"
local recording = false

---@class ObviTrainingBuy
---@field name string
---@field rank integer
---@field rankText? string
---@field cost integer

--- What the plan trains here: the services it wants that can be learnt now, and the higher ranks of those spells it
--- wants that open up once the lower rank is learnt (at your level already), in the trainer's order.
---@param plan ObviTrainingPlan
---@return ObviTrainingBuy[] list, integer cost
local function Planned(plan)
	local list, cost, buying = {}, 0, {}
	local level = UnitLevel("player")
	for pass = 1, 2 do
		for i = 1, GetNumTrainerServices() do
			local name, rank, category, rankText = ns.Service(i)
			local req = GetTrainerServiceLevelReq(i) or 0
			local now = category == "available"
			-- pass 2: a higher rank of a spell bought in pass 1, at your level, waiting only for the rank below
			local after = pass == 2 and category == "unavailable" and name and buying[name] and req <= level
			if name and ((pass == 1 and now) or after) and ns.Wants(plan, name, rank, req) then
				if pass == 1 then buying[name] = true end
				table.insert(list, { name = name, rank = rank, rankText = rankText, cost = GetTrainerServiceCost(i) })
				cost = cost + GetTrainerServiceCost(i)
			end
		end
	end
	table.sort(list, function(a, b) if a.name ~= b.name then return a.name < b.name end return a.rank < b.rank end)
	return list, cost
end

local function Label(e) return e.name .. (e.rankText and e.rankText ~= "" and (" (" .. e.rankText .. ")") or "") end

--- Buys the approved services that can be learnt now and the gold allows (later services first, so their index
--- stays right). Called again as the trainer updates, for the ranks that open up.
local function Buy()
	local money = GetMoney()
	for i = GetNumTrainerServices(), 1, -1 do
		local name, rank, category = ns.Service(i)
		local key = name and (name .. "|" .. rank)
		if category == "available" and key and approved[key] then
			local cost = GetTrainerServiceCost(i)
			if cost <= money then
				approved[key] = nil
				BuyTrainerService(i)
				money = money - cost
			end
		end
	end
end

-- the question: what will be trained, and the total
local StaticPopupDialogs = _G["StaticPopupDialogs"] ---@type table
local StaticPopup_Show = _G["StaticPopup_Show"] ---@type fun(which: string, a?: string, b?: string, data?: any): Frame?
StaticPopupDialogs.OBVITRAINING_TRAIN = {
	text = "%s",
	button1 = "Train",
	button2 = "Cancel",
	OnAccept = function(_, data)
		approved = {}
		for _, e in ipairs(data) do approved[e.name .. "|" .. e.rank] = true end
		buyingUntil = GetTime() + 5
		Buy()
	end,
	hideOnEscape = 1,
	timeout = 0,
	whileDead = 1,
}

local function Confirm()
	local plan = ns.Current()
	if not plan then return end
	local list, cost = Planned(plan)
	if #list == 0 then return end
	local lines = { ("%s: train these for %s?"):format(plan.title, ns.Coins(cost)), "" }
	for _, e in ipairs(list) do table.insert(lines, ("%s  %s"):format(Label(e), ns.Coins(e.cost))) end
	if cost > GetMoney() then
		table.insert(lines, "")
		table.insert(lines, "|cffff6060Not enough gold for all of it: only what you can afford is trained.|r")
	end
	StaticPopup_Show("OBVITRAINING_TRAIN", table.concat(lines, "\n"), nil, list)
end

local function ShowTooltip(self)
	local plan = ns.Current()
	GameTooltip:SetOwner(self, "ANCHOR_TOP", 0, 4)
	if not plan then
		GameTooltip:SetText("No training plan for your class")
	else
		local list, cost = Planned(plan)
		GameTooltip:SetText(plan.title)
		if #list == 0 then
			GameTooltip:AddLine("Nothing to train from the plan here.", 1, 1, 1)
		else
			GameTooltip:AddLine(("Trains %d for %s:"):format(#list, ns.Coins(cost)), 1, 1, 1)
			for _, e in ipairs(list) do GameTooltip:AddDoubleLine(Label(e), ns.Coins(e.cost), 1, 0.82, 0, 1, 1, 1) end
		end
	end
	GameTooltip:AddLine("Right-click: choose a plan, or edit it", 0.6, 0.6, 0.6)
	GameTooltip:Show()
end

local function Refresh()
	if not button then return end
	-- class trainers only: a profession trainer uses the same window
	local plan = ns.Current()
	button:SetShown(not IsTradeskillTrainer())
	button:SetEnabled(plan ~= nil and #(Planned(plan)) > 0)
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
		Confirm()
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
