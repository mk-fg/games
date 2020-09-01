local conf = require('config')
conf.update_from_settings()


local SentinelSet, Ticks

-- Note on how "set" tables are handled:
-- Value example: {1=..., 2=..., 3=..., n=3}
-- Add element X: set[set.n+1], set.n = X, set.n+1
-- Iteration (read only): for n = 1, set.n do ... end
-- Iteration (read/remove): local n = 1; while n <= set.n do ... n = n + 1 end
-- Remove element n: set[n], set.n, set[set.n] = set[set.n], set.n-1
-- Order of elements is not important there, while add/removal is O(1),
--  unlike table.insert/table.remove (which are O(n) and are very slow comparatively).

-- XXX: add strict-mode errors here


local utils = {

	distance = function(p1, p2)
		return ((p1.x - p2.x)^2 + (p1.y - p2.y)^2)^0.5 end,
	area = function(p, r)
		return {{p.x - r, p.y - r}, {p.x + r, p.y + r}} end,

	t = function(s, value)
		-- Makes padded table from other table keys or a string of keys
		local t = {}
		if not value then value = true end
		if type(s) == 'table' then for k,_ in pairs(s) do t[k] = value end
		else s:gsub('(%S+)', function(k) t[k] = value end) end
		return t
	end,

	log = function(src, val, data, print_data)
		if not conf.debug_log then return end
		if data or print_data then
			print(('--- '..src):format(val, serpent.line(data)))
		else print(('--- %s: %s'):format(src, serpent.line(val))) end
	end,

}


-- Signal structs/maps for various checks

local BiterSignals = {}
for _, t in ipairs{'biter', 'spitter'} do
	for _, sz in ipairs{'small', 'medium', 'big', 'behemoth'} do
		BiterSignals['virtual.signal-bds-'..sz..'-'..t] = true
end end
BiterSignals[conf.sig_biter_total] = true
BiterSignals[conf.sig_biter_other] = true


-- Mod Init Process

local function init_globals()
	local sets = utils.t('sentinel_info')
	for k, _ in pairs(utils.t('sentinel_info ticks')) do
		if global[k] then goto skip end
		global[k] = {}
		if sets[k] and not global[k].n then global[k].n = #(global[k]) end
	::skip:: end
end

local function init_refs()
	SentinelSet = global.sentinel_info
	Ticks = global.ticks
end

local function init_recipes(with_reset)
	for _, force in pairs(game.forces) do
		if with_reset then force.reset_recipes() end
		if force.technologies['circuit-network'].researched then
			force.recipes['sentinel-alarm'].enabled = true
			force.recipes['sentinel-combinator'].enabled = true
	end end
end

script.on_init(function() init_globals(); init_refs() end)
script.on_load(init_refs)
script.on_configuration_changed(function(data)
	init_globals(); init_refs()
	local update = data.mod_changes and data.mod_changes[script.mod_name]
	if update then init_recipes(update.old_version) end
end)


-- New entity hooks

local function sentinel_check(e)
	return e.valid and e.type == 'constant-combinator'
		and ( e.name == 'sentinel-combinator' or e.name == 'sentinel-alarm' )
end

local function sentinel_init(e)
	if not sentinel_check(e) then return end
	local sentinel_info = {e=e, alarm=e.name == 'sentinel-alarm'}
	SentinelSet[SentinelSet.n+1], SentinelSet.n = sentinel_info, SentinelSet.n+1
	return sentinel_info
end

local function on_built(ev) sentinel_init(ev.created_entity or ev.entity) end

script.on_event(defines.events.on_built_entity, on_built, {{filter='type', type='constant-combinator'}})
script.on_event(defines.events.on_robot_built_entity, on_built, {{filter='type', type='constant-combinator'}})
script.on_event(defines.events.script_raised_built, on_built, {{filter='type', type='constant-combinator'}})
script.on_event(defines.events.script_raised_revive, on_built, {{filter='type', type='constant-combinator'}})


-- On-nth-tick updates

local function find_sentinel_radar(s)
	s.p = nil
	local ps, pd, pd_new
	ps, s.p = s.e.surface.find_entities_filtered{
		position=s.e.position, radius=conf.radar_radius,
		force=s.e.force, type='radar' }
	for _, p in ipairs(ps) do
		pd_new = utils.distance(s.e.position, p.position)
		if not pd or pd > pd_new then pd, s.p = pd_new, p end
	end
end


local function update_sentinel_signal(s)
	local ecc = s.e.get_control_behavior()
	if not (ecc and (ecc.enabled or s.alarm)) then return end

	-- Find slots to replace/fill-in, as well as special control signals
	local ps, ps_stat, ps_free, sig, range, alarm_test = {}, {}, {}
	-- Internal slots on combinator itself
	for n, p in ipairs(ecc.parameters.parameters) do
		if not p.signal.name then table.insert(ps_free, {n, p.index})
		else
			sig = ('%s.%s'):format(p.signal.type, p.signal.name)
			if BiterSignals[sig] then ps_stat[sig] = {n, p.index} else ps[sig] = p end
			if sig == conf.sig_range then range = p.count or 0 end
			if sig == conf.sig_alarm_test then alarm_test = p.count ~= 0 end
	end end
	-- Connected circuit network signals
	-- get_merged_signal() is not used because it returns 0 when combinator is disabled,
	--  which is esp. relevant for alarms, as they are supposed to be disabled unless triggered.
	local signals = s.e.get_merged_signals()
	if signals then for _, p in ipairs(signals) do
		sig = ('%s.%s'):format(p.signal.type, p.signal.name)
		if sig == conf.sig_range then
			if ecc.enabled then range = p.count -- it's already a sum when enabled
				else range = p.count + (range or 0) end
		end
		if sig == conf.sig_alarm_test and p.count ~= 0 then alarm_test = true end
	end end
	-- Checks, defaults, fallbacks
	if (range or 0) == 0 then range = conf.default_scan_range end -- not set via any signals
	if range < 1 then return end -- R<=0 - can be disabled from circuit network that way

	-- Simplier enable/disable operation for Sentinel Alarm

	if s.alarm then
		local alarm
		if not alarm_test then alarm = s.e.surface
			.find_nearest_enemy{position=s.e.position, max_distance=range} and true
		else
			for _, p in ipairs(game.connected_players) do
				alarm = utils.distance(p.position, s.e.position) <= range
				if alarm then break end
		end end
		utils.log('- alarm state (range=%s): %s', range, alarm, true)
		ecc.enabled = alarm
		return
	end

	-- Full scan/count operation for Sentinel Combinator

	-- Run surface scan and count known/other biter entities (force=enemy)
	local stats, total = {}, 0
	local biters = s.p.surface.find_units{
		area=utils.area(s.p.position, range), force='enemy', condition='same' }
	for _, e in ipairs(biters) do
		if not e.valid then goto skip end
		sig = ('virtual.%s'):format('signal-bds-'..e.name)
		if not BiterSignals[sig] then sig = conf.sig_biter_other end
		stats[sig] = (stats[sig] or 0) + 1
		total = total + 1
	::skip:: end
	stats[conf.sig_biter_total] = total
	utils.log('- stats (range=%d): %s', range, stats)

	-- Replace/fill-in detected parameter slots
	local e_type, e_name
	table.sort(ps_free, function(a, b) return a[2] < b[2] end)
	for sig, c in pairs(stats) do
		if ps_stat[sig] then n, idx = table.unpack(ps_stat[sig])
		else for m, slot in pairs(ps_free) do
			n, idx, ps_free[m] = table.unpack(slot)
			break
		end end
		if n then
			e_type, e_name = sig:match('^([^.]+).(.+)$')
			ps[n], n = {index=idx, count=c, signal={type=e_type, name=e_name}}
		else break end
	end
	ecc.parameters = {parameters=ps}
end


script.on_nth_tick(conf.ticks_between_updates, function(ev)
	if conf.ticks_between_rescan and ( -- periodic map scans, default-disabled
			not Ticks.sentinel_check or Ticks.sentinel_check < ev.tick ) then
		local sentinel_uns = {}
		for n = 1, SentinelSet.n do sentinel_uns[SentinelSet[n].unit_number] = true end
		for _, s in ipairs(game.surfaces) do
			for _, e in ipairs(s.find_entities_filtered{type='constant-combinator'}) do
				if sentinel_check(e) and not sentinel_uns[e.unit_number] then sentinel_init(e) end
		end end
		Ticks.sentinel_check = ev.tick + (conf.ticks_between_rescan or 0)
	end

	utils.log('sentinel-update-loop (step=%s sentinels=%s)', Ticks.step, SentinelSet.n)
	local set, n, step, s = SentinelSet, 1, Ticks.step or 0
	while n <= set.n do
		if n % conf.ticks_update_steps ~= step then goto skip end
		s = set[n]
		if not s.e.valid then
			set[n], set.n, set[set.n] = set[set.n], set.n-1
			goto drop
		end
		utils.log('--- sentinel n=%d alarm=%s', n, s.alarm, true)

		if not s.alarm then
			if not s.p or not s.p.valid then
				find_sentinel_radar(s)
				if not s.p or not s.p.valid then goto skip end -- no radar in range
			end
			if s.p.energy <= 0 then goto skip end -- radar is not working
		end

		update_sentinel_signal(s)

	::skip:: n = n + 1 ::drop:: end
	Ticks.step = (step + 1) % conf.ticks_update_steps
end)
