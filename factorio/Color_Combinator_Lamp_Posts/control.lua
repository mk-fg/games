
-- ----- Misc events -----

script.on_event(defines.events.on_gui_opened, function(ev)
	if ev.gui_type ~= defines.gui_type.entity then return end
	local player = game.players[ev.player_index]
	local e = player.opened
	if not (e and e.name and e.name == 'cclp') then return end
	local cclp = global.cclps[e.unit_number]
	if not cclp then return end
	player.opened = cclp.core
end)

script.on_event(defines.events.on_entity_settings_pasted, function(ev)
	local e1, e2 = ev.source, ev.destination
	if not (e1.name == 'cclp' and e2.name == 'cclp') then return end
	local cb1 = global.cclps[e1.unit_number].core.get_or_create_control_behavior()
	local cb2 = global.cclps[e2.unit_number].core.get_or_create_control_behavior()
	cb2.enabled, cb2.parameters = cb1.enabled, cb1.parameters
end)


-- ----- Create/remove -----

local function cclp_init(e)
	if not e.valid then return end
	local core, core_data, cb, cb_params

	-- For placing from a blueprint - robots can't place this ghost,
	--  as there's no inventory item for it, but it has all parameters on it
	core = e.surface
		.find_entities_filtered{position=e.position, ghost_name='cclp-core'}
	if next(core) then
		cb = core[1].get_or_create_control_behavior()
		core_data = {cb.enabled, cb.parameters}
		core[1].destroy()
	else core_data = {true, {{
		index=1, signal={type='virtual', name='signal-white'}, count=1 }}} end

	core = e.surface.create_entity{
		name='cclp-core', position=e.position,
		force=e.force, create_build_effect_smoke=false }
	e.connect_neighbour{wire=defines.wire_type.red, target_entity=core}
	e.connect_neighbour{wire=defines.wire_type.green, target_entity=core}
	core.destructible = false

	cb = core.get_or_create_control_behavior()
	cb.enabled, cb_params = table.unpack(core_data)
	cb.parameters = cb_params

	cb = e.get_or_create_control_behavior()
	cb.use_colors = true
	cb.circuit_condition = {condition={ comparator='≠',
		first_signal={type='virtual', name='signal-anything'}, constant=0 }}

	return {e=e, core=core}
end

local function cclp_remove(uid)
	local cclp = global.cclps[uid] or {}
	if cclp.core and cclp.core.valid then cclp.core.destroy() end
	global.cclps[uid] = nil
end

local function on_built(ev)
	local e = ev.created_entity or ev.entity -- latter for revive event
	if not e.valid then return end
	global.cclps[e.unit_number] = cclp_init(e)
end

local cclp_built_filter = {{filter='name', name='cclp'}}
script.on_event(defines.events.on_built_entity, on_built, cclp_built_filter)
script.on_event(defines.events.on_robot_built_entity, on_built, cclp_built_filter)
script.on_event(defines.events.script_raised_built, on_built, cclp_built_filter)
script.on_event(defines.events.script_raised_revive, on_built, cclp_built_filter)


local function on_destroyed(ev)
	local e = ev.entity
	if e.name == 'entity-ghost' then -- remove core ghost as well
		local ghost = e.surface.find_entities_filtered{
			name='entity-ghost', ghost_name='cclp-core',
			area={{e.position.x-0.1, e.position.y-0.1}, {e.position.x+0.1, e.position.y+0.1}} }
		if next(ghost) then ghost[1].destroy() end
	else cclp_remove(e.unit_number) end
end

local cclp_remove_filter = { {filter='name', name='cclp'},
	{filter='name', name='entity-ghost'}, {mode='and', filter='ghost_name', name='cclp'} }
script.on_event(defines.events.on_pre_player_mined_item, on_destroyed, cclp_remove_filter)
script.on_event(defines.events.on_robot_pre_mined, on_destroyed, cclp_remove_filter)
script.on_event(defines.events.on_entity_died, on_destroyed, cclp_remove_filter)
script.on_event(defines.events.script_raised_destroy, on_destroyed, cclp_remove_filter)


-- ----- Init -----

local strict_mode = false
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

script.on_load(function() strict_mode_enable() end)

script.on_init(function()
	strict_mode_enable()
	global.cclps = {}
end)

script.on_configuration_changed(function(data)
	strict_mode_enable()
	global.cclps = global.cclps or {}
end)
