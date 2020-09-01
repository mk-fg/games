data:extend{

	{ type = 'technology',
		name = 'mlc',
		icon_size = 144,
		icon = '__Moon_Logic__/graphics/tech.png',
		effects={{type='unlock-recipe', recipe='mlc'}},
		prerequisites = {'circuit-network', 'advanced-electronics'},
		unit = {
		  count = 100,
		  ingredients = {
				{'automation-science-pack', 1},
				{'logistic-science-pack', 1} },
		  time = 15 },
		order = 'a-d-d-z' },

}
