#!/usr/bin/env python3

import itertools as it, operator as op, functools as ft
import datetime as dt, pathlib as pl, collections as cs
import os, sys, math, subprocess

import yaml


def naturaltime_diff( ts, ts0=None, ext=' ago',
		_units=dict( h=3600, m=60, s=1,
			y=365.25*86400, mo=30.5*86400, w=7*86400, d=1*86400 ) ):
	if isinstance(ts, (int, float)): ts = dt.datetime.fromtimestamp(ts)
	if isinstance(ts0, (int, float)): ts0 = dt.datetime.fromtimestamp(ts0)
	delta = abs(
		(ts - (ts0 or dt.datetime.now()))
		if not isinstance(ts, dt.timedelta) else ts )

	res, s = list(), delta.total_seconds()
	for unit, unit_s in sorted(_units.items(), key=op.itemgetter(1), reverse=True):
		val = math.floor(s / float(unit_s))
		if not val: continue
		res.append('{:.0f}{}'.format(val, unit))
		if len(res) >= 2: break
		s -= val * unit_s

	if not res: return 'just now'
	else:
		if ext: res.append(ext)
		return ' '.join(res)

def _path_ts(*paths):
	for p in paths: yield pl.Path(p).stat().st_mtime
	for root, dirs, files in it.chain.from_iterable(os.walk(p) for p in paths):
		p = pl.Path(root)
		for name in files: yield (p / name).stat().st_mtime

def path_ts(*paths):
	return dt.datetime.fromtimestamp(max(_path_ts(*paths)))

def p(*a, file=None, end='\n', flush=False, **k):
	if len(a) > 0:
		fmt, a = a[0], a[1:]
		a, k = ( ([fmt.format(*a,**k)], dict())
			if isinstance(fmt, str) and (a or k)
			else ([fmt] + list(a), k) )
	print(*a, file=file, end=end, flush=flush, **k)

p_yaml = lambda d: yaml.safe_dump(
	d, sys.stdout, allow_unicode=True, default_flow_style=False )


class BakSlot:
	__slots__ = 'name p ts'.split()
	def __init__(self, *args, **kws):
		for k,v in it.chain(zip(self.__slots__, args), kws.items()): setattr(self, k, v)

cmd_rm_rf = lambda p: subprocess.run(['rm', '-rf', '--one-file-system', '--', str(p)], check=True)
cmd_mv = lambda src, dst: subprocess.run(['mv', '--', str(src), str(dst)], check=True)

def cmd_extract(p_save, p_dst):
	with open(p_save) as src: save = list(yaml.safe_load_all(src))
	slot, save = dict(), save[1]
	for base in save['bases']:
		base_id = base['name'].lower()
		if base_id not in slot: slot[base_id] = dict()
		soldiers = base.get('soldiers') or list()
		for s in soldiers:
			eq = s.get('equipmentLayout')
			armor = s.get('armor')
			if not eq: continue
			try: slot[base_id][s['id']] = dict(eq=eq, armor=armor)
			except:
				p_yaml(s)
				raise
	pl.Path(p_dst).write_text(yaml.safe_dump(slot))

def cmd_apply(p_slot, p_save, p_dst):
	with open(p_slot) as src: slot = yaml.safe_load(src)
	with open(p_save) as src: save_full = list(yaml.safe_load_all(src))
	match, save = cs.Counter(), save_full[1]
	for base_id, loadouts in slot.items():
		for base in save['bases']:
			if base['name'].lower() == base_id: break
		else:
			p('Loadout for nx base discarded: {}', base_id)
			continue
		match.update(base=1)
		soldiers = base.get('soldiers') or list()
		for s_id, loadout in loadouts.items():
			for s in soldiers:
				if s['id'] == s_id: break
			else: continue # no such soldier here anymore
			if loadout.get('armor'): s['armor'] = loadout['armor']
			if loadout.get('eq'): s['equipmentLayout'] = loadout['eq']
			match.update(soldier=1)
	p('Loadouts matched: {}', match)
	pl.Path(p_dst).write_text(yaml.safe_dump_all(save_full))


def main(args=None):
	p_save_def = pl.Path(__file__).with_suffix('.save')

	import argparse
	parser = argparse.ArgumentParser(
		description='OXCE loadout manager.')

	parser.add_argument('-s', '--save',
		metavar='path', default=str(p_save_def),
		help='Save game to operate on, or a symlink to it. Defailt: %(default)s')
	parser.add_argument('-b', '--backup-path',
		metavar='path', default=str(p_save_def.resolve()) + '.loadouts',
		help='Path to dir where loadouts will be saved, auto-created. Defailt: %(default)s')

	cmds = parser.add_subparsers(title='Commands', dest='call')

	cmd = cmds.add_parser('list', help='List all available saved loadout slots. Default action.')
	cmd.add_argument('name', nargs='?',
		help='Name - or part of it - to filter list of slots by.')

	cmd = cmds.add_parser('save',
		help='Backup current soldeir loadout state to a new slot.')
	cmd.add_argument('name', nargs='?',
		help='Specific name to assign to this loadout backup.'
			' Default is to generate name based on save date/time and backup count.'
			' If name already exists, it will be overwritten.')

	cmd = cmds.add_parser('restore', help='Restore loadout state (latest one by default).')
	cmd.add_argument('name', nargs='?',
		help='Name - or part of it - to match loadout slot by. Latest one will be used.')

	cmd = cmds.add_parser('remove', help='Remove specified slots.',
		description='Default is a dry-run operation mode,'
			' for safety reasons, use -x/--confirm option to actually delete stuff.')
	cmd.add_argument('name', nargs='?',
		help='Name - or part of it - to match loadout slots by. Empty - match all.')
	cmd.add_argument('-1', '--one-oldest', action='store_true',
		help='Match only one oldest slot instead of all of them.')
	cmd.add_argument('-n', '--n-oldest', type=int, metavar='n',
		help='Match only n oldest slots instead of all of them.')
	cmd.add_argument('-x', '--confirm', action='store_true',
		help='Confirm removal of all matched loadout slots.')

	opts = parser.parse_args(sys.argv[1:] if args is None else args)

	p_save = pl.Path(opts.save)
	p_bak = pl.Path(opts.backup_path).expanduser()
	p_bak.mkdir(parents=True, exist_ok=True)
	loadouts = sorted(
		(BakSlot(p.name, p, path_ts(p)) for p in p_bak.iterdir()),
		key=op.attrgetter('ts'), reverse=True )

	if opts.call == 'list' or not opts.call:
		if p_save.exists():
			ts = path_ts(p_save)
			p('\nActive loadout: {} ({})\n', ts, naturaltime_diff(ts))
		else:
			p('\nActive loadout: missing/invalid save path\n')
		name = getattr(opts, 'name', None)
		loadouts = list(s for s in loadouts if not name or name in s.name)
		p( 'Stored loadouts ({}, latest first){}:',
			len(loadouts), ' [filter={!r}]'.format(name) if name else '' )
		for s in loadouts: p('  {}: {} ({})', s.name, s.ts, naturaltime_diff(s.ts))
		p()

	elif opts.call == 'save':
		name, ts = opts.name, path_ts(p_save)
		if name == 'save':
			parser.error('Backup named "save" looks like a typo, not allowed')
		if not name:
			name = 'bak.{}.{}'.format(
				len(list(p_bak.iterdir())), ts.strftime('%Y-%m-%d_%H%M%S') )
		p_dst, p_dst_bak = p_bak / name, None
		if p_dst.exists():
			p_dst_bak = str(p_dst) + '.tmp'
			cmd_rm_rf(p_dst_bak)
			cmd_mv(p_dst, p_dst_bak)
		try: cmd_extract(p_save, p_dst)
		except:
			cmd_rm_rf(p_dst)
			if p_dst_bak: cmd_mv(p_dst_bak, p_dst)
			raise
		if p_dst_bak: cmd_rm_rf(p_dst_bak)
		s = BakSlot(p_dst.name, p_dst, path_ts(p_dst))
		p('{}: {} ({})', s.name, s.ts, naturaltime_diff(s.ts))

	elif opts.call == 'restore':
		if not loadouts: parser.error('No backed-up loadouts to restore.')
		if not opts.name: s = loadouts[0]
		else:
			for s in loadouts:
				if opts.name in s.name: break
			else: parser.error('Faled to match any slot by string: {!r}'.format(opts.name))
		p_dst = p_save.resolve()
		p_dst_bak = str(p_dst) + '.tmp'
		cmd_rm_rf(p_dst_bak)
		cmd_mv(p_dst, p_dst_bak)
		try: cmd_apply(s.p, p_dst_bak, p_dst)
		except:
			cmd_rm_rf(p_dst)
			cmd_mv(p_dst_bak, p_dst)
			raise
		cmd_rm_rf(p_dst_bak)
		p( 'Restored backup{} - {}: {} ({})',
			' [latest]' if not opts.name else '', s.name, s.ts, naturaltime_diff(s.ts) )

	elif opts.call == 'remove':
		if opts.one_oldest: match = 1
		elif opts.n_oldest: match = opts.n_oldest
		else: match = math.inf
		loadouts_matched = list()
		for s in reversed(loadouts):
			if not (not opts.name or opts.name in s.name): continue
			match -= 1
			loadouts_matched.append(s)
			if match <= 0: break
		p(
			'Backed-up loadouts removed (count={}, oldest first){}:',
			len(loadouts_matched), ' [DRY-RUN]' if not opts.confirm else '' )
		for s in loadouts_matched:
			p('  {}: {} ({})', s.name, s.ts, naturaltime_diff(s.ts))
			if opts.confirm: cmd_rm_rf(s.p)

	else: parser.error('Unknown command: {}'.format(opts.call))

if __name__ == '__main__': sys.exit(main())
