local conf = require('config')
conf.update_from_settings()

script.on_configuration_changed(function(data)
	game.surfaces.nauvis.ticks_per_day = math.ceil(25000 * conf.multiplier)
end)
