data:extend{

	{
		type = 'recipe',
		name = 'power-meter-combinator',
		energy_required = 2,
		ingredients =
		{
			{'constant-combinator', 1},
			{'electronic-circuit', 5}
		},
		result = 'power-meter-combinator',
		result_count = 1,
		enabled = false
	},

	{
		type = 'item',
		name = 'power-meter-combinator',
		icon = '__Circuit_Power_Measurement_Combinator__/graphics/power-meter-combinator-icon.png',
		icon_size = 32,
		subgroup = 'circuit-network',
		place_result = 'power-meter-combinator',
		order = 'd[other]-c[power-meter-combinator]',
		stack_size = 50
	},

	{
		type = 'constant-combinator',
		name = 'power-meter-combinator',
		icon = '__Circuit_Power_Measurement_Combinator__/graphics/power-meter-combinator-icon.png',
		icon_size = 32,
		flags = {'placeable-neutral', 'player-creation'},
		minable = {mining_time = 0.1, result = 'power-meter-combinator'},
		max_health = 120,
		corpse = 'small-remnants',

		collision_box = {{-0.35, -0.35}, {0.35, 0.35}},
		selection_box = {{-0.5, -0.5}, {0.5, 0.5}},
		item_slot_count = 18,
		vehicle_impact_sound =  {filename = '__base__/sound/car-metal-impact.ogg', volume = 0.65},

		activity_led_light = {intensity = 0.8, size = 1, color = {r = 1.0, g = 1.0, b = 1.0}},
		activity_led_light_offsets = {
			{0.296875, -0.40625}, {0.25, -0.03125},
			{-0.296875, -0.078125}, {-0.21875, -0.46875} },
		circuit_wire_max_distance = 9,

		sprites = make_4way_animation_from_spritesheet{ layers =
			{ { scale = 0.5,
					filename = '__Circuit_Power_Measurement_Combinator__/graphics/power-meter-combinator.png',
					width = 114,
					height = 102,
					frame_count = 1,
					shift = util.by_pixel(0, 5) },
				{ scale = 0.5,
					filename = '__base__/graphics/entity/combinator/hr-constant-combinator-shadow.png',
					width = 98,
					height = 66,
					frame_count = 1,
					shift = util.by_pixel(8.5, 5.5),
					draw_as_shadow = true } } },
		activity_led_sprites = {
			north = {
				scale = 0.5,
				filename = "__base__/graphics/entity/combinator/activity-leds/hr-constant-combinator-LED-N.png",
				width = 14,
				height = 12,
				frame_count = 1,
				shift = util.by_pixel(9, -11.5) },
			east = {
				scale = 0.5,
				filename = "__base__/graphics/entity/combinator/activity-leds/hr-constant-combinator-LED-E.png",
				width = 14,
				height = 14,
				frame_count = 1,
				shift = util.by_pixel(7.5, -0.5) },
			south = {
				scale = 0.5,
				filename = "__base__/graphics/entity/combinator/activity-leds/hr-constant-combinator-LED-S.png",
				width = 14,
				height = 16,
				frame_count = 1,
				shift = util.by_pixel(-9, 2.5) },
			west = {
				scale = 0.5,
				filename = "__base__/graphics/entity/combinator/activity-leds/hr-constant-combinator-LED-W.png",
				width = 14,
				height = 16,
				frame_count = 1,
				shift = util.by_pixel(-7, -15) } },
			circuit_wire_connection_points = {
				{ shadow = {red = util.by_pixel(7, -6), green = util.by_pixel(23, -6)},
					wire = {red = util.by_pixel(-8.5, -17.5), green = util.by_pixel(7, -17.5)} },
				{ shadow = {red = util.by_pixel(32, -5), green = util.by_pixel(32, 8)},
					wire = {red = util.by_pixel(16, -16.5), green = util.by_pixel(16, -3.5)} },
				{ shadow = {red = util.by_pixel(25, 20), green = util.by_pixel(9, 20)},
					wire = {red = util.by_pixel(9, 7.5), green = util.by_pixel(-6.5, 7.5) } },
				{ shadow = {red = util.by_pixel(1, 11), green = util.by_pixel(1, -2)},
					wire = {red = util.by_pixel(-15, -0.5), green = util.by_pixel(-15, -13.5)} } },
	},

}
