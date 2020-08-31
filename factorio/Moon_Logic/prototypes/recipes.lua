data:extend({

	{
		type = "recipe",
		name = "mlc-sep",
		-- icon_size = 64,
		enabled = "false",
		ingredients =
		{
		  {"arithmetic-combinator", 1},
		  {"advanced-circuit", 5}
		},
		result = "mlc-sep"
	  },

	  {
		type = "recipe",
		name = "mlc",
		-- icon_size = 64,
		enabled = "false",
		ingredients =
		{
		  {"constant-combinator", 1},
		  {"advanced-circuit", 5}
		},
		result = "mlc"
	  },

	  {
		type = "recipe",
		name = "mlc-output",
		-- icon_size = 64,
		enabled = "false",
		ingredients =
		{
		  {"constant-combinator", 1},
		  {"advanced-circuit", 3}
		},
		result = "mlc-output"
	  },
	  {
		type = "recipe",
		name = "mlc-input",
		-- icon_size = 64,
		enabled = "false",
		ingredients =
		{
		  {"small-lamp", 1},
		  {"advanced-circuit", 3}
		},
		result = "mlc-input"
	  }



})
