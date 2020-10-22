data:extend{
  {
    type = 'item',
    name = 'switchbutton',
    icon = '__Switch_Button-1_0__/graphics/Switch_ButtonICO.png',
    icon_size = 40,
    flags = {},
    subgroup = mods.SchallCircuitGroup
      and 'circuit-combinator' or 'circuit-network',
    place_result='switchbutton',
    order = 'b[combinators]-d[switchbutton]',
    stack_size = 50,
  },
}
