data:extend(
{
		{
				type = 'technology',
				name = 'alien-bio-technology',
				icon = '__Will-o-the-Wisps_updated__/graphics/technology/alien-bio-technology.png',
				icon_size = 128,
				prerequisites = {'laser'},
				unit =
				{
						count = 300,
						ingredients =
						{
								{'science-pack-1', 1},
								{'science-pack-2', 1}
						},
				time = 30
				},
				effects =
				{
				{
					type = 'unlock-recipe',
					recipe = 'alien-flora-sample'
				},
				{
					type = 'unlock-recipe',
					recipe = 'wisp-yellow'
				},
				{
					type = 'unlock-recipe',
					recipe = 'wisp-red'
				},
				{
					type = 'unlock-recipe',
					recipe = 'wisp-purple'
				},
				{
					type = 'unlock-recipe',
					recipe = 'wisp-detector'
				}
				},
				order = 'e-f'
		}
}
)
