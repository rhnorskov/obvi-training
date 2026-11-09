# Obvi Training

In WoW Forever you don't want to train every rank of every spell: a lot of it is gold spent on spells you never
cast. This addon puts a **Train plan** button on the class trainer, next to Train. It trains only what the training
plan for your class says is worth it, and as new ranks open up (rank 2 after rank 1) it keeps going. Hover over it to
see what it will train and what it costs; right-click it to pick another plan for your class.

It works on its own: it doesn't need Obvi Guide, the guide viewer from the same repo.

## Plans

| Class | Plan |
|---|---|
| Paladin | Retribution (leveling) |

## Writing a plan

A plan is a Lua file in `Plans\` (listed in the TOC) that names the spells as the trainer lists them:

```lua
ObviTraining.Plan({
	title = "Retribution Paladin (leveling)",
	class = "PALADIN",
	spells = {
		["Holy Light"]            = "all",     -- every rank
		["Devotion Aura"]         = "first",   -- rank 1 only
		["Holy Wrath"]            = "skip",    -- none (the same as leaving it out)
		["Seal of Righteousness"] = { upto = 19, from = "Unsealed Wrath" },
		-- the ranks the trainer asks level 19 or less for, and every rank once you know Unsealed Wrath
	},
})
```

## Licence

GPL-3.0, see [LICENSE](LICENSE).
