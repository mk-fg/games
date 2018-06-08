-- Main entry point file, (re-)loaded on every new game start or savegame load.

local conf = require('config')
local utils = require('libs/utils')
local zones = require('libs/zones')


-- local references to globals
local Wisps, UVLights, Detectors
local ws

-- wisp_surface must only be used directly on entry points, and passed from there
local wisp_surface


------------------------------------------------------------
-- Wisps
------------------------------------------------------------

local function entity_is_tree(e) return e.type == 'tree' end
local function entity_is_rock(e)
	-- Match any entities with separate "rock" word in it, and not e.g. "rocket"
	return e.name == 'rock' or (
		e.name:match('rock') and e.name:match('%W?rock%W?') ~= 'rock' )
end

local wisp_spore_proto = 'wisp-purple'
local function wisp_spore_proto_check(name) return name:match('^wisp%-purple') end

local function wisp_init(entity, ttl, n)
	if not ttl then
		ttl = conf.wisp_ttl[entity.name]
		if not ttl then return end -- not a wisp entity
		ttl = ttl + utils.pick_jitter(conf.wisp_ttl_jitter)
	end
	entity.force = game.forces.wisps
	local wisp = {entity=entity, ttl=ttl}
	if not n then n = Wisps.n + 1; Wisps.n = n end
	Wisps[n] = wisp
end

local function wisp_create(name, surface, position, ttl, n)
	local max_distance, step, wisp = 6, 0.3
	local pos = surface.find_non_colliding_position(name, position, max_distance, step)
	if pos then
		wisp = surface.create_entity{
			name=name, position=pos, force=game.forces.wisps }
		wisp_init(wisp, ttl, n)
	end
	return wisp
end

local function wisp_create_at_random(name, near_entity)
	-- Create wisp based on conf.wisp_chance_func()
	local e = near_entity
	if not ( e and e.valid
		and conf.wisp_chance_func(e.surface.darkness) ) then return end
	e = wisp_create(name, e.surface, e.position)
	if e and not wisp_spore_proto_check(name) then
		e.set_command{
			type=defines.command.wander,
			distraction=defines.distraction.by_damage }
	end
end

local function wisp_emit_light(wisp)
	local light = wisp.light
	if not light then
		light = wisp.entity.name
		light = conf.wisp_light_aliases[light] or light
		light = conf.wisp_light_name_fmt:format(
			light, math.random(conf.wisp_light_counts[light]) )
		wisp.light = light
	end
	wisp.entity.surface.create_entity{name=light, position=wisp.entity.position}
end

local function wisp_aggression_set(surface, attack)
	local peace = true
	if attack
			and not surface.peaceful_mode
			and not conf.peaceful_wisps
		then peace = false end
	-- utils.log( 'wisp aggression set: %s [attack=%s pm=%s pw=%s]',
	-- 	not peace, attack, not surface.peaceful_mode, not conf.peaceful_wisps )
	game.forces.wisps.set_cease_fire(game.forces.player, peace)
end

local function wisp_group_create_or_join(unit)
	local pos = unit.position
	local units_near = unit.surface.find_entities_filtered{
		name=name, area=utils.get_area(conf.wisp_group_radius[unit.name], pos) }
	if not (next(units_near) and #units_near > 1) then return end
	local leader = true
	for _, units_near in ipairs(units_near) do
		if not units_near.unit_group then goto skip end
		units_near.unit_group.add_member(unit)
		leader = false
		break
	::skip:: end
	if not leader then return end
	local newGroup = unit.surface
		.create_unit_group{position=pos, force=game.forces.wisps}
	newGroup.add_member(unit)
	for _, unit in ipairs(units_near) do newGroup.add_member(unit) end
	if not game.forces.wisps.get_cease_fire('player') then
		newGroup.set_autonomous()
		newGroup.start_moving()
	end
end


------------------------------------------------------------
-- Tech
------------------------------------------------------------

local function get_circuit_input_wire(entity, signal, wire)
	local net = entity.get_circuit_network(wire)
	if net and net.signals then
		for _, input in ipairs(net.signals) do
			if input.signal.name == signal then return input.count end
		end
	end
	return 0
end

local function get_circuit_input(entity, signal)
	return get_circuit_input_wire(entity, signal, defines.wire_type.red)
		+ get_circuit_input_wire(entity, signal, defines.wire_type.green)
end

local function uv_light_init(entity)
	local n = UVLights.n + 1
	UVLights.n, UVLights[n] = n, {entity=entity}
end
local function uv_light_active(entity)
	local control  = entity.get_control_behavior()
	if control and control.valid then return not control.disabled end
	return true
end

local function detector_init(entity)
	local n = Detectors.n + 1
	Detectors.n, Detectors[n] = n, {entity=entity}
end


------------------------------------------------------------
-- on_tick tasks
------------------------------------------------------------

local tasks_monolithic = {
	-- All task functions here should return non-nil (number > 0)
	--  if they did something heavy, which will re-schedule other tasks on this tick.
	-- Args: surface.

	zones_spread = function(surface, n, steps)
		return 0.2 * zones.update_wisp_spread(n, steps)
	end,

	zones_forest = function(surface, n, steps)
		return zones.update_forests_in_spread(n, steps)
	end,

	spawn = function(surface)
		-- XXX: add wisps spawning from rocks too
		if Wisps.n >= conf.wisp_max_count then return end
		local workload, trees = 0

		-- wisp spawning near players
		for _, player in pairs(game.connected_players) do
			if not player.valid or player.surface.index ~= surface.index then goto skip end
			trees = zones.get_wisp_trees_near_pos(
				player.surface, player.position, conf.wisp_near_player_radius )
			for _, tree in ipairs(trees) do wisp_create_at_random('wisp-yellow', tree) end
			workload = workload + #trees
		::skip:: end

		if Wisps.n < conf.wisp_max_count * conf.wisp_forest_on_map_percent then
			-- wisp spawning in random forests
			trees = zones.get_wisp_trees_anywhere(conf.wisp_forest_spawn_count)
			for _, tree in ipairs(trees) do
				local wisp_name = utils.pick_chance{ -- nil - neither
					[wisp_spore_proto]=conf.wisp_forest_spawn_chance_purple,
					['wisp-yellow']=conf.wisp_forest_spawn_chance_yellow,
					['wisp-red']=conf.wisp_forest_spawn_chance_red }
				if wisp_name then wisp_create_at_random(wisp_name, tree) end
			end
			workload = workload + #trees
		end

		return workload
	end,

	pacify = function(surface)
		if conf.wisp_peace_chance_func(surface.darkness)
			then wisp_aggression_set(surface, false) end
		return 1
	end,

	tactics = function(surface)
		if surface.darkness > conf.min_darkness then return end
		if Wisps.n > 0 then return end
		local wisp = Wisps[math.random(Wisps.n)]
		if (wisp.entity.valid and wisp.entity.type == 'unit')
				and (not wisp.entity.unit_group and wisp.ttl > conf.intervals.expire) then
			wisp_group_create_or_join(wisp.entity)
		end
		return 20
	end
}

local tasks_entities = {
	-- Tasks to run for valid entities, each run adding "work" to on_tick workload.
	-- Args: object, entity, surface.

	light = {work=0.5, func=function(wisp, e, s)
		if wisp.ttl >= conf.wisp_light_min_ttl
			then wisp_emit_light(wisp) end end},

	expire = {work=1, func=function(wisp, e, s)
		-- Destroy one cycle after expire, so that light will be disabled first
		if wisp.ttl  <= 0 then e.destroy() end
		if conf.wisp_ttl_expire_chance_func(s.darkness, wisp)
			then wisp.ttl = 0
		elseif not conf.wisp_chance_func(s.darkness, wisp)
			then wisp.ttl = wisp.ttl -
				conf.intervals.expire * conf.work_steps.expire end
	end},

	uv = {work=1, func=function(uv, e, s)
		if not uv_light_active(e) then return end

		-- XXX: check how this calculation works out
		local energy_percent = e.energy * 0.00007 -- /14222

		if energy_percent > 0.2 then
			local wisps = s.find_entities_filtered{
				force='wisps', type='unit', area=utils.get_area(conf.uv_range, e.position) }
			if next(wisps) then
				local currentUvDmg = (conf.uv_dmg + math.random(3)) * energy_percent
				for _, wisp in ipairs(wisps) do
					wisp.damage(math.floor(currentUvDmg), game.forces.player, 'fire')
				end
			end

			if energy_percent > 0.6 then
				local spores = s.find_entities_filtered{
					name='wisp-purple', area=utils.get_area(conf.uv_range, e.position) }
				if next(spores) then for _, spore in ipairs(spores) do
					if utils.pick_chance(energy_percent - 0.55) then spore.destroy() end
				end end
			end
		end
	end},

	detectors = {work=1, func=function(wd, e, s)
		local range = get_circuit_input(e, 'signal-R')
		if range > 0 then
			range = math.abs(range)
			if range > 128 then range = 128 end
		else range = conf.detection_range end

		local counts = {}
		if next(Wisps) then
			local wisps = s.find_entities_filtered{
				force='wisps', area=utils.get_area(range, e.position) }
			for _, wisp in ipairs(wisps)
				do counts[wisp.name] = (counts[wisp.name] or 0) + 1 end
			counts['wisp-purple'] = s.count_entities_filtered{
				name=wisp_spore_proto, area=utils.get_area(range, e.position) }
		end

		local params = {}
		for name, count in pairs(counts) do
			params[#params+1] = {index=#params+1, signal={type='item', name=name}, count=count}
		end

		-- XXX: doesn't look right - test it, add total count, other signals
		e.get_control_behavior().parameters = {parameters=params}
	end},
}


local on_tick_backlog = {} -- delayed tasks due to work_limit_per_tick

local function run_on_object_set(set, task_func, step, steps)
	-- Iterate over n%steps==step entities, check o.entity.valid
	--  and either efficiently remove o from the set or run task_func on it.
	-- Return count of task_func runs.
	-- Built-in lua array operations - table.* and #arr tracking - are very bad for this.
	local n, obj, e = step
	while n <= set.n do
		obj = set[n]; e = obj.entity
		if e.valid then
			task_func(obj, e, e.surface)
			n = n + steps
		else set[n], set.n = set[set.n], set.n - 1 end
	end
	return (n - step) / steps -- count
end

local function on_tick_run_task(name, target)
	local iter_task, steps, res = tasks_entities[name], conf.work_steps[name]
	if steps then
		n = (ws[name] or 0) + 1
		if n > steps then n = 1 end
		ws[name] = n
	end
	if not iter_task then -- monolithic task
		res = tasks_monolithic[name](target, n, steps)
		-- utils.log('tick task - %s [%s/%s] = %s', name, n, steps, res)
	else -- task mapped to valid(-ated) objects in a number of steps
		res = iter_task.work * run_on_object_set(target, iter_task.func, n, steps)
		-- utils.log('tick task - %s [%d/%d] = %d', name, n, steps, res)
	end
	return res or 0
end

local function on_tick_run_backlog(workload)
	-- if next(on_tick_backlog)
	-- 	then utils.log('tick backlog check [count=%d]', #on_tick_backlog) end
	for n, task in pairs(on_tick_backlog) do
		workload = workload + on_tick_run_task(task.name, task.target)
		table.remove(on_tick_backlog, n)
		if workload >= conf.work_limit_per_tick then break end
	end
	return workload
end

local function on_tick_run(name, tick, workload, target)
	if tick % conf.intervals[name] ~= 0 then return 0 end
	if workload >= conf.work_limit_per_tick then
		table.insert(on_tick_backlog, {target=target, name=name})
		if #on_tick_backlog > 100 then
			-- Should never be more than #on_tick_tasks, unless bugs
			utils.error('Too many tasks in on_tick backlog'..
				' - most likely a bug in config.lua file of this mod') end
		-- utils.log(
		-- 	'tick task to backlog - %s [workload %d >= %d]',
		-- 	name, workload, conf.work_limit_per_tick )
		return 0
	else return workload + on_tick_run_task(name, target) end
end

local function on_tick(event)
	local surface, tick = wisp_surface, event.tick

	local workload = on_tick_run_backlog(workload or 0)
	local function run(task, target)
		workload = workload + on_tick_run(task, tick, workload, target)
	end

	local is_dark = surface.darkness > conf.min_darkness
	local wisps, uvlights, detectors = Wisps.n > 0, UVLights.n > 0, Detectors.n > 0

	if is_dark then
		run('spawn', surface)
		run('tactics', surface)
		if wisps and surface.darkness > conf.min_darkness_to_emit_light
			then run('light', Wisps) end
	else
		run('zones_spread', surface)
		run('zones_forest', surface)
	end

	if detectors then run('detectors', Detectors) end

	if wisps then
		if uvlights then run('uv', UVLights) end
		run('expire', Wisps)
	end
end


------------------------------------------------------------
-- Event handlers
------------------------------------------------------------

local function on_death(event)
	if entity_is_tree(event.entity) then wisp_create_at_random('wisp-yellow', event.entity) end
	if entity_is_rock(event.entity) then wisp_create_at_random('wisp-red', event.entity) end
	if event.entity.name == 'wisp-red' or event.entity.name == 'wisp-yellow' then
		wisp_aggression_set(event.entity.surface, true)
		if game.surfaces.nauvis.darkness >= conf.min_darkness
			then wisp_create(wisp_spore_proto, event.entity.surface, event.entity.position) end
	end
end

local function on_mined_entity(event)
	if entity_is_tree(event.entity) then wisp_create_at_random('wisp-yellow', event.entity) end
	if entity_is_rock(event.entity) then wisp_create_at_random('wisp-red', event.entity) end
end

local function on_trigger_created(event)
	-- Limit red wisps' replication via trigger_created_entity to specific percentage
	if utils.pick_chance(conf.wisp_red_damage_replication_chance)
	then wisp_init(event.entity)
	else event.entity.destroy() end
end

local function on_built_entity(event)
	local entity = event.created_entity

	if entity.name == 'UV-lamp' then return uv_light_init(entity) end
	if entity.name == 'wisp-detector' then return detector_init(entity) end

	if entity.name == 'wisp-purple' then
		-- Recreate wisp to change damage values
		local surface, pos = entity.surface, entity.position
		entity.destroy()
		local wisp =  wisp_create('wisp-purple', surface, pos)
	else wisp_init(entity) end
end

local function on_chunk_generated(event)
	if event.surface.index ~= wisp_surface.index then return end
	zones.reset_chunk(event.surface, event.area)
end

local function on_tick_init(event)
	wisp_surface = game.surfaces[conf.surface_name]

	-- script.on_nth_tick can be used here,
	--  but central on_tick can de-duplicate bunch of common checks,
	--  like check darkness level and skip bunch of stuff based on that.
	script.on_event(defines.events.on_tick, on_tick)
	on_tick(event)
end


------------------------------------------------------------
-- Init
------------------------------------------------------------

local function update_recipes(with_reset)
	for _, force in pairs(game.forces) do
		if with_reset then force.reset_recipes() end
		if force.technologies['alien-bio-technology'].researched then
			force.recipes['alien-flora-sample'].enabled = true
			force.recipes['wisp-yellow'].enabled = true
			force.recipes['wisp-red'].enabled = true
			force.recipes['wisp-purple'].enabled = true
			force.recipes['wisp-detector'].enabled = true
		end
		if force.technologies['solar-energy'].researched then
			force.recipes['UV-lamp'].enabled = true
		end
	end
end

local function apply_runtime_settings(event)
	local key, knob = event and event.setting
	local function key_update(k)
		if not (not key or key == k) then return end
		utils.log('Updating runtime option: %s', k)
		return settings.global[k]
	end

	knob = key_update('wisps-can-attack')
	if knob then
		local v_old, v = conf.peaceful_wisps, not knob.value
		conf.peaceful_wisps = v
		if game and v_old ~= v then
			if v then game.forces.wisps.set_cease_fire(game.forces.player, true) end
			for _, wisp in ipairs(Wisps) do
				if not wisp.entity.valid or wisp_spore_proto_check(wisp.entity.name) then goto skip end
				wisp.entity.set_command{ type=defines.command.wander,
					distraction=v and defines.distraction.none or defines.distraction.by_damage }
			::skip:: end
		end
	end

	knob = key_update('defences-shoot-wisps')
	if knob then
		conf.peaceful_defences = not knob.value
		if game then game.forces.player
			.set_cease_fire(game.forces.wisps, conf.peaceful_defences) end
	end

	knob = key_update('purple-wisp-damage')
	if knob then
		local v_old, v = conf.peaceful_spores, not knob.value
		conf.peaceful_spores = v
		if game and v_old ~= v then
			-- Replace all existing spores with harmless/corroding variants
			wisp_spore_proto = v and 'wisp-purple-harmless' or 'wisp-purple'
			for n, wisp in ipairs(Wisps) do
				if not wisp.entity.valid
						or not wisp_spore_proto_check(wisp.entity.name)
					then goto skip end
				local surface, pos = wisp.entity.surface, wisp.entity.position
				wisp.entity.destroy()
				wisp = wisp_create(wisp_spore_proto, surface, pos, wisp.ttl, n)
			::skip:: end
		end
	end
end

local function apply_version_updates(old_v, new_v)
	local function remap_key(o, k_old, k_new, default)
		if not o[k_new] then o[k_new], o[k_old] = o[k_old] end
		if not o[k_new] then o[k_new] = default end
	end

	if utils.version_less_than(old_v, '0.0.3') then
		utils.log('    - Updating TTL/TTU keys in global objects')
		for _,wisp in ipairs(Wisps) do remap_key(wisp, 'TTL', 'ttl') end
		for _,chunk in ipairs(Chunks) do remap_key(chunk, 'TTU', 'ttu') end
		for _,forest in ipairs(Forests) do remap_key(forest, 'TTU', 'ttu') end
	end

	if utils.version_less_than(old_v, '0.0.7') then
		for _,k in ipairs{
				'stepLIGTH', 'stepTTL', 'stepGC',
				'stepUV', 'stepDTCT', 'recentDayTime' }
			do global[k] = nil end
	end

	if utils.version_less_than(old_v, '0.0.10') then
		remap_key(ws, 'ttl', 'expire')
	end

	if utils.version_less_than(old_v, '0.0.13') then
		Wisps.n, UVLights.n, Detectors.n = #Wisps, #UVLights, #Detectors
		ws.gc, global.chunks, global.forests = nil
	end
end

local function init_globals()
	for _, k in ipairs{'zones', 'wisps', 'uvLights', 'detectors', 'workSteps'} do
		if not global[k] then global[k] = {} end
		if (k == 'wisps' or k == 'uvLights' or k == 'detectors')
			and not global[k].n then global[k].n = #(global[k]) end
	end
end

local function init_refs()
	utils.log('Init local references to globals...')
	Wisps, UVLights, Detectors = global.wisps, global.uvLights, global.detectors
	ws = global.workSteps
	utils.log(
		' - Object stats: wisps=%s uvs=%s detectors=%s',
		Wisps.n, UVLights.n, Detectors.n )

	utils.log('Init zones module...')
	if global.zones then zones.init(global.zones) end -- nil before on_configuration_changed
end

script.on_load(function()
	utils.log('Loading game...')
	init_refs()
	apply_runtime_settings()
end)

script.on_configuration_changed(function(data)
	utils.log('Updating mod configuration...')
	-- Add any new globals and pick them up in init_refs() again
	init_globals()
	init_refs(false)

	utils.log('Refreshing chunks...')
	zones.refresh_chunks(game.surfaces[conf.surface_name])

	utils.log('Processing mod updates...')
	local update = data.mod_changes and data.mod_changes[script.mod_name]
	if not update then return end
	if update.old_version then
		local v_old, v_new = update.old_version, update.new_version
		utils.log(' - Will-o-the-Wisps updated: %s -> %s', v_old, v_new)
		update_recipes(true)
		apply_version_updates(v_old, v_new)
	else
		utils.log(' - Updating tech requirements...')
		update_recipes()
	end
end)

script.on_init(function()
	utils.log('Initializing mod for a new game...')

	init_globals()
	init_refs()

	utils.log('Init wisps force...')
	if not game.forces.wisps then
		game.create_force('wisps')
		game.forces.wisps.ai_controllable = true
	end
	game.forces.wisps.set_cease_fire(game.forces.player, true)
	game.forces.player.set_cease_fire(game.forces.wisps, conf.peaceful_defences)
	game.forces.wisps.set_cease_fire(game.forces.enemy, true)
	game.forces.enemy.set_cease_fire(game.forces.wisps, true)

	apply_runtime_settings()
end)


script.on_event(defines.events.on_tick, on_tick_init)
script.on_event(defines.events.on_entity_died, on_death)
script.on_event(defines.events.on_pre_player_mined_item, on_mined_entity)
script.on_event(defines.events.on_robot_pre_mined, on_mined_entity)
script.on_event(defines.events.on_built_entity, on_built_entity)
script.on_event(defines.events.on_robot_built_entity, on_built_entity)
script.on_event(defines.events.on_chunk_generated, on_chunk_generated)
script.on_event(defines.events.on_trigger_created_entity, on_trigger_created)
script.on_event(defines.events.on_runtime_mod_setting_changed, apply_runtime_settings)
