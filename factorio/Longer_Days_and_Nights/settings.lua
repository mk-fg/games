local conf = require('config')

data:extend{
	{ order = '01',
		setting_type = 'startup',
		name = 'day-night-multiplier',
		type = 'int-setting',
		minimum_value = 1,
		default_value = conf.multiplier },
	{ order = '02',
		setting_type = 'startup',
		name = 'adjust-accumulator-capacity',
		type = 'bool-setting',
		default_value = conf.adjust_accumulators },
}
