
local wisp_beam_base = {
	type = 'beam',
	flags = {'not-on-map'},
	width = 0.5,
	damage_interval = 20,
	random_target_offset = true,
	working_sound = {
		{filename = '__base__/sound/fight/electric-beam.ogg', volume = 0.7} },
	action = {
		type = 'direct',
		action_delivery = {
			type = 'instant',
			target_effects = {
				{ type = 'damage',
					damage = {amount=6, type = 'ectoplasm'} } } } } }

-- Factorio 1.0 beams.lua - compare/copy it from there if it changes in the future:
--   append_base_electric_beam_graphics(
--     beam_table, blend_mode, beam_flags, beam_tint, light_tint )
local function make_color_beam(name, tint)
	local beam = table.deepcopy(wisp_beam_base)
	beam.name = name
	return append_base_electric_beam_graphics(
		beam, 'additive-soft', {'trilinear-filtering'}, tint, tint )
end


data:extend{

	{type='damage-type', name='corrosion'},
	{type='damage-type', name='uv'},
	{type='damage-type', name='ectoplasm'},

	make_color_beam('wisp-beam-yellow', {r=0.953, g=0.847, b=0}),
	make_color_beam('wisp-beam-red', {r=1.0, g=0, b=0.36}),
	make_color_beam('wisp-beam-blue', {r=0, g=1.0, b=0.98}),

	{ type = 'explosion',
		name = 'wisp-flash-attack',
		flags = {'not-on-map', 'placeable-off-grid'},
		animations = {
			{ filename = '__Will-o-the-Wisps_updated__/graphics/null.png',
				priority = 'high',
				width = 1,
				height = 1,
				frame_count = 1,
				animation_speed = 0.4,
				shift = {0, 0} }
		},
		rotate = false,
		light = {intensity = 0.6, size = 2, color = {r=0.2, g=0.9, b=0.4, a=0.1}}
	},

	{ type = 'explosion',
		name = 'wisp-null-effect',
		flags = {'not-on-map', 'placeable-off-grid'},
		animations = {
			{ filename = '__Will-o-the-Wisps_updated__/graphics/null.png',
				priority = 'high',
				width = 1,
				height = 1,
				frame_count = 1,
				animation_speed = 1,
				shift = {0, 0} } },
		rotate = false
	},

}
