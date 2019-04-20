local conf = require('config')

data:extend{
	{ order = '01',
		setting_type = 'startup',
		name = 'range-multiplier',
		type = 'double-setting',
		minimum_value = 0,
		default_value = conf.range_multiplier },
	{ order = '02',
		setting_type = 'startup',
		name = 'range-logistics',
		type = 'int-setting',
		minimum_value = -2,
		default_value = conf.range_logistics },
	{ order = '03',
		setting_type = 'startup',
		name = 'range-construction',
		type = 'int-setting',
		minimum_value = -2,
		default_value = conf.range_construction },
}
