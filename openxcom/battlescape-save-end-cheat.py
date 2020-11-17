#!/usr/bin/env python

import os, sys, pathlib as pl, operator as op, functools as ft, collections as cs

from ruamel import yaml # pip install --user ruamel.yaml


p = ft.partial(print, flush=True)
p_err = lambda s, *sx: p(f'ERROR: {s}', *sx, file=sys.stderr)

tweak_t = cs.namedtuple( 'Tweak',
	'line_n col match_prefix match_value value comment' )


def main(args=None):
	import argparse
	parser = argparse.ArgumentParser(
		description='Cheat script to replace OXCE save file'
			' with the one where all enemies on the map are stunned.')
	parser.add_argument('save', help='Path to YAML save file to process/replace.')
	parser.add_argument('-n', '--dry-run', action='store_true',
		help='Create .new file next to source one with all tweaks, but do not replace it.')
	opts = parser.parse_args(sys.argv[1:] if args is None else args)

	src, p_src = None, pl.Path(opts.save)
	with p_src.open() as src_file:
		for src in yaml.round_trip_load_all(src_file): pass
	if not src: parser.error(f'Last YAML document if file is empty: {p}')

	tweaks = list()
	for n, unit in enumerate(src['battleGame']['units']):
		if unit.get('faction') == 0: continue # player units
		if unit.get('wantsToSurrender') and unit.get('isSurrendering'): continue
		if unit['health'] <= 0 or (
			unit['stunlevel'] > 0 and unit['stunlevel'] >= unit['health'] ): continue

		if unit.get('wantsToSurrender'): # get unit to surrender, if possible
			line_n, col = unit.lc.value('isSurrendering')
			tweaks.append(tweak_t(
				line_n, col, 'isSurrendering:', 'false', 'true',
				f'isSurrendering=true for unit-{n} [{unit["genUnitType"]}]' ))

		else: # stun otherwise
			line_n, col = unit.lc.value('stunlevel')
			try: hp = unit['currStats']['health']
			except KeyError: hp = unit['health']
			tweaks.append(tweak_t(
				line_n, col, 'stunlevel:', str(unit['stunlevel']), str((hp + 1) * 2),
				f'Stun unit-{n} [{unit["genUnitType"]}]' ))

	tweaks.sort(key=op.attrgetter('line_n'), reverse=True)

	if not tweaks:
		p('Failed to find any stunlevel values to update, leaving file as-is')
		return
	p(f'Detected {len(tweaks)} unit value(s) to update')

	p_dst = p_src.parent / (p_src.name + '.new')
	with p_src.open() as src, p_dst.open('w') as dst:
		for n, line in enumerate(src):
			if tweaks and tweaks[-1].line_n == n:
				tt = tweaks.pop()
				p(f' - tweak [line={tt.line_n} col={tt.col}]: {tt.comment}')
				if not (
						(not tt.match_prefix or line[:tt.col].strip() == tt.match_prefix)
						and (not tt.match_value or line[tt.col:].strip() == tt.match_value) ):
					p_err(f'Failed to apply tweak {tt} to {line!r}, aborting')
					return 1
				line = line[:tt.col] + tt.value
			dst.write(line.rstrip() + '\n')

	if not opts.dry_run:
		p_bak = p_src.parent / (p_src.name + '.bak')
		p(f'Replacing {p_src.name} with updated {p_dst.name} (backup={p_bak.name}) ...')
		p_src.rename(p_bak)
		p_dst.rename(p_src)
	else: p(f'Note: -n/--dry-run mode specified, leaving new {p_dst.name} file as-is next to source')

	p('Finished')

if __name__ == '__main__': sys.exit(main())
