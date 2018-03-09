#!/usr/bin/env python

import itertools as it, operator as op, functools as ft
from datetime import datetime, timedelta
import os, sys, pathlib, logging, math, subprocess


profile_path_tpl = '~/.local/share/Red Hook Studios/Darkest/profile_{}'
backup_path = '~/.local/share/Red Hook Studios/Darkest.saves'


class LogMessage:
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

get_logger = lambda name: LogStyleAdapter(logging.getLogger(name))


def naturaltime_diff( ts, ts0=None, ext=None,
		_units=dict( h=3600, m=60, s=1,
			y=365.25*86400, mo=30.5*86400, w=7*86400, d=1*86400 ) ):
	if isinstance(ts, (int, float)): ts = datetime.fromtimestamp(ts)
	if isinstance(ts0, (int, float)): ts0 = datetime.fromtimestamp(ts0)
	delta = abs(
		(ts - (ts0 or datetime.now()))
		if not isinstance(ts, timedelta) else ts )

	res, s = list(), delta.total_seconds()
	for unit, unit_s in sorted(_units.items(), key=op.itemgetter(1), reverse=True):
		val = math.floor(s / float(unit_s))
		if not val: continue
		res.append('{:.0f}{}'.format(val, unit))
		if len(res) >= 2: break
		s -= val * unit_s

	if not res: return 'now'
	else:
		if ext: res.append(ext)
		return ' '.join(res)

def _path_ts(*paths):
	for root, dirs, files in it.chain.from_iterable(os.walk(str(p)) for p in paths):
		p = pathlib.Path(root)
		for name in files: yield (p / name).stat().st_mtime

def path_ts(*paths):
	return datetime.fromtimestamp(max(_path_ts(*paths)))

def p(*a, file=None, end='\n', flush=False, **k):
	if len(a) > 0:
		fmt, a = a[0], a[1:]
		a, k = ( ([fmt.format(*a,**k)], dict())
			if isinstance(fmt, str) and (a or k)
			else ([fmt] + list(a), k) )
	print(*a, file=file, end=end, flush=flush, **k)


class BakSlot:
	__slots__ = 'name p ts'.split()
	def __init__(self, *args, **kws):
		for k,v in it.chain(zip(self.__slots__, args), kws.items()): setattr(self, k, v)

cmd_rm_rf = lambda p: subprocess.run(['rm', '-rf', '--one-file-system', '--', str(p)], check=True)
cmd_cp_a = lambda src, dst: subprocess.run(['cp', '-a', '--', str(src), str(dst)], check=True)
cmd_mv = lambda src, dst: subprocess.run(['mv', '--', str(src), str(dst)], check=True)


def main(args=None):
	import argparse
	parser = argparse.ArgumentParser(
		description='Darkest Dungeon save game manager.')

	parser.add_argument('-p', '--profile', type=int, metavar='n', default=0,
		help='Profile number to operate on. Default: %(default)s')

	cmds = parser.add_subparsers(title='Commands', dest='call')

	cmd = cmds.add_parser('list', help='List all available savegame backups. Default action.')
	cmd.add_argument('name', nargs='?',
		help='Name - or part of it - to filter list of backup slots by.')

	cmd = cmds.add_parser('save', help='Backup current profile state to a new slot.')
	cmd.add_argument('name', nargs='?',
		help='Specific name to assign to this save backup.'
			' Default is to generate name based on save date/time and backup count.'
			' If name already exists, it will be overwritten.')

	cmd = cmds.add_parser('restore', help='Restore profile state backup (latest one by default).')
	cmd.add_argument('name', nargs='?',
		help='Name - or part of it - to match backup slot by. Latest one will be used.')

	cmd = cmds.add_parser('remove', help='Remove specified backups.',
		description='Default is a dry-run operation mode,'
			' for safety reasons, use -x/--confirm option to actually delete stuff.')
	cmd.add_argument('name', nargs='?',
		help='Name - or part of it - to match backup slots by. Empty - match all.')
	cmd.add_argument('-1', '--one-oldest', action='store_true',
		help='Match only one oldest backup slot instead of all of them.')
	cmd.add_argument('-n', '--n-oldest', type=int, metavar='n',
		help='Match only n oldest slots instead of all of them.')
	cmd.add_argument('-x', '--confirm', action='store_true',
		help='Confirm removal of all matched backup slots.')

	parser.add_argument('-d', '--debug', action='store_true', help='Verbose operation mode.')
	opts = parser.parse_args(sys.argv[1:] if args is None else args)

	global log
	logging.basicConfig(level=logging.DEBUG if opts.debug else logging.WARNING)
	log = get_logger('main')

	p_prof = pathlib.Path(profile_path_tpl.format(opts.profile)).expanduser()
	p_bak = pathlib.Path(backup_path).expanduser()
	p_bak.mkdir(parents=True, exist_ok=True)
	saves = sorted(
		(BakSlot(p.name, p, path_ts(p)) for p in p_bak.iterdir()),
		key=op.attrgetter('ts'), reverse=True )

	if opts.call == 'list' or not opts.call:
		if p_prof.exists():
			ts = path_ts(p_prof)
			p('\nActive savegame: {} ({} ago)\n', ts, naturaltime_diff(ts))
		else:
			p('\nActive savegame: missing path\n')
		name = getattr(opts, 'name', None)
		p( 'Backed-up saves (latest first){}:',
			' [filter={!r}]'.format(name) if name else '' )
		for s in saves:
			if not (not name or name in s.name): continue
			p('  {}: {} ({} ago)', s.name, s.ts, naturaltime_diff(s.ts))
		p()

	elif opts.call == 'save':
		name, ts = opts.name, path_ts(p_prof)
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
		try: cmd_cp_a(p_prof, p_dst)
		except:
			cmd_rm_rf(p_dst)
			cmd_mv(p_dst_bak, p_dst)
			raise
		if p_dst_bak: cmd_rm_rf(p_dst_bak)
		s = BakSlot(p_dst.name, p_dst, path_ts(p_dst))
		p('{}: {} ({} ago)', s.name, s.ts, naturaltime_diff(s.ts))

	elif opts.call == 'restore':
		if not saves: parser.error('No backed-up saves to restore.')
		if not opts.name: s = saves[0]
		else:
			for s in saves:
				if opts.name in s.name: break
			else: parser.error('Faled to match any slot by string: {!r}'.format(opts.name))
		p_dst_bak = str(p_prof) + '.tmp'
		cmd_rm_rf(p_dst_bak)
		cmd_mv(p_prof, p_dst_bak)
		try: cmd_cp_a(s.p, p_prof)
		except:
			cmd_rm_rf(p_prof)
			cmd_mv(p_dst_bak, p_prof)
			raise
		if p_dst_bak: cmd_rm_rf(p_dst_bak)
		p( 'Restored backup{} - {}: {} ({} ago)',
			' [latest]' if not opts.name else '', s.name, s.ts, naturaltime_diff(s.ts) )

	elif opts.call == 'remove':
		if opts.one_oldest: match = 1
		elif opts.n_oldest: match = opts.n_oldest
		else: match = math.inf
		saves_matched = list()
		for s in reversed(saves):
			if not (not opts.name or opts.name in s.name): continue
			match -= 1
			saves_matched.append(s)
			if match <= 0: break
		p(
			'Backed-up saves removed (count={}, oldest first){}:',
			len(saves_matched), ' [DRY-RUN]' if not opts.confirm else '' )
		for s in saves_matched:
			p('  {}: {} ({} ago)', s.name, s.ts, naturaltime_diff(s.ts))
			if opts.confirm: cmd_rm_rf(s.p)

	else: parser.error('Unknown command: {}'.format(opts.call))

if __name__ == '__main__': sys.exit(main())
