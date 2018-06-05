data:extend{

	{ type = 'recipe',
		name = 'alien-flora-sample',
		ingredients = {
			{'stone',100},
			{'raw-wood',100},
			{'coal',100},
		},
		result = 'alien-flora-sample',
		enabled = true },

	{ type = 'recipe',
		name = 'wisp-yellow',
		ingredients = {
			{'alien-flora-sample',100},
			{'raw-wood',100},
		},
		result = 'wisp-yellow',
		enabled = true },

	{ type = 'recipe',
		name = 'wisp-purple',
		ingredients = {
			{'alien-flora-sample',100},
			{'coal',100},
		},
		result = 'wisp-purple',
		enabled = true },

	{ type = 'recipe',
		name = 'wisp-red',
		ingredients = {
			{'alien-flora-sample',100},
			{'stone',100},
		},
		result = 'wisp-red',
		enabled = true },

	{ type = 'recipe',
		name = 'UV-lamp',
		ingredients = {
			{'advanced-circuit', 1},
			{'iron-plate', 4},
			{'copper-cable', 8},
		},
		result = 'UV-lamp',
		enabled = true },

	{ type = 'recipe',
		name = 'wisp-detector',
		icon = '__Will-o-the-Wisps_updated__/graphics/icons/wisp-detector.png',
		icon_size = 32,
		energy_required = 1.0,
		ingredients = {
			{'constant-combinator', 1},
			{'advanced-circuit', 3},
			{'wood', 9},
			{'wisp-yellow', 3},
			{'wisp-red', 3},
			{'wisp-purple', 3},
		},
		result = 'wisp-detector',
		enabled = true },

}
