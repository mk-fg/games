local conf = require('config')

-- Light for each wisp is picked at random on wisp creation
-- They can be made dynamic (change over time, flicker, etc),
--  but for wisps only slow changes make sense - constant lights look best.

for wisp_name, light_info_list in pairs(conf.wisp_light_entities) do
	for idx, light_info in pairs(light_info_list) do
		data:extend{{
			type = 'explosion',
			name = conf.wisp_light_name_fmt:format(wisp_name, idx),
			flags = {'not-on-map', 'placeable-off-grid'},
			animations = {
				{ filename = '__Will-o-the-Wisps_updated__/graphics/null.png',
					priority = 'high',
					width = 0,
					height = 0,
					frame_count = 1,
					animation_speed = conf.wisp_light_anim_speed,
					shift = {0, 0} } },
			rotate = false,
			light = light_info }}
	end
end

-- For compatibility with old versions
for _, light in pairs{'wisp-light-generic', 'wisp-flash'}
do data:extend{{
	type = 'explosion',
	name = light,
	flags = {'not-on-map', 'placeable-off-grid'},
	animations = {
		{ filename = '__Will-o-the-Wisps_updated__/graphics/null.png',
			priority = 'high',
			width = 0,
			height = 0,
			frame_count = 1,
			animation_speed = 0.03,
			shift = {0, 0} } },
	rotate = false,
	light = {intensity=0.7, size=4}
}} end
