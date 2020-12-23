--[[
	"Keybindused" is only to control the script (on_gui_opened), so it only work when his value is 0,
	and prevent to close the gui when the keybin key is presed to open the entity gui
]]

local onoff_on_click = settings.startup['ReverseOpenInventory'].value
local button_reach_range = settings.startup['ButtonReachRange'].value

local function player_can_reach_button(player, entity)
	-- Button on/off-on-click reach is a bit longer than the default one
	if not ( player.character and entity
		and entity.valid and entity.name == 'switchbutton' ) then return end
	local pos1, pos2 = player.position, entity.position
	return
		(((pos1.x - pos2.x)^2 + (pos1.y - pos2.y)^2)^0.5 < button_reach_range)
		or player.character.can_reach_entity(entity)
end

---------------------[BUILD ENTITY FUNCTION]---------------------
local function onBuilt(event)
	local switchbutton = event.created_entity or event.entity -- latter for revive event
	local control = switchbutton.get_or_create_control_behavior()
	local params = control.parameters -- for factorio-1.1 compatibility checks
	if not (params.parameters or params)[1].signal.name then -- can be already set via blueprint
		control.enabled, params = false, {{
			index=1, signal={type='virtual', name='signal-check'}, count=1 }}
		control.parameters = control.parameters.parameters and {parameters=params} or params
	end
end

-------------------[COPY/PASTE ENTITY FUNCTION]------------------
local function onPaste(event)
	local sb1, sb2 = event.source, event.destination
	if sb1.name == 'switchbutton' and sb2.name == 'switchbutton' then
		local control1 = sb1.get_or_create_control_behavior()
		local control2 = sb2.get_or_create_control_behavior()
		control2.enabled = control1.enabled
		control2.parameters = control1.parameters
	end
end

---------------------[CUSTOM INPUT FUNCTION]---------------------
local function onKey(event)
	local player = game.players[event.player_index]
	local entity = player.selected
	if player_can_reach_button(player, entity) then
		global.keybind_state[event.player_index] = true -- skip on_gui_opened handling
		if onoff_on_click then player.opened = entity
		else
			local control = entity.get_or_create_control_behavior()
			control.enabled = not control.enabled
		end
	end
	if onoff_on_click then global.keybind_state[event.player_index] = nil end
end

------------------------[OPEN ENTITY GUI]------------------------
script.on_event(defines.events.on_gui_opened, function(event)
	local player = game.players[event.player_index]
	local entity = player.selected
	if player_can_reach_button(player, entity)
			and entity.name == 'switchbutton'
			and onoff_on_click -- on/off on click
			and not global.keybind_state[event.player_index] then -- not from keybind
		player.opened = nil
		local control = entity.get_or_create_control_behavior()
		control.enabled = not control.enabled
	end
end)

---------------------------[HOOKS]---------------------------
local event_filter = {{filter='name', name='switchbutton'}}

script.on_event('switchbutton-keybind', onKey)
script.on_event(defines.events.on_built_entity, onBuilt, event_filter)
script.on_event(defines.events.on_robot_built_entity, onBuilt, event_filter)
script.on_event(defines.events.script_raised_built, onBuilt, event_filter)
script.on_event(defines.events.script_raised_revive, onBuilt, event_filter)
script.on_event(defines.events.on_entity_settings_pasted, onPaste)

script.on_init(function() global.keybind_state = {} end)
script.on_configuration_changed(function() global.keybind_state = global.keybind_state or {} end)
