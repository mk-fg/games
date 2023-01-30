local strict_mode = false -- bad pattern for MP, but hopefully ok because set consistently
local function strict_mode_enable()
	if strict_mode then return end
	setmetatable(_ENV, {
		__newindex = function(self, key, value)
			error('\n\n[ENV Error] Forbidden global *write*:\n'
				..serpent.line{key=key or '<nil>', value=value or '<nil>'}..'\n', 2) end,
		__index = function(self, key)
			if key == 'game' then return end -- used in utils.log check
			error('\n\n[ENV Error] Forbidden global *read*:\n'
				..serpent.line{key=key or '<nil>'}..'\n', 2) end })
	strict_mode = true
end


local function cc_state_toggle(player, state)
	if global.cc_state[player.index] ~= state
		then global.cc_state[player.index] = state
		else global.cc_state[player.index] = nil end
end

local function cc_state_apply(player)
	local state = global.cc_state[player.index]
	if not player.riding_state then
		if state then gui_destroy(player) end
		return
	end
	if state == 'cruise' then state = defines.riding.acceleration.accelerating
	elseif state == 'brake' then state = defines.riding.acceleration.braking
	else state = defines.riding.acceleration.nothing end
	player.riding_state = {direction=player.riding_state.direction, acceleration=state}
end


local function gui_update(player, event)
	local cc = global.guis[player.index]
	if not cc then return end
	local cruise, brake = cc.children[1], cc.children[2]
	if event then
		local state
		if type(event) == 'string' then state = event
		elseif event.element.name == cruise.name then state = 'cruise'
		elseif event.element.name == brake.name then state = 'brake' end
		if state then
			cc_state_toggle(player, state)
			cc_state_apply(player)
		end
	end
	if global.cc_state[player.index] == 'cruise'
		then cruise.caption, cruise.style = 'Cruising', 'vcc-cruise-enabled'
		else cruise.caption, cruise.style = 'Cruise', 'button' end
	if global.cc_state[player.index] == 'brake'
		then brake.caption, brake.style = 'Braking', 'vcc-brake-enabled'
		else brake.caption, brake.style = 'Brake', 'button' end
end

local function gui_create(player)
	local cc, cc_new = global.guis[player.index]
	if cc then return end
	cc_new, cc = pcall( player.gui.left.add,
		{type='frame', name='VCC-Frame', flow='vertical'} )
	if cc_new then
		cc.add{type='button', name='VCC-Cruise'}
		cc.add{type='button', name='VCC-Brake'}
	else
		cc = nil
		for _, e in pairs(player.gui.left.children)
			do if e.name == 'VCC-Frame' then cc = e; break end end
	end
	global.guis[player.index] = cc
	gui_update(player)
end

local function gui_destroy(player)
	local cc = global.guis[player.index]
	if cc then pcall(cc.destroy) end
	global.guis[player.index], global.cc_state[player.index] = nil
end


local function on_tick(event)
	for _, player in pairs(game.players)
		do if global.cc_state[player.index] then cc_state_apply(player) end end
end


script.on_event(defines.events.on_player_driving_changed_state, function(event)
	local player = game.players[event.player_index]
	if player.vehicle then gui_create(player) else gui_destroy(player) end
end)

script.on_event(defines.events.on_gui_click, function(event)
	gui_update(game.players[event.player_index], event)
end)

script.on_event(defines.events.on_tick, function(event)
	for _, player in pairs(game.players)
		do if player.vehicle then gui_create(player) end end
	script.on_event(defines.events.on_tick, on_tick)
end)

script.on_event('vcc-cruise', function(event) gui_update(game.players[event.player_index], 'cruise') end)
script.on_event('vcc-brake', function(event) gui_update(game.players[event.player_index], 'brake') end)

script.on_configuration_changed(function(data)
	if (global.init or 0) < 1
		then global.init, global.guis, global.cc_state = 1, {}, {} end
end)

script.on_init(function() strict_mode_enable() end)
script.on_load(function() strict_mode_enable() end)
