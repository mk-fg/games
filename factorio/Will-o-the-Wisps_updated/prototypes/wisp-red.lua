data:extend{{

	type = 'unit',
	name = 'wisp-red',
	icon = '__Will-o-the-Wisps_updated__/graphics/icons/wisp-red-capsule.png',
	icon_size = 32,
	flags = {'placeable-player', 'placeable-enemy', 'placeable-off-grid', 'breaths-air', 'not-repairable'},
	subgroup='enemies',
	max_health = 30,
	alert_when_damaged = false,
	order='b-b-c',
	resistances = {
		{type='physical', decrease=3},
		{type='fire', percent=50},
		{type='acid', percent=100} },
	collision_box = {{0, 0}, {0, 0}},
	selection_box = {{-0.3, -0.3}, {0.3, 0.3}},
	sticker_box = {{-0.1, -0.1}, {0.1, 0.1}},
	dying_explosion = 'blood-explosion-small',

	distraction_cooldown = 300,
	vision_distance = 30,
	movement_speed = 0.09,
	distance_per_frame = 0.2,
	pollution_to_join_attack = 5000,
	healing_per_tick = 0.01,

	move_while_shooting = true,
	affected_by_tiles = false,
	has_belt_immunity = true,

	working_sound = {
		sound = {
			{ filename = '__Will-o-the-Wisps_updated__/sound/wisp-2.ogg', volume = 0.5 },
			{ filename = '__Will-o-the-Wisps_updated__/sound/wisp-4.ogg', volume = 0.6 }
		},
		max_sounds_per_type = 2,
		audible_distance_modifier = 0.6,
		probability = 1 / (11 * 60) },
	dying_sound = {
		{ filename = '__Will-o-the-Wisps_updated__/sound/wisp-5.ogg', volume = 0.4 },
		{ filename = '__Will-o-the-Wisps_updated__/sound/wisp-6.ogg', volume = 0.3 }
	},

	attack_parameters = {
		type = 'beam',
		ammo_category = 'beam',
		cooldown = 20,
		range = 3,
		min_attack_distance = 3,
		ammo_type = {
			category = 'beam',
			action = {
				type = 'direct',
				action_delivery = {
					type = 'beam',
					beam = 'wisp-beam-red',
					max_length = 5,
					duration = 200,
					source_offset = {0.0, 0.0} } } },
		animation = {
			layers = {
				{ filename = '__Will-o-the-Wisps_updated__/graphics/entity/wisps/wisp-red-attack.png',
					priority = 'high',
					width = 158,
					height = 158,
					frame_count = 2,
					direction_count = 1,
					animation_speed = 0.7,
					scale = 0.7 },
			}
		}
	},

	run_animation = {
		layers = {
			{ filename = '__Will-o-the-Wisps_updated__/graphics/entity/wisps/wisp-red.png',
				priority = 'high',
				width = 158,
				height = 158,
				frame_count = 2,
				direction_count = 1,
				animation_speed = 0.7,
				scale = 0.4 },
		}
	},

}}
