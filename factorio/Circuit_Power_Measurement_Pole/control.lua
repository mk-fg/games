local conf = require('config')
conf.update_from_settings()


local PoleInfoSet, Ticks

-- Note on how "set" tables are handled:
-- Value example: {1=..., 2=..., 3=..., n=3}
-- Add element X: set[set.n+1], set.n = X, set.n+1
-- Iteration (read only): for n = 1, set.n do ... end
-- Iteration (read/remove): local n = 1; while n <= set.n do ... n = n + 1 end
-- Remove element n: set[n], set.n, set[set.n] = set[set.n], set.n-1
-- Order of elements is not important there, while add/removal is O(1),
--  unlike table.insert/table.remove (which are O(n) and are very slow comparatively).


local utils = {

	get_area = function(radius, x, y)
		if not y then x, y = x.x, x.y end
		return {{x - radius, y - radius}, {x + radius, y + radius}}
	end,

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
	local sets = utils.t('pole_info')
	for k, _ in pairs(utils.t('pole_info ticks')) do
		if global[k] then goto skip end
		global[k] = {}
		if sets[k] and not global[k].n then global[k].n = #(global[k]) end
	::skip:: end
end

local function init_refs()
	PoleInfoSet = global.pole_info
	Ticks = global.ticks
end

local function init_recipes(with_reset)
	for _, force in pairs(game.forces) do
		if with_reset then force.reset_recipes() end
		if force.technologies['circuit-network'].researched
			then force.recipes['circuit-electric-pole'].enabled = true end
	end
end

script.on_init(function() init_globals(); init_refs() end)
script.on_load(init_refs)
script.on_configuration_changed(function(data)
	init_globals(); init_refs()
	local update = data.mod_changes and data.mod_changes[script.mod_name]
	if not update then return else init_recipes(update.old_version) end
end)


local function pole_init(e)
	if e.name ~= 'circuit-electric-pole'  or e.type ~= 'electric-pole' then return end
	local pole_info = {e=e, stats_abs={}}
	PoleInfoSet[PoleInfoSet.n+1], PoleInfoSet.n = pole_info, PoleInfoSet.n+1
	return pole_info
end

local function on_built(ev) pole_init(ev.created_entity) end

script.on_event(defines.events.on_built_entity, on_built)
script.on_event(defines.events.on_robot_built_entity, on_built)


local function update_pole_signal(e, ec, stats_abs)
	local ecc = ec.get_control_behavior()
	if not (ecc and ecc.enabled) then return end
	local k, n, w, idx

	local w_stats, w_total = {}, 0
	for k, w in pairs(e.electric_network_statistics.output_counts) do
		w_last, stats_abs[k] = stats_abs[k], w
		if not w_last then goto skip end
		-- 0 in case of integer value rollover. Value is in watts per 60 ticks, hence division.
		w = math.max(0, w - w_last) / (conf.ticks_between_updates / 60)
		w_stats[('item.%s'):format(k)], w_total = w, w_total + w
	::skip:: end
	w_stats[conf.sig_kw_total] = w_total
	utils.log('stats', w_stats)

	-- Scan existing signals for slots to replace or fill-in
	local ps, ps_stat, ps_free = {}, {}, {}
	for n, p in ipairs(ecc.parameters.parameters) do
		if not p.signal.name then table.insert(ps_free, {n, p.index})
		else
			k = ('%s.%s'):format(p.signal.type, p.signal.name)
			if w_stats[k] then ps_stat[k] = {n, p.index} else ps[k] = p end
		end
	end

	-- Replace/fill-in detected parameter slots
	local e_type, e_name
	table.sort(ps_free, function(a,b) return a[2] < b[2] end)
	for k, w in pairs(w_stats) do
		w = utils.round(w / 1000) -- W -> kW
		if ps_stat[k] then n, idx = table.unpack(ps_stat[k])
		else for m, slot in pairs(ps_free) do
			n, idx, ps_free[m] = table.unpack(slot)
			break
		end end
		if n then
			e_type, e_name = k:match('^([^.]+).(.+)$')
			ps[n], n = { index=idx, count=w,
				signal={type=e_type, name=e_name} }
		else break end
	end

	ecc.parameters = {parameters=ps}
end


script.on_nth_tick(conf.ticks_between_updates, function(ev)
	if Ticks.pole_check
			or (conf.ticks_between_rescan and Ticks.pole_check < ev.tick) then
		for _, e in ipairs( game.surfaces.nauvis
				.find_entities_filtered{type='electric-pole', name='circuit-electric-pole'} ) do
			for n = 1, PoleInfoSet.n do if PoleInfoSet[n].e == e then e = nil; break end end
			if e then pole_init(e) end
		end
		Ticks.pole_check = ev.tick + (conf.ticks_between_rescan or 0)
	end

	utils.log('pole-loop', PoleInfoSet.n)
	local set, n, p = PoleInfoSet, 1
	while n <= set.n do
		p = set[n]
		if not p.e.valid then
			set[n], set.n, set[set.n] = set[set.n], set.n-1
			goto drop
		end
		utils.log('--- pole', n)

		if not p.c or not p.c.valid then
			p.c = game.surfaces.nauvis.find_entities_filtered{
				area=utils.get_area(conf.combinator_radius, p.e.position), limit=1,
				force=p.e.force, type='constant-combinator', name='constant-combinator' }
			if p.c and next(p.c) then p.c = p.c[1] else p.c = nil end
		end
		if not p.c then goto skip end

		update_pole_signal(p.e, p.c, p.stats_abs)

	::skip:: n = n + 1 ::drop:: end
end)
