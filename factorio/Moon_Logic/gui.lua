local gui_manager = {}
local comb_gui_class = {}


local function preset_help_tooltip(code)
	if not code
		then code = '-- [ left-click to save script here ] --'
		else code = code:match('^%s*(.-)%s*$')..
			'\n-- [ left-click - load, right-click - clear ] --' end
	return code
end

local function find_eid_for_gui_element(v)
	-- Returns eid of the gui table for the clicked element,
	--  along with local name of the button in data table and index of preset-btn
	for eid, e_g_els in pairs(global.guis) do
		if type(eid) ~= 'number' then goto skip end
		for elname, vv in pairs(e_g_els) do
			if elname == 'preset_btns' then
				for n, vvv in pairs(vv) do
					if v == vvv then return eid, 'preset_btn', n
				end end
			elseif vv == v then return eid, elname end
		end
	::skip:: end
	-- log(('BUG: GUI element not found: %s [gui dump follows]'):format(v and v.name or '???'))
	-- log(serpent.block(global.guis))
end

local function help_window_toggle(pn)
	local player = game.players[pn]
	if player.gui.screen['mlc_helper_'..pn] then
		player.gui.screen['mlc_helper_'..pn].destroy()
		return
	end
	local gui = player.gui.screen.add{ type='frame',
		name='mlc_helper_'..pn, caption='Moon Logic Combinator Info', direction='vertical' }
	gui.location = {math.max(50, player.display_resolution.width - 800), 150}
	local lines = {
		'Special variables available/handled in Lua environment:',
		'  uid (int) -- globally-unique number of this combinator.',
		'  red {signal-name=value, ...} -- signals in the red network (read only).',
		'  green {signal-name=value, ...} -- same for the green network.',
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
		'To learn signal names, connect anything with signals to this combinator,',
		'  and their names will be printed as colored inputs on the right of the code window.',
		' ',
		'Presets (buttons with numbers):',
		'  Save and Load - left-click, Delete - right-click, Overwrite - right then left.',
		' ' }
	for n, line in ipairs(lines) do gui.add{
		type='label', name='line_'..n, direction='horizontal', caption=line } end
	gui.add{type='button', name='mlc_help_x', caption='Got it'}
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


function gui_manager:on_gui_text_changed(ev)
	local eid = find_eid_for_gui_element(ev.element)
	if not eid then return end
	global.guis[eid]:on_gui_text_changed(eid, ev)
end

function gui_manager:on_gui_click(ev)
	if ev.element.name == 'mlc_help_x' -- untracked "help" windows
		then return ev.element.parent.destroy() end
	local eid, elname, n = find_eid_for_gui_element(ev.element)
	if not eid then return end
	global.guis[eid]:on_gui_click(eid, elname, n, ev)
end

function gui_manager:open(player, entity)
	local gui_data = self:create_gui(player, entity)
	setmetatable(gui_data, {__index=comb_gui_class})
	global.guis[entity.unit_number]=gui_data
	player.opened=gui_data.gui
end

function gui_manager:create_gui(player, entity)
	local eid = entity.unit_number
	local this_gui_data = {}
	local gui = player.gui.screen.add{ type='frame',
		name='mlc_gui_'..eid, caption='', direction='vertical' }
	gui.location = {100, 150}
	this_gui_data.gui = gui
		gui.caption = ( 'Moon Logic [%s] -'..
			' red {}, green {}, out {}, var {}, delay (int)' ):format(eid)
		gui.style.top_padding = 1
		gui.style.right_padding = 4
		gui.style.bottom_padding = 4
		gui.style.left_padding = 4
		--gui.style.scaleable = false
	gui.add{type = 'flow', name = 'flow', direction = 'horizontal'}
		gui.flow.style.width = 799
	local elem = gui.flow.add{type = 'sprite-button', name = 'mlc_x_'..eid, direction = 'horizontal'}
	this_gui_data.x_btn = elem
		elem.style.height=20
		elem.style.width=20
		elem.style.top_padding=0
		elem.style.bottom_padding=0
		elem.style.left_padding=0
		elem.style.right_padding=0
		--elem.style.disabled_font_color ={r=1,g=1,b=1}
		elem.sprite='mlc_close'
	elem = gui.flow.add{type = 'sprite-button', name = 'mlc_help', direction = 'horizontal'}
	this_gui_data.help_btn = elem
		elem.style.height=20
		elem.style.width=20
		elem.style.top_padding=0
		elem.style.bottom_padding=0
		elem.style.left_padding=0
		elem.style.right_padding=0
		elem.sprite='mlc_questionmark'
	elem = gui.flow.add{type = 'flow', name = 'flow1', direction = 'horizontal'}
		elem.style.width=15
	elem = gui.flow.add{type='sprite-button', name = 'mlc_back', state = true}
	this_gui_data.bw_btn = elem
		elem.style.height=20
		elem.style.width=20
		elem.style.top_padding=0
		elem.style.bottom_padding=0
		elem.style.left_padding=0
		elem.style.right_padding=0
		elem.sprite='mlc_back'
		elem.hovered_sprite ='mlc_back'
		elem.clicked_sprite ='mlc_back'
	elem = gui.flow.add{type='sprite-button', name = 'mlc_forward', state = true}
	this_gui_data.fw_btn = elem
		elem.style.height=20
		elem.style.width=20
		elem.style.top_padding=0
		elem.style.bottom_padding=0
		elem.style.left_padding=0
		elem.style.right_padding=0
		elem.sprite='mlc_forward'
		elem.hovered_sprite ='mlc_forward'
		elem.clicked_sprite  ='mlc_forward'
	elem=gui.flow.add{type = 'flow', name = 'flow2', direction = 'horizontal'}
		--elem.style.width=95
		elem.style.horizontally_stretchable = true
	local preset_btns = {}
	for n=0,20 do
		elem = gui.flow.add{type = 'button', name = 'mlc_preset_'..n, direction = 'horizontal',caption=n}
		preset_btns[n] = elem
			elem.style.height=20
			elem.style.width=27
			elem.style.top_padding=0
			elem.style.bottom_padding=0
			elem.style.left_padding=0
			elem.style.right_padding=0
		if not global.presets[n+1] then elem.style, elem.tooltip = 'button', preset_help_tooltip()
		else elem.style, elem.tooltip = 'green_button', preset_help_tooltip(global.presets[n+1]) end
	end
	this_gui_data.preset_btns = preset_btns
	elem = gui.add{type = 'table', column_count=2, name = 'main_table', direction = 'vertical'}
		elem.style.vertical_align = 'top'
	elem = gui.main_table.add{type = 'flow', column_count=1, name = 'left_table', direction = 'vertical'}
		elem.style.vertical_align = 'top'
		--elem.style.vertically_stretchable = true
		--elem.style.vertically_squashable = false
	elem = gui.main_table.left_table.add{type = 'scroll-pane',  name = 'code_scroll', direction = 'vertical'}
		--elem.style.vertically_stretchable = true
		--elem.style.vertically_squashable = false
		elem.style.maximal_height = 700
	elem = gui.main_table.left_table.code_scroll.add{type = 'table', column_count=1, name = 'code_table', direction = 'vertical'}
		--elem.style.vertically_stretchable = true
		--elem.style.vertically_squashable = false
	elem = gui.main_table.left_table.code_scroll.code_table.add{type = 'text-box', name = 'mlc_code', direction = 'vertical'}
	this_gui_data.code_tb = elem
		elem.style.vertically_stretchable = true
		--elem.style.vertically_squashable = false
		elem.style.width = 800
		elem.style.minimal_height = 100
		local mlc = global.combinators[eid]
		elem.text = mlc.code or ''
		local mlc_err = mlc.err_parse or mlc.err_run
		if mlc_err then
			local err_line = string.gsub(mlc_err,'.+:(%d+):.+', '%1')
			elem.text = code_error_highlight(elem.text, err_line)
		else elem.text = code_error_highlight(elem.text) end
		global.textboxes[gui.name] = elem.text
		if not global.history[gui.name] then
			global.history[gui.name] = {elem.text}
			global.historystate[gui.name] = 1
		end
	elem = gui.main_table.add{type='scroll-pane',name='flow',direction='vertical'}
		elem.style.maximal_height = 700
	gui.main_table.left_table.add{type = 'table', column_count=2, name = 'under_text', direction = 'vertical'}
		gui.main_table.left_table.under_text.style.width = 800
	gui.main_table.left_table.under_text.add{type = 'label', name = 'errors', direction = 'horizontal'}
		gui.main_table.left_table.under_text.errors.style.width = 760
	elem =gui.main_table.left_table.under_text.add{type = 'button', name = 'mlc_ok_'..eid, direction = 'horizontal',caption='ok'}
	this_gui_data.ok_btn = elem
		elem.style.width=35
		elem.style.height=30
		elem.style.top_padding=0
		elem.style.left_padding=0
	local i = global.historystate[gui.name]
	if global.history[gui.name][i-1] then
		gui.flow.mlc_back.sprite = 'mlc_back_enabled'
		gui.flow.mlc_back.ignored_by_interaction = false
	else
		gui.flow.mlc_back.sprite = 'mlc_back'
		gui.flow.mlc_back.ignored_by_interaction = true
	end
	if global.history[gui.name][i+1] then
		gui.flow.mlc_forward.sprite = 'mlc_forward_enabled'
		gui.flow.mlc_forward.ignored_by_interaction = false
	else
		gui.flow.mlc_forward.sprite = 'mlc_forward'
		gui.flow.mlc_forward.ignored_by_interaction = true
	end
	return this_gui_data
end


function comb_gui_class:insert_history(gui, code)
	local gui_name = gui
	if type(gui) ~= 'string' then gui_name = gui.name end
	local n = global.historystate[gui_name]
	if #global.history[gui_name] == global.historystate[gui_name] then
		n = n + 1
		table.insert(global.history[gui_name], code)
		global.historystate[gui_name] = n
	else
		n = n + 1
		global.history[gui_name][n] = code
		global.historystate[gui_name] = n
		for a = n + 1, #global.history[gui_name]
			do global.history[gui_name][a] = nil end
	end
	if n > 500 then
		n = n + 1
		table.remove(global.history[gui_name],1)
		global.historystate[gui_name] = n
	end
	if type(gui) ~= 'string' then
		if global.history[gui_name][n-1] then
			gui.flow.mlc_back.sprite = 'mlc_back_enabled'
			gui.flow.mlc_back.ignored_by_interaction = false
		else
			gui.flow.mlc_back.sprite = 'mlc_back'
			gui.flow.mlc_back.ignored_by_interaction = true
		end
		if global.history[gui_name][n+1] then
			gui.flow.mlc_forward.sprite = 'mlc_forward_enabled'
			gui.flow.mlc_forward.ignored_by_interaction = false
		else
			gui.flow.mlc_forward.sprite = 'mlc_forward'
			gui.flow.mlc_forward.ignored_by_interaction = true
		end
	end
end

function comb_gui_class:on_gui_click(eid, elname, preset_n, ev)

	local gui_t = global.guis[eid]
	local gui = gui_t.gui

	if elname == 'ok_btn' then
		local clean_code = code_error_highlight(gui_t.code_tb.text)
		load_code_from_gui(clean_code, eid)
		gui_t.code_tb.text = clean_code
	elseif elname == 'x_btn' then
		gui.destroy()
		global.guis[eid] = nil

	elseif elname == 'help_btn' then
		help_window_toggle(ev.player_index)

	elseif elname == 'preset_btn' then
		local subgui = ev.element.parent
		assert(subgui.parent == gui)
		local id = preset_n + 1
		if ev.button == defines.mouse_button_type.left then
			local code_textbox = gui_t.code_tb
			if global.presets[id] then
				code_textbox.text = global.presets[id]
				global.textboxes[gui.name] = code_textbox.text
				if not global.history[gui.name] then
					global.history[gui.name] = {code_textbox.text}
					global.historystate[gui.name] = 1
				else self:insert_history(gui, code_textbox.text) end
			else
				global.presets[id] = code_textbox.text
				ev.element.style = 'green_button'
				ev.element.tooltip = preset_help_tooltip(global.presets[id])
			end
		elseif ev.button == defines.mouse_button_type.right then
			global.presets[id] = nil
			ev.element.style = 'button'
			ev.element.tooltip = preset_help_tooltip()
		end

	elseif elname == 'bw_btn' then
		if ev.button == defines.mouse_button_type.left and ev.shift then self:history(gui, -50)
		elseif ev.button == defines.mouse_button_type.right then self:history(gui, -5)
		else self:history(gui, -1) end
	elseif elname == 'fw_btn' then
		if ev.button == defines.mouse_button_type.left and ev.shift then self:history(gui, 50)
		elseif ev.button == defines.mouse_button_type.right then self:history(gui, 5)
		else self:history(gui, 1) end
	end

end

function comb_gui_class:on_gui_text_changed(eid, ev)
	if ev.element.name ~= 'mlc_code' then return end

	if not global.textboxes then
		global.textboxes = {}
	end
	local gui = global.guis[eid].gui
	if not global.history[gui.name] then
		global.history[gui.name] = {ev.element.text}
		global.historystate[gui.name] = 1
	else self:insert_history(gui, ev.element.text) end
	global.textboxes[gui.name] = ev.element.text
end

function comb_gui_class:history(gui, interval)
	local gui_name = gui.name
	local eid = find_eid_for_gui_element(gui)
	local codebox = global.guis[eid].code_tb
	local i = math.min(#global.history[gui_name],math.max(1,global.historystate[gui_name]+interval))
	global.historystate[gui_name] = i
	codebox.text = global.history[gui_name][i]
	if global.history[gui_name][i-1] then
		gui.flow.mlc_back.sprite = 'mlc_back_enabled'
		gui.flow.mlc_back.ignored_by_interaction = false
	else
		gui.flow.mlc_back.sprite = 'mlc_back'
		gui.flow.mlc_back.ignored_by_interaction = true
	end
	if global.history[gui_name][i+1] then
		gui.flow.mlc_forward.sprite = 'mlc_forward_enabled'
		gui.flow.mlc_forward.ignored_by_interaction = false
	else
		gui.flow.mlc_forward.sprite = 'mlc_forward'
		gui.flow.mlc_forward.ignored_by_interaction = true
	end
	global.textboxes[gui_name] = codebox.text
end


return {gui_manager, comb_gui_class}
