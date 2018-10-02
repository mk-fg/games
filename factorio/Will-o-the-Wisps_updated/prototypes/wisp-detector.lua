data:extend{{

	type = 'constant-combinator',
	name = 'wisp-detector',
	icon = '__Will-o-the-Wisps_updated__/graphics/icons/wisp-detector.png',
	icon_size = 32,
	flags = {'placeable-neutral', 'player-creation'},
	minable = {hardness = 0.2, mining_time = 0.5, result = 'wisp-detector'},
	max_health = 90,
	corpse = 'small-remnants',
	collision_box = {{-0.35, -0.35}, {0.35, 0.35}},
	selection_box = {{-0.5, -0.5}, {0.5, 0.5}},
	item_slot_count = 18,
	vehicle_impact_sound = {filename='__base__/sound/car-metal-impact.ogg', volume=0.65},

	sprites = {
		north = {
			layers = {
				{ filename = '__Will-o-the-Wisps_updated__/graphics/entity/wisp-detector/wisp-detector.png',
					width = 58,
					height = 52,
					frame_count = 1,
					shift = util.by_pixel(0, 0),
					x = 0 },
				{ filename = '__Will-o-the-Wisps_updated__/graphics/entity/wisp-detector/wisp-detector-shadow.png',
					draw_as_shadow = true,
					frame_count = 1,
					width = 50,
					height = 34,
					priority = 'high',
					scale = 1,
					shift = util.by_pixel(9, 6),
					x = 0 },
			}
		},
		east = {
			layers = {
				{ filename = '__Will-o-the-Wisps_updated__/graphics/entity/wisp-detector/wisp-detector.png',
					frame_count = 1,
					width = 58,
					height = 52,
					priority = 'high',
					scale = 1,
					shift = util.by_pixel(0, 0),
					x = 58 },
				{ filename = '__Will-o-the-Wisps_updated__/graphics/entity/wisp-detector/wisp-detector-shadow.png',
					draw_as_shadow = true,
					frame_count = 1,
					width = 50,
					height = 34,
					priority = 'high',
					scale = 1,
					shift = util.by_pixel(9, 6),
					x = 50 },
			}
		},
		south = {
			layers = {
				{ filename = '__Will-o-the-Wisps_updated__/graphics/entity/wisp-detector/wisp-detector.png',
					frame_count = 1,
					width = 58,
					height = 52,
					priority = 'high',
					scale = 1,
					shift = util.by_pixel(0, 0),
					x = 116 },
				{ filename = '__Will-o-the-Wisps_updated__/graphics/entity/wisp-detector/wisp-detector-shadow.png',
					draw_as_shadow = true,
					frame_count = 1,
					width = 50,
					height = 34,
					priority = 'high',
					scale = 1,
					shift = util.by_pixel(9, 6),
					x = 100 },
			}
		},
		west = {
			layers = {
				{ filename = '__Will-o-the-Wisps_updated__/graphics/entity/wisp-detector/wisp-detector.png',
					frame_count = 1,
					width = 58,
					height = 52,
					priority = 'high',
					scale = 1,
					shift = util.by_pixel(0, 0),
					x = 174 },
				{ filename = '__Will-o-the-Wisps_updated__/graphics/entity/wisp-detector/wisp-detector-shadow.png',
					draw_as_shadow = true,
					frame_count = 1,
					width = 50,
					height = 34,
					priority = 'high',
					scale = 1,
					shift = util.by_pixel(9, 6),
					x = 150 },
			}
		}
	},

	activity_led_light = {
		color = {r=1, g=1, b=1},
		intensity = 0.8,
		size = 1,
	},
	activity_led_light_offsets = {
		{0.296875, -0.40625}, {0.25, -0.03125},
		{-0.296875, -0.078125}, {-0.21875, -0.46875} },
	activity_led_sprites = {
		east = {
			filename = '__Will-o-the-Wisps_updated__/graphics/entity/wisp-detector/wisp-detector-LED-E.png',
			frame_count = 1,
			height = 8,
			shift = {0.25, 0},
			width = 8,
		},
		north = {
			filename = '__Will-o-the-Wisps_updated__/graphics/entity/wisp-detector/wisp-detector-LED-N.png',
			frame_count = 1,
			height = 6,
			shift = {0.28125, -0.375},
			width = 8,
		},
		south = {
			filename = '__Will-o-the-Wisps_updated__/graphics/entity/wisp-detector/wisp-detector-LED-S.png',
			frame_count = 1,
			height = 8,
			shift = {-0.28125, 0.0625},
			width = 8,
		},
		west = {
			filename = '__Will-o-the-Wisps_updated__/graphics/entity/wisp-detector/wisp-detector-LED-W.png',
			frame_count = 1,
			height = 8,
			shift = {-0.21875, -0.46875},
			width = 8,
		},
	},

	circuit_wire_connection_points = {
		{ shadow = {
				green = {0.71875,-0.1875},
				red = {0.21875,-0.1875} },
			wire = {
				green = {0.21875,-0.546875},
				red = {-0.265625,-0.546875} } },
		{ shadow = {
				green = {1,0.25},
				red = {1,-0.15625} },
			wire = {
				green = {0.5,-0.109375},
				red = {0.5,-0.515625} } },
		{ shadow = {
				green = {0.28125,0.625},
				red = {0.78125,0.625} },
			wire = {
				green = {-0.203125,0.234375},
				red = {0.28125,0.234375} } },
		{ shadow = {
				green = {0.03125,-0.0625},
				red = {0.03125,0.34375}},
			wire = {
				green = {-0.46875,-0.421875},
				red = {-0.46875,-0.015625} } },
	},
	circuit_wire_max_distance = 12,

}}
