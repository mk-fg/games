-- Main entry point file, (re-)loaded on every new game start or savegame load.

local conf = require('config')
local utils = require('libs/utils')
local targeting = require('libs/targeting')


-- local references to globals
local Wisps
local Chunks
local Forests
local UvLights
local GlobalEnabled
local Detectors

local ws


------------------------------------------------------------
-- Wisp utils
------------------------------------------------------------

local function entity_is_tree(e) return e.type == 'tree' end
local function entity_is_rock(e)
	-- Match any entities with separate "rock" word in it, and not e.g. "rocket"
	return e.name == 'rock' or (
		e.name:match('rock') and e.name:match('%W?rock%W?') ~= 'rock' )
end
local function entity_is_wisp(e)
	return e.name == 'wisp-red' or e.name == 'wisp-yellow'
end

local function night_is_dark() -- darkness above min threshold for wisps
	return game.surfaces.nauvis.darkness > conf.min_darkness
end
local function night_is_cold() -- sets chance of wisps disappearing and going peaceful
	return utils.pick_chance(1 - conf.min_darkness * 2)
end
local function night_is_full_of_terrors() -- chance of wisps appearing
	return night_is_dark() and
		utils.pick_chance(game.surfaces.nauvis.darkness - conf.min_darkness * 8)
end

local wisp_spore_proto = 'wisp-purple'
local function wisp_spore_proto_check(name) return name:match('^wisp%-purple') end

local wisp_init_ttl_values = {
	['wisp-purple']=conf.wisp_ttl_purple,
	['wisp-purple-harmless']=conf.wisp_ttl_purple,
	['wisp-yellow']=conf.wisp_ttl_yellow,
	['wisp-red']=conf.wisp_ttl_red }

local function wisp_init(entity, ttl, key)
	if not ttl then
		ttl = wisp_init_ttl_values[entity.name]
		if not ttl then return end -- not a wisp
		ttl = utils.add_jitter(ttl, conf.wisp_ttl_jitter_sec)
	end
	entity.force = game.forces.wisps
	local wisp = {entity=entity, ttl=ttl}
	if not key then table.insert(Wisps, wisp) else Wisps[key] = wisp end
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
	-- Create wisp based on night_is_full_of_terrors() chance
	local e = near_entity
	if not (e and e.valid and night_is_full_of_terrors()) then return end
	e = wisp_create(name, e.surface, e.position)
	if e and not wisp_spore_proto_check(name) then
		e.set_command{
			type=defines.command.wander,
			distraction=defines.distraction.by_damage }
	end
end

local wisp_light_opts = {['wisp-yellow']=4, ['wisp-red']=3, ['wisp-purple']=4}
local function wisp_light(name, pos)
	if conf.wisp_lights_dynamic then
		name = string.format('%s-light-%02d', name, math.random(wisp_light_opts[name]))
	else name = 'wisp-light-generic' end
	game.surfaces.nauvis.create_entity{name=name, position=pos}
end

local function wisp_aggression_set(state)
	if not conf.peaceful_wisps and state then
		return game.forces.wisps.set_cease_fire(game.forces.player, false)
	end
	game.forces.wisps.set_cease_fire(game.forces.player, true)
end

local function wisp_group_create_or_join(unit, name, radius)
	local pos = unit.position
	local unitsNear = game.surfaces.nauvis
		.find_entities_filtered{name=name, area=utils.get_area(pos, radius)}
	if next(unitsNear) ~= nil and #unitsNear > 1  then
		local leader = true
		for _, unitNear in pairs(unitsNear) do
			if unitNear.unit_group ~= nil then
				unitNear.unit_group.add_member(unit)
				leader = false
				break
			end
		end
		if leader then
			local newGroup = game.surfaces.nauvis
				.create_unit_group{position=pos, force=game.forces.wisps}
			newGroup.add_member(unit)
			for _, unitNear in pairs(unitsNear) do newGroup.add_member(unitNear) end
			if game.forces.wisps.get_cease_fire('player') == false then
				newGroup.set_autonomous()
				newGroup.start_moving()
			end
		end
	end
end

local function uv_light_init(entity) table.insert(UvLights, entity) end
local function uv_light_active(entity)
	local control  = entity.get_control_behavior()
	if control and control.valid then return not control.disabled end
	return true
end

local function detector_init(entity) table.insert(Detectors, entity) end

local function next_work_step(key, tick)
	local tick_match = true
	if tick then tick_match = tick % conf.intervals[key] == 0 end
	if tick_match then
		local n, limit = (ws[key] or -1) + 1, conf.work_steps[key]
		if n >= limit then n = 0 end
		ws[key] = n
		return tick_match, n, limit
	else return tick_match end
end

------------------------------------------------------------
-- Circuit utils
------------------------------------------------------------
local function getCircuitInputByWire(entity, signal, wire)
	local net = entity.get_circuit_network(wire)
	if net and net.signals then
		for _, i in pairs(net.signals) do
			if i.signal.name == signal then return i.count end
		end
	end
	return nil
end

local function getCircuitInput(entity, signal)
	return getCircuitInputByWire(entity, signal, defines.wire_type.red) or
		getCircuitInputByWire(entity, signal, defines.wire_type.green)
end

------------------------------------------------------------
-- Event handlers
------------------------------------------------------------

local function on_death(event)
	if not GlobalEnabled then return end
	if entity_is_tree(event.entity) then wisp_create_at_random('wisp-yellow', event.entity) end
	if entity_is_rock(event.entity) then wisp_create_at_random('wisp-red', event.entity) end
	if entity_is_wisp(event.entity) then
		wisp_aggression_set(true)
		wisp_create(wisp_spore_proto, event.entity.surface, event.entity.position)
	end
end

local function on_mined_entity(event)
	if not GlobalEnabled then return end
	if entity_is_tree(event.entity) then wisp_create_at_random('wisp-yellow', event.entity) end
	if entity_is_rock(event.entity) then wisp_create_at_random('wisp-red', event.entity) end
end

local function on_tick(event) -- god function
	if not GlobalEnabled then return end

	local isColdVal = night_is_cold()
	local isDarkVal = night_is_dark()
	local isFullOfTerrorsVal = night_is_full_of_terrors()

	local tick, mark, step, mod = event.tick

	--------------------------------------
	-- Day/night cycle
	--------------------------------------
	if not isDarkVal and tick % conf.intervals.targeting == 0
		then targeting.prepareTarget() end

	if isDarkVal then
		--------------------------------------
		-- Spawn at night
		--------------------------------------
		-- wisp creation routine
		if tick % conf.intervals.wisp_spawn == 0 then
			-- wisp spawning near players
			if #Wisps < conf.wisp_max_count then
				local trees = targeting.getTreesNearPlayers()
				for _, tree in pairs(trees) do wisp_create_at_random('wisp-yellow', tree) end
			end
			-- wisp spawning in random forests
			if #Wisps < conf.wisp_max_count * conf.wisp_wandering_percent then
				local trees = targeting.getTreesEverywhere()
				if trees then
					for _, tree in pairs(trees) do
						local name = utils.pick_chance{
							[wisp_spore_proto]=conf.wisp_purple_spawn_chance,
							['wisp-yellow']=conf.wisp_yellow_spawn_chance,
							['wisp-red']=conf.wisp_red_spawn_chance }
						if name then wisp_create_at_random(name, tree) end
					end
				end
			end
		end
	end

	--------------------------------------
	-- Detectors
	-------------------------------------
	if next(Detectors) ~= nil then
		local mark, step, mod = next_work_step('detectors', tick)
		if mark then
			for key, detector in pairs(Detectors) do
				if key % mod == step then
					if detector.valid then
						local yellowCount = 0
						local redCount = 0
						local sporesCount = 0

						local range = getCircuitInput(detector, 'signal-R')
						if range then
							range = math.abs(range)
							if range > 128 then range = 128
							end
						else range = conf.detection_range end

						if next(Wisps) ~= nil then
							local wisps = game.surfaces.nauvis.find_entities_filtered{
								force='wisps', area=utils.get_area(detector.position, range) }
							if next(wisps) ~= nil then
								for _, wisp in pairs(wisps) do
									if wisp.name == 'wisp-yellow' then yellowCount = yellowCount + 1
									else redCount = redCount + 1
									end
								end
							end
							sporesCount = game.surfaces.nauvis.count_entities_filtered{
								name=wisp_spore_proto, area=utils.get_area(detector.position, range) }
						end

						local wispsCount = redCount + yellowCount + sporesCount
						local params = {parameters={
							{index=1, signal={type='item', name='wisp-red'}, count=redCount},
							{index=2, signal={type='item', name='wisp-yellow'}, count=yellowCount},
							{index=3, signal={type='item', name=wisp_spore_proto}, count=sporesCount} }}

						detector.get_control_behavior().parameters = params
					else table.remove(Detectors, key) end
				end
			end
		end
	end

	--------------------------------------
	-- Control wisps
	--------------------------------------
	if next(Wisps) ~= nil then
		--------------------------------------
		-- Each wisp emits light
		--------------------------------------
		if isDarkVal or isFakeDayVal then
			local mark, step, mod = next_work_step('light', tick)
			if mark then
				for key, wisp in pairs(Wisps) do
					if (key % mod == step and wisp.entity.valid)
						and (conf.wisp_spore_emit_light or not wisp_spore_proto_check(wisp.entity.name))
						and wisp.ttl > 64 then wisp_light(wisp.entity.name, wisp.entity.position) end
				end
			end
		end

		--------------------------------------
		-- UV lights
		--------------------------------------
		if next(UvLights) ~= nil then
			local mark, step, mod = next_work_step('uv', tick)
			if mark then
				for key, uv in pairs(UvLights) do
					if key % mod == step then
						if uv.valid then
							if uv_light_active(uv) then
								local energyPercent = uv.energy * 0.00007 -- /14222

								if energyPercent > 0.2 then
									local wisps = game.surfaces.nauvis.find_entities_filtered{
										force='wisps', type='unit', area=utils.get_area(uv.position, conf.uv_range) }
									if next(wisps) ~= nil then
										local currentUvDmg = (conf.uv_dmg + math.random(3)) * energyPercent
										for _, wisp in pairs(wisps) do
											wisp.damage(math.floor(currentUvDmg), game.forces.player, 'fire')
										end
									end

									if energyPercent > 0.6 then
										local spores = game.surfaces.nauvis.find_entities_filtered{
											name='wisp-purple', area=utils.get_area(uv.position, conf.uv_range) }
										if next(spores) ~= nil then for _, spore in pairs(spores) do
											if utils.pick_chance(energyPercent - 0.55) then spore.destroy() end
										end end
									end
								end

							end
						else table.remove(UvLights, key) end
					end
				end --for
				-- only one the low-priority routine per tick
				return
			end
		end -- next(UvLights) ~= nil

		--------------------------------------
		-- Wisp TTL routine
		--------------------------------------
		local mark, step, mod = next_work_step('ttl', tick)
		if mark then
			for key, wisp in pairs(Wisps) do
				if key % mod == step then
					if wisp.entity.valid then
						if wisp.ttl  <= 0 then
							-- remove wisps by TTL expiration
							wisp.entity.destroy()
							table.remove(Wisps, key)
						else
							-- TTL decrease with chance to skip iteration at night
							if not isFullOfTerrorsVal then wisp.ttl = wisp.ttl - conf.intervals.ttl end
							-- Chance to nullify TTL at day
							if not isDarkVal and not isColdVal then
								wisp.ttl = 0
								wisp_aggression_set(false)
							end
						end
					else
						-- remove forcibly destroyed wisps
						table.remove(Wisps, key)
					end
				end
			end
			-- only one the low-priority routine per tick
			return
		end

		--------------------------------------
		-- Time to find a company!
		--------------------------------------
		if tick % conf.intervals.tactical == 0 then
			if isDarkVal then
				local wisp = Wisps[math.random(#Wisps)]
				if wisp.entity.valid and wisp.entity.type == 'unit' then
					if wisp.entity.unit_group == nil and wisp.ttl > conf.intervals.ttl then
						if wisp.entity.name == 'wisp-yellow' then
							wisp_group_create_or_join(wisp.entity, 'wisp-yellow', 16)
						elseif wisp.entity.name == 'wisp-red' then
							wisp_group_create_or_join(wisp.entity, 'wisp-red', 6)
						end
					end
				end
			end
			-- only one the low-priority routine per tick
			return
		end

		if conf.experimental then
			--------------------------------------
			-- Sabotage
			--------------------------------------
			if tick % conf.intervals.sabotage ~= 0 then
				local wisp = Wisps[math.random(#Wisps)]
				if wisp.entity.valid and wisp.entity.name == 'wisp-purple' then
					local poles = game.surfaces.nauvis.find_entities_filtered{
						type='electric-pole', limit=1,
						area=utils.get_area(wisp.entity.position, conf.sabotage_range) }
					if next(poles) ~= nil then
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
				-- only one the low-priority routine per tick
				return
			end
		end

		--------------------------------------
		-- GC
		--------------------------------------
		local mark, step, mod = next_work_step('gc', tick)
		if mark then
			for key, wisp in pairs(Wisps) do
				if key % mod == step and not wisp.entity.valid then
					-- remove forcibly destroyed wisps
					table.remove(Wisps, key)
				end
			end
		end

	end --next(Wisps) ~= nil

end

local function on_trigger_created(event) -- for red wisps replication via trigger_created_entity
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
	UvLights = global.uvLights
	Detectors = global.detectors
	GlobalEnabled = global.enabled
	ws = global.workSteps

	targeting.init(global.chunks, global.forests)
end

local function apply_version_updates(old_v, new_v)
	if utils.version_less_than(old_v, '0.0.3') then
		utils.log('    - Updating TTL/TTU keys in global objects')
		local function remap_key(o, k_old, k_new, default)
			if not o[k_new] then o[k_new], o[k_old] = o[k_old] end
			if not o[k_new] then o[k_new] = default end
			if not o[k_new] then utils.log('Empty value after remap [%s -> %s]: %s', k_old, k_new, o) end
		end
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
end

local function apply_runtime_settings(event)
	local key, knob = event and event.setting
	utils.log('Updating runtime settings (change=%s)...', key or '[init]')
	local function key_update(k) return key and key == k and settings.global[k] end

	knob = key_update('wisps-can-attack')
	if knob then
		conf.peaceful_wisps = not knob.value
		if conf.peaceful_wisps then
			game.forces.wisps.set_cease_fire(game.forces.player, true)
		end
	end

	knob = key_update('defences-shoot-wisps')
	if knob then
		conf.peaceful_defences = not knob.value
		game.forces.player.set_cease_fire(game.forces.wisps, conf.peaceful_defences)
	end

	knob = key_update('purple-wisp-damage')
	if knob then
		local v_old, v = conf.peaceful_spores, not knob.value
		conf.peaceful_spores = v
		if v_old ~= v then
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

	knob = key_update('dynamic-wisp-lights')
	if knob then conf.wisp_lights_dynamic = knob.value end

end


script.on_load(function()
	utils.log('Loading game...')
	init_refs()
	apply_runtime_settings()
end)


script.on_configuration_changed(function(data) -- new game/mod version
	utils.log('Reconfiguring...')

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
	global.enabled = true

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
