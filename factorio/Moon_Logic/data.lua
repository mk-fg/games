-- Actual visible combinator is "mlc", which uses arithmetic-combinator base
-- Invisible "mlc-core" constant-combinator gets created and connected to its output when placed
-- All signals are set on the invisible combinator, while arithmetic one is only used for reading inputs
-- XXX: make arithmetic combinator imitate work and maybe change icons and such

local mlc = table.deepcopy(data.raw['arithmetic-combinator']['arithmetic-combinator'])
mlc.name = 'mlc'
mlc.minable = {hardness=0.2, mining_time=0.2, result='mlc'}

-- XXX: new graphics

-- mlc.additional_pastable_entities = {'mlc-old'}
-- mlc.energy_source = { type = 'void' }
-- mlc.energy_usage_per_tick = '1W'

-- mlc.sprites = make_4way_animation_from_spritesheet{
-- 	layers = {
-- 		{ filename = '__Moon_Logic__/graphics/mlc.png',
-- 		  width = 58,
-- 		  height = 52,
-- 		  frame_count = 1,
-- 		  shift = util.by_pixel(0, 5),
-- 		  hr_version = {
-- 				scale = 0.5,
-- 				filename = '__Moon_Logic__/graphics/hr-mlc.png',
-- 				width = 114,
-- 				height = 102,
-- 				frame_count = 1,
-- 				shift = util.by_pixel(0, 5) } },
-- 		{ filename = '__base__/graphics/entity/combinator/constant-combinator-shadow.png',
-- 		  width = 50,
-- 		  height = 34,
-- 		  frame_count = 1,
-- 		  shift = util.by_pixel(9, 6),
-- 		  draw_as_shadow = true,
-- 		  hr_version = {
-- 				scale = 0.5,
-- 				filename = '__base__/graphics/entity/combinator/hr-constant-combinator-shadow.png',
-- 				width = 98,
-- 				height = 66,
-- 				frame_count = 1,
-- 				shift = util.by_pixel(8.5, 5.5),
-- 				draw_as_shadow = true } } } }

local invisible_sprite = {filename='__Moon_Logic__/graphics/invisible.png', width=1, height=1}
local wire_conn = {wire={red={0, 0}, green={0, 0}}, shadow={red={0, 0}, green={0, 0}}}

data:extend{

	-- Buildings
  mlc,
	{ type = 'constant-combinator',
		name = 'mlc-core',
		flags = {'placeable-off-grid'},
		collision_mask = {},
		item_slot_count = 500,
		circuit_wire_max_distance = 3,
		sprites = invisible_sprite,
		activity_led_sprites = invisible_sprite,
		activity_led_light_offsets = {{0, 0}, {0, 0}, {0, 0}, {0, 0}},
		circuit_wire_connection_points = {wire_conn, wire_conn, wire_conn, wire_conn},
		draw_circuit_wires = false },

	-- Item
  { type = 'item',
		name = 'mlc',
		icon_size = 64,
		icon = '__Moon_Logic__/graphics/mlc-icon.png', -- XXX: diff icon
		flags = {flag_quickbar},
		subgroup = 'circuit-network',
		order = 'c[combinators]-da[mlc]',
		place_result = 'mlc',
		stack_size = 50 },

	-- Recipe
	{ type = 'recipe',
		name = 'mlc',
		enabled = 'false',
		ingredients = {
			{'constant-combinator', 1},
			{'advanced-circuit', 5} },
		result = 'mlc' },

	-- Signal
	{ type = 'virtual-signal',
		name = 'mlc-error',
		special_signal = false,
		icon = '__Moon_Logic__/graphics/error-icon.png',
		icon_size = 64,
		subgroup = 'virtual-signal-special',
		order = 'e[signal]-[zzz-mlc-err]' },

	-- Technology
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

	-- Key bindings
	{ type = 'custom-input',
		name = 'mlc-code-undo',
		key_sequence = 'CONTROL + LEFT',
		order = '01' },
	{ type = 'custom-input',
		name = 'mlc-code-redo',
		key_sequence = 'CONTROL + RIGHT',
		order = '02' },
	{ type = 'custom-input',
		name = 'mlc-code-save',
		key_sequence = 'CONTROL + S',
		order = '03' },
	{ type = 'custom-input',
		name = 'mlc-code-commit',
		key_sequence = 'CONTROL + RETURN',
		order = '04' },
	{ type = 'custom-input',
		name = 'mlc-code-close',
		key_sequence = 'CONTROL + Q',
		order = '05' },

	-- GUI button sprites
	{ type = 'sprite',
		name = 'mlc-fwd',
		filename = '__Moon_Logic__/graphics/btn-fwd.png',
		priority = 'extra-high-no-scale',
		width = 32,
		height = 32,
		flags = {'no-crop', 'icon'},
		scale = 0.3 },
	{ type = 'sprite',
		name = 'mlc-back',
		filename = '__Moon_Logic__/graphics/btn-back.png',
		priority = 'extra-high-no-scale',
		width = 32,
		height = 32,
		flags = {'no-crop', 'icon'},
		scale = 0.3 },
	{ type = 'sprite',
		name = 'mlc-fwd-enabled',
		filename = '__Moon_Logic__/graphics/btn-fwd-enabled.png',
		priority = 'extra-high-no-scale',
		width = 32,
		height = 32,
		flags = {'no-crop', 'icon'},
		scale = 0.3 },
	{ type = 'sprite',
		name = 'mlc-back-enabled',
		filename = '__Moon_Logic__/graphics/btn-back-enabled.png',
		priority = 'extra-high-no-scale',
		width = 32,
		height = 32,
		flags = {'no-crop', 'icon'},
		scale = 0.3 },
	{ type = 'sprite',
		name = 'mlc-close',
		filename = '__Moon_Logic__/graphics/btn-close.png',
		priority = 'extra-high-no-scale',
		width = 20,
		height = 20,
		flags = {'no-crop', 'icon'},
		scale = 1 },
	{ type = 'sprite',
		name = 'mlc-help',
		filename = '__Moon_Logic__/graphics/btn-help.png',
		priority = 'extra-high-no-scale',
		width = 20,
		height = 20,
		flags = {'no-crop', 'icon'},
		scale = 1 },
	{ type = 'sprite',
		name = 'mlc-clear',
		filename = '__Moon_Logic__/graphics/btn-clear.png',
		priority = 'extra-high-no-scale',
		width = 20,
		height = 20,
		flags = {'no-crop', 'icon'},
		scale = 1 },

}
