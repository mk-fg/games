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
					animation_speed = light_info.speed or conf.wisp_light_anim_speed,
					shift = {0, 0} } },
			rotate = false,
			light = light_info }}
	end
end

-- Wisp detector light uses same logic as wisp lights, but slightly different proto
data:extend{{
	type = 'explosion',
	name = 'wisp-detector-light-01',
	flags = {'not-on-map', 'placeable-off-grid'},
	animations = {
		{ filename = '__Will-o-the-Wisps_updated__/graphics/entity/wisp-detector/wisp-detector-light.png',
			priority = 'high',
			width = 0,
			height = 0,
			frame_count = 1,
			animation_speed = conf.wisp_light_anim_speed_detector,
			shift = util.by_pixel(0, -9) } },
	rotate = false,
	light = {intensity=0.3, size=7, color={r=0.95, g=0.0, b=0.8}} }}

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
