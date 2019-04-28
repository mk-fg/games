data:extend{

	{
		type = 'recipe',
		name = 'circuit-electric-pole',
		energy_required = 2,
		ingredients =
		{
			{'small-electric-pole', 1},
			{'electronic-circuit', 3}
		},
		result = 'circuit-electric-pole',
		result_count = 1,
		enabled = false
	},

	{
		type = 'item',
		name = 'circuit-electric-pole',
		icon = '__Circuit_Power_Measurement_Pole__/graphics/circuit-electric-pole-icon.png',
		icon_size = 32,
		subgroup = 'circuit-network',
		place_result = 'circuit-electric-pole',
		order = 'd[other]-c[circuit-electric-pole]',
		stack_size = 50
	},

	{
		type = 'electric-pole',
		name = 'circuit-electric-pole',
		icon = '__base__/graphics/icons/small-electric-pole.png',
		icon_size = 32,
		flags = {'placeable-neutral', 'player-creation', 'fast-replaceable-no-build-while-moving'},
		minable = {mining_time = 0.1, result = 'circuit-electric-pole'},
		max_health = 100,
		corpse = 'small-remnants',
		collision_box = {{-0.15, -0.15}, {0.15, 0.15}},
		selection_box = {{-0.4, -0.4}, {0.4, 0.4}},
		drawing_box = {{-0.5, -2.6}, {0.5, 0.5}},
		maximum_wire_distance = 7.5,
		supply_area_distance = 2.5,
		vehicle_impact_sound =	{ filename = '__base__/sound/car-wood-impact.ogg', volume = 1.0 },
		track_coverage_during_build_by_moving = true,
		fast_replaceable_group = 'electric-pole',
		pictures =
		{
			layers =
			{
				{
					filename = '__base__/graphics/entity/small-electric-pole/small-electric-pole.png',
					priority = 'extra-high',
					width = 36,
					height = 108,
					direction_count = 4,
					shift = util.by_pixel(2, -42),
					hr_version =
					{
						filename = '__base__/graphics/entity/small-electric-pole/hr-small-electric-pole.png',
						priority = 'extra-high',
						width = 72,
						height = 220,
						direction_count = 4,
						shift = util.by_pixel(1.5, -42.5),
						scale = 0.5
					}
				},
				{
					filename = '__Circuit_Power_Measurement_Pole__/graphics/circuit-electric-pole.png',
					priority = 'extra-high',
					width = 36,
					height = 108,
					direction_count = 4,
					shift = util.by_pixel(2, -42),
					tint = {r=0.128, g=0.516, b=0.031, a=1},
					hr_version =
					{
						filename = '__Circuit_Power_Measurement_Pole__/graphics/hr-circuit-electric-pole.png',
						priority = 'extra-high',
						width = 72,
						height = 220,
						direction_count = 4,
						shift = util.by_pixel(1.5, -42.5),
						scale = 0.5,
						tint = {r=0.128, g=0.516, b=0.031, a=1},
					}
				},
				{
					filename = '__base__/graphics/entity/small-electric-pole/small-electric-pole-shadow.png',
					priority = 'extra-high',
					width = 130,
					height = 28,
					direction_count = 4,
					shift = util.by_pixel(50, 2),
					draw_as_shadow = true,
					hr_version =
					{
						filename = '__base__/graphics/entity/small-electric-pole/hr-small-electric-pole-shadow.png',
						priority = 'extra-high',
						width = 256,
						height = 52,
						direction_count = 4,
						shift = util.by_pixel(51, 3),
						draw_as_shadow = true,
						scale = 0.5
					}
				}
			}
		},
		connection_points =
		{
			{
				shadow =
				{
					copper = util.by_pixel(98.5, 2.5),
					red = util.by_pixel(111.0, 4.5),
					green = util.by_pixel(85.5, 4.0)
				},
				wire =
				{
					copper = util.by_pixel(0.0, -82.5),
					red = util.by_pixel(13.0, -81.0),
					green = util.by_pixel(-12.5, -81.0)
				}
			},
			{
				shadow =
				{
					copper = util.by_pixel(99.5, 4.0),
					red = util.by_pixel(110.0, 9.0),
					green = util.by_pixel(92.5, -4.0)
				},
				wire =
				{
					copper = util.by_pixel(1.5, -81.0),
					red = util.by_pixel(12.0, -76.0),
					green = util.by_pixel(-6.0, -89.5)
				}
			},
			{
				shadow =
				{
					copper = util.by_pixel(100.5, 5.5),
					red = util.by_pixel(102.5, 14.5),
					green = util.by_pixel(103.5, -3.5)
				},
				wire =
				{
					copper = util.by_pixel(2.5, -79.5),
					red = util.by_pixel(4.0, -71.0),
					green = util.by_pixel(5.0, -89.5)
				}
			},
			{
				shadow =
				{
					copper = util.by_pixel(98.5, -1.5),
					red = util.by_pixel(88.0, 3.5),
					green = util.by_pixel(106.0, -9.0)
				},
				wire =
				{
					copper = util.by_pixel(0.5, -86.5),
					red = util.by_pixel(-10.5, -81.5),
					green = util.by_pixel(8.0, -93.5)
				}
			}
		},
		radius_visualisation_picture =
		{
			filename = '__base__/graphics/entity/small-electric-pole/electric-pole-radius-visualization.png',
			width = 12,
			height = 12,
			priority = 'extra-high-no-scale'
		}
	},

}
