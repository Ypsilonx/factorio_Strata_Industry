# Research Towns

*Nauvis was never empty. Its people have lived in its valleys for ages – they know every river, every season
and how to live alongside the planet. You know machines.*

**There are no labs.** Research happens in the town halls of the people of Nauvis. Find their towns, become
their partner, supply them with science packs, goods, fluids and power – and watch a medieval settlement grow
into a city of science, rebuilt step by step with the very technologies you research.

```
vanilla:  science packs → lab
now:      science packs + goods + fluids + power → town hall (+ houses, upkeep, partnership)
```

## Features

### Towns and partnership
- **Towns on the map** – the map generator places towns across Nauvis (a *Towns* slider in the map settings,
  visible in the map preview). The first town lies 100–200 tiles from your landing site and is your partner
  right away.
- **Partnership** – walk up to another town: its people greet you and ask for a small gift (materials you
  already produce). Deliver it through a depot next to its town hall and the town becomes your partner.

### Research and growth
- **Town levels = sciences** – each town level opens one new science pack (vanilla 7 levels, Space Age 12,
  overhaul mods as many as they have). Level up by delivering the new science pack, materials and enough
  connected houses (4 per level, at most 20). Beyond the last science, towns keep growing and gain research
  productivity.
- **Houses** – build them within reach of the town hall or another house (at most 5 in a row). Connected houses
  speed up research by (house level + 1) % each, +120 % at most, and are upgraded one by one (up to level 5)
  with surplus deliveries.
- **Upkeep** – while researching, a town keeps using a small share of the materials of its completed milestones
  (whole items per minute, a 5 minute stock). Without it the town hall stops.
- **Depots** – goods (2×2 warehouse), fluid and power depots supply the nearest town; the **town substation**
  is a real substation: build it within 4 tiles of a town building and connect it to your grid with a wire – the
  town takes power only through it.
  A **town board** sends the town's requests (milestone, house upgrade or upkeep) and progress in % to the
  circuit network.

### Bonuses for your factory
- **Specializations** – every town is skilled in one basic material, derived from the game's data (vanilla:
  iron and copper plates, steel, gears, cables, pipes, circuits…; overhaul mods get their own). Neighbouring
  towns always differ. A partner town raises the **productivity of all recipes that make its material** (including
  Space Age casting) by +1 % for every town level above 5 (from level 6 on), at most +15 % per town – you need
  less ore. More towns with the same specialization add only half, a quarter… of their bonus, +25 % per material
  at most. The town hall panel shows
  the specialization of every town, even one that is not your partner yet – choose your partners wisely.
  Bonuses from productivity research are kept.
- **Clean air** – a researching town hall absorbs pollution (30/min at the first science up to 1000/min at the
  last), and every level 5 house absorbs 15/min.

### Danger
- **Ruins** – if the biters destroy a town hall, the town survives in its ruins: it keeps its level, milestone
  progress, houses and depots, but does not research, takes no power and its specialization gives no bonus.
  Deliver the rebuild materials (half of the current milestone's materials) through its depots and the town hall
  is rebuilt at the same level.

### Graphics
- **Five eras** – the town hall is rebuilt with your research: a settlement of wood and thatch with fields,
  then steam power and workshops, warehouses and tenements, tanks and a glass observatory, and finally a city
  of science with solar fields, a roboport and roof gardens. Houses follow their own level (cottage → tenement
  with solar panels and a roof garden). Machines, trees, ground and items come from the game itself.
- **A researching town hall smokes** from its chimneys – you can see it working by day.
- **At night** windows, lanterns, lamps and fires light up the town.
- Buildings are linked by garlands of flags and lanterns, later by wooden and paved walkways on the ground. Hover a
  house or town hall to see the paths of its whole town network.

## Mod settings

| Setting | Type | Default | What it does |
|---|---|---|---|
| Material upkeep multiplier | startup | 1 | How much material towns use continuously (0 = no upkeep). Lower it for slow overhauls such as Pyanodon. |
| Pollution absorption multiplier | startup | 1 | How much pollution town halls and level 5 houses absorb (0 = none). |
| Town specialization strength | map (runtime) | 1 | Multiplies the specialization bonus (from town level 6) and its caps (0.5 = half, 0 = off). Can be changed in a running game – bonuses update immediately. |

The number and spacing of towns are set with the **Towns** slider in the map generator (frequency, size).

## How to start

1. Start a new map (or add the mod to an existing save – towns are added to the explored map).
2. Find your first town 100–200 tiles from the landing site and open its town hall.
3. Build a town substation next to it, connect it to your grid with a wire and insert red science packs – research
   starts.
4. Build houses and depots, deliver the milestone, press **Upgrade town**.
5. Explore: every new town you reach asks for a gift and then researches with you – and brings its specialization.

## Compatibility

- Factorio 2.0, base game and Space Age.
- Tested with Bob's mods (17 mods) and Pyanodon (`pymodpack`): sciences, milestones and specializations are
  derived automatically, all labs are replaced by town halls.
- Labs from other mods are removed (their recipes are hidden); labs already built in a save keep working.
- **Removing the mod** from a running save removes all town halls, houses and depots – and with them your
  research buildings. Add it to a save you mean to keep playing with it.

## Credits

- Graphics rendered in Blender by the author. The town renders include trees, machines, ground textures and
  items from Factorio – © Wube Software, used as permitted for mods.
- License: MIT (code). Factorio-derived graphics remain the property of Wube Software.
