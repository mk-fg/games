#!/usr/bin/env python3

import itertools as it, operator as op, functools as ft
from collections import OrderedDict
from os.path import exists, join, basename
import os, sys, re, time, logging, json, pprint, tempfile

import yaml


it_adjacent = lambda seq, n: it.zip_longest(*([iter(seq)] * n))
it_ngrams = lambda seq, n: zip(*(it.islice(seq, i, None) for i in range(n)))

class LogMessage(object):
	def __init__(self, fmt, a, k): self.fmt, self.a, self.k = fmt, a, k
	def __str__(self): return self.fmt.format(*self.a, **self.k) if self.a or self.k else self.fmt

class LogStyleAdapter(logging.LoggerAdapter):
	def __init__(self, logger, extra=None):
		super(LogStyleAdapter, self).__init__(logger, extra or {})
	def log(self, level, msg, *args, **kws):
		if not self.isEnabledFor(level): return
		log_kws = {} if 'exc_info' not in kws else dict(exc_info=kws.pop('exc_info'))
		msg, kws = self.process(msg, kws)
		self.logger._log(level, LogMessage(msg, args, kws), (), log_kws)

class LogPrefixAdapter(LogStyleAdapter):
	def __init__(self, logger, prefix, extra=None):
		if isinstance(logger, str): logger = get_logger(logger)
		if isinstance(logger, logging.LoggerAdapter): logger = logger.logger
		super(LogPrefixAdapter, self).__init__(logger, extra or {})
		self.prefix = prefix
	def process(self, msg, kws):
		super(LogPrefixAdapter, self).process(msg, kws)
		return '[{}] {}'.format(self.prefix, msg), kws

get_logger = lambda name: LogStyleAdapter(logging.getLogger(name))

def log_data(data, title=None):
	title = '' if not title else ' [{}]'.format(title)
	log.debug('Data{}:\n{}', title, pprint.pformat(data))


class WeaponCalc:

	line_len, line_n = 100, 50
	stats = OrderedDict(it_adjacent(
		['strength', 33, 'melee', 70, 'throwing', 40, 'time', 65, 'bravery', 40], 2 ))
	stat_enter, stat_inc = '', 10
	verbose = debug_items = False

	def __init__( self, items,
			filter_main=None, filter_ammo=None,
			show_ammo=False, debug_items=False, stats_path=None ):
		self.items_all = items
		self.items = filter_items(items, filter_main or list())
		if not show_ammo: self.items_ammo = dict()
		else:
			self.items_ammo = filter_items(
				items, filter_ammo, types=2 ) if filter_ammo else items
		self.debug_items, self.stats_path = debug_items, stats_path

	def __enter__(self):
		self.c = None
		return self

	def __exit__(self, exc_t, exc_val, exc_tb):
		if not self.c: return
		self.c.endwin()
		self.c = None


	_focus = 0
	@property
	def stat_focus(self): return self._focus
	@stat_focus.setter
	def stat_focus(self, v):
		self._focus = v
		focus_max = len(self.stats) - 1
		if self._focus < 0: self._focus = focus_max
		elif self._focus > focus_max: self._focus = 0
	@property
	def stat_focus_k(self): return list(self.stats.keys())[self.stat_focus]

	def stats_load(self):
		if not self.stats_path: return
		try:
			with open(self.stats_path) as src: stats = json.load(src)
			if stats: self.stats.update(stats)
		except Exception as err:
			log.error( 'Failed to load stats data'
				' from {!r}: {} {}', self.stats_path, type(err), err )

	def stats_save(self):
		if not self.stats_path: return
		with open(self.stats_path, 'w') as dst: json.dump(self.stats, dst)


	def run(self):
		self.stats_load()
		import locale, curses
		locale.setlocale(locale.LC_ALL, '')
		self.c = curses
		self.c.wrapper(self._run)

	def c_win_init(self):
		win = self.c_stdscr
		win.keypad(True)
		win.bkgdset(' ')
		return win

	def c_win_add(self, w, n, pos, line, hl=False):
		if n >= self.line_n: return
		line = line[:self.line_len - pos]
		try:
			w.addstr( n, pos, line,
				self.c.A_NORMAL if not hl else self.c.A_REVERSE )
		except Exception as err:
			log.error(
				'Failed to add line (n={} pos={} len={}) - {!r}: {} {}',
				n, pos, len(line), line, type(err), err )
			try: w.addstr(n, pos, '*ERROR*')
			except self.c.error: pass

	def c_key(self, k):
		if len(k) == 1: return ord(k)
		return getattr(self.c, 'key_{}'.format(k).upper(), object())


	def _run(self, stdscr):
		c, self.c_stdscr = self.c, stdscr
		c.curs_set(0)
		c.use_default_colors()
		win = self.c_win_init()
		key_match = ( lambda *choices:
			key_name.decode().lower() in choices
				or key in map(self.c_key, choices) )

		while True:
			self.c_win_draw(win)

			key = None
			while True:
				try: key = win.getch()
				except KeyboardInterrupt: key = self.c_key('q')
				except c.error: break
				try: key_name = c.keyname(key)
				except ValueError: key_name = 'unknown' # e.g. "-1"
				break
			if key is None: continue
			log.debug('Keypress event: {} ({})', key, key_name)

			stats_update = False
			if key_match('resize'): pass
			elif key_match('q'): break
			elif key_match('left'): self.stat_focus -= 1
			elif key_match('right'): self.stat_focus += 1
			elif key_match('enter', '^j') and self.stat_enter:
				k = self.stat_focus_k
				try: stats_update, self.stats[k] = True, int(self.stat_enter)
				except Exception as err:
					log.error('Failed to convert input to stat value ({}): {!r}', k, self.stat_enter)
				self.stat_enter = ''
				self.stat_focus += 1
			elif key_name.isdigit(): self.stat_enter += key_name.decode()
			elif key_match('up'):
				stats_update, v_mod = True, self.stats[self.stat_focus_k] % self.stat_inc
				self.stats[self.stat_focus_k] += (self.stat_inc - v_mod)
			elif key_match('down'):
				stats_update, v_mod = True, self.stats[self.stat_focus_k] % self.stat_inc
				self.stats[self.stat_focus_k] -= v_mod or self.stat_inc
			elif key_match('v'): self.verbose = not self.verbose

			if stats_update: self.stats_save()


	def c_win_draw(self, w):
		w.erase()
		wh, ww = w.getmaxyx()
		self.line_len, self.line_n = ww, wh
		out = ft.partial(self.c_win_add, w)

		row, pos = 1, 1
		for n, (k, v) in enumerate(self.stats.items()):
			stat = '{}: {:<3d}'.format(k, v)
			out(row, pos, stat, hl=(n == self.stat_focus))
			pos += len(stat) + 1
		out(row, pos, ' >> {}'.format(self.stat_enter))
		row += 2

		line_fmt = '{} {} -- {}'
		line_fmt_len = len(line_fmt.format(*['']*3))
		p_fmt = (
			'{h}{t} {dt:>3s} {dmg:>3d} {acc:>3d}% {dpu:>4.1f} - {tu:>2d}{tu_k}TU {e:>2d}E{q}{x}' )
		p_fmt_len = len(p_fmt.format(
			h=1, t='M', dt='cut', dmg=110, acc=200,
			dpu=20.3333, tu=99, tu_k='%', e=99, q=' !!!', x='' ))
		weight_fmt = '[{:>2d}]'
		weight_fmt_len = len(weight_fmt.format(99))
		name_len_max = min(
			self.line_len - line_fmt_len - weight_fmt_len - p_fmt_len,
			max(len(item['name']) for item in self.items.values()) )
		name_fmt = '{{:<{}s}}'.format(name_len_max)

		head_fmt = line_fmt.format('{}', '{{:<{}}}'.format(name_len_max), '{}')
		out(row, 0, head_fmt.format(
			'wght', 'weapon', 'HM type dmg acc  dpu - costs     [specials]' ))
		row += 1
		out(row, 0, head_fmt.format('----', '-'*9, '-'*50))
		row += 1

		pk = ( lambda k,t=True,o='?',f=None:
			{ True: t if t is not True else item.get(k),
				False: f if f is not None else o,
				None: o }[item.get(k) and bool(item[k])] )
		# Filled-in by hand from bootypedia, when bumped into new one (displays as number)
		# Strings like STR_DAMAGE_* can be searched and resolved instead to get all types
		dt_name = ( lambda dt:
			{7: 'cut', 1: 'prc', 3: 'con', 6: 'stn', 5: 'las', 4: 'pls', 9: 'chk', 0: '---'}\
			.get(dt, 'x{}'.format(dt)) )

		items = sorted(self.items.values(), key=op.itemgetter('name'))
		for item in items:
			q, x, ext, item = None, '', list(), item.copy()

			if item.get('compatibleAmmo'):
				if len(item['compatibleAmmo']) == 1: at, = item['compatibleAmmo']
				else:
					at = None
					for atx in item['compatibleAmmo']:
						if atx not in self.items_ammo: continue
						at = atx if at is None else False
				if at:
					for k, v in self.items_all[at].items():
						if k in [ 'name', 'type', 'battleType', 'listOrder',
								'categories', 'armor', 'size', 'requires', 'requiresBuy', 'weight' ]\
							or k.startswith('cost') or k.startswith('inv') or k.endswith('Sprite'): continue
						if k in item:
							log.debug( 'Skipping item/ammo key {!r} conflict for'
								' item {!r}, values (item/ammo): {!r} / {!r}', k, item['name'], item[k], v )
							q = True
						else: item[k] = v

			if self.debug_items: log_data(item, 'item info')
			name = name_fmt.format(item['name'][:name_len_max])
			weight = item.get('weight', -1)
			if weight < 0: q = True
			weight = weight_fmt.format(weight)
			acc_mods = dmg_mods = None

			cost_tu = cost_e = -1
			tu_k = pk('flatRate', ' ', '%')
			for t, tk in dict(M='melee', X='auto', S='snap', A='aimed', T='throw').items():
				k_acc, k_tu, k_cost = (k.format(tk.title()) for k in ['accuracy{}', 'tu{}', 'cost{}'])
				if k_acc in item: break
			else: t, tk, q = '?', None, True
			if k_tu in item: cost_tu, cost_e = item[k_tu], 0
			elif k_cost in item:
				c = item[k_cost]
				cost_tu, cost_e = c.get('time'), c.get('energy')
				if tu_k == '%' and self.stats.get('time', 0) > 0:
					cost_tu = int(round(self.stats['time'] * cost_tu / 100.0))

			acc = acc_base = item.get(k_acc, -1)
			if acc >= 0:
				v = None
				for tk in 'melee', 'accuracy':
					v = item.get('{}Multiplier'.format(tk))
					if v:
						vs, acc_mods = list(), list()
						for k, s in self.stats.items():
							vk = v.get(k, 0)
							if isinstance(vk, list): vk = max(vk)
							if not vk: continue
							acc_mods.append('{}*{}'.format(k, vk))
							vs.append(vk*s)
						vk = v.get('flatHundred', 0) * 100
						if vk: acc_mods = [str(vk)] + acc_mods
						acc, acc_mods = acc * (vk + sum(vs)) / 100, ' + '.join(acc_mods)

			dmg = dmg_base = item.get('power', -1)
			if dmg >= 0:
				v = item.get('damageBonus')
				if v:
					vs, dmg_mods = list(), list()
					for k, s in self.stats.items():
						vk = v.get(k, 0)
						if not vk: continue
						dmg_mods.append('{}*{}'.format(k, vk))
						vs.append(vk*s)
					dmg, dmg_mods = dmg + sum(vs), ' + '.join(dmg_mods)

			dpu = -1
			if dmg >= 0 and acc >= 0 and cost_tu >= 0:
				dpu = dmg * (acc / 100.0) / cost_tu

			da = (item.get('damageAlter') or dict()).copy()
			if da:
				if 'ArmorEffectiveness' in da:
					v = da.pop('ArmorEffectiveness')
					if v != 1.0: ext.append('kArmor={}'.format(v))
				if 'ResistType' in da:
					ext.append('res={}'.format(dt_name(da.pop('ResistType'))))
				for k, kx in [
						('ToHealth', 'toH'), ('ToStun', 'toStn'),
						('ToEnergy', 'toE'), ('ToMorale', 'toM'),
						('ToTime', 'toTU'), ('ToArmorPre', 'toA-pre') ]:
					if k in da: ext.append('{}={}'.format(kx, da.pop(k)))
				if 'RandomType' in da: ext.append('d{}'.format(da.pop('RandomType')))
				if da.pop('IgnoreOverKill', None): ext.append('no-ok')
				if da.pop('IgnoreDirection', None): ext.append('unidir')
				for k in ['FixRadius']: da.pop(k, None)
				if da: ext.append('+')

			dmg_decay = item.get('powerRangeReduction', 0)
			if dmg_decay:
				ext.append('-dmg[{}+]={}'.format(
					item.get('powerRangeThreshold', 0), dmg_decay ))
			acc_decay = item.get('dropoff', 1)
			if acc_decay != 1: ext.append('-acc={}'.format(acc_decay))
			dmg_ext = item.get('damageBonus', dict()).get('firing')
			if dmg_ext: ext.append('+dmg[skill]={}'.format(dmg_ext))

			if ext: x += ' [{}]'.format(' '.join(ext))

			if t == 'M' and 'meleePower' in item: q = True
			if item.get('skillApplied'): q = True

			p = dict(
				h=pk('twoHanded', '2', '1'), t=t,
				dt=dt_name(item.get('damageType', 0)),
				dmg=int(round(dmg)), acc=int(round(acc)),
				dpu=dpu, tu=cost_tu, tu_k=tu_k, e=cost_e,
				q=' !!!' if q else '', x=x )
			for v in p.values():
				if v == -1: q = True
			# log.debug(' - item params: {}', p)
			out(row, 0, line_fmt.format(weight, name, p_fmt.format(**p)))
			row += 1
			if self.verbose:
				line = 'acc: {}'.format(acc_base)
				if acc_mods: line += ' * ( {} )'.format(acc_mods)
				out(row, 5, line)
				row += 1
				line = 'power: {}'.format(dmg_base)
				if dmg_mods: line += ' + {}'.format(dmg_mods)
				out(row, 5, line)
				row += 2


def load_items(p_rul, p_cache=None, p_lang=None):
	assert p_rul or p_cache,\
		'At least one of ruleset fle or cache file must be specified.'

	ts_rul, ts_cache = (
		(0 if not (p and exists(p)) else os.stat(p).st_mtime)
		for p in [p_rul, p_cache] )
	cache_load = p_cache and ts_cache and ts_rul <= ts_cache
	cache_save = p_cache and ts_rul > ts_cache

	if cache_load:
		log.debug('Loading cache file...')
		with open(p_cache) as src: items = json.load(src)

	else:
		log.debug('Processing main ruleset file...')
		with open(p_rul) as src: items = yaml.load(src)
		items = items['items']

		log.debug('Processing translation files...')
		str_trans = dict()
		for p in p_lang or list():
			with open(p) as src: lang = yaml.load(src)
			if isinstance(lang, dict):
				if 'en-US' in lang:
					str_trans.update(lang['en-US'])
					lang = None
				elif 'extraStrings' in lang:
					for trans in lang['extraStrings']:
						if trans.get('type') == 'en-US':
							str_trans.update(trans['strings'])
							lang = None
			if lang:
				raise ValueError('Unable to parse lang-file: {!r}'.format(p))
		del lang

		log.debug('Mapping item type strings to names...')
		items, item_list = dict(), items
		for item in item_list:
			if item.get('delete'): continue
			t = item.get('type')
			if not t:
				log.debug('Discarding item without type: {}', item)
				continue
			item['name'] = item.get('name')
			if item['name']: item['name'] = str_trans.get(item['name']) or item['name']
			else: item['name'] = str_trans.get(t)
			if not item['name']:
				log.debug('Discarding item with no matching name: {}', item)
				continue
			assert t not in items, [t, item]
			items[t] = item
		del item_list

	if cache_save:
		log.debug('Saving cache file...')
		with open(p_cache, 'w') as dst: json.dump(items, dst)

	return items


def filter_items(items_all, pats, types=None):
	items, types = dict(), types or [1, 3, 4, 5]
	if not isinstance(types, (tuple, list)): types = [types]
	for t, item in items_all.items():
		if not item.get('battleType') in types:
			# log.debug('Skipping non-equipment item: {}', item)
			continue
		name = item['name']
		for p in pats:
			if p.startswith('re:'):
				if re.search(p[3:], name): break
			elif p.startswith('x:'):
				if p[2:] == name: break
			elif p.startswith('c:'):
				if p[2:] in name: break
			elif p.startswith('STR_') and t == p: break
			elif p.lower() in name.lower(): break
		else: continue
		items[t] = item
	return items


def main(args=None):
	import argparse
	parser = argparse.ArgumentParser(
		description='Curses-based calculator tool for'
			' weapon stats in OpenXcom X-Piratez mod.')

	parser.add_argument('name', nargs='*',
		help='Item name part(s) to pick for display. Case-sensitive (!!!).'
			' Can start from STR_ to use raw item name/type, or be prefixed'
				' by "re:" to be treated as regexp, "x:" for exact name match only.')

	parser.add_argument('-r', '--ruleset', help='Path to YAML ruleset file to use values from.')
	parser.add_argument('-l', '--lang', action='append',
		help='Path to language file(s).'
			' Can be used multiple times, with strings in later ones overriding former.')
	parser.add_argument('-c', '--cache', help='JSON file to cache/use parsed item data to/from.')
	parser.add_argument('--no-stats-cache', action='store_true',
		help='Do not store entered stats between runs in TMPDIR.')

	parser.add_argument('-a', '--show-ammo', action='store_true',
		help='Update weapon stats with compatible ammo type, if it can be uniquely matched.')
	parser.add_argument('-t', '--ammo-type', action='append',
		help='Pattern(s) for matching ammo type, if several are available.'
			' Same rules for matching as with "name" argument. Implies --show-ammo.')

	parser.add_argument('-s', '--show-items',
		action='store_true', help='Special mode to only'
			' match specified items, print parameters to stdout and exit.')

	parser.add_argument('--debug', action='store_true', help='Verbose operation mode.')
	parser.add_argument('--debug-items',
		action='store_true', help='Log/pprint raw item parameters to stderr.')
	opts = parser.parse_args(sys.argv[1:] if args is None else args)

	global log, print
	logging.basicConfig(
		level=logging.DEBUG if opts.debug else logging.WARNING,
		format='%(asctime)s :: %(levelname)s :: %(message)s',
		datefmt='%Y-%m-%d %H:%M:%S' )
	log = get_logger('main')
	print = ft.partial(print, file=sys.stderr, flush=True) # stdout is used by curses

	log.debug('Loading items...')
	items = load_items(opts.ruleset, p_cache=opts.cache, p_lang=opts.lang)

	if opts.no_stats_cache: stats_tmp = None
	else:
		stats_tmp = basename(__file__)
		if stats_tmp.endswith('.py'): stats_tmp = stats_tmp[:-3]
		stats_tmp = join(tempfile.gettempdir(), '.{}.stats'.format(stats_tmp))

	with WeaponCalc(
			items, opts.name, opts.ammo_type,
			show_ammo=opts.show_ammo or opts.ammo_type,
			debug_items=opts.debug_items, stats_path=stats_tmp ) as app:
		if not app.items: parser.error('No items match any of the specified criterias')
		if opts.show_items:
			pprint.pprint(app.items)
			return
		log.debug('Entering curses ui loop...')
		app.run()

	log.debug('Finished')


if __name__ == '__main__': sys.exit(main())
