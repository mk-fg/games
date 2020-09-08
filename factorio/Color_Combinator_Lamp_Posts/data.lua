local hit_effects = require('__base__/prototypes/entity/demo-hit-effects')
local sounds = require('__base__/prototypes/entity/demo-sounds')

local function png(name) return ('__Color_Combinator_Lamp_Posts__/art/%s.png'):format(name) end


-- Klonan's Expanded Color Lamps settings

local conf, extra_colors = settings.startup

if conf['cclp-add-extra-colors'].value then
	local function RGB(r,g,b) return {r = r/255, g = g/255, b = b/255} end
	local lamp = data.raw.lamp['small-lamp']

	data:extend{
		{ type = 'item-subgroup',
			name = 'virtual-signal-color-extra',
			group = 'signals',
			order = 'dz' } }

	extra_colors = table.deepcopy(lamp.signal_to_color_mapping)
	for n, sig in ipairs{
			-- Non-default mappings for default signals
			{type='virtual', name='signal-white', color = RGB(255, 255, 255)},
			{type='virtual', name='signal-grey', color = RGB(136, 136, 136)},
			{type='virtual', name='signal-black', color = RGB(34, 34, 34)},

			-- Mappings for new signals
			{type='virtual', name='signal-light-grey', color = RGB(228, 228, 228)},
			{type='virtual', name='signal-orange', color = RGB(229, 149, 0)},
			{type='virtual', name='signal-brown', color = RGB(160, 106, 66)},
			{type='virtual', name='signal-light-green', color = RGB(148, 224, 68)},
			{type='virtual', name='signal-light-blue', color = RGB(0, 131, 199)},
			{type='virtual', name='signal-light-purple', color = RGB(207, 110, 228)},
			{type='virtual', name='signal-dark-purple', color = RGB(130, 0, 128)} } do
		table.insert(extra_colors, sig)
		if data.raw['virtual-signal'][sig.name] then goto skip end
		data:extend{
			{ type = 'virtual-signal',
				name = sig.name,
				icons = {{icon='__base__/graphics/icons/signal/signal_grey.png', tint=sig.color}},
				icon_size = 64, icon_mipmaps = 4,
				subgroup = 'virtual-signal-color-extra',
				order = ('dz[colors]-[%02d%s]'):format(n, sig.name) } }
	::skip:: end

	-- Add extra colors to regular lamps as well
	lamp.signal_to_color_mapping = extra_colors
end


-- Entities

local cclp = table.deepcopy(data.raw.lamp['small-lamp'])

cclp.name = 'cclp'
cclp.icon = png('cclp-icon')
cclp.icon_mipmaps = 1
cclp.minable = {mining_time = 0.1, result = 'cclp'}
cclp.energy_usage_per_tick = '2KW'

-- Should be force-enabled via combinator anyway
cclp.darkness_for_all_lamps_on = 1
cclp.darkness_for_all_lamps_off = 0

-- cclp.corpse = 'lamp-remnants'
-- cclp.dying_explosion = 'lamp-explosion'

cclp.picture_off = {layers = {
	{ filename = png('cclp'),
		priority = 'high',
		width = 83,
		height = 139,
		frame_count = 1,
		axially_symmetrical = false,
		direction_count = 1,
		shift = util.by_pixel(0.25, -11),
		scale = 0.3 },
	{ filename = png('cclp-shadow'),
		priority = 'high',
		width = 197,
		height = 67,
		frame_count = 1,
		axially_symmetrical = false,
		direction_count = 1,
		shift = util.by_pixel(19, 0),
		draw_as_shadow = true,
		scale = 0.3 } }}

cclp.picture_on =
	{ filename = png('cclp-light'),
		priority = 'high',
		width = 90,
		height = 78,
		frame_count = 1,
		axially_symmetrical = false,
		direction_count = 1,
		shift = util.by_pixel(0, -27.5),
		scale = 0.3 }

local cclp_wire_shadow = util.by_pixel(32, 5)
cclp.circuit_wire_connection_point = {
	wire={red=util.by_pixel(9.5, -18.5), green=util.by_pixel(6.5, -16.5)},
	shadow={red=cclp_wire_shadow, green=cclp_wire_shadow} }
cclp.circuit_connector_sprites = nil
cclp.circuit_wire_max_distance = 6

-- Color/intensity/radius settings
local cclp_r, cclp_v = conf['cclp-glow-radius'].value, conf['cclp-glow-intensity'].value
cclp.light = {intensity=cclp_v, size=cclp_r, color={r=1.0, g=1.0, b=1.0}}
cclp.light_when_colored = {intensity=cclp_v, size=cclp_r, color={r=1.0, g=1.0, b=1.0}}
cclp.glow_size, cclp.glow_color_intensity = cclp_r, conf['cclp-color-intensity'].value
cclp.glow_render_mode = 'additive' -- additive or multiplicative
if extra_colors then cclp.signal_to_color_mapping = extra_colors end

data:extend{cclp}


do -- cclp-core hidden combinator, includes item to be copied to blueprints
	local invisible_sprite = {filename=png('invisible'), width=1, height=1}
	local wire_conn = cclp.circuit_wire_connection_point
	data:extend{

		{ type = 'constant-combinator',
			name = 'cclp-core',
			icon = png('cclp-core-icon'),
			icon_size = 64,
			flags = {'placeable-neutral', 'player-creation', 'placeable-off-grid', 'hide-alt-info'},
			selectable_in_game = false,
			collision_mask = {'layer-11'},
			item_slot_count = 1,
			circuit_wire_max_distance = 3,
			sprites = invisible_sprite,
			activity_led_sprites = invisible_sprite,
			activity_led_light_offsets = {{0, 0}, {0, 0}, {0, 0}, {0, 0}},
			circuit_wire_connection_points = {wire_conn, wire_conn, wire_conn, wire_conn},
			draw_circuit_wires = false },

		{ type = 'item',
			name = 'cclp-core',
			icon = png('cclp-core-icon'),
			icon_size = 64,
			subgroup = 'circuit-network',
			order = 'zzzzzzz',
			place_result = 'cclp-core',
			stack_size = 50,
			flags = {'hidden'} } }
end


-- Recipes/items/tech

data:extend{
	{ type = 'recipe',
		name = 'cclp',
		enabled = false,
		ingredients = {
			{'constant-combinator', 1},
			{'small-lamp', 1},
			{'copper-cable', 2}
		},
		result = 'cclp' },

	{ type = 'item',
		name = 'cclp',
		icon = png('cclp-icon'),
		icon_size = 64,
		subgroup = 'circuit-network',
		order = 'a[light]-b[cclp]',
		place_result = 'cclp',
		stack_size = 50 },

	{ type = 'technology',
		name = 'cclp',
		icon_size = 128,
		icon = png('tech'),
		effects={{type='unlock-recipe', recipe='cclp'}},
		prerequisites = {'optics', 'circuit-network'},
		unit = {
		  count = 40,
		  ingredients = {
				{'automation-science-pack', 1},
				{'logistic-science-pack', 1} },
		  time = 15 },
		order = 'a-d-d-z' },
}
