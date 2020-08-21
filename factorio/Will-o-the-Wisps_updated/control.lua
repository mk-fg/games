-- Main entry point file, (re-)loaded on every new game start or savegame load.

local conf_base = require('config')
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
local conf, Init, InitState
local Wisps, WispDrones, WispCongregations, UVLights, Detectors -- sets
local WispAttackEntities -- temporary set of aggressive wisp entities
local MapStats, WorkSteps, WorkSets, WorkChecks



------------------------------------------------------------
-- Mechanics formulas from global.conf
------------------------------------------------------------
-- These are no longer allowed in globals as of 0.18.x,
--  so moved here, despite being full of various parameters.

local function uv_lamp_damage_func(energy_percent)
	return math.floor(energy_percent * (10 * (1 + math.random(-5, 5)/10))) end

-- See also: chart in doc/uv-lamp-spore-kill-chart.html
local function uv_lamp_spore_kill_chance_func(energy_percent)
	return math.random() < energy_percent * 0.15 end

-- XXX: hard to make this work without seq scans, but maybe possible
-- local function uv_lamp_ttl_change_func(energy_percent, wisp)
-- 	if math.random() < (energy_percent + 0.01)  * 0.15
-- 		then wisp.ttl = wisp.ttl / 3 end end

local function wisp_chance_func(darkness, wisp)
	-- Used to roll whether new wisp should be spawned,
	--  and to have existing wisps' ttl not decrease on expire-check (see intervals below).
	return darkness > conf.min_darkness
		and math.random() < darkness - 0.40 end

-- All wisp_uv_* chances only work with conf.wisp_uv_expire_step value
local function wisp_uv_expire_exp(uv) return math.pow(1.3, 1 + uv * 0.08) - 1.3 end
local wisp_uv_expire_exp_bp = wisp_uv_expire_exp(6)
local function wisp_uv_expire_chance_func(darkness, uv, wisp)
	-- When returns true, wisp's ttl will drop to 0 on expire_uv.
	-- Check is made per wisp each time when
	--  darkness drops by conf.wisp_daytime_expire_step
	--  or on every interval*step when <min_darkness.
	local chance
	if uv < 6 then chance = wisp_uv_expire_exp(uv)
	else chance = wisp_uv_expire_exp_bp + uv * 0.01 end
	return math.random() < chance
end

-- Applies to all wisps, runs on global uv level changes, not per-wisp
local function wisp_uv_peace_chance_func(darkness, uv)
	return math.random() < (uv / 10) * 0.3
end



------------------------------------------------------------
-- Politics
------------------------------------------------------------

local wisp_forces = utils.t('wisp wisp_attack')

local function get_player_forces(force)
	local forces = {}
	for _, player in pairs(game.players) do
		if player.connected
				and (not force or force.index == player.force.index)
			then table.insert(forces, player.force) end
	end
	return forces
end

local function wisp_force_init(name)
	local wisps
	if not game.forces[name] then
		wisps = game.create_force(name)
		wisps.ai_controllable = true
	else wisps = game.forces[name] end
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

local function wisp_player_aggression_set(player_force)
	game.forces.wisp.set_cease_fire(player_force, true)
	game.forces.wisp_attack.set_cease_fire(player_force, false)
	player_force.set_cease_fire(game.forces.wisp, conf.peaceful_defences)
	player_force.set_cease_fire(game.forces.wisp_attack, false)
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

	local cf_state, k1, k2 = {}
	for _, cf in ipairs{'wisp-player', 'wisp_attack-player', 'wisp-enemy', 'wisp_attack-enemy'} do
		k1, k2 = string.match(cf, '^([%w_]+)-([%w_]+)$')
		table.insert(cf_state, game.forces[k1].get_cease_fire(game.forces[k2]) and 'peace' or 'war')
		table.insert(cf_state, game.forces[k2].get_cease_fire(game.forces[k1]) and 'peace' or 'war')
	end
	print_func(( 'wisps: cease-fire-settings w/p=%s/%s'..
		' wa/p=%s/%s w/b=%s/%s wa/b=%s/%s' ):format(table.unpack(cf_state)))
	print_func(('wisps: spores-harmless=%s'):format(conf.peaceful_spores))
end


------------------------------------------------------------
-- Entities
------------------------------------------------------------

local function entity_is_tree(e) return e.type == 'tree' end
local function entity_is_rock(e) return utils.match_word(e.name, 'rock') end

local function init_light(o)
	-- Passed object can be wisp, drone or wisp-detector
	local light = o.entity.name
	light = conf.light_aliases[light] or light
	local lights = conf.light_entities[light] or {}
	if not next(lights) then goto done end
	light = lights[math.random(#lights)]
	if light.size then light.scale, light.size = light.size / 9.375 end
	o.light = rendering.draw_light(utils.tc{
		conf.light_defaults, light,
		surface=o.entity.surface, target=o.entity })
	::done:: return o
end

local function uv_light_init(entity)
	local n = UVLights.n + 1
	UVLights.n, UVLights[n] = n, {entity=entity}
end

local function detector_init(entity)
	local n = Detectors.n + 1
	Detectors.n, Detectors[n] = n, init_light{entity=entity}
end

local wisp_unit_proto_map = {['wisp-red']=true, ['wisp-yellow']=true, ['wisp-green']=true}
local function wisp_unit_proto_check(name) return wisp_unit_proto_map[name] end

local function wisp_spore_proto_name()
	return conf.peaceful_spores and 'wisp-purple-harmless' or 'wisp-purple' end
local function wisp_spore_proto_check(name) return name:match('^wisp%-purple') end

local function wisp_drone_proto_check(name) return name:match('^wisp%-drone%-') end

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
	-- Enforce limit to prevent e.g. red wisps from spawning endlessly
	if Wisps.n > conf.wisp_max_count then return entity.destroy() end
	if not ttl then
		ttl = conf.wisp_ttl[entity.name]
		if not ttl then return end -- not a wisp entity
		ttl = ttl + utils.pick_jitter(conf.wisp_ttl_jitter)
	end
	entity.force = game.forces.wisp
	local wisp = init_light{entity=entity, ttl=ttl, uv_level=0}
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
	-- Create wisp based on wisp_chance_func()
	local e = near_entity
	if not ( e and e.valid
		and wisp_chance_func(e.surface.darkness) ) then return end
	e = wisp_create(name, e.surface, e.position)
	if e and e.valid and not wisp_spore_proto_check(name) then
		e.set_command{
			type=defines.command.wander,
			distraction=defines.distraction.by_damage }
	end
	return e
end


------------------------------------------------------------
-- Routine tasks to run periodically from on_tick handlers
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
		local trees = zones.get_wisp_trees_anywhere(conf.wisp_forest_spawn_count)
		local wisp_chances, wisp_name = {
			[wisp_spore_proto_name()]=conf.wisp_forest_spawn_chance_purple,
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
				and wisp_uv_peace_chance_func(surface.darkness, uv)
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
				{type=defines.command.wander, wander_in_group=false} } }
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

	expire_ttl = {work=0.3, func=function(wisp, e, s)
		-- Works by time passing by reducing ttl value,
		--  so that even with long nights, wisps come and go normally.
		-- wisp_chance_func is rolled to not decrease ttl at night, to spread-out ttls.
		-- e.destroy() works one cycle after expire, so that light will be disabled first.
		if wisp.ttl  <= 0 then return e.destroy() end
		if not wisp_chance_func(s.darkness, wisp)
			then wisp.ttl = wisp.ttl - conf.intervals.expire_ttl * conf.work_steps.expire_ttl end
	end},

	expire_uv = {work=0.1, func=function(wisp, e, s)
		-- Chance to destroy each wisp when night is over.
		-- At zero darkness, such check is done on each call using max uv value.
		-- Works by making checks when darkness crosses threshold levels.
		if wisp.ttl <= 0 then return end
		local uv = math.floor((1 - s.darkness) / conf.wisp_uv_expire_step)
		if (s.darkness <= conf.min_darkness or uv > wisp.uv_level)
				and wisp_uv_expire_chance_func(s.darkness, uv, wisp) then
			wisp.ttl = math.min(wisp.ttl, utils.pick_jitter(conf.wisp_uv_expire_jitter, true))
		end
		wisp.uv_level = uv
	end},

	uv = {work=4, func=function(uv, e, s)
		local control  = e.get_control_behavior()
		if control and control.valid and control.disabled then return end

		if e.energy > conf.uv_lamp_energy_limit then conf.uv_lamp_energy_limit = e.energy end
		local energy_percent = e.energy / conf.uv_lamp_energy_limit
		if energy_percent < conf.uv_lamp_energy_min then return end

		-- Effects on unit-type wisps - reds and yellows
		local wisps, wisp = wisp_find_units(s, e.position, conf.uv_lamp_range)
		if next(wisps) then
			local damage = uv_lamp_damage_func(energy_percent)
			for _, entity in ipairs(wisps) do
				entity.set_command{ type=defines.command.flee,
					from=e, distraction=defines.distraction.none }
				entity.damage(damage, game.forces.wisp, 'fire')
			end
		end

		-- Effects on non-unit wisps - purple
		wisps = s.find_entities_filtered{
			name=wisp_spore_proto_name(), area=utils.get_area(conf.uv_lamp_range, e.position) }
		if next(wisps) then for _, entity in ipairs(wisps) do
			if uv_lamp_spore_kill_chance_func(energy_percent) then entity.destroy() end
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
				name=wisp_spore_proto_name(), area=utils.get_area(range, e.position) }
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
		local tick, dst_dist, c = game.tick, cg.dst, conf.congregate
		if not dst_dist then return end
		local dst_dist = utils.get_distance(dst_dist, group.position)
		if dst_dist > c.dst_arrival_radius
				and (tick - cg.dst_ts) < c.dst_arrival_ticks
			then return end
		local pos = wisp_find_player_target_pos( s,
			utils.get_area(c.dst_next_building_radius, cg.dst),
			c.entity, cg.force_name )
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

local function run_periodic_task(name, target)
	-- Returns workload value, which is not used
	local iter_task, steps, n, res = tasks_entities[name], conf.work_steps[name], 1
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


------------------------------------------------------------
-- Event handlers
------------------------------------------------------------

local tick_handlers = {}

local function on_nth_tick(event)
	if not InitState.configured then Init.state_tick() end
	local ev_name = tick_handlers[event.nth_tick]

	-- Some things run under certain conditions,
	--  with ev_check being condition name from WorkChecks.
	local ev_check = WorkChecks[ev_name]
	if ev_check then
		local is_dark = InitState.surface.darkness > conf.min_darkness
		if not ({ wisps=Wisps.n > 0,
				dark=is_dark, light=not is_dark })[ev_check]
			then return end
	end

	-- Skip running tasks that iterate over sets when sets are empty.
	local ev_set = WorkSets[ev_name]
	if not ev_set then ev_set = InitState.surface
	elseif ev_set.n <= 0 then return end

	run_periodic_task(ev_name, ev_set)
end

local function on_death(event)
	if not (InitState and InitState.configured) then return end
	local e = event.entity
	if entity_is_tree(e) then wisp_create_at_random('wisp-yellow', e) end
	if entity_is_rock(e) then wisp_create_at_random('wisp-red', e) end
	if wisp_unit_proto_check(e.name) then
		local aggro, area = true
		if conf.wisp_death_retaliation_radius > 0
			then area = utils.get_area(conf.wisp_death_retaliation_radius, e.position) end
		if conf.wisp_aggro_on_player_only
				and not next(get_player_forces(event.force or (event.cause and event.cause.force)))
			then aggro = false end
		if aggro then wisp_aggression_set(e.surface, true, event.force, area) end
		if e.surface.darkness >= conf.min_darkness
			then wisp_create(wisp_spore_proto_name(), e.surface, e.position) end
	elseif wisp_drone_proto_check(e.name)
		then e.surface.create_entity{name=e.name..'-death', position=e.position} end
end

local function on_mined_entity(event)
	if not (InitState and InitState.configured) then return end
	if entity_is_tree(event.entity) then wisp_create_at_random('wisp-yellow', event.entity) end
	if entity_is_rock(event.entity) then wisp_create_at_random('wisp-red', event.entity) end
end

local function on_built_entity(event)
	if not (InitState and InitState.configured) then return end
	local e = event.created_entity
	if e.name == 'UV-lamp' then return uv_light_init(e) end
	if e.name == 'wisp-detector' then return detector_init(e) end
	if e.name == 'wisp-purple' then
		local surface, pos = e.surface, e.position
		e.destroy()
		local wisp =  wisp_create(wisp_spore_proto_name(), surface, pos)
	else wisp_init(e) end
end

local function on_chunk_generated(event)
	if not (InitState and InitState.configured) then return end
	if event.surface.index ~= InitState.surface.index then return end
	zones.reset_chunk_area(event.surface, event.area)
end

local function on_trigger_created(event)
	if not (InitState and InitState.configured) then return end
	-- Limit red wisps' replication via trigger_created_entity to specific percentage
	if event.entity.name ~= 'wisp-red' then return end
	if utils.pick_chance(conf.wisp_red_damage_replication_chance)
	then wisp_init(event.entity)
	else event.entity.destroy() end
end

local function on_drone_placed(event)
	if not (InitState and InitState.configured) then return end
	local surface = game.players[event.player_index].surface
	local drones = surface.find_entities_filtered{
		name='wisp-drone-blue', area=utils.get_area(1, event.position) }
	if not next(drones) then return end
	for _, entity in ipairs(drones) do
		for n = 1, WispDrones.n do
			if WispDrones[n].entity == entity then entity = nil; break end
		end
		if not entity then goto skip end
		local n = WispDrones.n + 1
		WispDrones.n, WispDrones[n] = n, init_light{entity=entity}
	::skip:: end
end

local function on_player_change(event)
	if not InitState then return end
	if not InitState.configured then Init.state_tick() end -- new game cutscene before ticks
	-- With on_player_changed_force, old force doesn't get any changes
	wisp_player_aggression_set(game.players[event.player_index].force)
end


------------------------------------------------------------
-- Console command-line Interface
------------------------------------------------------------

local cmd_help = [[
zone update - Scan all chunks on the map for will-o-wisp spawning zones.
zone rescan - Same as "zone update", but force-rescan all chunks, not just fill-in missing ones.
zone stats - Print pollution and misc other stats for scanned zones to console.
zone labels [n] - Add map labels to all found forest spawning zones.
... Parameter (double, default=0.005) is a min threshold to display a spawn chance number in the label.
zone labels remove - Remove map labels from scanned zones.
zone spawn [n] - Spawn wisps in the forested map zones.
... Parameter (integer, default=1) sets how many spawn-cycles to simulate.
incidents - Add map labels for last wisp aggression-change incidents.
incidents remove - Remove map labels for wisp aggression incidents.
attack - Have all will-o-wisps on the map turn hostile towards player(s).
congregate - Find green wisps ground and send them to players base.
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
		player.print('--- Usage: /wisp [command...]')
		player.print('Supported subcommands:')
		for line in cmd_help:gmatch('%s*%S.-\n') do player.print('  '..line:sub(1, -2)) end
		player.print('[use /clear command to clear long message outputs like above]')
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
		elseif cmd == 'rescan' then zones.full_update(true)
		elseif cmd == 'stats' then zones.print_stats(player.print)
		elseif cmd == 'labels' then
			if args[3] ~= 'remove' then
				local label_threshold = tonumber(args[3] or '0.005')
				zones.forest_labels_add(InitState.surface, player.force, label_threshold)
			else zones.forest_labels_remove(player.force) end
		elseif cmd == 'spawn' then
			local cycles = tonumber(args[3] or '1')
			local ticks = cycles * conf.intervals.spawn_on_map
			player.print(
				('Simulating %d spawn-cycle(s) (%s [%s ticks] of night time)')
				:format(cycles, utils.fmt_ticks(ticks), utils.fmt_n_comma(ticks)) )
			for n = 1, cycles do tasks_monolithic.spawn_on_map(InitState.surface) end
		else return usage() end
	elseif cmd == 'incidents' then
		wisp_incident_labels(MapStats.incidents, args[2] == 'remove')
	elseif cmd == 'congregate' then tasks_monolithic.congregate(InitState.surface)
	elseif cmd == 'attack' then wisp_aggression_set(InitState.surface, true)
	elseif cmd == 'radicalize' then tasks_monolithic.radicalize(InitState.surface)
	elseif cmd == 'peace' then wisp_aggression_stop(InitState.surface)
	elseif cmd == 'stats' then wisp_print_stats(player.print)
	else return usage() end
end


------------------------------------------------------------
-- Init / updates / settings
------------------------------------------------------------
Init = {} -- to allow defining/calling these in any order

function Init.settings(event)
	utils.log(' - Updating runtime options')

	local key, knob, v = event and event.setting
	local function key_update(k, k_conf, v_invert)
		if key and key ~= k then return end
		utils.log('  - updating key: %s - %s %s', k, settings.global[k].value, '-')
		if k_conf then
			v = settings.global[k].value
			if v_invert then v = not v end
			if conf[k_conf] == v then return end
			utils.log('   - conf key %s: %s -> %s %s', k_conf, conf[k_conf], v, ':')
			conf[k_conf] = v
		end
		return settings.global[k]
	end

	knob = key_update('wisps-can-attack', 'peaceful_wisps', true)
	if knob then
		local wa = game.forces.wisp_attack
		if conf.peaceful_wisps then
			for _, force in ipairs(get_player_forces()) do wa.set_cease_fire(force, true) end
			wisp_aggression_stop(InitState.surface)
		else
			for _, force in ipairs(get_player_forces()) do wa.set_cease_fire(force, false) end
		end
	end

	knob = key_update('defences-shoot-wisps', 'peaceful_defences', true)
	if knob then for _, force in ipairs(get_player_forces()) do
		force.set_cease_fire(game.forces.wisp, conf.peaceful_defences)
	end end

	knob = key_update('purple-wisp-damage', 'peaceful_spores', true)
	if knob then
		-- Replace all existing spores with harmless/corroding variants
		local proto, surface, pos = wisp_spore_proto_name()
		for n, wisp in ipairs(Wisps) do
			if not wisp.entity.valid
					or not wisp_spore_proto_check(wisp.entity.name)
				then goto skip end
			surface, pos = wisp.entity.surface, wisp.entity.position
			wisp.entity.destroy()
			wisp = wisp_create(proto, surface, pos, wisp.ttl, n)
		::skip:: end
	end

	knob = key_update('wisp-biter-aggression', 'wisp_biter_aggression')
	if knob then wisp_biter_aggression_set() end

	key_update('wisp-death-retaliation-radius', 'wisp_death_retaliation_radius')
	key_update('wisp-aggro-on-player-only', 'wisp_aggro_on_player_only')
	key_update('wisp-aggression-factor', 'wisp_aggression_factor')
	key_update('wisp-map-spawn-count', 'wisp_max_count')
	key_update('wisp-map-spawn-pollution-factor', 'wisp_forest_spawn_pollution_factor')

	local wisp_spawns_sum = 0
	for _, c in ipairs{'purple', 'yellow', 'red', 'green'} do
		local k, k_conf = 'wisp-map-spawn-'..c, 'wisp_forest_spawn_chance_'..c
		key_update(k, k_conf)
		wisp_spawns_sum = wisp_spawns_sum + conf[k_conf]
	end
	if wisp_spawns_sum > 1 then
		for _, c in ipairs{'purple', 'yellow', 'red', 'green'} do
			local k = 'wisp_forest_spawn_chance_'..c
			conf[k] = conf[k] / wisp_spawns_sum
		end
	end
end

function Init.globals()
	utils.log('Init: globals')
	local sets = utils.t([[
		wisps wisp_drones wisp_congregations
		uv_lights detectors wisp_attack_entities ]])
	for k, _ in pairs(utils.t([[
			wisps wisp_drones wisp_congregations wisp_attack_entities
			uv_lights detectors zones map_stats work_steps init_state ]])) do
		if global[k] then goto skip end
		global[k] = {}
		if sets[k] and not global[k].n then global[k].n = #(global[k]) end
	::skip:: end
	if not global.conf then global.conf = {} end
	for k, v in pairs(conf_base) do global.conf[k] = v end
	zones.init_globals(global.zones)
end

function Init.refs()
	-- "strict mode" hack to find local vars that are used globally or without initialization
	-- Enabled here, it should apply to all runtime scripts of the mod, but not to any other mods
	-- Suggested by Pi-C, made by eradicator, very useful to detect "missing local/var" bugs
	utils.log('Init: strict mode switch')
	setmetatable(_ENV, {
		__newindex = function(self, key, value)
			error('\n\n[ENV Error] Forbidden global *write*:\n'
				..serpent.line{key=key or '<nil>', value=value or '<nil>'}..'\n') end,
		__index = function(self, key)
			if key == 'game' then return end -- used in utils.log check
			error('\n\n[ENV Error] Forbidden global *read*:\n'
				..serpent.line{key=key or '<nil>'}..'\n') end })

	utils.log('Init: refs')
	conf, InitState = global.conf, global.init_state
	Wisps, WispDrones = global.wisps, global.wisp_drones
	WispCongregations = global.wisp_congregations
	UVLights, Detectors = global.uv_lights, global.detectors
	WispAttackEntities = global.wisp_attack_entities
	MapStats, WorkSteps = global.map_stats, global.work_steps
	WorkSets = { detectors=Detectors,
		uv=UVLights, recongregate=WispCongregations,
		expire_uv=Wisps, expire_ttl=Wisps }
	WorkChecks = {
		spawn_near_players='dark', spawn_on_map='dark',
		tactics='dark', congregate='dark', radicalize='dark',
		zones_spread='light', zones_forest='light',
		uv='wisps', recongregate='wisps', pacify='wisps' }
	utils.log(
		' - Object stats: wisps=%s drones=%s uvs=%s detectors=%s%s',
		Wisps and Wisps.n, WispDrones and WispDrones.n,
		UVLights and UVLights.n, Detectors and Detectors.n, '' )
	zones.init_refs(global.zones)
end

function Init.state_reset()
	for k, _ in pairs(InitState) do InitState[k] = nil end
end

function Init.state_tick()
	utils.log('Init: state')
	InitState.surface = game.surfaces[conf.surface_name]
	Init.settings()

	-- XXX: scan_new_chunks on some reasonable interval
	-- chunks_new = zones.scan_new_chunks(InitState.surface)
	zones.refresh_chunks(InitState.surface)

	if InitState.update then
		if InitState.update_versions then
			local v_old, v_new = table.unpack(InitState.update_versions)
			local v_old_int = utils.version_to_num(v_old)
			local function version_less_than(ver)
				if v_old_int < utils.version_to_num(ver)
					then utils.log(' - Applying mod update from pre-'..ver); return true end
			end

			if version_less_than('0.1.3') then
				for _, force in ipairs(get_player_forces()) do wisp_player_aggression_set(force) end
			end
			if version_less_than('0.1.6') then wisp_biter_aggression_set() end
			if version_less_than('0.3.2') then
				for _, force in ipairs(get_player_forces()) do wisp_player_aggression_set(force) end
			end
		end

		for _, force in pairs(game.forces) do
			if InitState.update_versions then force.reset_recipes() end
			if force.technologies['alien-bio-technology'].researched then
				force.recipes['alien-flora-sample'].enabled = true
				force.recipes['wisp-detector'].enabled = true
			end
			if force.technologies['solar-energy'].researched
				then force.recipes['UV-lamp'].enabled = true end
			if force.technologies['combat-robotics'].researched
				then force.recipes['wisp-drone-blue-capsule'].enabled = true end
		end
	end

	InitState.configured = true
end


commands.add_command('wisp', run_wisp_command(), run_wisp_command)

script.on_load(function()
	utils.log('[will-o-wisps] Loading game...')
	Init.refs()
	utils.log('[will-o-wisps] Game load: done')
end)

script.on_configuration_changed(function(data)
	utils.log('[will-o-wisps] Resetting init state flags')

	Init.globals()
	Init.refs() -- repeat for new globals and such
	Init.state_reset()

	local update = data.mod_changes and data.mod_changes[script.mod_name]
	if update then
		InitState.update = true
		if update.old_version then
			local v_old, v_new = update.old_version, update.new_version
			InitState.update_versions = {v_old, v_new}
		end
	end

	utils.log('[will-o-wisps] Init state flags: %s', InitState)
end)

script.on_init(function()
	utils.log('[will-o-wisps] Initializing mod for a new game...')

	Init.globals()
	Init.refs()

	utils.log('Init wisps force...')
	wisp_force_init('wisp')
	wisp_force_init('wisp_attack')
	for _, force in ipairs(get_player_forces()) do wisp_player_aggression_set(force) end
	wisp_biter_aggression_set()

	utils.log('[will-o-wisps] Game init: done')
end)

-- Multiple script.on_nth_tick use same handler via tick_handlers dispatcher
for ev, tick in pairs(conf_base.intervals) do
	if tick_handlers[tick] then
		error(('BUG: duplicate tick handlers: "%s" and "%s"'):format(ev, tick_handlers[tick]))
	end
	tick_handlers[tick] = ev
	script.on_nth_tick(tick, on_nth_tick)
end

script.on_event(defines.events.on_entity_died, on_death)
script.on_event(defines.events.on_pre_player_mined_item, on_mined_entity)
script.on_event(defines.events.on_robot_pre_mined, on_mined_entity)
script.on_event(defines.events.on_built_entity, on_built_entity)
script.on_event(defines.events.on_robot_built_entity, on_built_entity)
script.on_event(defines.events.on_chunk_generated, on_chunk_generated)
script.on_event(defines.events.on_trigger_created_entity, on_trigger_created)
script.on_event(defines.events.on_player_used_capsule, on_drone_placed)
script.on_event(defines.events.on_player_created, on_player_change)
script.on_event(defines.events.on_player_changed_force, on_player_change)

script.on_event(defines.events.on_runtime_mod_setting_changed, Init.settings)
