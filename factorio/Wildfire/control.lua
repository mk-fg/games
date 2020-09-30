local conf = require('config')
conf.update_from_settings()


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


local function update_tree_entities()
	local st = {}
	for _, p in pairs(game.get_filtered_entity_prototypes{{filter='type', type='tree'}}) do
		if p.emissions_per_second > 0 or p.emissions_per_second > -0.0005 then goto skip end
		table.insert(st, p.name)
	::skip:: end
	global.surface_trees = st
end

local function update_surface_bounds(ev)
	-- Updates known map bounds on new chunk generation
	if not global.surface_bounds then
		global.surface_bounds = {
			x1=0, x2=0, y1=0, y2=0,
			surface=game.surfaces.nauvis.index }
	end
	local p = global.surface_bounds
	if ev.surface.index ~= p.surface then return end
	local p1, p2 = ev.area.left_top, ev.area.right_bottom
	p.x1, p.x2 = math.min(p.x1, p1.x), math.max(p.x2, p2.x)
	p.y1, p.y2 = math.min(p.y1, p2.y), math.max(p.y2, p1.y)
end

local function rescan_surface_bounds()
	local p, p1, p2 = global.surface_bounds
	for c in game.surfaces.nauvis.get_chunks() do
		p1, p2 = c.area.left_top, c.area.right_bottom
		p.x1, p.x2 = math.min(p.x1, p1.x), math.max(p.x2, p2.x)
		p.y1, p.y2 = math.min(p.y1, p2.y), math.max(p.y2, p1.y)
	end
end


local function find_random_pos(bounds)
	local p = global.surface_bounds
	if not p then return end
	return {x=math.random(p.x1, p.x2), y=math.random(p.y1, p.y2)}
end

local function check_spark_pos_balance(p)
	local s = game.surfaces.nauvis
	if not global.surface_trees then update_tree_entities() end
	local trees = s.find_entities_filtered{
		position=p, radius=conf.check_radius, name=global.surface_trees }

	local c_green, c_dead = 0, 0
	for _, e in ipairs(trees) do
		if e.tree_stage_index == e.tree_stage_index_max
			then c_dead = c_dead + 1 else c_green = c_green + 1 end
	end
	if c_green < conf.min_green_trees or c_dead > conf.max_dead_trees
			or not (c_dead == 0 or (c_green / c_dead) > conf.green_dead_balance)
		then trees = nil end

	return trees, c_green, c_dead
end

local function pick_random_tree_pos(trees)
	return trees[math.random(1, #trees)].position
end

local function find_fire_position()
	-- Top-level func that runs all checks above in proper sequence
	local spark_pos = find_random_pos(global.surface_bounds)
	if not spark_pos then return end

	local valid_trees = check_spark_pos_balance(spark_pos)
	if not valid_trees then return end

	spark_pos = pick_random_tree_pos(valid_trees)
	if not spark_pos then return end

	return spark_pos
end


local function catch_fire(pos)
	if not game.forces.wildfire then game.create_force('wildfire') end
	game.surfaces.nauvis.create_entity{
		name='fire-flame-on-tree', position=pos, force='wildfire' }
end


local wf_cmd_help = [[
scan - Scan all chunks on the map for fire zone bounds.
spark [n] [tag] - Make n (default=1) attempt(s) to find spark position and ignite it.
... Adding last "tag" parameter will add tag label at that position on the map.
tag [clear] - Make one attempt to find spark-area and label its center without fire.
... "clear" will remove map tags added by this mod instead.
]]

local function run_wf_cmd(cmd)
	if not cmd then return 'Wildfire mod-specific'..
		' admin commands. Run without parameters for more info.' end
	local player = game.players[cmd.player_index]
	local function usage()
		player.print('--- Usage: /wf [command...]')
		player.print('Supported subcommands:')
		for line in wf_cmd_help:gmatch('%s*%S.-\n') do player.print('  '..line:sub(1, -2)) end
		player.print('[use /clear command to clear long message outputs like above]')
	end
	if not cmd.parameter or cmd.parameter == '' then return usage() end
	if not player.admin then
		player.print('ERROR: all wf-commands are only available to admin player')
		return
	end
	local args = {}
	cmd.parameter:gsub('(%S+)', function(v) table.insert(args, v) end)
	cmd = args[1]

	if cmd == 'scan' then
		rescan_surface_bounds()
		player.print(('Spark zone: %s'):format(serpent.line(global.surface_bounds)))

	elseif cmd == 'spark' then
		local n_max, pos = tonumber(args[2] or 1) or 1
		for n = 1, n_max do
			pos = find_fire_position()
			if pos then break end
		end
		if pos then
			catch_fire(pos)
			if args[3] then
				if args[3] ~= 'tag' then return usage() end
				if not global.tags then global.tags = {} end
				local tag = {position={pos.x, pos.y}, icon={type='item', name='wood'}, text='spark'}
				for _, player in ipairs(game.connected_players)
					do table.insert( global.tags,
						player.force.add_chart_tag(game.surfaces.nauvis, tag) ) end
			end
		else player.print(( 'spark: failed to find random'..
			' position that passed all checks (n=%s)' ):format(n_max)) end

	elseif cmd == 'tag' then
		if args[2] then
			if args[2] ~= 'clear' then return usage() end
			for _, tag in ipairs(global.tags) do if tag.valid then tag.destroy() end end
			global.tags = nil
			return
		end
		local pos = find_random_pos(global.surface_bounds)
		if not pos then return end
		local trees, c_green, c_dead = check_spark_pos_balance(pos)
		if not trees then trees = {} end
		if not global.tags then global.tags = {} end
		local tag = {
			position={pos.x, pos.y}, icon={type='item', name='wood'},
			text=('green=%s dead=%s total=%s'):format(c_green, c_dead, #trees) }
		for _, player in ipairs(game.connected_players)
			do table.insert( global.tags,
				player.force.add_chart_tag(game.surfaces.nauvis, tag) ) end
		player.print(( 'tag: pos={x=%s, y=%s} trees=%s'..
			' [green=%s dead=%s]' ):format(pos.x, pos.y, #trees, c_green, c_dead))

	else return usage() end
end


local function check_time(ev)
	if not global.spark_tick then
		global.spark_tick = ev.tick + conf.spark_interval +
			math.random(-conf.spark_interval_jitter, conf.spark_interval_jitter)
		global.spark_check_limit = conf.check_limit
	end
	if ev.tick < global.spark_tick then return end

	global.spark_check_limit = global.spark_check_limit - 1
	if global.spark_check_limit >= 0 then
		local pos = find_fire_position()
		if not pos then return end
		catch_fire(pos)
	end

	global.spark_tick, global.check_bounds = nil
end


commands.add_command('wf', run_wf_cmd(), run_wf_cmd)

script.on_configuration_changed(function(data) global.surface_trees = nil end)
script.on_init(function() strict_mode_enable() end)
script.on_load(function() strict_mode_enable() end)

script.on_nth_tick(conf.check_interval, check_time)
script.on_event(defines.events.on_chunk_generated, update_surface_bounds)
