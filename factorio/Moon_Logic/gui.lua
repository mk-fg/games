local conf = require('config')


local function help_window_toggle(pn)
	local player = game.players[pn]
	if player.gui.screen['mlc-helper-'..pn] then
		player.gui.screen['mlc-helper-'..pn].destroy()
		return
	end
	local gui = player.gui.screen.add{ type='frame',
		name='mlc-helper-'..pn, caption='Moon Logic Combinator Info', direction='vertical' }
	gui.location = {math.max(50, player.display_resolution.width - 800), 150}
	local lines = {
		'Special variables available/handled in Lua environment:',
		'  uid (int) -- globally-unique number of this combinator.',
		('  %s {signal-name=value, ...} -- signals in the %s network (read only).')
			:format(conf.red_wire_name, conf.red_wire_name),
		('  %s {signal-name=value, ...} -- same for the %s network.')
			:format(conf.green_wire_name, conf.green_wire_name),
		'  out {signal-name=value, ...} -- a table with all signals sent to networks.',
		'    They are permanent, so to remove a signal you need to set its entry',
		'     to nil or 0, or flush all signals by entering "out = {}" (creates a fresh table).',
		'  var {} -- a table to easily store values between code runs (per-mlc globals work too).',
		'  delay (number) -- delay in ticks until next run (saves ups), has to be set on each run!',
		'  debug (bool) -- set to true to print debug info about next code run to factorio log.',
		' ',
		'Factorio APIs available, aside from general Lua stuff:',
		'  game.tick -- read-only int for factorio game tick, to measure time intervals.',
		'  game.print(...) -- prints string as in-game console output.',
		'  game.log(...) -- prints to factorio log.',
		' ',
		'Presets (buttons with numbers):',
		'  Save and Load - left-click, Delete - right-click, Overwrite - right then left.',
		'Default Hotkeys (rebindable, do not work when editing text-box is focused):',
		'  Ctrl-S - save, Ctrl-Left/Right - undo/redo,',
		'  Ctrl-Enter - save and close, Ctrl-Q or Esc - close.',
		' ',
		'To learn signal names, connect anything with signals to this combinator,',
		'and their names will be printed as colored inputs on the right of the code window.',
		' ' }
	for n, line in ipairs(lines) do gui.add{
		type='label', name='line_'..n, direction='horizontal', caption=line } end
	gui.add{type='button', name='mlc-help-close', caption='Got it'}
end

local err_icon_sub_add = '[color=#c02a2a]%1[/color]'
local err_icon_sub_clear = '%[color=#c02a2a%]([^\n]+)%[/color%]'
local function code_error_highlight(text, line_err)
	-- Add/strip rich error highlight tags
	text = text:gsub(err_icon_sub_clear, '%1')
	line_err = tonumber(line_err)
	if not line_err then return text end
	local _, line_count = text:gsub('([^\n]*)\n?','')
	if string.sub(text, -1) == '\n'
		then line_count = line_count + 1 end
	local n, result = 0, ''
	for line in text:gmatch('([^\n]*)\n?') do
		n = n + 1
		if n < line_count then
			if n == line_err
				then line = line:gsub('^(.+)$', err_icon_sub_add) end
			if n > 1 then line = '\n'..line end
			result = result..line
	end end
	return result
end

local function set_history_btns_state(gui_t, mlc)
	local hist_log, n = mlc.history, mlc.history_state
	if n and hist_log[n-1] then
		gui_t.mlc_back.sprite = 'mlc-back-enabled'
		gui_t.mlc_back.ignored_by_interaction = false
	else
		gui_t.mlc_back.sprite = 'mlc-back'
		gui_t.mlc_back.ignored_by_interaction = true
	end
	if n and hist_log[n+1] then
		gui_t.mlc_fwd.sprite = 'mlc-fwd-enabled'
		gui_t.mlc_fwd.ignored_by_interaction = false
	else
		gui_t.mlc_fwd.sprite = 'mlc-fwd'
		gui_t.mlc_fwd.ignored_by_interaction = true
	end
end

local function preset_help_tooltip(code)
	if not code
		then code = '-- [ left-click to save script here ] --'
		else code = code:match('^%s*(.-)%s*$')..
			'\n-- [ left-click - load, right-click - clear ] --' end
	return code
end

local function create_gui(player, entity)
	local uid = entity.unit_number
	local mlc = global.combinators[uid]
	local mlc_err = mlc.err_parse or mlc.err_run

	-- Main frame
	local el_map, el = {} -- map is to check if el belonds to this gui
	local gui_t = {uid=uid, el_map=el_map}

	local function elc(parent, props, style)
		el = parent.add(props)
		for k,v in pairs(style or {}) do el.style[k] = v end
		gui_t[props.name:gsub('%-', '_')], el_map[el.index] = el, el
		return el
	end

	local gui = elc( player.gui.screen,
			{ type='frame', name='mlc-gui',
				direction='vertical', caption =
					('Moon Logic [%s] - %s {}, %s {}, out {}, var {}, delay (int)')
					:format(uid, conf.red_wire_name, conf.green_wire_name) },
			{top_padding=1, right_padding=4, bottom_padding=4, left_padding=4} )
		el.location = {20, 150} -- doesn't work from initial props

	-- Main table
	local mt = elc(gui, {type='table', column_count=2, name='mt', direction='vertical'})

	-- MT column-1
	local mt_left = elc(mt, {type='flow', name='mt-left', direction='vertical'})

	-- MT column-1: action button bar at the top
	local top_btns = elc( mt_left,
		{type='flow', name='mt-top-btns', direction='horizontal'}, {width=799} )

	local function top_btns_add(name, tooltip)
		local sz, pad = 20, 0
		return elc( top_btns,
			{type='sprite-button', name=name, sprite=name, direction='horizontal', tooltip=tooltip},
			{height=sz, width=sz, top_padding=pad, bottom_padding=pad, left_padding=pad, right_padding=pad} )
	end

	top_btns_add('mlc-close', 'Discard changes and close [[color=#e69100]Esc[/color]]')
	top_btns_add('mlc-help', 'Toggle quick reference window')

	elc(top_btns, {type='flow', name='mt-top-spacer-a', direction='horizontal'}, {width=10})

	top_btns_add( 'mlc-back',
		'Undo [[color=#e69100]Ctrl-Left[/color]]\nRight-click - undo 5, right+shift - undo 50' )
	top_btns_add( 'mlc-fwd',
		'Redo [[color=#e69100]Ctrl-Right[/color]]\nRight-click - redo 5, right+shift - redo 50' )
	set_history_btns_state(gui_t, mlc)

	top_btns_add('mlc-clear', 'Clear code window')

	elc(top_btns, {type='flow', name='mt-top-spacer-b', direction='horizontal'}, {width=10})

	-- MT column-1: preset buttons at the top
	for n=0, 20 do
		elc( top_btns,
			{ type='button', name='mlc-preset-'..n, direction='horizontal', caption=n,
				tooltip='Discard changes and close [[color=#e69100]Esc[/color]]' },
			{height=20, width=27, top_padding=0, bottom_padding=0, left_padding=0, right_padding=0} )
		if not global.presets[n] then el.style, el.tooltip = 'button', preset_help_tooltip()
		else el.style, el.tooltip = 'green_button', preset_help_tooltip(global.presets[n]) end
	end

	-- MT column-1: code text-box
	elc(mt_left, {type='scroll-pane',  name='mlc-code-scroll', direction='vertical'}, {maximal_height=700})
	elc( el, {type='text-box', name='mlc-code', direction='vertical', text=mlc.code or ''},
		{vertically_stretchable=true, width=800, minimal_height=300} )
	if mlc_err
		then el.text = code_error_highlight(el.text, string.gsub(mlc_err,'.+:(%d+):.+', '%1'))
		else el.text = code_error_highlight(el.text) end
	mlc.textbox = el.text -- XXX: maybe restore mlc.textbox instead with revert-to-code button?

	-- MT column-1: error bar at the bottom
	elc(mt_left, {type='label', name='mlc-errors', direction='horizontal'}, {horizontally_stretchable=true})

	-- MT column-2
	local mt_right = elc(mt, {type='flow', name='mt-right', direction='vertical'})

	-- MT column-2: input signal list
	elc(mt_right, {type='label', name='signal-header', caption='Network Signals:'}, {font='heading-2'})
	elc( mt_right, {type='scroll-pane', name='signal-pane', direction='vertical'},
		{vertically_stretchable=true, vertically_squashable=true, maximal_height=700} )

	-- MT column-2: input signal list
	local control_btns = elc(mt_right, {type='flow', name='mt-br-btns', direction='horizontal'})
	elc(control_btns, {type='button', name='mlc-save', caption='Save'}, {width=60})
	elc(control_btns, {type='button', name='mlc-close', caption='Close'}, {width=60})
	elc(control_btns, {type='button', name='mlc-commit', caption='Save & Close'})

	return gui_t
end


-- ----- Interface for control.lua -----

local function find_gui(el)
	-- Finds uid and gui table for specified event-target element
	local el_chk
	for uid, gui_t in pairs(global.guis) do
		el_chk = gui_t.el_map[el.index]
		if el_chk and el_chk == el then return uid, gui_t end end
	-- log(('No gui match for el: %s %s %s'):format(el.player_index, el.index, el.name))
end

local guis = {}

function guis.open(player, entity)
	local gui_t = create_gui(player, entity)
	global.guis[entity.unit_number] = gui_t
	player.opened = gui_t.mlc_gui
end

function guis.close(uid)
	local gui_t = global.guis[uid]
	local gui = gui_t and (gui_t.mlc_gui or gui_t.gui)
	if gui then gui.destroy() end
	global.guis[uid] = nil
end

function guis.history_insert(gui_t, mlc, code)
	local hist_log, n = mlc.history, mlc.history_state
	code = code:match('^%s*(.-)%s*$')..'\n' -- normalize leading/trailing spaces
	-- XXX: do not store empty strings
	if not hist_log then
		mlc.history = {mlc.textbox}
		mlc.history_state = 1
	else
		if hist_log[n] == code then n = n
		elseif #hist_log == n then
			n = n + 1
			table.insert(hist_log, code)
		else
			n = n + 1
			hist_log[n] = code
			for a = n + 1, #hist_log do hist_log[a] = nil end
		end
		while n > conf.code_history_limit do
			n = n - 1
			table.remove(hist_log, 1)
		end
		mlc.history_state = n
	end
	if gui_t then set_history_btns_state(gui_t, mlc) end
end

function guis.history_restore(gui_t, mlc, offset)
	if not mlc.history then return end
	local n = math.min(#mlc.history, math.max(1, mlc.history_state + offset))
	mlc.history_state = n
	gui_t.mlc_code.text = mlc.history[n]
	set_history_btns_state(gui_t, mlc)
	mlc.textbox = gui_t.mlc_code.text
end

function guis.save_code(eid, code)
	local gui_t = global.guis[eid]
	if not gui_t then return end
	local clean_code = code_error_highlight(code or gui_t.mlc_code.text)
	load_code_from_gui(clean_code, eid)
	gui_t.mlc_code.text = clean_code
end

function guis.on_gui_text_changed(ev)
	if ev.element.name ~= 'mlc-code' then return end
	local uid, gui_t = find_gui(ev.element)
	if not uid then return end
	local mlc = global.combinators[uid]
	if not mlc then return end
	guis.history_insert(gui_t, mlc, ev.element.text)
	global.combinators[uid].textbox = ev.element.text
end

function guis.on_gui_click(ev)
	local el = ev.element
	if el.name == 'mlc-help-close' -- untracked "help" windows
		then return el.parent.destroy() end

	local uid, gui_t = find_gui(el)
	if not uid then return end
	local mlc = global.combinators[uid]
	if not mlc then return guis.close(uid) end
	local el_id = el.name
	local preset_n = tonumber(el_id:match('^mlc%-preset%-(%d+)$'))
	local rmb = defines.mouse_button_type.right

	if el_id == 'mlc-save' then guis.save_code(uid)
	elseif el_id == 'mlc-commit' then guis.save_code(uid); guis.close(uid)
	elseif el_id == 'mlc-clear' then
		guis.save_code(uid, '')
		guis.on_gui_text_changed{element=gui_t.mlc_code}
	elseif el_id == 'mlc-close' then guis.close(uid)
	elseif el_id == 'mlc-help' then help_window_toggle(ev.player_index)

	elseif preset_n then
		if ev.button == defines.mouse_button_type.left then
			if global.presets[preset_n] then
				gui_t.mlc_code.text = global.presets[preset_n]
				mlc.textbox = gui_t.mlc_code.text
				guis.history_insert(gui_t, mlc, gui_t.mlc_code.text)
			else
				global.presets[preset_n] = gui_t.mlc_code.text
				el.style = 'green_button'
				el.tooltip = preset_help_tooltip(global.presets[preset_n])
			end
		elseif ev.button == rmb then
			global.presets[preset_n] = nil
			el.style = 'button'
			el.tooltip = preset_help_tooltip()
		end

	elseif el_id == 'mlc-back' then
		if ev.button == rmb and ev.shift then guis.history_restore(gui_t, mlc, -50)
		elseif ev.button == rmb then guis.history_restore(gui_t, mlc, -5)
		else guis.history_restore(gui_t, mlc, -1) end
	elseif el_id == 'mlc-fwd' then
		if ev.button == rmb and ev.shift then guis.history_restore(gui_t, mlc, 50)
		elseif ev.button == rmb then guis.history_restore(gui_t, mlc, 5)
		else guis.history_restore(gui_t, mlc, 1) end
	end
end

function guis.on_gui_close(ev)
	local uid, gui_t = find_gui(ev.element)
	if uid then guis.close(uid) end
end

return guis
