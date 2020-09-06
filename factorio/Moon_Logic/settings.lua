local conf = require('config')

data:extend{
	{ order = '01',
		setting_type = 'startup',
		name = 'red-wire-name',
		type = 'string-setting',
		default_value = conf.red_wire_name },
	{ order = '02',
		setting_type = 'startup',
		name = 'green-wire-name',
		type = 'string-setting',
		default_value = conf.green_wire_name },
	{ order = '03',
		setting_type = 'startup',
		name = 'gui-signals-update-interval',
		type = 'int-setting',
		minimum_value = 1,
		default_value = conf.gui_signals_update_interval },
}
