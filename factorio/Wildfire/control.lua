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

local function debug_player_pos()
	for _, p in ipairs(game.connected_players) do return p.position end
end

local function debug_place_tag(p, text)
	if not global.tags then global.tags = {} end
	local tag = {position=p, icon={type='virtual', name='signal-dot'}, text=text}
	for _, p in ipairs(game.connected_players)
		do table.insert(global.tags, p.force.add_chart_tag(game.surfaces.nauvis, tag)) end
end


local function update_tree_entities()
	local st = {}
	for _, p in pairs(game.get_filtered_entity_prototypes{{filter='type', type='tree'}}) do
		if p.emissions_per_second > 0 or p.emissions_per_second > -0.0005 then goto skip end
		table.insert(st, p.name)
	::skip:: end
	global.surface_trees = st
end


local function find_random_pos()
	local p = game.surfaces.nauvis.get_random_chunk()
	return {x=p.x*32 + 16, y=p.y*32 + 16}
end

local function check_spark_pos_balance(p, subsample, subsample_debug)
	local s = game.surfaces.nauvis
	if not global.surface_trees then update_tree_entities() end
	local trees = s.find_entities_filtered{
		position=p, radius=conf.check_radius, name=global.surface_trees }

	local c_green, c_dead = 0, 0
	for _, e in ipairs(trees) do
		if e.tree_stage_index == e.tree_stage_index_max
			then c_dead = c_dead + 1 else c_green = c_green + 1 end
	end
	if (not subsample and c_green < conf.min_green_trees)
			or c_dead > conf.max_dead_trees
			or not (c_dead == 0 or (c_green / c_dead) > conf.green_dead_balance)
		then trees = nil end

	if not subsample and trees and conf.check_sample_n then
		-- Pick and run same algo on points around the initial one
		local a, ad = math.random() * 2 * math.pi, 2 * math.pi / conf.check_sample_n
		local r, ps, st, sg, sd = conf.check_sample_offset
		for n = 1, conf.check_sample_n do
			ps = {x=p.x + r * math.cos(a), y=p.y + r * math.sin(a)}
			st, sg, sd = check_spark_pos_balance(ps, true)
			if subsample_debug then
				debug_place_tag( ps, ('%s [%s %s %s]')
					:format(n, #(st or {}) > 0 and 'pass' or 'fail', sg, sd) )
			end
			c_dead = c_dead + sd
			if c_dead > conf.max_dead_trees then st = nil end
			if not st then break end
			a = a + ad
		end
		if not st then trees = nil end
	end

	return trees, c_green, c_dead
end

local function pick_random_tree_pos(trees)
	return trees[math.random(1, #trees)].position
end

local function find_fire_position()
	-- Top-level func that runs all checks above in proper sequence
	local spark_pos = find_random_pos()
	if not spark_pos then return end
	local valid_trees = check_spark_pos_balance(spark_pos)
	if not valid_trees then return end
	spark_pos = pick_random_tree_pos(valid_trees)
	if not spark_pos then return end
	return spark_pos
end

local function create_wildfire(pos)
	if not game.forces.wildfire then game.create_force('wildfire') end
	game.surfaces.nauvis.create_entity{
		name='fire-flame-on-tree', position=pos, force='wildfire' }
end


local wf_cmd_help = [[
watch - on/off toggle for revealing charted map chunks every check_interval (mod setting).
chart n - generate/reveal up to n tiles around player(s), to test fire-starting on or to visualize radius.
spark [n] [tag] - Make n (default=1) attempt(s) to find wildfire start position and ignite it.
    "tag" parameter at the end will add tag label at that position on the map.
tag [here | clear] [sub] - Make one attempt to find spark-area and label it without fire.
    "here" - check/tag player's position, "clear" will remove all map tags added by this mod.
    "sub" - also put labels at all sampled points around center, if such sampling is enabled.
]]

local function run_wf_cmd(cmd)
	if not cmd then return 'Wildfire mod-specific'..
		' admin commands. Run without parameters for more info.' end
	local player = game.players[cmd.player_index]
	local function usage()
		player.print('--- Usage: /wf [command...]')
		player.print('Supported wildfire-mod subcommands:')
		for line in wf_cmd_help:gmatch('%s*%S.-\n') do player.print('  '..line:sub(1, -2)) end
		player.print('[use /clear command to clear long message outputs like above]')
	end
	if not cmd.parameter or cmd.parameter == '' then return usage() end

	local function wfp(msg) player.print('Wildfire :: '..msg) end
	if not player.admin then
		wfp('ERROR: all wf-commands are only available to admin player')
		return
	end
	local args = {}
	cmd.parameter:gsub('(%S+)', function(v) table.insert(args, v) end)
	cmd = args[1]

	if cmd == 'watch' then
		global.debug_watch = not global.debug_watch and true or nil
		wfp( ('Reveal map mode: %s')
			:format(global.debug_watch and 'enabled' or 'disabled') )

	elseif cmd == 'chart' then
		local r, x, y = tonumber(args[2] or 1) or 1
		wfp(('Charting radius: %s'):format(r))
		for _, p in ipairs(game.connected_players) do
			x, y = p.position.x, p.position.y
			p.force.chart(p.surface, {{x - r, y - r}, {x + r, y + r}})
		end

	elseif cmd == 'spark' then
		local n_max, pos = tonumber(args[2] or 1) or 1
		for n = 1, n_max do
			pos = find_fire_position()
			if pos then break end
		end
		if pos then
			create_wildfire(pos)
			if args[3] then
				if args[3] ~= 'tag' then return usage() end
				if not global.tags then global.tags = {} end
				local tag = {position=pos, icon={type='item', name='wood'}, text='spark'}
				for _, player in ipairs(game.connected_players)
					do table.insert( global.tags,
						player.force.add_chart_tag(game.surfaces.nauvis, tag) ) end
			end
		else wfp(( 'spark: failed to find random position'..
			' that passed all checks (n=%s)' ):format(n_max)) end

	elseif cmd == 'tag' then
		local tag_clear, tag_here, tag_sub
		if args[2] then
			if args[2] == 'clear' then tag_clear = true
			elseif args[2] == 'here' then tag_here = true
			elseif args[2] == 'sub' then tag_sub = true
			else return usage() end end
		if args[3] then
			if args[3] == 'sub' then tag_sub = true
			else return usage() end end
		if tag_clear then
			for _, tag in ipairs(global.tags) do if tag.valid then tag.destroy() end end
			global.tags = nil
			return
		end
		local pos
		if tag_here then pos = debug_player_pos() else pos = find_random_pos() end
		if not pos then return end
		local trees, c_green, c_dead = check_spark_pos_balance(pos, nil, tag_sub)
		if not global.tags then global.tags = {} end
		local spark = ('spark=%s [green=%s dead=%s]')
			:format(trees and 'yes' or 'no', c_green, c_dead)
		local tag = {position=pos, icon={type='item', name='wood'}, text=spark}
		for _, player in ipairs(game.connected_players)
			do table.insert( global.tags,
				player.force.add_chart_tag(game.surfaces.nauvis, tag) ) end
		wfp(('tag: pos={x=%s, y=%s} %s'):format(pos.x, pos.y, spark))

	else return usage() end
end


local function check_time(ev)
	if global.debug_watch then
		for _, p in ipairs(game.connected_players) do p.force.chart_all() end end

	if not global.spark_tick then
		global.spark_tick = ev.tick + conf.spark_interval +
			math.random(-conf.spark_interval_jitter, conf.spark_interval_jitter)
	end
	if ev.tick < global.spark_tick then return end

	global.spark_tick = nil
	local pos = find_fire_position()
	if pos then create_wildfire(pos) end
end


commands.add_command('wf', run_wf_cmd(), run_wf_cmd)

script.on_configuration_changed(function(data)
	global.surface_trees = nil -- in case mods change trees

	global.surface_bounds = nil -- ver < 0.0.4
	if global.spark_check_limit -- ver < 0.0.5
		then global.spark_tick = nil end
end)

script.on_init(function() strict_mode_enable() end)
script.on_load(function() strict_mode_enable() end)

script.on_nth_tick(conf.check_interval, check_time)
