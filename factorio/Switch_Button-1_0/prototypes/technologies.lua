local tech = data.raw.technology['circuit-network'].effects
local newUnlock = {
  type = 'unlock-recipe',
  recipe = 'switchbutton'
}

table.insert(tech, newUnlock)
