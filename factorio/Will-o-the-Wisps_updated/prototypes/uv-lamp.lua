data:extend({
		{
				type = "lamp",
				name = "UV-lamp",
				icon = "__Will-o-the-Wisps_updated__/graphics/icons/uv-lamp.png",
				icon_size = 32,
				flags = {"placeable-neutral", "player-creation"},
				minable = {hardness = 0.2, mining_time = 0.5, result = "UV-lamp"},
				max_health = 25,
				corpse = "small-remnants",
				collision_box = {{-0.15, -0.15}, {0.15, 0.15}},
				selection_box = {{-0.5, -0.5}, {0.5, 0.5}},
				vehicle_impact_sound =  { filename = "__base__/sound/car-metal-impact.ogg", volume = 0.65 },
				energy_source =
				{
						type = "electric",
						usage_priority = "secondary-input",
				},
				energy_usage_per_tick = "80kW",
				light = {intensity = 1.0, size = 60, color = {r=0.48, g=0.1, b=0.8, a=0.5}},
				light_when_colored = {intensity = 1.0, size = 60, color = {r=0.48, g=0.1, b=0.8, a=0.5}},
				glow_size = 4,
				glow_color_intensity = 0.5,
				picture_off =
				{
						filename = "__Will-o-the-Wisps_updated__/graphics/entity/uv-lamp/light-off.png",
						priority = "high",
						width = 67,
						height = 58,
						frame_count = 1,
						axially_symmetrical = false,
						direction_count = 1,
						shift = {-0.015625, 0.15625},
				},
				picture_on =
				{
						filename = "__base__/graphics/entity/small-lamp/light-on-patch.png",
						priority = "high",
						width = 62,
						height = 62,
						frame_count = 1,
						axially_symmetrical = false,
						direction_count = 1,
						shift = {-0.03125, -0.03125},
				},
				signal_to_color_mapping =
				{

				},
				circuit_wire_connection_point =
				{
						shadow =
						{
								red = {0.734375, 0.578125},
								green = {0.609375, 0.640625},
						},
						wire =
						{
								red = {0.40625, 0.34375},
								green = {0.40625, 0.5},
						}
				},
				circuit_connector_sprites = circuit_connector_definitions["lamp"].sprites,
				circuit_wire_max_distance = default_circuit_wire_max_distance
		}
})
