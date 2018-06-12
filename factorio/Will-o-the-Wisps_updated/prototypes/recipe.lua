data:extend{

	{ type = 'recipe',
		name = 'alien-flora-sample',
		energy_required = 14,
		ingredients = {
			{'stone', 20},
			{'raw-wood', 20},
			{'coal', 20},
		},
		result = 'alien-flora-sample',
		enabled = false },

	{ type = 'recipe',
		name = 'UV-lamp',
		energy_required = 3,
		ingredients = {
			{'small-lamp', 1},
			{'electronic-circuit', 5},
			{'iron-plate', 4},
			{'copper-cable', 4},
		},
		result = 'UV-lamp',
		enabled = false },

	{ type = 'recipe',
		name = 'wisp-detector',
		icon = '__Will-o-the-Wisps_updated__/graphics/icons/wisp-detector.png',
		icon_size = 32,
		energy_required = 10,
		ingredients = {
			{'constant-combinator', 1},
			{'advanced-circuit', 3},
			{'wood', 9},
			{'alien-flora-sample', 3},
		},
		result = 'wisp-detector',
		enabled = false },

	{ type = 'recipe',
		name = 'wisp-drone-blue-capsule',
		icon = '__Will-o-the-Wisps_updated__/graphics/icons/wisp-drone-blue.png',
		icon_size = 32,
		energy_required = 8,
		ingredients = {
			{'UV-lamp', 1},
			{'advanced-circuit', 1},
			{'alien-flora-sample', 1},
		},
		result = 'wisp-drone-blue-capsule',
		enabled = false },

	-- Legacy recipes that are never enabled
	{type='recipe', name='wisp-yellow', ingredients={}, result='wisp-yellow', enabled=false},
	{type='recipe', name='wisp-purple', ingredients={}, result='wisp-purple', enabled=false},
	{type='recipe', name='wisp-red', ingredients={}, result='wisp-red', enabled=false},

}
