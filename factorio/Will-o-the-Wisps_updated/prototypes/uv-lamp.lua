local hit_effects = require('__base__/prototypes/entity/hit-effects')
local sounds = require('__base__/prototypes/entity/sounds')

-- Regular lamp: light={ intensity=0.9 size=40 } colored={ intensity=1 size=6 }
local uv_light = {intensity=0.3, size=5, color={r=0.8, g=0.1, b=0.9, a=0.2}}

data:extend{{

	type = 'lamp',
	name = 'UV-lamp',
	icon = '__Will-o-the-Wisps_updated__/graphics/icons/uv-lamp.png',
	icon_size = 32,
	flags = {'placeable-neutral', 'player-creation'},
	minable = {hardness = 0.2, mining_time = 0.5, result = 'UV-lamp'},
	max_health = 80,
	collision_box = {{-0.15, -0.15}, {0.15, 0.15}},
	selection_box = {{-0.5, -0.5}, {0.5, 0.5}},

	corpse = 'lamp-remnants',
	dying_explosion = 'lamp-explosion',
	damaged_trigger_effect = hit_effects.entity(),
	vehicle_impact_sound = sounds.generic_impact,
	open_sound = sounds.machine_open,
	close_sound = sounds.machine_close,
	working_sound = {
		sound = {
			filename = '__Will-o-the-Wisps_updated__/sound/lamp-working.ogg',
			volume = 0.4 },
		max_sounds_per_type = 3,
		use_doppler_shift = false,
		audible_distance_modifier = 0.5 },

	energy_usage_per_tick = '160kW', -- lamp = 5kW
	energy_source = {
		type = 'electric',
		usage_priority = 'secondary-input',
		buffer_capacity = '320kJ',
		input_flow_limit = '320kW',
	},

	light = uv_light,
	light_when_colored = uv_light,
	glow_size = 6,
	glow_color_intensity = 0.13500000000000001,

	darkness_for_all_lamps_off = 0.2,
	darkness_for_all_lamps_on = 0.5,

	signal_to_color_mapping = {},

	picture_off = {
		filename = '__Will-o-the-Wisps_updated__/graphics/entity/uv-lamp/uv-lamp.png',
		axially_symmetrical = false,
		direction_count = 1,
		frame_count = 1,
		width = 67,
		height = 58,
		priority = 'high',
		shift = util.by_pixel(0, 5),
	},
	picture_on = {
		axially_symmetrical = false,
		direction_count = 1,
		filename = '__Will-o-the-Wisps_updated__/graphics/entity/uv-lamp/uv-lamp-light.png',
		frame_count = 1,
		width = 62,
		height = 62,
		priority = 'high',
		shift = util.by_pixel(-0.5, -1),
	},

	circuit_wire_connection_point = circuit_connector_definitions.lamp.points,
	circuit_connector_sprites = circuit_connector_definitions.lamp.sprites,
	circuit_wire_max_distance = 9,

}}
