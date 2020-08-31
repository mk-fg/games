sp = 	{
	"automation-science-pack",
	"logistic-science-pack",
	"chemical-science-pack",
	"military-science-pack",
	"production-science-pack",
	"utility-science-pack"
}


data:extend({

	{
		type = "technology",
		name = "mlc",
		icon_size = 144,
		icon = "__Moon_Logic__/graphics/tech.png",
		effects =
		{
		  {
			type = "unlock-recipe",
			recipe = "mlc"
		  },
		  {
			type = "unlock-recipe",
			recipe = "mlc-sep"
		  },
		  {
			type = "unlock-recipe",
			recipe = "mlc-output"
		  },
		  {
			type = "unlock-recipe",
			recipe = "mlc-input"
		  }
		},
		prerequisites = {"circuit-network", "advanced-electronics"},
		unit =
		{
		  count = 100,
		  ingredients =
		  {
			{sp[1], 1},
			{sp[2], 1}
		  },
		  time = 15
		},
		order = "a-d-d-z",
	  },

})
