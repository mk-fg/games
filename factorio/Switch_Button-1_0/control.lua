--[[
  "Keybindused" is only to control the script (on_gui_opened), so it only work when his value is 0,
  and prevent to close the gui when the keybin key is presed to open the entity gui
]]

---------------------[BUILD ENTITY FUNCTION]---------------------
local function onBuilt(event)
  local switchbutton = event.created_entity or event.entity -- latter for revive event
  local control = switchbutton.get_or_create_control_behavior()
  if not control.parameters.parameters[1].signal.name then
    control.enabled = false
    control.parameters = {parameters={{ index=1,
      signal={type='virtual', name='signal-check'}, count=1 }}}
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
  global.keybind_state[event.player_index] = true
  if entity and entity.valid then
    local distance = math.abs(player.position.x-entity.position.x)+math.abs(player.position.y-entity.position.y)
    if distance < 15 or player.character.can_reach_entity(entity) then
      local control = entity.get_or_create_control_behavior()
      if settings.startup['ReverseOpenInventory'].value then
        player.opened = entity
        global.keybind_state[event.player_index] = nil
      elseif not settings.startup['ReverseOpenInventory'].value then
        control.enabled = not control.enabled
      end
    end
  end
end

------------------------[OPEN ENTITY GUI]------------------------
script.on_event(defines.events.on_gui_opened, function(event)
  local player = game.players[event.player_index]
  local entity = player.selected
  if entity ~= nil and entity.name == 'switchbutton' and not global.keybind_state[event.player_index] then
    local control = entity.get_or_create_control_behavior()
    if settings.startup['ReverseOpenInventory'].value then
      player.opened = nil
      control.enabled = not control.enabled
    end
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
