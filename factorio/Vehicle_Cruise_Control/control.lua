local GUIs = {}
local CCState = {}


local function cc_state_toggle(player, state)
	if CCState[player.index] ~= state
		then CCState[player.index] = state
		else CCState[player.index] = nil end
end

local function cc_state_apply(player)
	local state = CCState[player.index]
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
	local cc = GUIs[player.index]
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
	if CCState[player.index] == 'cruise'
		then cruise.caption, cruise.style = 'Cruising', 'vcc-cruise-enabled'
		else cruise.caption, cruise.style = 'Cruise', 'button' end
	if CCState[player.index] == 'brake'
		then brake.caption, brake.style = 'Braking', 'vcc-brake-enabled'
		else brake.caption, brake.style = 'Brake', 'button' end
end

local function gui_create(player)
	local cc, cc_new = GUIs[player.index]
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
	GUIs[player.index] = cc
	gui_update(player)
end

local function gui_destroy(player)
	local cc = GUIs[player.index]
	if cc then pcall(cc.destroy) end
	GUIs[player.index], CCState[player.index] = nil
end


local function on_tick(event)
	for _, player in pairs(game.players)
		do if CCState[player.index] then cc_state_apply(player) end end
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
