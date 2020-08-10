data:extend{
	{ type = 'custom-input',
		name = 'vcc-cruise',
		key_sequence = 'CONTROL + W',
		consuming = 'none' },
	{ type = 'custom-input',
		name = 'vcc-brake',
		key_sequence = 'CONTROL + S',
		consuming = 'none' },
}

local styles = data.raw['gui-style'].default
styles['vcc-cruise-enabled'] = {
	type = 'button_style',
	parent = 'green_button' }
styles['vcc-brake-enabled'] = {
	type = 'button_style',
	parent = 'red_button' }
