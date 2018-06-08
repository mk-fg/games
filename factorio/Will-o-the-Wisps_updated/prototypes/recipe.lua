data:extend{

	{ type = 'recipe',
		name = 'alien-flora-sample',
		ingredients = {
			{'stone',1},
			{'raw-wood',1},
			{'coal',1},
		},
		result = 'alien-flora-sample',
		enabled = false },

	{ type = 'recipe',
		name = 'wisp-yellow',
		ingredients = {
			{'alien-flora-sample',20},
			{'raw-wood',20},
		},
		result = 'wisp-yellow',
		enabled = false },

	{ type = 'recipe',
		name = 'wisp-purple',
		ingredients = {
			{'alien-flora-sample',20},
			{'coal',20},
		},
		result = 'wisp-purple',
		enabled = false },

	{ type = 'recipe',
		name = 'wisp-red',
		ingredients = {
			{'alien-flora-sample',20},
			{'stone',20},
		},
		result = 'wisp-red',
		enabled = false },

	{ type = 'recipe',
		name = 'UV-lamp',
		ingredients = {
			{'advanced-circuit', 1},
			{'iron-plate', 4},
			{'copper-cable', 8},
		},
		result = 'UV-lamp',
		enabled = false },

	{ type = 'recipe',
		name = 'wisp-detector',
		icon = '__Will-o-the-Wisps_updated__/graphics/icons/wisp-detector.png',
		icon_size = 32,
		energy_required = 1.0,
		ingredients = {
			{'constant-combinator', 1},
			{'advanced-circuit', 3},
			{'wood', 9},
			{'wisp-yellow', 1},
			{'wisp-red', 1},
			{'wisp-purple', 1},
		},
		result = 'wisp-detector',
		enabled = false },

}
