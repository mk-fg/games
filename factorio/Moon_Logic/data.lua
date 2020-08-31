
local trans = {
  filename = '__Moon_Logic__/graphics/trans.png',
  width = 1,
  height = 1,
}
local con_point = {
  wire = {
	red = {0, 0},
	green = {0, 0},
  },
  shadow = {
	red = {0, 0},
	green = {0, 0},
  },
}


combinator = table.deepcopy(data.raw['constant-combinator']['constant-combinator'])
combinator.name = 'mlc'
combinator.item_slot_count = 500
combinator.minable = {mining_time = 0.5, result = 'mlc'}
combinator.additional_pastable_entities = {'mlc-sep'}
combinator.sprites = make_4way_animation_from_spritesheet({ layers =
	  {
		{
		  filename = '__Moon_Logic__/graphics/mlc.png',
		  width = 58,
		  height = 52,
		  frame_count = 1,
		  shift = util.by_pixel(0, 5),
		  hr_version =
		  {
			scale = 0.5,
			filename = '__Moon_Logic__/graphics/hr-mlc.png',
			width = 114,
			height = 102,
			frame_count = 1,
			shift = util.by_pixel(0, 5)
		  }
		},
		{
		  filename = '__base__/graphics/entity/combinator/constant-combinator-shadow.png',
		  width = 50,
		  height = 34,
		  frame_count = 1,
		  shift = util.by_pixel(9, 6),
		  draw_as_shadow = true,
		  hr_version =
		  {
			scale = 0.5,
			filename = '__base__/graphics/entity/combinator/hr-constant-combinator-shadow.png',
			width = 98,
			height = 66,
			frame_count = 1,
			shift = util.by_pixel(8.5, 5.5),
			draw_as_shadow = true
		  }
		}
	  }
	})


combinator2 = table.deepcopy(data.raw['arithmetic-combinator']['arithmetic-combinator'])
combinator2.name = 'mlc-sep'
combinator2.minable = {mining_time = 0.5, result = 'mlc-sep'}
combinator2.additional_pastable_entities = {'mlc'}
combinator2.energy_source = { type = 'void' }
combinator2.energy_usage_per_tick = '1W'

local combinator2_item = table.deepcopy(data.raw['item']['arithmetic-combinator'])
combinator2_item.name = combinator2.name
combinator2_item.place_result = combinator2.name
combinator2_item.subgroup = 'circuit-network'
combinator2_item.order = 'c[combinators]-db[mlc-sep]'



combinator_output = table.deepcopy(data.raw['constant-combinator']['constant-combinator'])
combinator_output.name = 'mlc-output'
combinator_output.item_slot_count = 500
combinator_output.minable = {mining_time = 0.5, result = 'mlc-output'}

combinator_output_item = table.deepcopy(data.raw['item']['constant-combinator'])
combinator_output_item.name = combinator_output.name
combinator_output_item.place_result = combinator_output.name
combinator_output_item.subgroup = 'circuit-network'
combinator_output_item.order = 'c[combinators]-dc[mlc-output]'


combinator_input = table.deepcopy(data.raw['lamp']['small-lamp'])
combinator_input.name = 'mlc-input'
combinator_input.minable = {mining_time = 0.5, result = 'mlc-input'}
combinator_input.energy_source = { type = 'void' }
combinator_input.energy_usage_per_tick = '1W'


combinator_input_item = table.deepcopy(data.raw['item']['small-lamp'])
combinator_input_item.name = combinator_input.name
combinator_input_item.place_result = combinator_input.name
combinator_input_item.subgroup = 'circuit-network'
combinator_input_item.order = 'c[combinators]-dd[mlc-input]'


data:extend({
  combinator,
  {
	type = 'item',
	name = 'mlc',
	icon_size = 64,
	icon = '__Moon_Logic__/graphics/mlc-icon.png',
	flags = {flag_quickbar},
	subgroup = 'circuit-network',
	order = 'c[combinators]-da[mlc]',
	place_result = 'mlc',
	stack_size = 50
  },

  combinator2, combinator2_item,
  {
	type = 'constant-combinator',
	name = 'mlc-proxy',
	flags = {'placeable-off-grid'},
	collision_mask = {},
	item_slot_count = 500,
	circuit_wire_max_distance = 3,
	sprites = {
	  north = trans,
	  east = trans,
	  south = trans,
	  west = trans,
	},
	activity_led_sprites = trans,
	activity_led_light_offsets = {{0, 0}, {0, 0}, {0, 0}, {0, 0}},

	circuit_wire_connection_points = {con_point, con_point, con_point, con_point},
	draw_circuit_wires = false,
  },

  combinator_output, combinator_output_item,
  combinator_input, combinator_input_item
})

require 'prototypes.recipes'
require 'prototypes.sprites'
require 'prototypes.technology'
require 'prototypes.signals'
