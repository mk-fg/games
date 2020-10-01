local conf = require('config')

data:extend{

	conf.s{
		order = '11',
		setting_type = 'startup',
		type = 'int-setting',
		minimum_value = 60,
		name = 'spark_interval' },
	conf.s{
		order = '12',
		setting_type = 'startup',
		type = 'int-setting',
		minimum_value = 0,
		name = 'spark_interval_jitter' },

	conf.s{
		order = '21',
		setting_type = 'startup',
		type = 'int-setting',
		minimum_value = 1,
		name = 'check_interval' },
	conf.s{
		order = '22',
		setting_type = 'startup',
		type = 'int-setting',
		minimum_value = 1,
		name = 'check_radius' },
	conf.s{
		order = '23',
		setting_type = 'startup',
		type = 'int-setting',
		minimum_value = 1,
		name = 'check_limit' },

	conf.s{
		order = '31',
		setting_type = 'startup',
		minimum_value = 1,
		type = 'int-setting',
		name = 'min_green_trees' },
	conf.s{
		order = '32',
		setting_type = 'startup',
		minimum_value = 0,
		type = 'int-setting',
		name = 'max_dead_trees' },
	conf.s{
		order = '33',
		setting_type = 'startup',
		type = 'double-setting',
		minimum_value = 0,
		name = 'green_dead_balance' },

}
