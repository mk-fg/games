local conf = require('config')
conf.update_from_settings()


local MeterSet, Ticks

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

	log = function(src, val)
		if not conf.debug_log then return end
		print(('--- %s: %s'):format(src, serpent.block(val)))
	end,

}


local function init_globals()
	local sets = utils.t('meter_info')
	for k, _ in pairs(utils.t('meter_info ticks')) do
		if global[k] then goto skip end
		global[k] = {}
		if sets[k] and not global[k].n then global[k].n = #(global[k]) end
	::skip:: end
end

local function init_refs()
	MeterSet = global.meter_info
	Ticks = global.ticks
end

local function init_recipes(with_reset)
	for _, force in pairs(game.forces) do
		if with_reset then force.reset_recipes() end
		if force.technologies['circuit-network'].researched
			then force.recipes['power-meter-combinator'].enabled = true end
	end
end

script.on_init(function() init_globals(); init_refs() end)
script.on_load(init_refs)
script.on_configuration_changed(function(data)
	init_globals(); init_refs()
	local update = data.mod_changes and data.mod_changes[script.mod_name]
	if update then init_recipes(update.old_version) end
end)


local function meter_init(e)
	if e.name ~= 'power-meter-combinator'
		or e.type ~= 'constant-combinator' then return end
	local meter_info = {e=e, stats_abs={}}
	MeterSet[MeterSet.n+1], MeterSet.n = meter_info, MeterSet.n+1
	return meter_info
end


local on_built_filter = {{filter='name', name='power-meter-combinator'}}
local function on_built(ev) meter_init(ev.created_entity or ev.entity) end

script.on_event(defines.events.on_built_entity, on_built, on_built_filter)
script.on_event(defines.events.on_robot_built_entity, on_built, on_built_filter)
script.on_event(defines.events.script_raised_built, on_built, on_built_filter)
script.on_event(defines.events.script_raised_revive, on_built, on_built_filter)


local function update_meter_signal(meter)
	local ecc = meter.e.get_control_behavior()
	if not (ecc and ecc.enabled) then return end
	local k, n, w, idx

	local w_stats, w_total, w_other, stats_abs = {}, 0, 0, meter.stats_abs
	for k, w in pairs(meter.p.electric_network_statistics.output_counts) do
		w_last, stats_abs[k] = stats_abs[k], w
		if not w_last then goto skip end
		-- 0 in case of integer value rollover. Value is in watts per 60 ticks, hence division.
		w = math.max(0, w - w_last) / (conf.ticks_between_updates / 60)
		w_total = w_total + w
		if game.item_prototypes[k]
			then w_stats[('item.%s'):format(k)] = w
			else w_other = w_other + w end -- stats for non-item entities, can't be used as signals
	::skip:: end
	w_stats[conf.sig_kw_total] = w_total
	if w_other > 0 then w_stats[conf.sig_kw_other] = w_other end
	utils.log('stats', w_stats)

	-- Scan existing signals for slots to replace or fill-in
	local ps, ps_stat, ps_free, ps_last = {}, {}, {}, meter.params_last or {}
	for n, p in ipairs(ecc.parameters.parameters) do
		if not p.signal.name then table.insert(ps_free, {n, p.index})
		else
			k = ('%s.%s'):format(p.signal.type, p.signal.name)
			if w_stats[k] then ps_stat[k] = {n, p.index} else
				-- Check here drops signals that were updated
				--  from pole before, but no longer are due to grid changes.
				if ps_last[k] ~= p.index then ps[k] = p end
				ps_last[k] = nil
			end
		end
	end
	meter.params_last = ps_last -- initialized here

	-- Replace/fill-in detected parameter slots
	local e_type, e_name
	table.sort(ps_free, function(a, b) return a[2] < b[2] end)
	for k, w in pairs(w_stats) do
		w = utils.round(w / 1000) -- W -> kW
		w = math.min(w, 2^31-1) -- can happen when connecting long-running grids
		if ps_stat[k] then n, idx = table.unpack(ps_stat[k])
		else for m, slot in pairs(ps_free) do
			n, idx, ps_free[m] = table.unpack(slot)
			break
		end end
		if n then
			e_type, e_name = k:match('^([^.]+).(.+)$')
			ps[n], ps_last[k], n = { index=idx,
				count=w, signal={type=e_type, name=e_name} }, idx
		else break end
	end

	ecc.parameters = {parameters=ps}
end


script.on_nth_tick(conf.ticks_between_updates, function(ev)
	if conf.ticks_between_rescan and (
			not Ticks.meter_check or Ticks.meter_check < ev.tick ) then
		local meter_uns = {}
		for n = 1, MeterSet.n do meter_uns[MeterSet[n].unit_number] = true end
		for _, s in ipairs(game.surfaces) do
			for _, e in ipairs(s.find_entities_filtered{
					type='constant-combinator', name='power-meter-combinator' }) do
				if not meter_uns[e.unit_number] then meter_init(e) end
		end end
		Ticks.meter_check = ev.tick + (conf.ticks_between_rescan or 0)
	end

	utils.log('meter-update-loop', MeterSet.n)
	local set, n, m = MeterSet, 1
	while n <= set.n do
		m = set[n]
		if not m.e.valid then
			set[n], set.n, set[set.n] = set[set.n], set.n-1
			goto drop
		end
		utils.log('--- meter', n)

		if not m.p or not m.p.valid then
			local ps, pd, pd_new
			ps, m.p = m.e.surface.find_entities_filtered{
				position=m.e.position, radius=conf.pole_radius,
				force=m.e.force, type='electric-pole' }
			for _, p in ipairs(ps) do
				pd_new = utils.distance(m.e.position, p.position)
				if not pd or pd > pd_new then pd, m.p = pd_new, p end
			end
		end
		if not m.p then goto skip end

		update_meter_signal(m)

	::skip:: n = n + 1 ::drop:: end
end)
