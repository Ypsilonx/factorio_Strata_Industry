--- Tipy a triky (nativní okno nápovědy): příběh modu a základy měst. Texty v locale.
--- Bez `trigger`; `starting_status` je zobrazí od začátku hry (výchozí „locked“ by je skryl).
data:extend({
  { type = "tips-and-tricks-item-category", name = "rt-towns", order = "z-[research-towns]" },
  { type = "tips-and-tricks-item", name = "rt-story", category = "rt-towns", order = "a", is_title = true,
    starting_status = "suggested" },
  { type = "tips-and-tricks-item", name = "rt-towns", category = "rt-towns", order = "b", indent = 1, starting_status = "unlocked" },
  { type = "tips-and-tricks-item", name = "rt-exploring", category = "rt-towns", order = "b2", indent = 1, starting_status = "unlocked" },
  { type = "tips-and-tricks-item", name = "rt-depots", category = "rt-towns", order = "c", indent = 1, starting_status = "unlocked" },
  { type = "tips-and-tricks-item", name = "rt-milestones", category = "rt-towns", order = "d", indent = 1, starting_status = "unlocked" },
})
