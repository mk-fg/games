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


local utils = {

	distance = function(p1, p2)
		return ((p1.x - p2.x)^2 + (p1.y - p2.y)^2)^0.5 end,

	round = function(num, dec_places)
		local mult = 10^(dec_places or 0)
		return math.floor(num * mult + 0.5) / mult
	end,

	t = function(s, value)
		-- Makes padded table from other table keys or a string of keys
		local t = {}
		if not value then value = true end
		if type(s) == 'table' then for k,_ in pairs(s) do t[k] = value end
		else s:gsub('(%S+)', function(k) t[k] = value end) end
		return t
	end,

	log = function(src, val, data)
		if not conf.debug_log then return end
		if data then print(('--- '..src):format(val, serpent.block(data)))
		else print(('--- %s: %s'):format(src, serpent.block(val))) end
	end,

}

-- These biter signals will be set/reset after each scan
local biter_signals = {}
for _, t in ipairs{'biter', 'spitter'} do
	for _, sz in ipairs{'small', 'medium', 'big', 'behemoth'} do
		biter_signals['virtual.signal-bds-'..sz..'-'..t] = true
end end
biter_signals[conf.sig_biter_total] = true
biter_signals[conf.sig_biter_other] = true


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
		if force.technologies['circuit-network'].researched
			then force.recipes['sentinel-combinator'].enabled = true end
	end
end

script.on_init(function() init_globals(); init_refs() end)
script.on_load(init_refs)
script.on_configuration_changed(function(data)
	init_globals(); init_refs()
	local update = data.mod_changes and data.mod_changes[script.mod_name]
	if update then init_recipes(update.old_version) end
end)


local function sentinel_init(e)
	if e.name ~= 'sentinel-combinator'
		or e.type ~= 'constant-combinator' then return end
	local sentinel_info = {e=e}
	SentinelSet[SentinelSet.n+1], SentinelSet.n = sentinel_info, SentinelSet.n+1
	return sentinel_info
end

local function on_built(ev) sentinel_init(ev.created_entity) end

script.on_event( defines.events.on_built_entity, on_built,
	{{filter='type', type='constant-combinator'}, {filter='name', name='sentinel-combinator'}} )
script.on_event( defines.events.on_robot_built_entity, on_built,
	{{filter='type', type='constant-combinator'}, {filter='name', name='sentinel-combinator'}} )


local function update_sentinel_signal(sentinel)
	local ecc = sentinel.e.get_control_behavior()
	if not (ecc and ecc.enabled) then return end

	-- Find slots to replace/fill-in, as well as range (R) signal
	local ps, ps_stat, ps_free, sig, range = {}, {}, {}
	for n, p in ipairs(ecc.parameters.parameters) do
		if not p.signal.name then table.insert(ps_free, {n, p.index})
		else
			sig = ('%s.%s'):format(p.signal.type, p.signal.name)
			if biter_signals[sig] then ps_stat[sig] = {n, p.index} else ps[sig] = p end
			if sig == conf.sig_range then range = p.count or 0 end -- R set on detector itself
		end
	end
	local signals = sentinel.e.get_merged_signals()
	if signals then for _, p in ipairs(signals) do
		sig = ('%s.%s'):format(p.signal.type, p.signal.name)
		if sig == conf.sig_range then range = (range or 0) + p.count end
	end end
	if not range then range = conf.default_scan_range end -- not set via any signals
	if range < 1 then return end -- R<=0 - can be disabled from circuit network that way

	-- Run surface scan and count known/other biter entities (force=enemy)
	local stats, total = {}, 0
	local biters = sentinel.p.surface.find_entities_filtered{
		force='enemy', position=sentinel.p.position, radius=range }
	for _, e in ipairs(biters) do
		if not e.valid then goto skip end
		sig = ('virtual.%s'):format('signal-bds-'..e.name)
		if not biter_signals[sig] then sig = conf.sig_biter_other end
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
	if conf.ticks_between_rescan and (
			not Ticks.sentinel_check or Ticks.sentinel_check < ev.tick ) then
		local sentinel_uns = {}
		for n = 1, SentinelSet.n do sentinel_uns[SentinelSet[n].unit_number] = true end
		for _, s in ipairs(game.surfaces) do
			for _, e in ipairs(s.find_entities_filtered{
					type='constant-combinator', name='sentinel-combinator' }) do
				if not sentinel_uns[e.unit_number] then sentinel_init(e) end
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
		utils.log('--- sentinel', n)

		if conf.radar_radius > 0 and s.p == s.e then s.p = nil end -- for settings change
		if not s.p or not s.p.valid then
			if conf.radar_radius > 0 then
				local ps, pd, pd_new
				ps, s.p = s.e.surface.find_entities_filtered{
					position=s.e.position, radius=conf.radar_radius,
					force=s.e.force, type='radar' }
				for _, p in ipairs(ps) do
					pd_new = utils.distance(s.e.position, p.position)
					if not pd or pd > pd_new then pd, s.p = pd_new, p end
				end
			elseif s.e.valid then s.p = s.e end -- radar requirement disabled
		end
		if not s.p or (conf.radar_radius > 0 and s.p.energy <= 0) then goto skip end -- check if radar is working

		update_sentinel_signal(s)

	::skip:: n = n + 1 ::drop:: end
	Ticks.step = (step + 1) % conf.ticks_update_steps
end)
