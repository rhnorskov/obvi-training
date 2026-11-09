-- Retribution Paladin, leveling: the spells worth training and the ones to save the gold on. Spells not listed
-- (Seal of Justice, Concentration Aura, Turn Undead, Holy Wrath...) aren't trained.

ObviTraining.Plan({
	title = "Retribution Paladin (leveling)",
	class = "PALADIN",
	spells = {
		-- every rank
		["Seal of Righteousness"] = { upto = 19, from = "Unsealed Wrath" },   -- until 20, again with the talent (~40)
		["Holy Light"]            = "all",
		["Blessing of Might"]     = "all",
		["Judgement"]             = "all",
		["Holy Strike"]           = "all",
		["Seal of the Crusader"]  = "all",
		["Hammer of Justice"]     = "all",
		["Retribution Aura"]      = "all",
		["Blessing of Freedom"]   = "all",
		["Consecration"]          = "all",
		["Seal of Command"]       = "all",
		["Exorcism"]              = "all",   -- worth it against undead and demons
		["Flash of Light"]        = "all",
		["Divine Shield"]         = "all",
		["Cleanse"]               = "all",
		["Hammer of Wrath"]       = "all",
		-- the first rank only
		["Devotion Aura"]         = "first",
		["Lay on Hands"]          = "first",
		["Blessing of Sacrifice"] = "first",
		-- not while leveling (tanking: Seal of Fury)
		["Seal of Fury"]          = "skip",
		["Seal of Justice"]       = "skip",
		["Concentration Aura"]    = "skip",
		["Turn Undead"]           = "skip",
		["Holy Wrath"]            = "skip",
	},
})
