local conf = require('config')

data:extend{

	{ type = 'smoke-with-trigger',
		subgroup='enemies',
		name = 'wisp-purple',
		icon = '__Will-o-the-Wisps_updated__/graphics/icons/wisp-purple-capsule.png',
		icon_size = 32,
		flags = {'placeable-player', 'placeable-enemy', 'placeable-off-grid', 'breaths-air', 'not-repairable'},
		show_when_smoke_off = true,
		animation = {
			filename = '__Will-o-the-Wisps_updated__/graphics/entity/wisp-purple/wisp-purple.png',
			flags = {'compressed'},
			priority = 'high',
			width = 158,
			height = 158,
			frame_count = 5,
			direction_count = 1,
			animation_speed = 0.9,
			scale = 0.3 },
		slow_down_factor = 0,
		affected_by_wind = true,
		cyclic = true,
		duration = conf.wisp_ttl_purple * 12,
		fade_away_duration = conf.wisp_ttl_purple * 6,
		spread_duration = 10,
		color = {r=0.9, g=0.5, b=0.9,a=0.0},
		action = {
			type = 'direct',
			action_delivery = {
				type = 'instant',
				target_effects = {
					type = 'nested-result',
					action = {
						type = 'area',
						radius = conf.wisp_purple_area,
						entity_flags = {'player-creation'},
						action_delivery = {
							type = 'instant',
							target_effects = {
								{ type = 'create-entity',
									entity_name = 'wisp-flash-attack',
									offset = {0, 0},
									offset_deviation = {{-0.5, -0.5}, {0.5, 0.5}} },
								{ type = 'create-entity',
									entity_name = 'wisp-purple-light-01',
									offset = {0, 0},
									offset_deviation = {{-0.5, -0.5}, {0.5, 0.5}} },
								{ type = 'damage',
									damage = {amount = conf.wisp_purple_dmg, force = 'wisps', type = 'corrosion'} } } } } } }
		},
		action_cooldown = 50 },

	{ type = 'smoke-with-trigger',
		subgroup='enemies',
		name = 'wisp-purple-harmless',
		order = 'wisp-xxx',
		icon = '__Will-o-the-Wisps_updated__/graphics/icons/wisp-purple-capsule.png',
		icon_size = 32,
		flags = {'placeable-enemy', 'placeable-off-grid', 'breaths-air', 'not-repairable'},
		show_when_smoke_off = true,
		animation = {
			filename = '__Will-o-the-Wisps_updated__/graphics/entity/wisp-purple/wisp-purple.png',
			flags = {'compressed'},
			priority = 'high',
			width = 158,
			height = 158,
			frame_count = 5,
			direction_count = 1,
			animation_speed = 0.9,
			scale = 0.3 },
		slow_down_factor = 0,
		affected_by_wind = true,
		cyclic = true,
		duration = conf.wisp_ttl_purple * 12,
		fade_away_duration = conf.wisp_ttl_purple * 6,
		spread_duration = 10,
		color = {r=0.9, g=0.5, b=0.9,a=0.0},
		action = {
			type = 'direct',
			action_delivery = {
				type = 'instant',
				target_effects = {
					type = 'nested-result',
					action = {
						type = 'area',
						radius = conf.wisp_purple_area,
						entity_flags = {'player-creation'},
						action_delivery = {
							type = 'instant',
							target_effects = {
								{ type = 'create-entity',
									entity_name = 'wisp-purple-light-01',
									offset = {0, 0},
									offset_deviation = {{-0.5, -0.5}, {0.5, 0.5}} } } } } } }
		},
		action_cooldown = 50 },

}
