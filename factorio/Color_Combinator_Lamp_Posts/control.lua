

-- ----- Open combinator instead of lamp -----

script.on_event(defines.events.on_gui_opened, function(ev)
	local player = game.players[ev.player_index]
	local e = player.opened
	if not (e and e.name == 'cclp') then return end
	local cclp = global.cclps[e.unit_number]
	if not cclp then return end
	player.opened = cclp.core
end)


-- ----- Create/remove -----

local function cclp_init(e)
	if not e.valid then return end

	local core = e.surface.create_entity{
		name='cclp-core', position=e.position,
		force=e.force, create_build_effect_smoke=false }
	e.connect_neighbour{wire=defines.wire_type.red, target_entity=core}
	e.connect_neighbour{wire=defines.wire_type.green, target_entity=core}
	core.destructible = false

	local cb = core.get_or_create_control_behavior()
	cb.parameters = {parameters={{ index=1,
		signal={type='virtual', name='signal-white'}, count=1 }}}
	cb.enabled = true

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

local cclp_filter = {{filter='name', name='cclp'}}

local function on_built(ev)
	local e = ev.created_entity or ev.entity -- latter for revive event
	if not e.valid then return end
	global.cclps[e.unit_number] = cclp_init(e)
end

script.on_event(defines.events.on_built_entity, on_built, cclp_filter)
script.on_event(defines.events.on_robot_built_entity, on_built, cclp_filter)
script.on_event(defines.events.script_raised_built, on_built, cclp_filter)
script.on_event(defines.events.script_raised_revive, on_built, cclp_filter)

local function on_destroyed(ev) cclp_remove(ev.entity.unit_number) end

script.on_event(defines.events.on_pre_player_mined_item, on_destroyed, cclp_filter)
script.on_event(defines.events.on_robot_pre_mined, on_destroyed, cclp_filter)
script.on_event(defines.events.on_entity_died, on_destroyed, cclp_filter)
script.on_event(defines.events.script_raised_destroy, on_destroyed, cclp_filter)


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

local function init_recipes(with_reset)
	for _, force in pairs(game.forces) do
		if with_reset then force.reset_recipes() end
		if force.technologies['optics'].researched
			then force.recipes['cclp'].enabled = true end
	end
end

script.on_load(function() strict_mode_enable() end)

script.on_init(function()
	strict_mode_enable()
	global.cclps = {}
end)

script.on_configuration_changed(function(data)
	strict_mode_enable()
	global.cclps = global.cclps or {}
	local update = data.mod_changes and data.mod_changes[script.mod_name]
	if update then init_recipes(update.old_version) end
end)
