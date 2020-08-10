local hit_effects = require('__base__/prototypes/entity/demo-hit-effects')
local sounds = require('__base__/prototypes/entity/demo-sounds')

data:extend{

	{
		type = 'recipe',
		name = 'sentinel-combinator',
		energy_required = 2,
		ingredients =
		{
			{'constant-combinator', 1},
			{'electronic-circuit', 5}
		},
		result = 'sentinel-combinator',
		result_count = 1,
		enabled = false
	},

	{
		type = 'item',
		name = 'sentinel-combinator',
		icon = '__Biter_Detector_Sentinel_Combinator__/art/sentinel-combinator-icon.png',
		icon_size = 64,
		subgroup = 'circuit-network',
		place_result = 'sentinel-combinator',
		order = 'd[other]-c[sentinel-combinator]',
		stack_size = 50
	},

	{
		type = 'constant-combinator',
		name = 'sentinel-combinator',
		icon = '__Biter_Detector_Sentinel_Combinator__/art/sentinel-combinator-icon.png',
		icon_size = 64,
		flags = {'placeable-neutral', 'player-creation'},
		minable = {mining_time = 0.1, result = 'sentinel-combinator'},
		damaged_trigger_effect = hit_effects.entity(),
		max_health = 120,
		corpse = 'small-remnants',
		resistances = { {type = 'fire', percent = 50}, {type = 'impact', percent = 10} },
		collision_box = {{-0.25, -0.25}, {0.25, 0.25}},
		selection_box = {{-0.5, -0.5}, {0.5, 0.5}},

		item_slot_count = 18,
		circuit_wire_max_distance = 12,
		vehicle_impact_sound = sounds.generic_impact,

		sprites = make_4way_animation_from_spritesheet{ layers = {
			{ filename = '__Biter_Detector_Sentinel_Combinator__/art/sentinel-combinator.png',
				frame_count = 1,
				scale = 0.5,
				width = 80,
				height = 110 },
			{ filename = '__Biter_Detector_Sentinel_Combinator__/art/sentinel-combinator-shadow.png',
				frame_count = 1,
				scale = 0.5,
				width = 120,
				height = 110,
				shift = util.by_pixel(8, 1),
				draw_as_shadow = true } } },

		-- Aligned for constant combinator HR sprites from 0.18
		activity_led_sprites = {
			north = {
				scale = 0.5,
				filename = '__base__/graphics/entity/combinator/activity-leds/hr-constant-combinator-LED-E.png',
				width = 14,
				height = 14,
				frame_count = 1,
				shift = util.by_pixel(-7, -12.5) },
			east = {
				scale = 0.5,
				filename = '__base__/graphics/entity/combinator/activity-leds/hr-constant-combinator-LED-W.png',
				width = 14,
				height = 16,
				frame_count = 1,
				shift = util.by_pixel(4, -9) },
			south = {
				scale = 0.5,
				filename = '__base__/graphics/entity/combinator/activity-leds/hr-constant-combinator-LED-E.png',
				width = 14,
				height = 14,
				frame_count = 1,
				shift = util.by_pixel(7, -11) },
			west = {
				scale = 0.5,
				filename = '__base__/graphics/entity/combinator/activity-leds/hr-constant-combinator-LED-W.png',
				width = 14,
				height = 16,
				frame_count = 1,
				shift = util.by_pixel(-4, -14) } },
		activity_led_light = {intensity = 0.8, size = 1, color = {r = 0.002, g = 0.93, b = 0.98}},
		activity_led_light_offsets = {
			util.by_pixel(-7, -12.5), util.by_pixel(4, -9),
			util.by_pixel(7, -11), util.by_pixel(-4, -14) },
		circuit_wire_connection_points = {
			{ wire = {red = util.by_pixel(-5, -11), green = util.by_pixel(-12.5, -13)},
				shadow = {red = util.by_pixel(25, 15), green = util.by_pixel(29, 11)} },
			{ wire = {red = util.by_pixel(15, -16), green = util.by_pixel(9, -13)},
				shadow = {red = util.by_pixel(35, 10), green = util.by_pixel(32, 13)} },
			{ wire = {red = util.by_pixel(3.5, -24), green = util.by_pixel(11, -20)},
				shadow = {red = util.by_pixel(29, 11), green = util.by_pixel(32, 14)} },
			{ wire = {red = util.by_pixel(-15, -21), green = util.by_pixel(-7.5, -24)},
				shadow = {red = util.by_pixel(26, 14), green = util.by_pixel(31, 11)} } },

	},

}


data:extend{{
	type = 'item-subgroup',
	name = 'virtual-signal-biter',
	group = 'signals',
	order = 'x' }} -- should be ordered pretty much last

-- Signals for biter/spitter small/medium/big/behemoth
for _, t in ipairs{'biter', 'spitter'} do
	for n, sz in ipairs{'small', 'medium', 'big', 'behemoth'} do
		data:extend{{
			type = 'virtual-signal',
			name = 'signal-bds-'..sz..'-'..t,
			icon = '__base__/graphics/icons/'..sz..'-'..t..'.png',
			icon_size = 64, icon_mipmaps = 4,
			subgroup = 'virtual-signal-biter', order = 'x['..t..']-['..n..']' }}
end end

data:extend{
	{ type = 'virtual-signal',
		name = 'signal-bds-other',
		icon = '__Biter_Detector_Sentinel_Combinator__/art/sig-other-icon.png',
		icon_size = 64, icon_mipmaps = 4,
		subgroup = 'virtual-signal-biter', order = 'x[zzz]-[1]' },
	{ type = 'virtual-signal',
		name = 'signal-bds-total',
		icon = '__Biter_Detector_Sentinel_Combinator__/art/sig-total-icon.png',
		icon_size = 64, subgroup = 'virtual-signal-biter', order = 'x[zzz]-[2]' } }
