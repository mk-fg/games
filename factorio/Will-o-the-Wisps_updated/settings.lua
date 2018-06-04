local conf = require('config')

data:extend{

	{ order = '0010',
		setting_type = 'runtime-global',
		name = 'wisps-can-attack',
		type = 'bool-setting',
		default_value = not conf.peaceful_wisps },
	{ order = '0020',
		setting_type = 'runtime-global',
		name = 'defences-shoot-wisps',
		type = 'bool-setting',
		default_value = not conf.peaceful_defences },
	{ order = '0030',
		setting_type = 'runtime-global',
		name = 'purple-wisp-damage',
		type = 'bool-setting',
		default_value = not conf.peaceful_spores },

	{ order = '0040',
		setting_type = 'runtime-global',
		name = 'dynamic-wisp-lights',
		type = 'bool-setting',
		default_value = conf.wisp_lights_dynamic },

}
