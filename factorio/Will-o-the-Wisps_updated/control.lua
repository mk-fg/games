-------------------------------------------------------------------------
-- Import constants
-------------------------------------------------------------------------
local config = require("config")
local const = require("libs/consts")

local MAX_WISPS_COUNT = config.MAX_WISPS_COUNT
local PURPLE_WISPS_EMIT_LIGHT = config.PURPLE_WISPS_EMIT_LIGHT

local WANDERING_WISP_PERCENT = const.WANDERING_WISP_PERCENT
local TTL_DEVIATION = const.TTL_DEVIATION
local YELLOW_TTL = const.YELLOW_TTL
local PURPLE_TTL = const.PURPLE_TTL
local REPLICATION_CHANCE = const.REPLICATION_CHANCE
local PURPLE_SPAWN_CHANCE = config.PURPLE_SPAWN_CHANCE
local YELLOW_SPAWN_CHANCE = config.YELLOW_SPAWN_CHANCE
local RED_SPAWN_CHANCE = config.RED_SPAWN_CHANCE

local ETERNAL_NIGHT = config.ETERNAL_NIGHT
local FAKE_DAY_MODE = config.FAKE_DAY_MODE
local FAKE_DAY_MULT = config.FAKE_DAY_MULT
local SKIP_AGRESSION_AT_NIGHT = config.SKIP_AGRESSION_AT_NIGHT

local SPAWN_PERIOD = const.SPAWN_PERIOD
local TARGETING_PERIOD = const.TARGETING_PERIOD
local EMIT_LIGHT_PERIOD = const.EMIT_LIGHT_PERIOD
local EMIT_LIGHT_FRAGM = const.EMIT_LIGHT_FRAGM
local TTL_CHECK_PERIOD = const.TTL_CHECK_PERIOD
local TTL_CHECK_FRAGM = const.TTL_CHECK_FRAGM
local GC_FRAGM = const.GC_FRAGM
local UV_CHECK_PERIOD = const.UV_CHECK_PERIOD
local UV_CHECK_FRAGM = const.UV_CHECK_FRAGM
local DETECTION_PERIOD = const.DETECTION_PERIOD
local DETECTION_FRAGM = const.DETECTION_FRAGM
local TACTICAL_PERIOD = const.TACTICAL_PERIOD
local SABOTAGE_PERIOD = const.SABOTAGE_PERIOD
local SABOTAGE_RANGE = const.SABOTAGE_RANGE

local EXPERIMANTAL = const.EXPERIMANTAL

local UV_DMG = const.UV_DMG
local UV_RANGE = const.UV_RANGE
local DTCT_RANGE = const.DTCT_RANGE

-------------------------------------------------------------------------
-- Import utils
-------------------------------------------------------------------------
-- Common utils
local commonUtils = require("libs/common")
local echo = commonUtils.echo
local log = commonUtils.log
local getNauvis = commonUtils.getNauvis

local utils = require("libs/utils")
local isDark = utils.isDark
local isFullOfTerrors = utils.isFullOfTerrors
local isCold = utils.isCold
local getArea = utils.getArea
local getDeviation = utils.getDeviation
local checkChance = utils.checkChance

-- Targeting utils
local targeting = require("libs/targeting")
local getTreesNearPlayers = targeting.getTreesNearPlayers
local getTreesEverywhere = targeting.getTreesEverywhere
local prepareTarget = targeting.prepareTarget

-------------------------------------------------------------------------
-- Vars
-------------------------------------------------------------------------
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

local function initWisp(entity, TTL)
	entity.force = game.forces['wisps']
	table.insert(Wisps, { entity = entity, TTL = TTL } )
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
	getNauvis().create_entity{name="wisp-flash", position=pos}
end

local function nextPortion(counter, fragmentation)
	if counter < fragmentation then
		return counter + 1
	end
	return 0
end

-- Create new wisp
local function createWisp(wispName, surface, position, TTL)
		local maxDistance = 6
		local step = 0.3
		local pos = surface.find_non_colliding_position(wispName, position, maxDistance, step)
		local newWisp
		if position then
			newWisp = surface.create_entity{name=wispName, position=pos, force = game.forces['wisps']}
			local TTL = getDeviation(TTL, TTL_DEVIATION)
			initWisp(newWisp, TTL)
		end
	return newWisp
end

local function setWispsAgression(state)
	if (state) then
		game.forces['wisps'].set_cease_fire(game.forces.player, false)
		return
	end
	game.forces['wisps'].set_cease_fire(game.forces.player, true)
end

local function createOrJoinGroup(unit, name, radius)
	local pos = unit.position
	local unitsNear = getNauvis().find_entities_filtered{name = name, area = getArea(pos, radius)}
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
			local newGroup = getNauvis().create_unit_group{position=pos, force=game.forces['wisps']}
			newGroup.add_member(unit)
			for _, unitNear in pairs(unitsNear) do
				newGroup.add_member(unitNear)
			end
			if game.forces['wisps'].get_cease_fire("player") == false then
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
-- Try to create yellow wisp near entity
local function tryToCreateYellowWisp(entity)
	if entity and entity.valid then
		if isFullOfTerrors() then
			local wander = {type = defines.command.wander, distraction = defines.distraction.by_damage}
			local wisp = createWisp("wisp-yellow", entity.surface, entity.position, YELLOW_TTL)
			wisp.set_command(wander)
		end
	end
end
-- Try to create purple wisp near entity
local function tryToCreatePurpleWisp(entity)
	if entity and entity.valid then
		if isFullOfTerrors() then
			createWisp("wisp-purple", entity.surface, entity.position, PURPLE_TTL)
		end
	end
end
-- Try to create red wisp near entity
local function tryToCreateRedWisp(entity)
	if entity and entity.valid then
		if isFullOfTerrors() then
			local wander = {type = defines.command.wander, distraction = defines.distraction.by_damage}
			local wisp = createWisp("wisp-red", entity.surface, entity.position, YELLOW_TTL)
			wisp.set_command(wander)
		end
	end
end

------------------------------------------------------------
-- Handle events
------------------------------------------------------------
local function onDeathHandler(event)
	if not GlobalEnabled then return end

	if event.entity.type == "tree" then
		tryToCreateYellowWisp(event.entity)
	end

	if event.entity.name == "stone-rock" then
		tryToCreateRedWisp(event.entity)
	end

	--echo("Destroyed by: "..event.force.name)

	if event.force == game.forces['wisps'] then
		if event.entity.type == "electric-pole" then
			--log("pole destroyed by wisps!")
			--poleDestroyedByWisps(event.entity)
		end
	end

	if (event.entity.name == "wisp-yellow") or (event.entity.name == "wisp-red") then
		-- peaceful wisps - off
		setWispsAgression(true)
		-- create spore
		createWisp("wisp-purple", event.entity.surface, event.entity.position, PURPLE_TTL)
	end
end

local function onMinedHandler(event)
	if not GlobalEnabled then return end

	if event.entity.type == "tree" then
		tryToCreateYellowWisp(event.entity)
	end

	if event.entity.name == "stone-rock" then
		tryToCreateRedWisp(event.entity)
	end
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
	local isFakeDayVal = nightDuration > ETERNAL_NIGHT
	if isFakeDayVal then
		if FAKE_DAY_MODE then
			-- fake day
			isDarkVal = false
			isColdVal = false
			isFullOfTerrorsVal = false
		end

		if tick % 384 and (nightDuration > ETERNAL_NIGHT * (1 + FAKE_DAY_MULT)) then
			-- reset fake day
			RecentDayTime = tick
			-- force reset the agressive state of the wisps
			if SKIP_AGRESSION_AT_NIGHT then
				setWispsAgression(false)
			end
		end
	end

	--------------------------------------
	-- Day/night cycle
	--------------------------------------
	if not isDarkVal or isFakeDayVal then
		--------------------------------------
		-- Targeting at day
		--------------------------------------
		if tick % TARGETING_PERIOD == 0 then
			prepareTarget()
		end
	end

	if isDarkVal then
		--------------------------------------
		-- Spawn at night
		--------------------------------------
		-- wisp creation routine
		if tick % SPAWN_PERIOD == 0 then
			-- wisp spawning near players
			if #Wisps < MAX_WISPS_COUNT then
				local trees = getTreesNearPlayers()
				for _, tree in pairs(trees) do
					tryToCreateYellowWisp(tree)
				end
			end
			-- wisp spawning in random forests
			if #Wisps < MAX_WISPS_COUNT * WANDERING_WISP_PERCENT then
				local trees = getTreesEverywhere()
				if trees then
					for _, tree in pairs(trees) do
						if checkChance(PURPLE_SPAWN_CHANCE) then
							tryToCreatePurpleWisp(tree)
						elseif checkChance(YELLOW_SPAWN_CHANCE) then
							tryToCreateYellowWisp(tree)
						elseif checkChance(RED_SPAWN_CHANCE) then
							tryToCreateRedWisp(tree)
						end
					end
				end
			end
		end
	end

	--------------------------------------
	-- Detectors
	-------------------------------------
	if next(Detectors) ~= nil then
		if tick % DETECTION_PERIOD == 0 then
			StepDTCT = nextPortion(StepDTCT, DETECTION_FRAGM)
			for key, detector in pairs(Detectors) do
				if (key % DETECTION_FRAGM == StepDTCT) then
					if detector.valid then
						local yellowCount = 0
						local redCount = 0
						local sporesCount = 0

						local range = getCircuitInput(detector, "signal-R")
						if range then
							range = math.abs(range)
							if range > 128 then
								range = 128
							end
						else
							range = DTCT_RANGE
						end

						if next(Wisps) ~= nil then
							local wisps = getNauvis().find_entities_filtered{force= "wisps", area = getArea(detector.position, range)}
							if next(wisps) ~= nil then
								for _, wisp in pairs(wisps) do
									if wisp.name == "wisp-yellow" then
										yellowCount = yellowCount + 1
									else
										redCount = redCount + 1
									end
								end
							end
							sporesCount = getNauvis().count_entities_filtered{name= "wisp-purple", area = getArea(detector.position, range)}
						end

						local wispsCount = redCount + yellowCount + sporesCount
						local params =  {parameters=
							{
								{index=1,signal={type="item",name="wisp-red"},count=redCount},
								{index=2,signal={type="item",name="wisp-yellow"},count=yellowCount},
								{index=3,signal={type="item",name="wisp-purple"},count=sporesCount}
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
			if tick % EMIT_LIGHT_PERIOD == 0 then
				StepLIGTH = nextPortion(StepLIGTH, EMIT_LIGHT_FRAGM)
				for key, wisp in pairs(Wisps) do
					if (key % EMIT_LIGHT_FRAGM == StepLIGTH) and wisp.entity.valid then
						if PURPLE_WISPS_EMIT_LIGHT or wisp.entity.name ~= "wisp-purple" then
							if wisp.TTL > 64 then
								local pos = wisp.entity.position
								flash(pos)
							end
						end
					end
				end
			end
		end

		--------------------------------------
		-- UV lights
		--------------------------------------
		if next(UvLights) ~= nil then
			if tick % UV_CHECK_PERIOD == 0 then
				StepUV = nextPortion(StepUV, UV_CHECK_FRAGM)
				for key, uv in pairs(UvLights) do
					if (key % UV_CHECK_FRAGM == StepUV) then
						if uv.valid then
							if isActive(uv) then
								local energyPercent = uv.energy * 0.00007 -- /14222
								if energyPercent > 0.2 then
									local wisps = getNauvis().find_entities_filtered{force= "wisps", type = "unit", area = getArea(uv.position, UV_RANGE)}
									if next(wisps) ~= nil then
										local currentUvDmg = (UV_DMG + math.random(3)) * energyPercent
										for _, wisp in pairs(wisps) do
											wisp.damage(math.floor(currentUvDmg), game.forces.player, "fire")
										end
									end

									if energyPercent > 0.6 then
										local spores = getNauvis().find_entities_filtered{name= "wisp-purple", area = getArea(uv.position, UV_RANGE)}
										if next(spores) ~= nil then
											for _, spore in pairs(spores) do
												if checkChance(energyPercent - 0.55) then
													spore.destroy()
												end
											end
										end
									end
								end
							end
						else
							table.remove(UvLights, key)
						end
					end
				end --for
				-- only one the low-priority routine per tick
				return
			end
		end --next(UvLights) ~= nil

		--------------------------------------
		-- Wisp TTL routine
		--------------------------------------
		if tick % TTL_CHECK_PERIOD == 0 then
			StepTTL = nextPortion(StepTTL, TTL_CHECK_FRAGM)
			for key, wisp in pairs(Wisps) do
				if (key % TTL_CHECK_FRAGM == StepTTL) then
					if wisp.entity.valid then
						if wisp.TTL  <= 0 then
							-- remove wisps by TTL expiration
							wisp.entity.destroy()
							table.remove(Wisps, key)
						else
							-- TTL decrease with chance to skip iteration at night
							if not isFullOfTerrorsVal then
								wisp.TTL = wisp.TTL - TTL_CHECK_PERIOD
							end
							-- chance to nullify TTL at day
							if not isDarkVal and not isColdVal then
								wisp.TTL = 0
								-- peaceful wisps - on
								setWispsAgression(false)
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
		if tick % TACTICAL_PERIOD == 0 then
			if isDarkVal then
				local wisp = Wisps[math.random(#Wisps)]
				if wisp.entity.valid and wisp.entity.type == "unit" then
					if wisp.entity.unit_group == nil and wisp.TTL > TTL_CHECK_PERIOD then
						if wisp.entity.name == "wisp-yellow" then
							createOrJoinGroup(wisp.entity, "wisp-yellow", 16)
						elseif wisp.entity.name == "wisp-red" then
							createOrJoinGroup(wisp.entity, "wisp-red", 6)
						end
					end
				end
			end
			-- only one the low-priority routine per tick
			return
		end

		if EXPERIMANTAL then
		--------------------------------------
		-- Sabotage
		--------------------------------------
		if tick % SABOTAGE_PERIOD ~= 0 then
			local wisp = Wisps[math.random(#Wisps)]
			if wisp.entity.valid and wisp.entity.name == "wisp-purple" then
				local poles = getNauvis().find_entities_filtered{type= "electric-pole", area = getArea(wisp.entity.position, SABOTAGE_RANGE), limit = 1}
				if next(poles) ~= nil then
					local pos = poles[1].position
					pos.x = pos.x + math.random(-4, 4) * 0.1
					pos.y = pos.y + math.random(-5, 5) * 0.1
					local wispAttached = getNauvis().create_entity{name = "wisp-attached", position = pos , force = "wisps"}
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
			StepGC = nextPortion(StepGC, GC_FRAGM)
			for key, wisp in pairs(Wisps) do
				if (key % GC_FRAGM == StepGC) and not wisp.entity.valid then
					-- remove forcibly destroyed wisps
					table.remove(Wisps, key)
				end
			end
		end

	end --next(Wisps) ~= nil

end

local function onCreatedHandler(entity)
	if entity.name == "wisp-purple" then
		local TTL = getDeviation(PURPLE_TTL, TTL_DEVIATION)
		initWisp(entity, TTL)
		return
	end
	if entity.name == "wisp-yellow" then
		local TTL = getDeviation(YELLOW_TTL, TTL_DEVIATION)
		initWisp(entity, TTL)
		return
	end
	if entity.name == "wisp-red" then
		local TTL = getDeviation(YELLOW_TTL, TTL_DEVIATION)
		initWisp(entity, TTL)
	end
end

local function onTriggerCreatedHandler(event)
	if checkChance(REPLICATION_CHANCE) then
		local entity = event.entity
		onCreatedHandler(entity)
	else
		event.entity.destroy()
	end
end

local function onBuiltHandler(event)
	local entity = event.created_entity
	if entity.name == "UV-lamp" then
		initUvLight(entity)
		return
	end

	if entity.name == "wisp-detector" then
		initDetector(entity)
		return
	end

	if entity.name == "wisp-purple" then
		-- recreate wisp to change force of damage
		local pos = entity.position
		local surface = entity.surface
		entity.destroy()
		local wisp =  createWisp("wisp-purple", surface, pos, PURPLE_TTL)
	else
		onCreatedHandler(entity)
	end
end

local function onChunkGeneratedHandler(event)
	if (event.surface.index == 1) then
		Chunks[#Chunks + 1] = {area = event.area, TTU = -1}
	end
end

------------------------------------------------------------
-- Init
------------------------------------------------------------
local function updateRecipes(withReset)
	for _, force in pairs(game.forces) do
		if withReset then
			force.reset_recipes()
		end
		if force.technologies["alien-bio-technology"].researched then
			force.recipes["alien-flora-sample"].enabled = true
			force.recipes["wisp-yellow"].enabled = true
			force.recipes["wisp-red"].enabled = true
			force.recipes["wisp-purple"].enabled = true
			force.recipes["wisp-detector"].enabled = true
		end
		if force.technologies["solar-energy"].researched then
			force.recipes["UV-lamp"].enabled = true
		end
	end
end

local function initWispsForce()
	log("Init wisps force..")
	if not game.forces['wisps'] then
		game.create_force('wisps')
		game.forces['wisps'].ai_controllable = true
	end
	game.forces['wisps'].set_cease_fire(game.forces.player, true) -- setWispsAgression(false)
	game.forces['player'].set_cease_fire(game.forces.wisps, false)
	game.forces['wisps'].set_cease_fire(game.forces.enemy, true)
	game.forces['enemy'].set_cease_fire(game.forces.wisps, true)
end

local function initChunksMap()
	log(" - reloading chunks..")
	local surface = getNauvis()
	for chunk in surface.get_chunks() do
		onChunkGeneratedHandler({
			surface = surface,
			area={left_top = {chunk.x*32, chunk.y*32},
						right_bottom = {(chunk.x+1)*32, (chunk.y+1)*32}}
		})
	end
end

local function initRefs()
	log("Init local references to globals..")
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
	log("Just loading game..")
	initRefs()
end

local function verToNum(ver)
	-- removes all non-digits
	ver = string.gsub(ver, "%D", "")
	return tonumber(ver)
end

local function verLessThan(ver, lessThan)
	if verToNum(ver) < verToNum(lessThan) then
		log("[Old ver less than "..lessThan.."]")
		return true
	end
	return false
end

local function updateVersion(old_v, new_v)
	if verLessThan(old_v, "14.22.9") then
		log("   - remove: global.nextChunk")
		global.nextChunk = nil

		log("   - add: global.detectors")
		global.detectors = global.detectors or {}
		Detectors = global.detectors

		log("   - add: global.step{LIGTH / TTL / GC / UV / DTCT}")
		global.stepLIGTH = global.stepLIGTH or 0
		global.stepTTL = global.stepTTL or 0
		global.stepGC = global.stepGC or 0
		global.stepUV = global.stepUV or 0
		global.stepDTCT = global.stepDTCT or 0

		StepLIGTH = global.stepLIGTH
		StepTTL = global.stepTTL
		StepGC = global.stepGC
		StepUV = global.stepUV
		StepDTCT = global.stepDTCT

		log("   - add: global.recentTargetingTime")
		global.recentTargetingTime = global.recentTargetingTime or 0
		RecentTargetingTime = global.recentTargetingTime

	end
	if verLessThan(old_v, "14.22.11") then
		log("   - rename: global.recentTargetingTime -> global.recentDayTime")
		global.recentTargetingTime = nil
		global.recentDayTime = global.recentDayTime or game.tick
		RecentDayTime = global.recentDayTime
	end
end

local function onConfigChanged(data)
	log("Reconfiguring:")
	initChunksMap()
	local this = "Will-o-the-Wisps_updated"

	if data.mod_changes then
		if data.mod_changes[this] then
			if data.mod_changes[this].old_version then
				local oldVer = data.mod_changes[this].old_version
				local newVer = data.mod_changes[this].new_version
				log(" - Will-o-the-Wisps updated: "..oldVer.." -> "..newVer)
				updateRecipes(true)
				updateVersion(oldVer, newVer)
			else
				log(" - Init Will-o-the-Wisps mod on existing game.")
				updateRecipes()
			end
		else
			-- some other mod was added, removed or modified
		end
	end
	log("Done.")
end

local function onInit()
	log("Init globals..")
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
