local conf = {}

-- Tick on which game will freeze/unfreeze daytime advancement.
-- Lower values will mean smoother transitions but slightly less load.
conf.tick = 13

-- Mod advances unfreezes daytime every Nth tick-period, this is N.
conf.multiplier = 4

-- If true, data-updates.lua will multiply buffer_capacity for all data.raw.accumulator entities by conf.multiplier.
conf.adjust_accumulators = true

return conf
