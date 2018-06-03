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

local StepLIGTH
local StepTTL
local StepGC
local StepUV
local StepDTCT
local RecentDayTime


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

local wisp_init_ttl_values = {
	['wisp-purple']=conf.wisp_ttl_purple,
	['wisp-yellow']=conf.wisp_ttl_yellow,
	['wisp-red']=conf.wisp_ttl_red }

local function wisp_init(entity, ttl)
	if not ttl then
		ttl = wisp_init_ttl_values[entity.name]
		if not ttl then return end -- not a wisp
		ttl = utils.add_jitter(ttl, conf.wisp_ttl_jitter_sec)
	end
	entity.force = game.forces['wisps']
	table.insert(Wisps, {entity=entity, ttl=ttl})
end

local function wisp_create(name, surface, position, ttl)
	local max_distance, step, wisp = 6, 0.3, nil
	local pos = surface.find_non_colliding_position(name, position, max_distance, step)
	if pos then
		wisp = surface.create_entity{
			name=name, position=pos, force=game.forces['wisps'] }
		wisp_init(wisp, ttl)
	end
	return wisp
end

local function wisp_create_at_random(name, near_entity)
	-- Create wisp based on night_is_full_of_terrors() chance
	local e = near_entity
	if not (e and e.valid and night_is_full_of_terrors()) then return end
	e = wisp_create(name, e.surface, e.position)
	if e and name ~= 'wisp-purple' then
		e.set_command{
			type=defines.command.wander,
			distraction=defines.distraction.by_damage }
	end
end

local function wisp_flash(pos)
	game.surfaces.nauvis.create_entity{name='wisp-flash', position=pos}
end

local function wisp_aggression_set(state)
	if state then return game.forces['wisps'].set_cease_fire(game.forces.player, false) end
	game.forces['wisps'].set_cease_fire(game.forces.player, true)
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
				.create_unit_group{position=pos, force=game.forces['wisps']}
			newGroup.add_member(unit)
			for _, unitNear in pairs(unitsNear) do newGroup.add_member(unitNear) end
			if game.forces['wisps'].get_cease_fire('player') == false then
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

local function next_work_fragment(counter, fragmentation)
	if counter < fragmentation then return counter + 1 end
	return 0
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
		wisp_create('wisp-purple', event.entity.surface, event.entity.position)
	end
end

local function on_mined_entity(event)
	if not GlobalEnabled then return end
	if entity_is_tree(event.entity) then wisp_create_at_random('wisp-yellow', event.entity) end
	if entity_is_rock(event.entity) then wisp_create_at_random('wisp-red', event.entity) end
end

local function on_tick(event) -- god function
	if not GlobalEnabled then return end

	local tick = event.tick
	local isColdVal = night_is_cold()
	local isDarkVal = night_is_dark()
	local isFullOfTerrorsVal = night_is_full_of_terrors()

	--------------------------------------
	-- Long night mods support
	--------------------------------------
	if tick % 256 and not isDarkVal then RecentDayTime = tick end

	local nightDuration = tick - RecentDayTime
	local isFakeDayVal = nightDuration > conf.time_fake_night_len
	if isFakeDayVal then
		if conf.time_fake_day_mode then
			-- fake day
			isDarkVal = false
			isColdVal = false
			isFullOfTerrorsVal = false
		end

		if tick % 384 and (
				nightDuration > conf.time_fake_night_len
					* (1 + conf.time_fake_day_mult) ) then
			-- reset fake day
			RecentDayTime = tick
			-- force reset the agressive state of the wisps
			if conf.reset_aggression_at_night then wisp_aggression_set(false) end
		end
	end

	--------------------------------------
	-- Day/night cycle
	--------------------------------------
	if not isDarkVal or isFakeDayVal then
		--------------------------------------
		-- Targeting at day
		--------------------------------------
		if tick % conf.targeting_interval == 0 then targeting.prepareTarget() end
	end

	if isDarkVal then
		--------------------------------------
		-- Spawn at night
		--------------------------------------
		-- wisp creation routine
		if tick % conf.wisp_spawn_interval == 0 then
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
							['wisp-purple']=conf.wisp_purple_spawn_chance,
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
		if tick % conf.detection_interval == 0 then
			StepDTCT = next_work_fragment(StepDTCT, conf.detection_fragm)
			for key, detector in pairs(Detectors) do
				if (key % conf.detection_fragm == StepDTCT) then
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
								name='wisp-purple', area=utils.get_area(detector.position, range) }
						end

						local wispsCount = redCount + yellowCount + sporesCount
						local params =  {parameters={
							{index=1,signal={type='item',name='wisp-red'},count=redCount},
							{index=2,signal={type='item',name='wisp-yellow'},count=yellowCount},
							{index=3,signal={type='item',name='wisp-purple'},count=sporesCount} }}

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
			if tick % conf.wisp_light_interval == 0 then
				StepLIGTH = next_work_fragment(StepLIGTH, conf.wisp_light_fragm)
				for key, wisp in pairs(Wisps) do
					if ( (key % conf.wisp_light_fragm == StepLIGTH) and wisp.entity.valid )
						and ( conf.wisp_purple_emit_light or wisp.entity.name ~= 'wisp-purple' )
						and wisp.ttl > 64 then wisp_flash(wisp.entity.position) end
				end
			end
		end

		--------------------------------------
		-- UV lights
		--------------------------------------
		if next(UvLights) ~= nil then
			if tick % conf.uv_check_interval == 0 then
				StepUV = next_work_fragment(StepUV, conf.uv_check_fragm)
				for key, uv in pairs(UvLights) do
					if (key % conf.uv_check_fragm == StepUV) then
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
		if tick % conf.ttl_check_interval == 0 then
			StepTTL = next_work_fragment(StepTTL, conf.ttl_check_fragm)
			for key, wisp in pairs(Wisps) do
				if (key % conf.ttl_check_fragm == StepTTL) then
					if wisp.entity.valid then
						if wisp.ttl  <= 0 then
							-- remove wisps by TTL expiration
							wisp.entity.destroy()
							table.remove(Wisps, key)
						else
							-- TTL decrease with chance to skip iteration at night
							if not isFullOfTerrorsVal then
								wisp.ttl = wisp.ttl - conf.ttl_check_interval
							end
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
		if tick % conf.tactical_interval == 0 then
			if isDarkVal then
				local wisp = Wisps[math.random(#Wisps)]
				if wisp.entity.valid and wisp.entity.type == 'unit' then
					if wisp.entity.unit_group == nil and wisp.ttl > conf.ttl_check_interval then
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
			if tick % conf.sabotage_interval ~= 0 then
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
		if tick % 16 ~= 0 then
			StepGC = next_work_fragment(StepGC, conf.gc_fragm)
			for key, wisp in pairs(Wisps) do
				if (key % conf.gc_fragm == StepGC) and not wisp.entity.valid then
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
		local pos = entity.position
		local surface = entity.surface
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

	targeting.init(global.chunks, global.forests)
	RecentDayTime = global.recentDayTime

	StepLIGTH = global.stepLIGTH
	StepTTL = global.stepTTL
	StepGC = global.stepGC
	StepUV = global.stepUV
	StepDTCT = global.stepDTCT
end

local function apply_version_updates(old_v, new_v)
	if utils.version_less_than(old_v, '0.0.3') then
		utils.log('    - Updating TTL/TTU keys in global objects')
		local function remap_key(o, k_old, k_new, default)
			if not o[k_new] then o[k_new], o[k_old] = o[k_old], nil end
			if not o[k_new] then o[k_new] = default end
			if not o[k_new] then utils.log('Empty value after remap [%s -> %s]: %s', k_old, k_new, o) end
		end
		for _,wisp in pairs(Wisps) do remap_key(wisp, 'TTL', 'ttl') end
		for _,chunk in pairs(Chunks) do remap_key(chunk, 'TTU', 'ttu') end
		for _,forest in pairs(Forests) do remap_key(forest, 'TTU', 'ttu') end
	end
end


script.on_load(function()
	utils.log('Loading game...')
	init_refs()
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

	global.stepLIGTH = 0
	global.stepTTL = 0
	global.stepGC = 0
	global.stepUV = 0
	global.stepDTCT = 0
	global.recentDayTime = 0

	utils.log('Init wisps force...')
	if not game.forces['wisps'] then
		game.create_force('wisps')
		game.forces['wisps'].ai_controllable = true
	end
	game.forces['wisps'].set_cease_fire(game.forces.player, true)
	game.forces['player'].set_cease_fire(game.forces.wisps, false)
	game.forces['wisps'].set_cease_fire(game.forces.enemy, true)
	game.forces['enemy'].set_cease_fire(game.forces.wisps, true)

	init_refs()
end)


script.on_event(defines.events.on_tick, on_tick)
script.on_event(defines.events.on_entity_died, on_death)
script.on_event(defines.events.on_pre_player_mined_item, on_mined_entity)
script.on_event(defines.events.on_robot_pre_mined, on_mined_entity)
script.on_event(defines.events.on_built_entity, on_built_entity)
script.on_event(defines.events.on_robot_built_entity, on_built_entity)
script.on_event(defines.events.on_chunk_generated, on_chunk_generated)
script.on_event(defines.events.on_trigger_created_entity, on_trigger_created)
