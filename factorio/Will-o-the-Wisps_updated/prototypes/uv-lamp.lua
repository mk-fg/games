-- Regular lamp: light={ intensity=0.9 size=40 } colored={ intensity=1 size=6 }
local uv_light = {intensity=0.3, size=5, color={r=0.8, g=0.1, b=0.9, a=0.2}}
local function shift(dx, dy) return {dx / 64, dy / 64} end

data:extend{{

	type = 'lamp',
	name = 'UV-lamp',
	icon = '__Will-o-the-Wisps_updated__/graphics/icons/uv-lamp.png',
	icon_size = 32,
	flags = {'placeable-neutral', 'player-creation'},
	minable = {hardness = 0.2, mining_time = 0.5, result = 'UV-lamp'},
	max_health = 80,
	corpse = 'small-remnants',
	collision_box = {{-0.15, -0.15}, {0.15, 0.15}},
	selection_box = {{-0.5, -0.5}, {0.5, 0.5}},
	vehicle_impact_sound = {filename='__base__/sound/car-metal-impact.ogg', volume=0.65},

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
		shift = {0, 0},
	},
	picture_on = {
		axially_symmetrical = false,
		direction_count = 1,
		filename = '__Will-o-the-Wisps_updated__/graphics/entity/uv-lamp/uv-lamp-light.png',
		frame_count = 1,
		width = 62,
		height = 62,
		priority = 'high',
		shift = {-0.015625,-0.1875},
	},

	circuit_connector_sprites = {
		blue_led_light_offset = shift(11, 28),
		red_green_led_light_offset = shift(10, 21),
		led_light = {intensity = 0.8, size = 0.9},
		led_blue = {
			filename = '__base__/graphics/entity/circuit-connector/hr-ccm-universal-04e-blue-LED-on-sequence.png',
			width = 60,
			height = 60,
			priority = 'low',
			scale = 0.5,
			shift = shift(9, 9),
			x = 120,
			y = 180,
		},
		led_blue_off = {
			filename = '__base__/graphics/entity/circuit-connector/hr-ccm-universal-04f-blue-LED-off-sequence.png',
			width = 46,
			height = 44,
			priority = 'low',
			scale = 0.5,
			shift = shift(9, 9),
			x = 92,
			y = 132,
		},
		led_green = {
			filename = '__base__/graphics/entity/circuit-connector/hr-ccm-universal-04h-green-LED-sequence.png',
			width = 48,
			height = 46,
			priority = 'low',
			scale = 0.5,
			shift = shift(9, 9),
			x = 96,
			y = 138,
		},
		led_red = {
			filename = '__base__/graphics/entity/circuit-connector/hr-ccm-universal-04i-red-LED-sequence.png',
			width = 48,
			height = 46,
			priority = 'low',
			scale = 0.5,
			shift = shift(9, 9),
			x = 96,
			y = 138,
		},
		connector_main = {
			filename = '__base__/graphics/entity/circuit-connector/hr-ccm-universal-04a-base-sequence.png',
			width = 52,
			height = 50,
			priority = 'low',
			scale = 0.5,
			shift = shift(9, 11),
			x = 104,
			y = 150,
		},
		connector_shadow = {
			draw_as_shadow = true,
			filename = '__base__/graphics/entity/circuit-connector/hr-ccm-universal-04b-base-shadow-sequence.png',
			width = 62,
			height = 46,
			priority = 'low',
			scale = 0.5,
			shift = shift(12, 14),
			x = 124,
			y = 138,
		},
		wire_pins = {
			filename = '__base__/graphics/entity/circuit-connector/hr-ccm-universal-04c-wire-sequence.png',
			width = 62,
			height = 58,
			priority = 'low',
			scale = 0.5,
			shift = shift(9, 9),
			x = 124,
			y = 174,
		},
		wire_pins_shadow = {
			draw_as_shadow = true,
			filename = '__base__/graphics/entity/circuit-connector/hr-ccm-universal-04d-wire-shadow-sequence.png',
			width = 70,
			height = 56,
			priority = 'low',
			scale = 0.5,
			shift = shift(19, 17),
			x = 140,
			y = 168,
		}
	},

	circuit_wire_connection_point = {
		shadow = {
			green = shift(34, 33),
			red = shift(49, 30) },
		wire = {
			green = shift(31, 27),
			red = shift(28, 12) } },
	circuit_wire_max_distance = 9,

}}
