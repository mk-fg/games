
mlc = table.deepcopy(data.raw['constant-combinator']['constant-combinator'])
mlc.name = 'mlc'
mlc.item_slot_count = 50
mlc.minable = {hardness = 0.2, mining_time = 0.2, result = 'mlc'}
mlc.sprites = make_4way_animation_from_spritesheet{
	layers = {
		{ filename = '__Moon_Logic__/graphics/mlc.png',
		  width = 58,
		  height = 52,
		  frame_count = 1,
		  shift = util.by_pixel(0, 5),
		  hr_version = {
				scale = 0.5,
				filename = '__Moon_Logic__/graphics/hr-mlc.png',
				width = 114,
				height = 102,
				frame_count = 1,
				shift = util.by_pixel(0, 5) } },
		{ filename = '__base__/graphics/entity/combinator/constant-combinator-shadow.png',
		  width = 50,
		  height = 34,
		  frame_count = 1,
		  shift = util.by_pixel(9, 6),
		  draw_as_shadow = true,
		  hr_version = {
				scale = 0.5,
				filename = '__base__/graphics/entity/combinator/hr-constant-combinator-shadow.png',
				width = 98,
				height = 66,
				frame_count = 1,
				shift = util.by_pixel(8.5, 5.5),
				draw_as_shadow = true } } } }

data:extend{
  mlc,
  { type = 'item',
		name = 'mlc',
		icon_size = 64,
		icon = '__Moon_Logic__/graphics/mlc-icon.png',
		flags = {flag_quickbar},
		subgroup = 'circuit-network',
		order = 'c[combinators]-da[mlc]',
		place_result = 'mlc',
		stack_size = 50 },
}


data:extend{
	{ type = 'custom-input',
		name = 'mlc-code-save',
		key_sequence = 'CONTROL + S' },
	{ type = 'custom-input',
		name = 'mlc-code-undo',
		key_sequence = 'CONTROL + Z' },
	{ type = 'custom-input',
		name = 'mlc-code-redo',
		key_sequence = 'CONTROL + SHIFT + Z' },
	{ type = 'custom-input',
		name = 'mlc-code-commit',
		key_sequence = 'CONTROL + RETURN' },
}


require('prototypes.recipes')
require('prototypes.sprites')
require('prototypes.technology')
require('prototypes.signals')
