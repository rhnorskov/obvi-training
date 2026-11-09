-- Obvi Training: plans, their rules, your edits, the class trainer's spell list (remembered) and the text form for
-- import and export. Trainer.lua puts the "Train plan" button on the trainer; UI.lua is the plan window.
local _, addon = ...
---@class ObviTrainingNS
local ns = addon

---@alias ObviTrainingRule "all"|"first"|"skip"|{upto?: integer, from?: string}
--- "all": every rank; "first": rank 1 only; "skip": none (as a spell not in the plan); a table: the ranks the
--- trainer asks level `upto` or less for, and every rank once you know the spell (or talent) `from`.

---@class ObviTrainingPlan
---@field title string
---@field class string                              the class file name ("PALADIN")
---@field spells table<string, ObviTrainingRule>    by the spell's name as the trainer lists it

---@class ObviTrainingRank
---@field level integer   the level the trainer asks for
---@field cost integer    copper

---@class ObviTrainingSpell
---@field icon? integer|string
---@field ranks table<integer, ObviTrainingRank>

---@class ObviTrainingDB
---@field plans? ObviTrainingPlan[]   your plans, and your edits of built-in ones (same title and class)
---@field trainer? table<string, table<string, ObviTrainingSpell>>   class -> spell name -> what the trainer lists

---@class ObviTrainingCharDB
---@field plan? string   the chosen plan's title (nil: the first plan for the class)

---@class ObviTrainingNS
---@field db ObviTrainingDB
---@field charDB ObviTrainingCharDB
---@field builtin ObviTrainingPlan[]
---@field Refresh fun()   the trainer button and the plan window, after a change
---@field OpenWindow fun()   the plan window (UI.lua)
local builtin = {} ---@type ObviTrainingPlan[]
ns.builtin = builtin
ns.Refresh = function() end

ObviTraining = ObviTraining or {}

--- Adds a built-in training plan (Plans\*.lua).
---@param plan ObviTrainingPlan
function ObviTraining.Plan(plan) table.insert(builtin, plan) end

function ns.Class() return select(2, UnitClass("player")) end

local function Copy(plan)
	local spells = {}
	for name, rule in pairs(plan.spells) do
		spells[name] = type(rule) == "table" and { upto = rule.upto, from = rule.from } or rule
	end
	return { title = plan.title, class = plan.class, spells = spells }
end

local function Saved() ns.db.plans = ns.db.plans or {} return ns.db.plans end

local function Find(list, title, class)
	for i, p in ipairs(list) do if p.title == title and p.class == class then return p, i end end
end

--- Whether a plan is (an edit of) a built-in one.
---@param plan ObviTrainingPlan
function ns.IsBuiltin(plan) return Find(builtin, plan.title, plan.class) ~= nil end

--- Whether a built-in plan has your edits.
---@param plan ObviTrainingPlan
function ns.IsEdited(plan) return ns.IsBuiltin(plan) and Find(Saved(), plan.title, plan.class) ~= nil end

--- The plans for a class (default: yours): the built-in ones (your edit in place of one you changed), then yours.
---@param class? string
---@return ObviTrainingPlan[]
function ns.Plans(class)
	class = class or ns.Class()
	local list = {}
	for _, p in ipairs(builtin) do
		if p.class == class then table.insert(list, Find(Saved(), p.title, p.class) or p) end
	end
	for _, p in ipairs(Saved()) do
		if p.class == class and not Find(builtin, p.title, p.class) then table.insert(list, p) end
	end
	return list
end

--- The plan in use: the one chosen for this character, or the first for its class.
---@return ObviTrainingPlan?
function ns.Current()
	local list = ns.Plans()
	local chosen = ns.charDB and ns.charDB.plan
	for _, p in ipairs(list) do if p.title == chosen then return p end end
	return list[1]
end

---@param plan ObviTrainingPlan
function ns.Choose(plan) ns.charDB.plan = plan.title ns.Refresh() end

--- Your copy of a plan to change: a built-in plan is copied into your plans the first time.
---@param plan ObviTrainingPlan
---@return ObviTrainingPlan
function ns.Editable(plan)
	local mine = Find(Saved(), plan.title, plan.class)
	if mine then return mine end
	mine = Copy(plan)
	table.insert(Saved(), mine)
	return mine
end

--- Saves a plan (an imported one, a new one) in your plans, in place of one with the same title and class.
---@param plan ObviTrainingPlan
function ns.Save(plan)
	local _, i = Find(Saved(), plan.title, plan.class)
	if i then Saved()[i] = plan else table.insert(Saved(), plan) end
end

--- Deletes your plan, or your edits of a built-in one (back to the built-in).
---@param plan ObviTrainingPlan
function ns.Delete(plan)
	local _, i = Find(Saved(), plan.title, plan.class)
	if i then table.remove(Saved(), i) end
end

--- Whether the player knows a spell or talent, by name (talents with a spell of their own are in the spellbook).
---@param name string
function ns.Knows(name)
	local info = C_Spell.GetSpellInfo(name)
	return info ~= nil and C_SpellBook.IsSpellKnown(info.spellID)
end

--- What a rule does with a rank: "train", "skip", or "later" (trained once you know the rule's `from`).
---@param rule ObviTrainingRule?
---@param rank integer
---@param level integer   what the trainer asks for it
---@return "train"|"skip"|"later"
function ns.Verdict(rule, rank, level)
	if rule == "all" then return "train" end
	if rule == "first" then return rank == 1 and "train" or "skip" end
	if type(rule) == "table" then
		if rule.upto and level <= rule.upto then return "train" end
		if rule.from then return "later" end
	end
	return "skip"
end

--- Whether the plan trains a rank now (a "later" rank once you know the spell it waits for).
---@param plan ObviTrainingPlan
---@param name string
---@param rank integer
---@param level integer
function ns.Wants(plan, name, rank, level)
	local rule = plan.spells[name]
	local v = ns.Verdict(rule, rank, level)
	if v == "later" then return type(rule) == "table" and rule.from ~= nil and ns.Knows(rule.from) end
	return v == "train"
end

--- A rule in words, for the window.
---@param rule ObviTrainingRule?
function ns.Describe(rule)
	if rule == "all" then return "All ranks" end
	if rule == "first" then return "First rank" end
	if type(rule) == "table" then
		local parts = {}
		if rule.upto then table.insert(parts, "Up to level " .. rule.upto) end
		if rule.from then table.insert(parts, "all with " .. rule.from) end
		return table.concat(parts, ", ")
	end
	return "Skip"
end

--- "Rank 3" -> 3 (no rank: 1).
---@param text? string
function ns.RankOf(text) return tonumber(text and text:match("(%d+)")) or 1 end

-- the text form: a header, then a line per spell. "#" starts a comment.
--   Obvi Training plan
--   title: Retribution Paladin (leveling)
--   class: PALADIN
--   Holy Light: all
--   Devotion Aura: first
--   Seal of Righteousness: upto 19, from Unsealed Wrath

local function RuleText(rule)
	if type(rule) ~= "table" then return rule end
	local parts = {}
	if rule.upto then table.insert(parts, "upto " .. rule.upto) end
	if rule.from then table.insert(parts, "from " .. rule.from) end
	return table.concat(parts, ", ")
end

--- A plan as text, spells in name order.
---@param plan ObviTrainingPlan
---@return string
function ns.Export(plan)
	local lines = { "Obvi Training plan", "title: " .. plan.title, "class: " .. plan.class }
	local names = {}
	for name in pairs(plan.spells) do table.insert(names, name) end
	table.sort(names)
	for _, name in ipairs(names) do table.insert(lines, name .. ": " .. RuleText(plan.spells[name])) end
	return table.concat(lines, "\n")
end

--- A plan from text; nil and why when it can't be read.
---@param text string
---@return ObviTrainingPlan?, string?
function ns.Import(text)
	local plan = { spells = {} }
	local n = 0
	for raw in (text .. "\n"):gmatch("(.-)\r?\n") do
		n = n + 1
		local line = raw:gsub("#.*$", ""):match("^%s*(.-)%s*$")
		if line ~= "" and line ~= "Obvi Training plan" then
			local key, value = line:match("^(.-)%s*:%s*(.-)$")
			if not key or key == "" then return nil, ("line %d: expected 'name: rule'"):format(n) end
			if key == "title" then plan.title = value
			elseif key == "class" then plan.class = value:upper()
			elseif value == "all" or value == "first" or value == "skip" then plan.spells[key] = value
			else
				local rule = {}
				for piece in value:gmatch("[^,]+") do
					local part = piece:match("^%s*(.-)%s*$")
					local upto = part:match("^upto%s+(%d+)$")
					local from = part:match("^from%s+(.+)$")
					if upto then rule.upto = tonumber(upto)
					elseif from then rule.from = from
					else return nil, ("line %d: '%s' isn't all, first, skip, upto <level> or from <spell>"):format(n, part) end
				end
				plan.spells[key] = rule
			end
		end
	end
	if not plan.title or plan.title == "" then return nil, "no 'title:' line" end
	if not plan.class or plan.class == "" then return nil, "no 'class:' line" end
	return plan
end

--- Remembers what the class trainer lists (every rank, with its level and cost), to show the whole plan away from
--- the trainer. The trainer's filters are opened up for the reading and put back after.
function ns.Record()
	if IsTradeskillTrainer() then return end
	ns.db.trainer = ns.db.trainer or {}
	local spells = ns.db.trainer[ns.Class()] or {}
	ns.db.trainer[ns.Class()] = spells
	local filters = {}
	for _, f in ipairs({ "available", "unavailable", "used" }) do
		filters[f] = GetTrainerServiceTypeFilter(f)
		if not filters[f] then SetTrainerServiceTypeFilter(f, true, false) end
	end
	for i = 1, GetNumTrainerServices() do
		local name, rankText, category = GetTrainerServiceInfo(i)
		if name and category ~= "header" then
			local spell = spells[name] or { ranks = {} }
			spells[name] = spell
			spell.icon = GetTrainerServiceIcon(i) or spell.icon
			spell.ranks[ns.RankOf(rankText)] = { level = GetTrainerServiceLevelReq(i) or 0, cost = GetTrainerServiceCost(i) or 0 }
		end
	end
	for f, on in pairs(filters) do if not on then SetTrainerServiceTypeFilter(f, false, false) end end
end

function ns.Coins(copper) return C_CurrencyInfo.GetCoinTextureString(copper) end

local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:SetScript("OnEvent", function(_, _, name)
	if name ~= "ObviTraining" then return end
	ObviTrainingDB = ObviTrainingDB or {}
	ObviTrainingCharDB = ObviTrainingCharDB or {}
	ns.db, ns.charDB = ObviTrainingDB, ObviTrainingCharDB
	events:UnregisterEvent("ADDON_LOADED")
end)
