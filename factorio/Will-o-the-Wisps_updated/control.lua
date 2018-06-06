-- Main entry point file, (re-)loaded on every new game start or savegame load.

local conf = require('config')
local utils = require('libs/utils')
local zones = require('libs/zones')


-- local references to globals
local Wisps
local Chunks
local Forests
local UVLights
local Detectors

local ws


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

local function wisp_init(entity, ttl, key)
	if not ttl then
		ttl = conf.wisp_ttl[entity.name]
		if not ttl then return end -- not a wisp entity
		ttl = ttl + math.random(-conf.wisp_ttl_jitter_sec, conf.wisp_ttl_jitter_sec)
	end
	entity.force = game.forces.wisps
	local wisp = {entity=entity, ttl=ttl}
	if not key then key = #Wisps + 1 end
	Wisps[key] = wisp
end

local function wisp_create(name, surface, position, ttl, key)
	local max_distance, step, wisp = 6, 0.3
	local pos = surface.find_non_colliding_position(name, position, max_distance, step)
	if pos then
		wisp = surface.create_entity{
			name=name, position=pos, force=game.forces.wisps }
		wisp_init(wisp, ttl, key)
	end
	return wisp
end

local function wisp_create_at_random(name, near_entity)
	-- Create wisp based on conf.wisp_chance_func()
	local e = near_entity
	if not ( e and e.valid
		and conf.wisp_chance_func(game.surfaces.nauvis.darkness) ) then return end
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
		light = string.format( conf.wisp_light_name_fmt,
			light, math.random(conf.wisp_light_counts[light]) )
		wisp.light = light
	end
	game.surfaces.nauvis.create_entity{name=light, position=wisp.entity.position}
end

local function wisp_aggression_set(attack)
	local peace = true
	if not conf.peaceful_wisps and attack then peace = false end
	game.forces.wisps.set_cease_fire(game.forces.player, peace)
end

local function wisp_group_create_or_join(unit)
	local pos = unit.position
	local units_near = game.surfaces.nauvis.find_entities_filtered{
		name=name, area=utils.get_area(pos, conf.wisp_group_radius[unit.name]) }
	if not (next(units_near) and #units_near > 1) then return end
	local leader = true
	for _, units_near in pairs(units_near) do
		if not units_near.unit_group then goto skip end
		units_near.unit_group.add_member(unit)
		leader = false
		break
	::skip:: end
	if not leader then return end
	local newGroup = game.surfaces.nauvis
		.create_unit_group{position=pos, force=game.forces.wisps}
	newGroup.add_member(unit)
	for _, unit in pairs(units_near) do newGroup.add_member(unit) end
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
		for _, input in pairs(net.signals) do
			if input.signal.name == signal then return input.count end
		end
	end
end

local function get_circuit_input(entity, signal)
	return get_circuit_input_wire(entity, signal, defines.wire_type.red)
		+ get_circuit_input_wire(entity, signal, defines.wire_type.green)
end

local function uv_light_init(entity) UVLights[#UVLights+1] = entity end
local function uv_light_active(entity)
	local control  = entity.get_control_behavior()
	if control and control.valid then return not control.disabled end
	return true
end

local function detector_init(entity) Detectors[#Detectors] = entity end


------------------------------------------------------------
-- on_tick workload tasks
------------------------------------------------------------
-- Each one can return number to add to "workload" counter in on_tick,
--  which will reschedule other tasks to next ticks upon reaching work_limit_per_tick.

local function task_scan_zones()
	zones.find_new_forest()
	return 1
end

local function task_spawn()
	if #Wisps >= conf.wisp_max_count then return end

	-- wisp spawning near players
	-- XXX: add wisps spawning from rocks too
	local trees = zones.get_wisp_trees_near_players()
	for _, tree in pairs(trees) do wisp_create_at_random('wisp-yellow', tree) end

	if #Wisps >= conf.wisp_max_count * conf.wisp_percent_in_random_forests
		then return end

	-- wisp spawning in random forests
	for _, tree in pairs(zones.get_wisp_trees_anywhere() or {}) do
		local wisp_name = utils.pick_chance{
			[wisp_spore_proto]=conf.wisp_purple_spawn_chance,
			['wisp-yellow']=conf.wisp_yellow_spawn_chance,
			['wisp-red']=conf.wisp_red_spawn_chance }
		if wisp_name then wisp_create_at_random(wisp_name, tree) end
	end
	return 1 -- this part can be heavy
end

local function task_light(iter_step)
	if game.surfaces.nauvis.darkness < conf.min_darkness_to_emit_light then return end
	for n, wisp in iter_step(Wisps) do
		if not wisp.entity.valid then goto skip end
		if wisp.ttl >= conf.wisp_light_min_ttl then wisp_emit_light(wisp) end
	::skip:: end
	-- Runs quite often, so doesn't increment workload here, but maybe it should
end

local function task_expire(iter_step)
	local darkness = game.surfaces.nauvis.darkness
	local total, expired = 0, 0
	for n, wisp in iter_step(Wisps) do
		if not wisp.entity.valid then goto skip end
		total = total + 1

		-- Destroy one cycle after expire, so that light will be disabled first
		if wisp.ttl  <= 0 then
			wisp.entity.destroy()
			expired = expired + 1
		end

		if conf.wisp_ttl_expire_chance_func(darkness, wisp) then
			wisp.ttl = 0
		elseif not conf.wisp_chance_func(darkness, wisp)
			then wisp.ttl = wisp.ttl - conf.intervals.expire end
	::skip:: end
	-- utils.log( 'Wisp expire stats:'..
	-- 		' count=%d processed=%d expired=%d %.1f%%',
	-- 	#Wisps, total, expired, (expired / total) * 100 )
	if conf.wisp_peace_chance_func(darkness) then wisp_aggression_set(false) end
	return 1
end

local function task_tactics()
	if game.surfaces.nauvis.darkness > conf.min_darkness then return end
	if not next(Wisps) then return end
	local wisp = Wisps[math.random(#Wisps)]
	if (wisp.entity.valid and wisp.entity.type == 'unit')
			and (not wisp.entity.unit_group and wisp.ttl > conf.intervals.expire) then
		wisp_group_create_or_join(wisp.entity)
	end
	return 1
end

local function task_sabotage() -- not used
	local wisp = Wisps[math.random(#Wisps)]
	if wisp.entity.valid and wisp.entity.name == 'wisp-purple' then
		local poles = game.surfaces.nauvis.find_entities_filtered{
			type='electric-pole', limit=1,
			area=utils.get_area(wisp.entity.position, conf.sabotage_range) }
		if next(poles) then
			local pos = poles[1].position
			pos.x = pos.x + math.random(-4, 4) * 0.1
			pos.y = pos.y + math.random(-5, 5) * 0.1
			local wispAttached = game.surfaces.nauvis
				.create_entity{name = 'wisp-attached', position = pos , force = 'wisps'}
			if wispAttached then
				local oldEntity = wisp.entity
				wisp.entity = wispAttached
				oldEntity.destroy()
			end
		end
	end
	return 1
end

local function task_detectors(iter_step)
	for n, detector in iter_step(Detectors) do
		if not detector.valid then goto skip end

		-- XXX: selectable range input signal
		local range = get_circuit_input(detector, 'signal-R')
		if range then
			range = math.abs(range)
			if range > 128 then range = 128 end
		else range = conf.detection_range end

		local counts = {}
		if next(Wisps) then
			local wisps = game.surfaces.nauvis.find_entities_filtered{
				force='wisps', area=utils.get_area(detector.position, range) }
			for _, wisp in pairs(wisps)
				do counts[wisp.name] = (counts[wisp.name] or 0) + 1 end
			counts['wisp-purple'] = game.surfaces.nauvis.count_entities_filtered{
				name=wisp_spore_proto, area=utils.get_area(detector.position, range) }
		end

		for name, count in pairs(counts) do
			params[#params+1] = {index=#params, signal={type='item', name=name}, count=count}
		end

		-- XXX: doesn't look right - test it, add total count, other signals
		detector.get_control_behavior().parameters = {parameters=params}
	::skip:: end
	return 1
end

local function task_uv(iter_step)
	if not next(UVLights) then return end

	for n, uv in iter_step(UVLights) do
		if not uv.valid then goto skip end
		if not uv_light_active(uv) then goto skip end

		-- XXX: check how this calculation works out
		local energyPercent = uv.energy * 0.00007 -- /14222

		if energyPercent > 0.2 then
			local wisps = game.surfaces.nauvis.find_entities_filtered{
				force='wisps', type='unit', area=utils.get_area(uv.position, conf.uv_range) }
			if next(wisps) then
				local currentUvDmg = (conf.uv_dmg + math.random(3)) * energyPercent
				for _, wisp in pairs(wisps) do
					wisp.damage(math.floor(currentUvDmg), game.forces.player, 'fire')
				end
			end

			if energyPercent > 0.6 then
				local spores = game.surfaces.nauvis.find_entities_filtered{
					name='wisp-purple', area=utils.get_area(uv.position, conf.uv_range) }
				if next(spores) then for _, spore in pairs(spores) do
					if utils.pick_chance(energyPercent - 0.55) then spore.destroy() end
				end end
			end
		end
	::skip:: end
	return 1
end

local function task_gc()
	-- Copying table is always more efficient than table.remove, even in reverse order
	local list
	list, Wisps = Wisps, {}
	for n, e in pairs(list) do if e.entity.valid then Wisps[#Wisps+1] = e end end
	list, Detectors = Detectors, {}
	for n, e in pairs(list) do if e.valid then Detectors[#Detectors+1] = e end end
	list, UVLights = UVLights, {}
	for n, e in pairs(list) do if e.valid then UVLights[#UVLights+1] = e end end
	return 1
end


------------------------------------------------------------
-- on_tick task scheduler
------------------------------------------------------------

local on_tick_tasks = {
	-- All task functions here should return non-nil (number > 0)
	--  if they did something heavy, which will re-schedule other tasks on this tick.
	zones = task_scan_zones,
	spawn = task_spawn,
	detectors = task_detectors,
	light = task_light,
	uv = task_uv,
	expire = task_expire,
	tactics = task_tactics,
	sabotage = task_sabotage,
	gc = task_gc }
local on_tick_backlog = {} -- delayed tasks due to work_limit_per_tick

local function work_step_iter(step, steps)
	-- Returns iterator function that goes through specified 1/nth of table.
	-- step must be in [0, steps-1] range - doesn't start with 1.
	local function iter_func(entities)
		local function iter_step(entities, n)
			local e
			repeat n, e = next(entities, n)
			until not n or n % steps == step
			return n, e
		end
		return iter_step, entities, nil
	end
	return iter_func
end

local function on_tick_run_task(task_name)
	-- Creates iterator to split large lists of entities
	--  into separate chunks for less on_tick load.
	local steps, n, iter_step = conf.work_steps[task_name]
	if steps then
		n = (ws[task_name] or -1) + 1
		if n >= steps then n = 0 end
		ws[task_name] = n
		iter_step = work_step_iter(n, steps)
	end
	return on_tick_tasks[task_name](iter_step) or 0
	-- utils.log('tick run task - %s [%s/%s] = %d', task_name, n, steps, tt); return tt
end

local function on_tick_run_backlog(workload)
	for n, task_name in pairs(on_tick_backlog) do
		workload, on_tick_backlog[n] = workload + on_tick_run_task(task_name)
		if workload >= conf.work_limit_per_tick then break end
	end
	return workload
end

local function on_tick_run(task_name, tt, workload)
	if tt % conf.intervals[task_name] ~= 0 then return 0 end
	if workload >= conf.work_limit_per_tick then
		on_tick_backlog[#on_tick_backlog+1] = task_name
		if #on_tick_backlog > 100 then
			-- Should never be more than #on_tick_tasks, unless bugs
			utils.error('Too many tasks in on_tick backlog'..
				' - most likely a bug in config.lua file of this mod') end
		-- utils.log( 'tick backlog - %s [workload %d >= %d]',
		-- 	task_name, workload, conf.work_limit_per_tick )
		return 0
	else return workload + on_tick_run_task(task_name) end
end

local function on_tick(event)
	local tick, workload = event.tick, 0
	local function run(task) workload = workload + on_tick_run(task, tick, workload) end
	workload = on_tick_run_backlog(workload)

	if game.surfaces.nauvis.darkness > conf.min_darkness then
		run('spawn')
		run('tactics')
	else run('zones') end

	if next(Detectors) then run('detectors') end

	if next(Wisps) then
		run('light')
		run('uv')
		run('expire')
		-- run('sabotage')
	end

	run('gc')
end


------------------------------------------------------------
-- Other event handlers
------------------------------------------------------------

local function on_death(event)
	if entity_is_tree(event.entity) then wisp_create_at_random('wisp-yellow', event.entity) end
	if entity_is_rock(event.entity) then wisp_create_at_random('wisp-red', event.entity) end
	if event.entity.name == 'wisp-red' or event.entity.name == 'wisp-yellow' then
		wisp_aggression_set(true)
		if game.surfaces.nauvis.darkness >= conf.min_darkness
			then wisp_create(wisp_spore_proto, event.entity.surface, event.entity.position) end
	end
end

local function on_mined_entity(event)
	if entity_is_tree(event.entity) then wisp_create_at_random('wisp-yellow', event.entity) end
	if entity_is_rock(event.entity) then wisp_create_at_random('wisp-red', event.entity) end
end

local function on_trigger_created(event)
	-- For red wisps replication via trigger_created_entity
	if utils.pick_chance(conf.wisp_replication_chance)
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
	if event.surface.index == 1 then
		Chunks[#Chunks + 1] = {area=event.area, ttu=-1}
	end
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

local function init_refs()
	-- XXX: make this stuff configurable via mod options
	utils.log('Sanity checks...')
	if ( conf.wisp_purple_spawn_chance +
			conf.wisp_yellow_spawn_chance +
			conf.wisp_red_spawn_chance ) > 1 then
		utils.error('Wisp spawn chances in config.lua must sum up to <1.')
	end

	utils.log('Init local references to globals...')
	Wisps = global.wisps
	Chunks = global.chunks
	Forests = global.forests
	UVLights = global.uvLights
	Detectors = global.detectors
	ws = global.workSteps
	utils.log(
		'wisps=%d chunks=%d forests=%d uvs=%d detectors=%d',
		#Wisps, #Chunks, #Forests, #UVLights, #Detectors )

	zones.init(global.chunks, global.forests)
end

local function apply_version_updates(old_v, new_v)
	local function remap_key(o, k_old, k_new, default)
		if not o[k_new] then o[k_new], o[k_old] = o[k_old] end
		if not o[k_new] then o[k_new] = default end
	end

	if utils.version_less_than(old_v, '0.0.3') then
		utils.log('    - Updating TTL/TTU keys in global objects')
		for _,wisp in pairs(Wisps) do remap_key(wisp, 'TTL', 'ttl') end
		for _,chunk in pairs(Chunks) do remap_key(chunk, 'TTU', 'ttu') end
		for _,forest in pairs(Forests) do remap_key(forest, 'TTU', 'ttu') end
	end

	if utils.version_less_than(old_v, '0.0.7') then
		for _,k in ipairs{
				'stepLIGTH', 'stepTTL', 'stepGC',
				'stepUV', 'stepDTCT', 'recentDayTime' }
			do global[k] = nil end
		if not global.workSteps then global.workSteps = {} end
		ws = global.workSteps
	end

	if utils.version_less_than(old_v, '0.0.10') then
		remap_key(ws, 'ttl', 'expire')
		ws['gc'] = nil
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
			for key, wisp in pairs(Wisps) do
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
			for key, wisp in pairs(Wisps) do
				if not wisp.entity.valid
						or not wisp_spore_proto_check(wisp.entity.name)
					then goto skip end
				local surface, pos = wisp.entity.surface, wisp.entity.position
				wisp.entity.destroy()
				wisp = wisp_create(wisp_spore_proto, surface, pos, wisp.ttl, key)
			::skip:: end
		end
	end

end


script.on_load(function()
	utils.log('Loading game...')
	init_refs()
	apply_runtime_settings()
end)

script.on_configuration_changed(function(data)
	utils.log('Reconfiguring...') -- new game/mod version

	utils.log(' - Refreshing chunks...')
	for n = 1, #Chunks do Chunks[n] = nil end
	local surface = game.surfaces.nauvis
	for chunk in surface.get_chunks() do
		on_chunk_generated{
			surface = surface,
			area = { left_top={chunk.x*32, chunk.y*32},
				right_bottom={(chunk.x+1)*32, (chunk.y+1)*32}} }
	end

	local mod_name = 'Will-o-the-Wisps_updated'
	if data.mod_changes and data.mod_changes[mod_name] then
		if data.mod_changes[mod_name].old_version then
			local oldVer = data.mod_changes[mod_name].old_version
			local newVer = data.mod_changes[mod_name].new_version
			utils.log(' - Will-o-the-Wisps updated: '..oldVer..' -> '..newVer)
			update_recipes(true)
			apply_version_updates(oldVer, newVer)
		else
			utils.log(' - Init Will-o-the-Wisps mod on existing game.')
			update_recipes()
		end
	end
end)

script.on_init(function()
	utils.log('Init globals...')
	global.wisps = {}
	global.chunks = {}
	global.forests = {}
	global.uvLights = {}
	global.detectors = {}
	global.workSteps = {}

	utils.log('Init wisps force...')
	if not game.forces.wisps then
		game.create_force('wisps')
		game.forces.wisps.ai_controllable = true
	end
	game.forces.wisps.set_cease_fire(game.forces.player, true)
	game.forces.player.set_cease_fire(game.forces.wisps, conf.peaceful_defences)
	game.forces.wisps.set_cease_fire(game.forces.enemy, true)
	game.forces.enemy.set_cease_fire(game.forces.wisps, true)

	init_refs()
	apply_runtime_settings()
end)


script.on_event(defines.events.on_tick, on_tick)
script.on_event(defines.events.on_entity_died, on_death)
script.on_event(defines.events.on_pre_player_mined_item, on_mined_entity)
script.on_event(defines.events.on_robot_pre_mined, on_mined_entity)
script.on_event(defines.events.on_built_entity, on_built_entity)
script.on_event(defines.events.on_robot_built_entity, on_built_entity)
script.on_event(defines.events.on_chunk_generated, on_chunk_generated)
script.on_event(defines.events.on_trigger_created_entity, on_trigger_created)
script.on_event(defines.events.on_runtime_mod_setting_changed, apply_runtime_settings)
