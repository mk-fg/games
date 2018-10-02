-- Main entry point file, (re-)loaded on every new game start or savegame load.

local conf = require('config')
local utils = require('libs/utils')
local zones = require('libs/zones')


-- Note on how "set" tables are handled:
-- Value example: {1=..., 2=..., 3=..., n=3}
-- Add element X: set[set.n+1], set.n = X, set.n+1
-- Iteration (read only): for n = 1, set.n do ... end
-- Iteration (read/remove): local n = 1; while n <= set.n do ... n = n + 1 end
-- Remove element n: set[n], set.n, set[set.n] = set[set.n], set.n-1
-- Order of elements is not important there, while add/removal is O(1),
--  unlike table.insert/table.remove (which are O(n) and are very slow comparatively).

-- local references to globals
local Wisps, WispDrones, WispCongregations, UVLights, Detectors -- sets
local WispAttackEntities -- temporary set of aggressive wisp entities
local MapStats, WorkSteps

-- WispSurface must only be used directly on entry points, and passed from there
local WispSurface
-- Not sure how UVLightEnergyLimit value is calculated, so re-adjusted if ever seen higher
local UVLightEnergyLimit = 2844.45


------------------------------------------------------------
-- Politics
------------------------------------------------------------

local wisp_forces = utils.t('wisp wisp_attack')

local function get_player_forces()
	local forces = {}
	for _, player in pairs(game.players)
		do if player.connected then table.insert(forces, player.force) end end
	return forces
end

local function wisp_force_init(name, attack_players)
	local peaceful, wisps = not attack_players
	if not game.forces[name] then
		wisps = game.create_force(name)
		wisps.ai_controllable = true
	else wisps = game.forces[name] end
	for _, force in ipairs(get_player_forces()) do
		wisps.set_cease_fire(force, peaceful)
		force.set_cease_fire(wisps, peaceful and conf.peaceful_defences)
	end
	wisps.set_cease_fire(game.forces.enemy, true)
	game.forces.enemy.set_cease_fire(wisps, true)
	if wisps.name ~= 'wisp' and game.forces.wisp then
		wisps.set_cease_fire(game.forces.wisp, true)
		game.forces.wisp.set_cease_fire(wisps, true)
	end
	return wisps
end

local function wisp_incident_log(t, area, count)
	-- Tracks last incidents in a round-robin queue
	if not MapStats.incidents then MapStats.incidents = {a=1, b=1} end
	local q, q_max, ts = MapStats.incidents, conf.incident_track_max, game.tick
	if q[q.b] then
		q.b = q.b % q_max + 1
		if q[q.b] then
			for _, tag in pairs(q[q.b].tags) do if tag.valid then tag.destroy() end end
			if q.b == q.a then q.a = q.a % q_max + 1 end
		end
	end
	q[q.b] = { t=t, ts=ts, n=count, tags={},
		x=(area[1][1] + area[2][1])/2, y=(area[1][2] + area[2][2])/2 }
	ts = ts - conf.incident_track_timeout
	while q.a ~= q.b and q[q.a] and q[q.a].ts < ts do
		q.a, tags, q[q.a] = q.a % q_max + 1, q[q.a].tags
		for _, tag in pairs(tags) do if tag.valid then tag.destroy() end end
	end
end

local function wisp_aggression_set(surface, attack, force, area)
	if force and wisp_forces[force.name] then return end
	local peace = true
	if attack
			and not surface.peaceful_mode
			and not conf.peaceful_wisps
		then peace = false end

	local set, e = WispAttackEntities
	if not area then
		-- Change force for all wisps on the map
		if peace then
			for n = 1, set.n do
				if set[n] and set[n].valid then set[n].force = 'wisp' end
				set[n] = nil
			end
			set.n = 0
		else
			set.n = 0
			for n = 1, Wisps.n do
				e = Wisps[n].entity
				if not ( e.valid and e.type == 'unit'
						and conf.wisp_group_radius[e.name] )
					then goto skip end
				e.force = 'wisp_attack'
				set[set.n+1], set.n = e, set.n+1
			::skip:: end
		end
	else
		-- Change force for wisps in specified area
		local force = peace and 'wisp_attack' or 'wisp'
		local entities = surface.find_entities_filtered{force=force, type='unit', area=area}
		if #entities > 0 then wisp_incident_log(peace and 'peace' or 'attack', area, #entities) end
		if peace then for _, e in ipairs(entities) do e.force = 'wisp' end
		else for _, e in ipairs(entities) do
			if not conf.wisp_group_radius[e.name] then goto skip end
			e.force = 'wisp_attack'
			set[set.n+1], set.n = e, set.n+1
		::skip:: end end
	end
	-- utils.log(
	-- 	'wisp-aggression: peace=%s attack-set=%s attack-force=%s area=%s',
	-- 	peace, set.n, game.forces.wisp_attack.get_entity_count('wisp-yellow'), area )
end

local function wisp_aggression_stop(surface)
	-- Commands all attacking wisps to stop in addition to making them non-hostile
	local set, e = WispAttackEntities
	for n = 1, set.n do
		e = set[n]
		if not e or not e.valid then goto skip end
		e.set_command{type=defines.command.wander, distraction=defines.distraction.none}
	::skip:: end
	wisp_aggression_set(surface, false)
end

local function wisp_biter_aggression_set()
	local wisp_biter_peace = not conf.wisp_biter_aggression
	for _, force in ipairs{'wisp', 'wisp_attack'} do
		force = game.forces[force]
		if not force then goto skip end
		force.set_cease_fire(game.forces.enemy, wisp_biter_peace)
		game.forces.enemy.set_cease_fire(force, wisp_biter_peace)
	::skip:: end
end

local function wisp_incident_labels(q, remove)
	if not q or not q[q.a] then return end
	local n, q_max, inc, tag = q.a, conf.incident_track_max
	while q[n] do
		inc = q[n]
		if not remove then
			tag = {
				position={inc.x, inc.y}, icon={type='item', name='wisp-red'},
				text=('[%s] %s (n=%s)'):format(utils.fmt_ticks(inc.ts), inc.t, inc.n) }
			for _, player in ipairs(game.connected_players) do
				if inc.tags[player.force.name] and inc.tags[player.force.name].valid then goto skip end
				inc.tags[player.force.name] = player.force.add_chart_tag(player.surface, tag)
			::skip:: end
		else
			for k, tag in pairs(inc.tags)
				do if tag.valid then inc.tags[k] = tag.destroy() end end
		end
		if n == q.b then break end
		n = n % q_max + 1
	end
end

local function wisp_print_stats(print_func)
	local c, e = {types={}, types_hostile={}}
	for n = 1, Wisps.n do
		e = Wisps[n].entity
		if not e.valid then goto skip end
		c.types[e.name] = (c.types[e.name] or 0) + 1
		c.total = (c.total or 0) + 1
	::skip:: end
	for n = 1, WispAttackEntities.n do
		e = WispAttackEntities[n]
		if not (e and e.valid) then goto skip end
		c.types_hostile[e.name] = (c.types_hostile[e.name] or 0) + 1
		c.hostile = (c.hostile or 0) + 1
	::skip:: end

	local fmt = utils.fmt_n_comma
	local function print_types(name, key, force)
		local types = {}
		for t, count in pairs(c[key])
			do table.insert(types, ('%s=%s'):format(t:gsub('^wisp%-', ''), fmt(count))) end
		print_func(('wisps: types %s - %s'):format(name, table.concat(types, ' ')))
	end
	local function print_types_force(name, force_name)
		local types, force = {yellow=0, red=0, green=0}, game.forces[force_name]
		for t, count in pairs(types) do table.insert( types,
			('%s=%s'):format(t, fmt(force.get_entity_count(('wisp-%s'):format(t)))) ) end
		print_func(('wisps: types %s - %s'):format(name, table.concat(types, ' ')))
	end

	print_func(('wisps: total=%s hostile=%s'):format(fmt(c.total or 0), fmt(c.hostile or 0)))
	print_types('all', 'types')
	print_types('hostile', 'types_hostile')
	print_types_force('force-peaceful', 'wisp')
	print_types_force('force-hostile', 'wisp_attack')
end


------------------------------------------------------------
-- Wisp entities
------------------------------------------------------------

local function entity_is_tree(e) return e.type == 'tree' end
local function entity_is_rock(e) return utils.match_word(e.name, 'rock') end

local wisp_unit_proto_map = {['wisp-red']=true, ['wisp-yellow']=true, ['wisp-green']=true}
local function wisp_unit_proto_check(name) return wisp_unit_proto_map[name] end

local wisp_spore_proto = 'wisp-purple'
local function wisp_spore_proto_check(name) return name:match('^wisp%-purple') end

local function wisp_find_units(surface, pos, radius)
	local area
	if not radius then area = pos else area = utils.get_area(radius, pos) end
	local units = surface.find_entities_filtered{
		force={'wisp', 'wisp_attack'}, type='unit', area=area } or {}
	return units
end

local function wisp_find_player_target_pos(surface, area, entity_name, force)
	local forces, targets = force and {force} or utils.map(game.connected_players, 'force')
	for _, force in ipairs(forces) do
		targets = surface.find_entities_filtered{area=area, force=force}
		if #targets == 0 then goto skip end
		targets = surface.find_non_colliding_position(
			entity_name, targets[math.random(#targets)].position, 32, 0.3 )
		if targets then return targets, force.name end
	::skip:: end
end

local function wisp_init(entity, ttl, n)
	if not ttl then
		ttl = conf.wisp_ttl[entity.name]
		if not ttl then return end -- not a wisp entity
		ttl = ttl + utils.pick_jitter(conf.wisp_ttl_jitter)
	end
	entity.force = game.forces.wisp
	local wisp = {entity=entity, ttl=ttl, uv_level=0}
	if not n then n = Wisps.n + 1; Wisps.n = n end
	Wisps[n] = wisp
end

local function wisp_create(name, surface, position, ttl, n)
	local pos, wisp = surface.find_non_colliding_position(name, position, 6, 0.3)
	if pos then
		wisp = surface.create_entity{name=name, position=pos, force='wisp'}
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
	return e
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


------------------------------------------------------------
-- Tech
------------------------------------------------------------

local function uv_light_init(entity)
	local n = UVLights.n + 1
	UVLights.n, UVLights[n] = n, {entity=entity}
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
	-- Args: surface, n (step number, 0 <= n < steps), steps.

	zones_spread = function(surface, n, steps)
		return 0.2 * zones.update_wisp_spread(n, steps)
	end,

	zones_forest = function(surface, n, steps)
		return zones.update_forests_in_spread(n, steps)
	end,

	spawn_near_players = function(surface)
		-- XXX: add wisps spawning from rocks too
		if Wisps.n >= conf.wisp_max_count then return end
		local workload, trees = 0
		for _, player in pairs(game.connected_players) do
			if not player.valid or player.surface.index ~= surface.index then goto skip end
			trees = zones.get_wisp_trees_near_pos(
				player.surface, player.position, conf.wisp_near_player_radius )
			for _, tree in ipairs(trees) do wisp_create_at_random('wisp-yellow', tree) end
			workload = workload + #trees
		::skip:: end
		return workload
	end,

	spawn_on_map = function(surface)
		if Wisps.n >= conf.wisp_max_count * conf.wisp_forest_on_map_percent then return end
		trees = zones.get_wisp_trees_anywhere(conf.wisp_forest_spawn_count)
		local wisp_chances, wisp_name = {
			[wisp_spore_proto]=conf.wisp_forest_spawn_chance_purple,
			['wisp-yellow']=conf.wisp_forest_spawn_chance_yellow,
			['wisp-green']=conf.wisp_forest_spawn_chance_green,
			['wisp-red']=conf.wisp_forest_spawn_chance_red }
		for _, tree in ipairs(trees) do
			wisp_name = utils.pick_chance(wisp_chances)
			if wisp_name then wisp_create_at_random(wisp_name, tree) end
		end
		return #trees * 20
	end,

	pacify = function(surface)
		local uv = math.floor((1 - surface.darkness) / conf.wisp_uv_expire_step)
		if (surface.darkness <= conf.min_darkness or uv > (MapStats.uv_level or 0))
				and conf.wisp_uv_peace_chance_func(surface.darkness, uv)
			then wisp_aggression_set(surface, false) end
		MapStats.uv_level = uv
		return 1
	end,

	tactics = function(surface)
		local set, e, n = WispAttackEntities
		while set.n > 0 do
			n = math.random(set.n); e = set[n]
			if e and e.valid and e.force.name == 'wisp_attack' and not e.unit_group
				then break else set[n], set.n, set[set.n], e = set[set.n], set.n - 1 end
		end
		if not e then return 10 end

		local units_near = e.surface.find_entities_filtered{
			name=e.name, area=utils.get_area(conf.wisp_group_radius[e.name], e.position) }
		if not (units_near and #units_near > 1) then return 20 end

		-- If there's a group in the area already, just join that one
		local leader = true
		for _, e2 in ipairs(units_near) do
			if not e2.unit_group or e2.force ~= e.force then goto skip end
			leader = false
			e2.unit_group.add_member(e)
			break
		::skip:: end
		if not leader then return 25 end

		local group = e.surface
			.create_unit_group{position=e.position, force='wisp_attack'}
		group.add_member(e)
		for _, e2 in ipairs(units_near) do e2.force = e.force; group.add_member(e2) end
		group.set_autonomous()
		group.start_moving()
		return 30
	end,

	congregate = function(surface, n)
		local c = conf.congregate
		local chance = conf.wisp_forest_spawn_chance_green * c.chance_factor
		if n and not (math.random() < chance) then return end

		-- Find polluted-forest spawn area with custom pollution factor and create group there
		local group_size = math.random(
			math.ceil(c.group_size * c.group_size_min_factor), c.group_size )
		local wisps, trees, wisp = {},
			zones.get_wisp_trees_anywhere(group_size, c.source_pollution_factor)
		for _, tree in ipairs(trees) do
			wisp = wisp_create_at_random(c.entity, tree)
			if wisp then table.insert(wisps, wisp) end
		end
		wisp = wisps[1]
		if not wisp then return 10 end
		local surface = wisp.surface
		local group = surface.create_unit_group{position=wisp.position, force='wisp'}
		for _, e in ipairs(wisps) do group.add_member(e) end

		-- Find nearby high-pollution chunk, pick random player thing there as target
		local pos_chunk = zones.find_industrial_pos(surface, wisp.position, c.dst_chunk_radius)
		local pos, force_name = wisp_find_player_target_pos(
			surface, utils.get_area(c.dst_find_building_radius, pos_chunk), wisp.name )
		if not pos then pos = pos_chunk end

		-- Send group to target, registering it in WispCongregations for target updates
		group.set_command{
			type=defines.command.compound,
			structure_type=defines.compound_command.return_last,
			commands={
				{type=defines.command.go_to_location, destination=pos},
				{type=defines.command.wander} } }
		local cg = {dst=pos, dst_ts=game.tick, force_name=force_name, entity=group}
		local set = WispCongregations
		set[set.n+1], set.n = cg, set.n+1
		return 100
	end,

	radicalize = function(surface, n)
		if n and not (math.random() < conf.wisp_aggression_factor) then return end
		local trees = zones.get_wisp_trees_anywhere(conf.wisp_forest_spawn_count)
		for _, tree in ipairs(trees) do
			wisp_aggression_set( tree.surface, true, nil,
				utils.get_area(conf.wisp_death_retaliation_radius, tree.position) )
		end
		return #trees * 30
	end,

}

local tasks_entities = {
	-- Tasks to run for valid entities, each run adding "work" to on_tick workload.
	-- Args: object, entity, surface.

	light_wisps = {work=0.5, func=function(wisp, e, s)
		if wisp.ttl >= conf.wisp_light_min_ttl
			then wisp_emit_light(wisp) end end},
	light_detectors = {work=0.5, func=function(detector, e, s) wisp_emit_light(detector) end},
	light_drones = {work=0.3, func=function(drone, e, s) wisp_emit_light(drone) end},

	expire_ttl = {work=0.3, func=function(wisp, e, s)
		-- Works by time passing by reducing ttl value,
		--  so that even with long nights, wisps come and go normally.
		-- wisp_chance_func is rolled to not decrease ttl at night, to spread-out ttls.
		-- e.destroy() works one cycle after expire, so that light will be disabled first.
		if wisp.ttl  <= 0 then return e.destroy() end
		if not conf.wisp_chance_func(s.darkness, wisp)
			then wisp.ttl = wisp.ttl - conf.intervals.expire_ttl * conf.work_steps.expire_ttl end
	end},

	expire_uv = {work=0.1, func=function(wisp, e, s)
		-- Chance to destroy each wisp when night is over.
		-- At zero darkness, such check is done on each call using max uv value.
		-- Works by making checks when darkness crosses threshold levels.
		if wisp.ttl <= 0 then return end
		local uv = math.floor((1 - s.darkness) / conf.wisp_uv_expire_step)
		if (s.darkness <= conf.min_darkness or uv > wisp.uv_level)
				and conf.wisp_uv_expire_chance_func(s.darkness, uv, wisp) then
			wisp.ttl = math.min(wisp.ttl, utils.pick_jitter(conf.wisp_uv_expire_jitter, true))
		end
		wisp.uv_level = uv
	end},

	uv = {work=4, func=function(uv, e, s)
		local control  = e.get_control_behavior()
		if control and control.valid and control.disabled then return end

		if e.energy > UVLightEnergyLimit then UVLightEnergyLimit = e.energy end
		local energy_percent = e.energy / UVLightEnergyLimit
		if energy_percent < conf.uv_lamp_energy_min then return end

		-- Effects on unit-type wisps - reds and yellows
		local wisps, wisp = wisp_find_units(s, e.position, conf.uv_lamp_range)
		if next(wisps) then
			local damage = conf.uv_lamp_damage_func(energy_percent)
			for _, entity in ipairs(wisps) do
				entity.set_command{ type=defines.command.flee,
					from=e, distraction=defines.distraction.none }
				entity.damage(damage, game.forces.wisp, 'fire')
			end
		end

		-- Effects on non-unit wisps - purple
		wisps = s.find_entities_filtered{
			name=wisp_spore_proto, area=utils.get_area(conf.uv_lamp_range, e.position) }
		if next(wisps) then for _, entity in ipairs(wisps) do
			if conf.uv_lamp_spore_kill_chance_func(energy_percent) then entity.destroy() end
		end end
	end},

	detectors = {work=1, func=function(wd, e, s)
		local control = e.get_control_behavior()
		if not control.enabled then return end
		local signals = e.get_merged_signals()

		-- Get range from both local parameters and merged inputs
		-- Also used to scan local parameters for free/wisp slots to use/update
		local params, params_wisp, params_free, range, name = {}, {}, {}, 0
		for n, param in ipairs(control.parameters.parameters) do
			name = param.signal.name
			if not name then table.insert(params_free, {n, param.index})
			elseif wisp_unit_proto_check(name)
					or wisp_spore_proto_check(name)
				then params_wisp[name] = {n, param.index}
			else
				if name == conf.detection_range_signal
					then range = range + param.count end
				params[n] = param
			end
		end
		if signals then for _, param in ipairs(signals) do
			if param.signal.name == conf.detection_range_signal
				then range = range + param.count end
		end end
		if range > 0 then range = math.min(range, conf.detection_range_max)
		else range = conf.detection_range_default end

		-- Wisp counts
		local counts, wisps = {}
		if next(Wisps) then
			wisps = wisp_find_units(s, e.position, range)
			for _, wisp in ipairs(wisps)
				do counts[wisp.name] = (counts[wisp.name] or 0) + 1 end
			wisps = s.count_entities_filtered{
				name=wisp_spore_proto, area=utils.get_area(range, e.position) }
			if wisps > 0 then counts['wisp-purple'] = wisps end
		end

		-- Update parameters without moving them around
		local n, idx
		table.sort(params_free, function(a,b) return a[2] < b[2] end)
		for name, count in pairs(counts) do
			if params_wisp[name] then n, idx = table.unpack(params_wisp[name])
			else for m, slot in pairs(params_free) do
				n, idx, params_free[m] = table.unpack(slot)
				break
			end end
			if n then
				params[n], n = { index=idx,
					count=count, signal={type='item', name=name} }
			else break end
		end
		control.parameters = {parameters=params}
	end},

	recongregate = {work=20, func=function(cg, group, s)
		if not #group.members then group.destroy(); return end
		local tick, dst_dist = game.tick, cg.dst
		if not dst_dist then return end
		local dst_dist = utils.get_distance(dst_dist, group.position)
		if dst_dist > conf.congregate.dst_arrival_radius
				and (tick - cg.dst_ts) < c.dst_arrival_ticks
			then return end
		local pos = wisp_find_player_target_pos(
			s, utils.get_area(c.dst_next_building_radius, cg.dst),
			conf.congregate.entity, cg.force_name )
		if not pos then cg.dst, cg.dst_ts = nil; return end
		cg.dst, cg.dst_ts = pos, tick
		group.set_command{
			type=defines.command.compound,
			structure_type=defines.compound_command.return_last,
			commands={
				{type=defines.command.go_to_location, destination=pos},
				{type=defines.command.wander} } }
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
		if e.valid
			then task_func(obj, e, e.surface); n = n + steps
			else set[n], set.n, set[set.n] = set[set.n], set.n - 1 end
	end
	return (n - step) / steps -- count
end

local function on_tick_run_task(name, target)
	local iter_task, steps, res = tasks_entities[name], conf.work_steps[name]
	if steps then
		n = (WorkSteps[name] or 0) + 1
		if n > steps then n = 1 end
		WorkSteps[name] = n
	end
	-- Passed "n" value goes from 1 to "steps"
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
	local surface, tick = WispSurface, event.tick

	local workload = on_tick_run_backlog(workload or 0)
	local function run(task, target)
		workload = workload + on_tick_run(task, tick, workload, target)
	end

	local is_dark = surface.darkness > conf.min_darkness
	local wisps, drones, cgs = Wisps.n > 0, WispDrones.n > 0, WispCongregations.n > 0
	local uvlights, detectors = UVLights.n > 0, Detectors.n > 0

	if is_dark then
		run('spawn_near_players', surface)
		run('spawn_on_map', surface)
		run('tactics', surface)
		run('congregate', surface)
		run('radicalize', surface)
		if surface.darkness > conf.min_darkness_to_emit_light then
			if drones then run('light_drones', WispDrones) end
			if wisps then run('light_wisps', Wisps) end
			if detectors then run('light_detectors', Detectors) end
		end
	else
		run('zones_spread', surface)
		run('zones_forest', surface)
	end

	if detectors then run('detectors', Detectors) end

	if wisps then
		if uvlights then run('uv', UVLights) end
		if cgs then run('recongregate', WispCongregations) end
		run('expire_uv', Wisps)
		run('expire_ttl', Wisps)
		run('pacify', surface)
	end
end


------------------------------------------------------------
-- Event handlers
------------------------------------------------------------

local function on_death(event)
	local e = event.entity
	if entity_is_tree(e) then wisp_create_at_random('wisp-yellow', e) end
	if entity_is_rock(e) then wisp_create_at_random('wisp-red', e) end
	if wisp_unit_proto_check(e.name) then
		local area
		if conf.wisp_death_retaliation_radius > 0
			then area = utils.get_area(conf.wisp_death_retaliation_radius, e.position) end
		wisp_aggression_set(e.surface, true, event.force, area)
		if e.surface.darkness >= conf.min_darkness
			then wisp_create(wisp_spore_proto, e.surface, e.position) end
	end
end

local function on_mined_entity(event)
	if entity_is_tree(event.entity) then wisp_create_at_random('wisp-yellow', event.entity) end
	if entity_is_rock(event.entity) then wisp_create_at_random('wisp-red', event.entity) end
end

local function on_trigger_created(event)
	-- Limit red wisps' replication via trigger_created_entity to specific percentage
	if event.entity.name ~= 'wisp-red' then return end
	if utils.pick_chance(conf.wisp_red_damage_replication_chance)
	then wisp_init(event.entity)
	else event.entity.destroy() end
end

local function on_drone_placed(event)
	local surface = game.players[event.player_index].surface
	local drones = surface.find_entities_filtered{
		name='wisp-drone-blue', area=utils.get_area(1, event.position) }
	if not next(drones) then return end
	for _, entity in ipairs(drones) do
		for n = 1, WispDrones.n do
			if WispDrones[n].entity == entity then entity = nil; break end
		end
		if not entity then goto skip end
		local drone = {entity=entity}
		local n = WispDrones.n + 1
		WispDrones[n], WispDrones.n = drone, n
	::skip:: end
end

local function on_built_entity(event)
	local e = event.created_entity
	if e.name == 'UV-lamp' then return uv_light_init(e) end
	if e.name == 'wisp-detector' then return detector_init(e) end
	if e.name == 'wisp-purple' then
		local surface, pos = e.surface, e.position
		e.destroy()
		local wisp =  wisp_create(wisp_spore_proto, surface, pos)
	else wisp_init(e) end
end

local function on_chunk_generated(event)
	if event.surface.index ~= WispSurface.index then return end
	zones.reset_chunk_area(event.surface, event.area)
end

local function on_tick_init(event)
	WispSurface = game.surfaces[conf.surface_name]
	zones.init(global.zones)
	wisp_biter_aggression_set()

	-- script.on_nth_tick can be used here,
	--  but central on_tick can de-duplicate bunch of common checks,
	--  like check darkness level and skip bunch of stuff based on that.
	script.on_event(defines.events.on_tick, on_tick)
	on_tick(event)
end


------------------------------------------------------------
-- Console command-line Interface
------------------------------------------------------------

local cmd_help = [[
zone update - Scan all chunks on the map for will-o-wisp spawning zones.
zone stats - Print pollution and misc other stats for scanned zones to console.
zone labels [n] - Add map labels to all found forest spawning zones.
... Parameter (double, default=0.005) is a min threshold to display a spawn chance number in the label.
zone labels remove - Remove map labels from scanned zones.
zone spawn [n] - Spawn wisps in the forested map zones.
... Parameter (integer, default=1) sets how many spawn-cycles to simulate.
incidents - Add map labels for last wisp aggression-change incidents.
incidents remove - Remove map labels for wisp aggression incidents.
attack - Have all will-o-wisps on the map turn hostile towards player(s).
radicalize - Make wisps in randomly-picked spawn zones aggressive.
peace - Pacify all will-o-the-wisps on the map, command them to stop attacking.
stats - Print some stats about wisps on the map.
]]

local function run_wisp_command(cmd)
	if not cmd
		then return 'Will-o\'-the-Wisps mod-specific'..
			' admin commands. Run without parameters for more info.' end
	local player = game.players[cmd.player_index]
	local function usage()
		player.print('Usage: /wisp [command...]')
		player.print('Supported subcommands:')
		for line in cmd_help:gmatch('%s*%S.-\n') do player.print('  '..line:sub(1, -2)) end
	end
	if not cmd.parameter or cmd.parameter == '' then return usage() end
	if not player.admin then
		player.print('ERROR: all wisp-commands are only available to admin player')
		return
	end
	local args = {}
	cmd.parameter:gsub('(%S+)', function(v) table.insert(args, v) end)

	cmd = args[1]
	if cmd == 'zone' then
		cmd = args[2]
		if cmd == 'update' then zones.full_update()
		elseif cmd == 'stats' then zones.print_stats(player.print)
		elseif cmd == 'labels' then
			if args[3] ~= 'remove' then
				local label_threshold = tonumber(args[3] or '0.005')
				zones.forest_labels_add(WispSurface, player.force, label_threshold)
			else zones.forest_labels_remove(player.force) end
		elseif cmd == 'spawn' then
			local cycles = tonumber(args[3] or '1')
			local ticks = cycles * conf.intervals.spawn_on_map
			player.print(
				('Simulating %d spawn-cycle(s) (%s [%s ticks] of night time)')
				:format(cycles, utils.fmt_ticks(ticks), utils.fmt_n_comma(ticks)) )
			for n = 1, cycles do tasks_monolithic.spawn_on_map(WispSurface) end
		else return usage() end
	elseif cmd == 'incidents' then
		wisp_incident_labels(MapStats.incidents, args[2] == 'remove')
	elseif cmd == 'congregate' then tasks_monolithic.congregate(WispSurface)
	elseif cmd == 'attack' then wisp_aggression_set(WispSurface, true)
	elseif cmd == 'radicalize' then tasks_monolithic.radicalize(WispSurface)
	elseif cmd == 'peace' then wisp_aggression_stop(WispSurface)
	elseif cmd == 'stats' then wisp_print_stats(player.print)
	else return usage() end
end


------------------------------------------------------------
-- Init / updates / settings
------------------------------------------------------------

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
			if v then
				local wisps = game.forces.wisp_attack
				for _, force in ipairs(get_player_forces()) do wisps.set_cease_fire(force, true) end
			elseif not v then wisp_aggression_stop(WispSurface) end
		end
	end
	knob = key_update('wisp-death-retaliation-radius')
	if knob then conf.wisp_death_retaliation_radius = knob.value end

	knob = key_update('defences-shoot-wisps')
	if knob then
		local v_old, v = conf.peaceful_wisps, not knob.value
		conf.peaceful_defences = v
		if game and v_old ~= v then for _, force in ipairs(get_player_forces()) do
			force.set_cease_fire(game.forces.wisp, conf.peaceful_defences)
		end end
	end

	knob = key_update('purple-wisp-damage')
	if knob then
		local v_old, v = conf.peaceful_spores, not knob.value
		conf.peaceful_spores = v
		wisp_spore_proto = v and 'wisp-purple-harmless' or 'wisp-purple'
		if game and v_old ~= v then
			-- Replace all existing spores with harmless/corroding variants
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

	knob = key_update('wisp-biter-aggression')
	if knob then
		conf.wisp_biter_aggression = knob.value
		if game then wisp_biter_aggression_set() end
	end

	knob = key_update('wisp-aggression-factor')
	if knob then conf.wisp_aggression_factor = knob.value end
	knob = key_update('wisp-map-spawn-count')
	if knob then conf.wisp_max_count = knob.value end
	knob = key_update('wisp-map-spawn-pollution-factor')
	if knob then conf.wisp_forest_spawn_pollution_factor = knob.value end

	local wisp_spawns_sum = 0
	for _, c in ipairs{'purple', 'yellow', 'red', 'green'} do
		local k, k_conf = 'wisp-map-spawn-'..c, 'wisp_forest_spawn_chance_'..c
		knob = key_update(k)
		if knob then conf[k_conf] = knob.value end
		wisp_spawns_sum = wisp_spawns_sum + conf[k_conf]
	end
	if wisp_spawns_sum > 1 then
		for _, c in ipairs{'purple', 'yellow', 'red', 'green'} do
			local k = 'wisp_forest_spawn_chance_'..c
			conf[k] = conf[k] / wisp_spawns_sum
		end
	end
end

local function update_recipes(with_reset)
	for _, force in pairs(game.forces) do
		if with_reset then force.reset_recipes() end
		if force.technologies['alien-bio-technology'].researched then
			force.recipes['alien-flora-sample'].enabled = true
			force.recipes['wisp-detector'].enabled = true
		end
		if force.technologies['solar-energy'].researched then
			force.recipes['UV-lamp'].enabled = true
		end
		if force.technologies['combat-robotics'].researched then
			force.recipes['wisp-drone-blue-capsule'].enabled = true
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
	end

	if utils.version_less_than(old_v, '0.0.7') then
		for _,k in ipairs{
				'stepLIGTH', 'stepTTL', 'stepGC',
				'stepUV', 'stepDTCT', 'recentDayTime' }
			do global[k] = nil end
	end

	if utils.version_less_than(old_v, '0.0.10')
		then remap_key(WorkSteps, 'ttl', 'expire') end

	if utils.version_less_than(old_v, '0.0.13') then
		Wisps.n, UVLights.n, Detectors.n = #Wisps, #UVLights, #Detectors
		WorkSteps.gc, global.chunks, global.forests = nil
	end

	if utils.version_less_than(old_v, '0.0.17') then
		WorkSteps.spawn, WorkSteps.expire = nil
		for _, wisp in ipairs(Wisps) do wisp.uv_level = 0 end
	end

	if utils.version_less_than(old_v, '0.0.25') then
		WorkSteps.light = nil
		for _, force in pairs(game.forces)
			do for _, k in ipairs{'wisp-yellow', 'wisp-purple', 'wisp-red'}
				do force.recipes[k].enabled = false end end
	end

	if utils.version_less_than(old_v, '0.0.28') then
		global.wisp_drones, global.wispDrones = WispDrones
		global.uv_lights, global.uvLights = UVLights
		global.map_stats, global.mapUVLevel = MapStats
		global.work_steps, global.workSteps = WorkSteps
	end

	if utils.version_less_than(old_v, '0.0.34') then
		local wisps = game.forces.wisps
		for _, force in ipairs(get_player_forces()) do wisps.set_cease_fire(force, true) end
		wisp_force_init('wisp')
		wisp_force_init('wisp_attack', true)
		game.merge_forces('wisps', 'wisp')
	end
end

local function init_commands()
	utils.log('Init commands...')
	commands.add_command( 'wisp',
		run_wisp_command(), run_wisp_command )
end

local function init_globals()
	local sets = utils.t([[
		wisps wisp_drones wisp_congregations
		uv_lights detectors wisp_attack_entities ]])
	for k, _ in pairs(utils.t([[
			wisps wisp_drones wisp_congregations wisp_attack_entities
			uv_lights detectors zones map_stats work_steps ]])) do
		if global[k] then goto skip end
		global[k] = {}
		if sets[k] and not global[k].n then global[k].n = #(global[k]) end
	::skip:: end
end

local function init_refs()
	utils.log('Init local references to globals...')
	Wisps, WispDrones = global.wisps, global.wisp_drones
	WispCongregations = global.wisp_congregations
	UVLights, Detectors = global.uv_lights, global.detectors
	WispAttackEntities = global.wisp_attack_entities
	MapStats, WorkSteps = global.map_stats, global.work_steps
	utils.log(
		' - Object stats: wisps=%s drones=%s uvs=%s detectors=%s%s',
		Wisps and Wisps.n, WispDrones and WispDrones.n,
		UVLights and UVLights.n, Detectors and Detectors.n, '' )
end


script.on_load(function()
	utils.log('Loading game...')
	init_commands()
	init_refs()
	apply_runtime_settings()
end)

script.on_configuration_changed(function(data)
	utils.log('Updating mod configuration...')
	-- Add any new globals and pick them up in init_refs() again
	init_globals()
	init_refs()

	utils.log('Refreshing chunks...')
	zones.init(global.zones)
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

	init_commands()
	init_globals()
	init_refs()

	utils.log('Init wisps force...')
	wisp_force_init('wisp')
	wisp_force_init('wisp_attack', true)

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
script.on_event(defines.events.on_player_used_capsule, on_drone_placed)
script.on_event(defines.events.on_runtime_mod_setting_changed, apply_runtime_settings)
