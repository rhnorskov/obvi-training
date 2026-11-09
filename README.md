# Obvi Training

In WoW Forever you don't want to train every rank of every spell: a lot of it is gold spent on spells you never
cast. Obvi Training puts a **Train plan** button on the class trainer, next to Train. It trains only what the training
plan for your class says is worth it, and as new ranks open up (rank 2 after rank 1) it keeps going. Hover over it to
see what it will train and what it costs; right-click it to pick another plan, or open the plan window.

It works on its own: it doesn't need Obvi Guide, the guide viewer from the same repo.

## The plan window

`/otr` (or **Plans...** in the button's right-click menu) shows the plan for your class: every spell the trainer
teaches, in the order you learn them, with a box per rank showing the level it's learnt at, coloured by what the plan
does with it (green trained, grey skipped, gold trained once you know the spell the rule waits for). At the top, what
the plan costs against training every rank.

- **Edit**: click a spell's rule to change it: All ranks, First rank, Skip, Up to level..., or all ranks once you know
  a spell or talent. Changing a built-in plan keeps your version; **Reset** brings the built-in one back.
- **New plan** / **Copy this plan**: in the plan's menu (the button at the top left).
- **Export**: the plan as text, to copy and share. **Import**: paste a plan's text.

The window learns the spells from your class trainer: talk to it once and it remembers every spell and rank it
teaches, with the level and cost.

## Plans

| Class | Plan |
|---|---|
| Paladin | Retribution (leveling) |

## The plan text

What Export gives and Import takes; also how a built-in plan is written (a Lua file in `Plans\`, listed in the TOC):

```
Obvi Training plan
title: Retribution Paladin (leveling)
class: PALADIN
Holy Light: all
Devotion Aura: first
Holy Wrath: skip
Seal of Righteousness: upto 19, from Unsealed Wrath
```

`all` every rank, `first` rank 1 only, `skip` none (the same as leaving the spell out), `upto 19` the ranks learnt at
level 19 or below, `from Unsealed Wrath` every rank once you know that spell or talent. Spell names as the trainer
lists them.

```lua
ObviTraining.Plan({
	title = "Retribution Paladin (leveling)",
	class = "PALADIN",
	spells = {
		["Holy Light"]            = "all",
		["Seal of Righteousness"] = { upto = 19, from = "Unsealed Wrath" },
	},
})
```

## Licence

GPL-3.0, see [LICENSE](LICENSE).
