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

local function isDark()
	return game.surfaces.nauvis.darkness > conf.min_darkness
end
local function isCold()
	return utils.check_chance(1 - conf.min_darkness * 2)
end
local function isFullOfTerrors()
	return isDark() and
		utils.check_chance(game.surfaces.nauvis.darkness - conf.min_darkness * 8)
end

local function initWisp(entity, ttl)
	entity.force = game.forces['wisps']
	table.insert(Wisps, {entity=entity, ttl=ttl})
end

local function initUvLight(entity)
	table.insert(UvLights, entity)
end

local function isActive(entity)
	local control  = entity.get_control_behavior()
	if control and control.valid then
		return not control.disabled
	end
	return true
end

local function initDetector(entity)
	table.insert(Detectors, entity)
end

local function flash(pos)
	game.surfaces.nauvis.create_entity{name='wisp-flash', position=pos}
end

local function nextPortion(counter, fragmentation)
	if counter < fragmentation then return counter + 1 end
	return 0
end

-- Create new wisp
local function createWisp(wispName, surface, position, ttl)
		local maxDistance = 6
		local step = 0.3
		local pos = surface.find_non_colliding_position(wispName, position, maxDistance, step)
		local newWisp
		if position then
			newWisp = surface.create_entity{
				name=wispName, position=pos, force = game.forces['wisps'] }
			initWisp(newWisp, utils.get_deviation(ttl, conf.wisp_ttl_jitter_sec))
		end
	return newWisp
end

local function setWispsAggression(state)
	if state then return game.forces['wisps'].set_cease_fire(game.forces.player, false) end
	game.forces['wisps'].set_cease_fire(game.forces.player, true)
end

local function createOrJoinGroup(unit, name, radius)
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
			for _, unitNear in pairs(unitsNear) do
				newGroup.add_member(unitNear)
			end
			if game.forces['wisps'].get_cease_fire('player') == false then
				newGroup.set_autonomous()
				newGroup.start_moving()
			end
		end
	end
end

------------------------------------------------------------
-- Circuit utils
------------------------------------------------------------
local function getCircuitInputByWire(entity, signal, wire)
	local net = entity.get_circuit_network(wire)
	if net and net.signals then
		for _, i in pairs(net.signals) do
			if i.signal.name == signal then
				return i.count
			end
		end
	end
	return nil
end

local function getCircuitInput(entity, signal)
	return getCircuitInputByWire(entity, signal, defines.wire_type.red) or
		getCircuitInputByWire(entity, signal, defines.wire_type.green)
end

------------------------------------------------------------
-- Creating new wisps
------------------------------------------------------------

local function tryToCreateYellowWisp(entity)
	if entity and entity.valid then
		if isFullOfTerrors() then
			local wander = {type = defines.command.wander, distraction = defines.distraction.by_damage}
			local wisp = createWisp('wisp-yellow', entity.surface, entity.position, conf.wisp_ttl_yellow)
			wisp.set_command(wander)
		end
	end
end

local function tryToCreatePurpleWisp(entity)
	if entity and entity.valid then
		if isFullOfTerrors() then
			createWisp('wisp-purple', entity.surface, entity.position, conf.wisp_ttl_purple)
		end
	end
end

local function tryToCreateRedWisp(entity)
	if entity and entity.valid then
		if isFullOfTerrors() then
			local wander = {type=defines.command.wander, distraction=defines.distraction.by_damage}
			local wisp = createWisp('wisp-red', entity.surface, entity.position, conf.wisp_ttl_yellow)
			wisp.set_command(wander)
		end
	end
end

------------------------------------------------------------
-- Event handlers
------------------------------------------------------------

local function onDeathHandler(event)
	if not GlobalEnabled then return end
	if entity_is_tree(event.entity) then tryToCreateYellowWisp(event.entity) end
	if entity_is_rock(event.entity) then tryToCreateRedWisp(event.entity) end
	if entity_is_wisp(event.entity) then
		setWispsAggression(true)
		createWisp('wisp-purple', event.entity.surface, event.entity.position, conf.wisp_ttl_purple)
	end
end

local function onMinedHandler(event)
	if not GlobalEnabled then return end
	if entity_is_tree(event.entity) then tryToCreateYellowWisp(event.entity) end
	if entity_is_rock(event.entity) then tryToCreateRedWisp(event.entity) end
end

local function onTickHandler(event)
	if not GlobalEnabled then return end

	local tick = event.tick
	local isDarkVal = isDark()
	local isColdVal = isCold()
	local isFullOfTerrorsVal = isFullOfTerrors()

	--------------------------------------
	-- Long night mods support
	--------------------------------------
	if tick % 256 and not isDarkVal then
		RecentDayTime = tick
	end

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
			if conf.reset_aggression_at_night then setWispsAggression(false) end
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
				for _, tree in pairs(trees) do tryToCreateYellowWisp(tree) end
			end
			-- wisp spawning in random forests
			if #Wisps < conf.wisp_max_count * conf.wisp_wandering_percent then
				local trees = targeting.getTreesEverywhere()
				if trees then
					for _, tree in pairs(trees) do
						if utils.check_chance(conf.wisp_purple_spawn_chance) then tryToCreatePurpleWisp(tree)
						elseif utils.check_chance(conf.wisp_yellow_spawn_chance) then tryToCreateYellowWisp(tree)
						elseif utils.check_chance(conf.wisp_red_spawn_chance) then tryToCreateRedWisp(tree) end
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
			StepDTCT = nextPortion(StepDTCT, conf.detection_fragm)
			for key, detector in pairs(Detectors) do
				if (key % conf.detection_fragm == StepDTCT) then
					if detector.valid then
						local yellowCount = 0
						local redCount = 0
						local sporesCount = 0

						local range = getCircuitInput(detector, 'signal-R')
						if range then
							range = math.abs(range)
							if range > 128 then
								range = 128
							end
						else
							range = conf.detection_range
						end

						if next(Wisps) ~= nil then
							local wisps = game.surfaces.nauvis.find_entities_filtered{
								force='wisps', area=utils.get_area(detector.position, range) }
							if next(wisps) ~= nil then
								for _, wisp in pairs(wisps) do
									if wisp.name == 'wisp-yellow' then
										yellowCount = yellowCount + 1
									else
										redCount = redCount + 1
									end
								end
							end
							sporesCount = game.surfaces.nauvis.count_entities_filtered{
								name='wisp-purple', area=utils.get_area(detector.position, range) }
						end

						local wispsCount = redCount + yellowCount + sporesCount
						local params =  {parameters=
							{
								{index=1,signal={type='item',name='wisp-red'},count=redCount},
								{index=2,signal={type='item',name='wisp-yellow'},count=yellowCount},
								{index=3,signal={type='item',name='wisp-purple'},count=sporesCount}
							}}

						detector.get_control_behavior().parameters = params
					else
						table.remove(Detectors, key)
					end
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
				StepLIGTH = nextPortion(StepLIGTH, conf.wisp_light_fragm)
				for key, wisp in pairs(Wisps) do
					if ( (key % conf.wisp_light_fragm == StepLIGTH) and wisp.entity.valid )
						and ( conf.wisp_purple_emit_light or wisp.entity.name ~= 'wisp-purple' )
						and wisp.ttl > 64 then flash(wisp.entity.position) end
				end
			end
		end

		--------------------------------------
		-- UV lights
		--------------------------------------
		if next(UvLights) ~= nil then
			if tick % conf.uv_check_interval == 0 then
				StepUV = nextPortion(StepUV, conf.uv_check_fragm)
				for key, uv in pairs(UvLights) do
					if (key % conf.uv_check_fragm == StepUV) then
						if uv.valid then
							if isActive(uv) then
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
											if utils.check_chance(energyPercent - 0.55) then spore.destroy() end
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
			StepTTL = nextPortion(StepTTL, conf.ttl_check_fragm)
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
							-- chance to nullify TTL at day
							if not isDarkVal and not isColdVal then
								wisp.ttl = 0
								-- peaceful wisps - on
								setWispsAggression(false)
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
							createOrJoinGroup(wisp.entity, 'wisp-yellow', 16)
						elseif wisp.entity.name == 'wisp-red' then
							createOrJoinGroup(wisp.entity, 'wisp-red', 6)
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
			StepGC = nextPortion(StepGC, conf.gc_fragm)
			for key, wisp in pairs(Wisps) do
				if (key % conf.gc_fragm == StepGC) and not wisp.entity.valid then
					-- remove forcibly destroyed wisps
					table.remove(Wisps, key)
				end
			end
		end

	end --next(Wisps) ~= nil

end

local function onCreatedHandler(entity)
	if entity.name == 'wisp-purple' then
		initWisp(entity, utils.get_deviation(conf.wisp_ttl_purple, conf.wisp_ttl_jitter_sec))
		return
	end
	if entity.name == 'wisp-yellow' then
		initWisp(entity, utils.get_deviation(conf.wisp_ttl_yellow, conf.wisp_ttl_jitter_sec))
		return
	end
	if entity.name == 'wisp-red' then
		initWisp(entity, utils.get_deviation(conf.wisp_ttl_yellow, conf.wisp_ttl_jitter_sec))
	end
end

local function onTriggerCreatedHandler(event)
	if utils.check_chance(conf.wisp_replication_chance) then
		local entity = event.entity
		onCreatedHandler(entity)
	else
		event.entity.destroy()
	end
end

local function onBuiltHandler(event)
	local entity = event.created_entity
	if entity.name == 'UV-lamp' then
		initUvLight(entity)
		return
	end

	if entity.name == 'wisp-detector' then
		initDetector(entity)
		return
	end

	if entity.name == 'wisp-purple' then
		-- recreate wisp to change force of damage
		local pos = entity.position
		local surface = entity.surface
		entity.destroy()
		local wisp =  createWisp('wisp-purple', surface, pos, conf.wisp_ttl_purple)
	else
		onCreatedHandler(entity)
	end
end

local function onChunkGeneratedHandler(event)
	if event.surface.index == 1 then
		Chunks[#Chunks + 1] = {area=event.area, ttu=-1}
	end
end

------------------------------------------------------------
-- Init
------------------------------------------------------------
local function updateRecipes(withReset)
	for _, force in pairs(game.forces) do
		if withReset then force.reset_recipes() end
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

local function initWispsForce()
	utils.log('Init wisps force..')
	if not game.forces['wisps'] then
		game.create_force('wisps')
		game.forces['wisps'].ai_controllable = true
	end
	game.forces['wisps'].set_cease_fire(game.forces.player, true) -- setWispsAggression(false)
	game.forces['player'].set_cease_fire(game.forces.wisps, false)
	game.forces['wisps'].set_cease_fire(game.forces.enemy, true)
	game.forces['enemy'].set_cease_fire(game.forces.wisps, true)
end

local function initChunksMap()
	utils.log(' - reloading chunks..')
	local surface = game.surfaces.nauvis
	for chunk in surface.get_chunks() do
		onChunkGeneratedHandler{
			surface = surface,
			area = { left_top={chunk.x*32, chunk.y*32},
				right_bottom={(chunk.x+1)*32, (chunk.y+1)*32}} }
	end
end

local function initRefs()
	utils.log('Init local references to globals..')
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

local function onLoad()
	utils.log('Just loading game..')
	initRefs()
end

local function verToNum(ver)
	-- removes all non-digits
	ver = string.gsub(ver, '%D', '')
	return tonumber(ver)
end

local function verLessThan(ver, lessThan)
	if verToNum(ver) < verToNum(lessThan) then
		utils.log('  - Update from pre-'..lessThan)
		return true
	end
	return false
end

local function updateVersion(old_v, new_v)
	if verLessThan(old_v, '0.0.3') then
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

local function onConfigChanged(data)
	utils.log('Reconfiguring:')
	initChunksMap()
	local this = 'Will-o-the-Wisps_updated'

	if data.mod_changes then
		if data.mod_changes[this] then
			if data.mod_changes[this].old_version then
				local oldVer = data.mod_changes[this].old_version
				local newVer = data.mod_changes[this].new_version
				utils.log(' - Will-o-the-Wisps updated: '..oldVer..' -> '..newVer)
				updateRecipes(true)
				updateVersion(oldVer, newVer)
			else
				utils.log(' - Init Will-o-the-Wisps mod on existing game.')
				updateRecipes()
			end
		else
			-- some other mod was added, removed or modified
		end
	end
	utils.log('Done.')
end

local function onInit()
	utils.log('Init globals..')
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

	initRefs()
	initWispsForce()
end

script.on_init(onInit)
script.on_load(onLoad)
script.on_configuration_changed(onConfigChanged)
script.on_event(defines.events.on_chunk_generated, onChunkGeneratedHandler)
script.on_event(defines.events.on_entity_died, onDeathHandler)
script.on_event(defines.events.on_pre_player_mined_item, onMinedHandler)
script.on_event(defines.events.on_robot_pre_mined, onMinedHandler)
script.on_event(defines.events.on_tick, onTickHandler)
script.on_event(defines.events.on_robot_built_entity, onBuiltHandler)
script.on_event(defines.events.on_built_entity, onBuiltHandler)
script.on_event(defines.events.on_trigger_created_entity, onTriggerCreatedHandler)
