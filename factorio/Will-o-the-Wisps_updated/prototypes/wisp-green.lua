data:extend{{

	type = 'unit',
	name = 'wisp-green',
	icon = '__Will-o-the-Wisps_updated__/graphics/icons/wisp-green-capsule.png',
	icon_size = 32,
	flags = {'placeable-player', 'placeable-enemy', 'placeable-off-grid', 'breaths-air', 'not-repairable'},
	subgroup='enemies',
	max_health = 20,
	alert_when_damaged = false,
	order='b-b-c',
	resistances = {
		{ type = 'acid', percent = 100 },
	},
	healing_per_tick = 0.01,
	collision_box = {{0, 0}, {0, 0}},
	selection_box = {{-0.3, -0.3}, {0.3, 0.3}},
	sticker_box = {{-0.1, -0.1}, {0.1, 0.1}},
	distraction_cooldown = 60,
	vision_distance = 20,
	movement_speed = 0.12,
	distance_per_frame = 0.1,
	pollution_to_join_attack = 9000,
	dying_explosion = 'blood-explosion-small',

	working_sound = {
		sound = {
			{filename='__Will-o-the-Wisps_updated__/sound/wisp-1.ogg', volume=0.6},
			{filename='__Will-o-the-Wisps_updated__/sound/wisp-3.ogg', volume=0.6},
		},
		max_sounds_per_type = 2,
		audible_distance_modifier = 0.6,
		probability = 1 / (11 * 60)
	},

	dying_sound = {
		{filename='__Will-o-the-Wisps_updated__/sound/wisp-5.ogg', volume=0.4},
		{filename='__Will-o-the-Wisps_updated__/sound/wisp-6.ogg', volume=0.3},
	},

	attack_parameters = {
		type = 'projectile',
		range = 0.5,
		cooldown = 35,
		ammo_category = 'melee',
		ammo_type = {
			category = 'melee',
			target_type = 'entity',
			action = {
				type = 'direct',
				action_delivery = {
					type = 'instant',
					target_effects = {{type = 'create-entity', entity_name = 'wisp-null-effect'}} } } },
		animation = {
			filename = '__Will-o-the-Wisps_updated__/graphics/entity/wisps/wisp-green-attack.png',
			priority = 'high',
			width = 158,
			height = 158,
			frame_count = 2,
			direction_count = 1,
			animation_speed = 0.5,
			scale = 0.3 },
	},

	run_animation = {
		layers = {
			{ filename = '__Will-o-the-Wisps_updated__/graphics/entity/wisps/wisp-green.png',
				priority = 'high',
				width = 158,
				height = 158,
				still_frame = 3,
				frame_count = 2,
				direction_count = 1,
				animation_speed = 0.5,
				scale = 0.2 }
		},
	},

}}
