data:extend({
		{
				type = 'recipe',
				name = 'alien-flora-sample',
				enabled = true,
				ingredients =
				{
						{'stone',100},
						{'raw-wood',100},
						{'coal',100},
		},
		result = 'alien-flora-sample',
				enabled = 'false'
	},
		{
				type = 'recipe',
				name = 'wisp-yellow',
				enabled = true,
				ingredients =
				{
						{'alien-flora-sample',100},
						{'raw-wood',100}
		},
		result = 'wisp-yellow',
				enabled = 'false'
	},
		{
				type = 'recipe',
				name = 'wisp-purple',
				enabled = true,
				ingredients =
				{
						{'alien-flora-sample',100},
						{'coal',100}
		},
		result = 'wisp-purple',
				enabled = 'false'
	},
		{
				type = 'recipe',
				name = 'wisp-red',
				enabled = true,
				ingredients =
				{
						{'alien-flora-sample',100},
						{'stone',100}
		},
		result = 'wisp-red',
				enabled = 'false'
	},
		{
				type = 'recipe',
				name = 'UV-lamp',
				enabled = true,
				ingredients =
				{
						{'advanced-circuit', 1},
						{'iron-plate', 4},
						{'copper-cable', 8}
				},
				result = 'UV-lamp',
				enabled = 'false'
		},
		{
				type = 'recipe',
				name = 'wisp-detector',
				icon = '__Will-o-the-Wisps_updated__/graphics/icons/wisp-detector.png',
				icon_size = 32,
				energy_required = 1.0,
				enabled = 'false',
				ingredients =
				{
						{'constant-combinator', 1},
						{'advanced-circuit', 3},
						{'wood', 9},
						{'wisp-yellow', 3},
						{'wisp-red', 3},
						{'wisp-purple', 3}
				},
				result = 'wisp-detector',
				enabled = 'false'
		}

})
