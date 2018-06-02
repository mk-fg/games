data:extend({
		{
				type = "electric-turret",
				name = "wisp-attached",
				icon = "__Will-o-the-Wisps_updated__/graphics/icons/wisp-purple-capsule.png",
				icon_size = 32,
				flags = { "placeable-player", "placeable-enemy", "placeable-off-grid"},
				collision_box = {{ -0.0, -0.0}, {0.0, 0.0}},
				selection_box = {{ -0.5, -0.5}, {0.5, 0.5}},
				minable = { mining_time = 1.5, result = "alien-flora-sample" },
				max_health = 120,
				alert_when_damaged = false,
				dying_explosion = "blood-explosion-small",
				rotation_speed = 0.01,
				preparing_speed = 0.05,
				folding_speed = 0.05,
				energy_source =
				{
						type = "electric",
						buffer_capacity = "801kJ",
						input_flow_limit = "9600kW",
						drain = "24kW",
						usage_priority = "primary-input"
				},
				light = {intensity = 0.5, size = 60, color = { r = 0.48, g = 0.1, b = 0.8, a = 0.1}},
				folded_animation =
				{
						layers =
						{
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
								}
						}
				},
				preparing_animation =
				{
						layers =
						{
								{
										filename = "__Will-o-the-Wisps_updated__/graphics/entity/wisp-purple/wisp-purple.png",
										flags = { "compressed" },
										priority = "high",
										width = 158,
										height = 158,
										frame_count = 5,
										direction_count = 1,
										animation_speed = 0.9,
										scale = 0.4
								}
						}
				},
				prepared_animation =
				{
						layers =
						{
								{
										filename = "__Will-o-the-Wisps_updated__/graphics/entity/wisp-purple/wisp-purple.png",
										flags = { "compressed" },
										priority = "high",
										width = 158,
										height = 158,
										frame_count = 5,
										direction_count = 1,
										animation_speed = 0.9,
										scale = 0.5
								}
						}
				},
				folding_animation =
				{
						layers =
						{
								{
										filename = "__Will-o-the-Wisps_updated__/graphics/entity/wisp-purple/wisp-purple.png",
										flags = { "compressed" },
										priority = "high",
										width = 158,
										height = 158,
										frame_count = 5,
										direction_count = 1,
										animation_speed = 0.9,
										scale = 0.4
								}
						}
				},
				base_picture =
				{
						layers =
						{
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
								}
						}
				},
				vehicle_impact_sound =    { filename = "__base__/sound/car-metal-impact.ogg", volume = 0.65 },

				attack_parameters =
				{
						type = "projectile",
						ammo_category = "electric",
						cooldown = 20,
						projectile_center = {0, -0.2},
						projectile_creation_distance = 1.4,
						range = 0,
						damage_modifier = 4,
						ammo_type =
						{
								type = "projectile",
								category = "laser-turret",
								energy_consumption = "800kJ",
								action =
								{
										{
												type = "direct",
												action_delivery =
												{
														{
																type = "projectile",
																projectile = "laser",
																starting_speed = 0.28
														}
												}
										}
								}
						},
						sound =
						{
							{ filename = "__Will-o-the-Wisps_updated__/sound/wisp-1.ogg", volume = 0.6 },
							{ filename = "__Will-o-the-Wisps_updated__/sound/wisp-3.ogg", volume = 0.6 }
						}
				},
				call_for_help_radius = 40
		}
})
