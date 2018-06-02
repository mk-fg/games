local consts = require("libs/consts")
local PURPLE_TTL = consts.PURPLE_TTL

local config = require("config")
local CORROSION_AREA = config.CORROSION_AREA
local CORROSION_DMG = config.CORROSION_DMG

data:extend({
{
		type = "smoke-with-trigger",
		subgroup="enemies",
		name = "wisp-purple",
		icon = "__Will-o-the-Wisps_updated__/graphics/icons/wisp-purple-capsule.png",
		icon_size = 32,
		flags = {"placeable-player", "placeable-enemy", "placeable-off-grid", "breaths-air", "not-repairable"},
		show_when_smoke_off = true,
		animation =
		{
				filename = "__Will-o-the-Wisps_updated__/graphics/entity/wisp-purple/wisp-purple.png",
				flags = { "compressed" },
				priority = "high",
				width = 158,
				height = 158,
				frame_count = 5,
				direction_count = 1,
				animation_speed = 0.9,
				scale = 0.3
		},
		slow_down_factor = 0,
		affected_by_wind = true,
		cyclic = true,
		duration = PURPLE_TTL*12,
		fade_away_duration = PURPLE_TTL*6,
		spread_duration = 10,
		color = { r = 0.9, g = 0.5, b = 0.9,a = 0.0 },
		action =
		{
			type = "direct",
			action_delivery =
			{
				type = "instant",
				target_effects =
				{
					type = "nested-result",
					action =
					{
						type = "area",
						radius = CORROSION_AREA,
						entity_flags = {"player-creation"},
						action_delivery =
						{
							type = "instant",
							target_effects =
							{
								{
									type = "create-entity",
									entity_name = "wisp-flash-attack",
									offset = {0, 0},
									offset_deviation = {{-0.5, -0.5}, {0.5, 0.5}}
								},
								{
									type = "create-entity",
									entity_name = "wisp-flash",
									offset = {0, 0},
									offset_deviation = {{-0.5, -0.5}, {0.5, 0.5}}
								},
								{
									type = "damage",
									damage = {amount = CORROSION_DMG, force = "wisps", type = "corrosion"}
								}
							}
						}
					}
				}
			}
		},
		action_cooldown = 50
	}
})
