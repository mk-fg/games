local conf = require('config')

data:extend{
	{ order = '01',
		setting_type = 'startup',
		name = 'signal-update-interval',
		type = 'int-setting',
		minimum_value = 1,
		default_value = conf.ticks_between_updates },
}
data:extend{
	{ order = '02',
		setting_type = 'startup',
		name = 'signal-update-steps',
		type = 'int-setting',
		minimum_value = 1,
		default_value = conf.ticks_update_steps },
}
