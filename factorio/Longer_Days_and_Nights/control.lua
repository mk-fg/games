local conf = require('config')
conf.multiplier = settings.startup['day-night-multiplier'].value
conf.adjust_accumulators = settings.startup['adjust-accumulator-capacity'].value

script.on_nth_tick(conf.tick, function(ev)
	for _, s in pairs(game.surfaces) do
		if not s.always_day then
			if global.counter == 0 then s.freeze_daytime = false
			elseif global.counter == 1 then s.freeze_daytime = true end
		end
	end
	global.counter = (global.counter + 1) % conf.multiplier
end)

script.on_init(function() global.counter = global.counter or 0 end)
