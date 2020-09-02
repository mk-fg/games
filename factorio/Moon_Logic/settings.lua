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
}
