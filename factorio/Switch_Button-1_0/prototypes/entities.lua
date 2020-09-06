require ('circuit-connector-sprites')

local switchbutton = table.deepcopy(data.raw['constant-combinator']['constant-combinator'])
switchbutton.name = 'switchbutton'
switchbutton.icon = '__Switch_Button-1_0__/graphics/Switch_Button_OFF.png'
switchbutton.icon_size = 40
switchbutton.item_slot_count = 1
switchbutton.minable.result = 'switchbutton'

if not settings.startup['ShowBonusGui'].value then
  switchbutton.flags = {'placeable-neutral', 'player-creation', 'hide-alt-info'}
end

local sprite = {
  filename = '__Switch_Button-1_0__/graphics/Switch_Button_OFF.png',
  width = 40,
  height = 40,
  frame_count = 1,
  shift = {0.0, 0.0},
}

switchbutton.sprites = {
  north = sprite,
  east = sprite,
  south = sprite,
  west = sprite,
}

local activity_led_light_offset = {0, 0}
local activity_led_sprite = {
  filename = '__Switch_Button-1_0__/graphics/Switch_Button_ON.png',
  width = 40,
  height = 40,
  frame_count = 1,
  shift = activity_led_light_offset,
}

switchbutton.activity_led_sprites = {
  north = activity_led_sprite,
  east  = activity_led_sprite,
  south = activity_led_sprite,
  west  = activity_led_sprite, }

activity_led_light = {
  intensity = 0.0,
  size = 0.0,}

local circuit_wire_connection_points = {
  shadow = {
    red = {-0.35, 0.45},
    green = {-0.4, 0.45},
  },
  wire = {
    red = {-0.35, 0.45},
    green = {-0.4, 0.45},
  }}

switchbutton.circuit_wire_connection_points = {
  circuit_wire_connection_points,
  circuit_wire_connection_points,
  circuit_wire_connection_points,
  circuit_wire_connection_points,
}

circuit_wire_max_distance = default_circuit_wire_max_distance,
data:extend{switchbutton}
