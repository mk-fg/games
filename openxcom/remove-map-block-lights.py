#!/usr/bin/env python3

import pathlib as pl, collections as cs, functools as ft
import os, sys, pprint, unicodedata, struct, time

import yaml # pip install --user pyyaml


p = ft.partial(print, flush=True)
p_err = lambda s, *sx: [p(f'ERROR: {s}', *sx, file=sys.stderr), 1][1]
str_norm = lambda v: unicodedata.normalize('NFKC', v.strip()).casefold()


def find_btd_entities( data, query=None, *,
		lookup=None, path_filter=None, results=None, path=None, btd='battlescapeTerrainData' ):
	'Find dicts with battlescapeTerrainData matching "[key1 key2 ...] [key=value]" query string.'
	if results is None: results = list()
	if path is None: path = list()

	if query:
		path_filter = str_norm(query).split()
		if '=' in path_filter[-1]: path_filter, lookup = path_filter[:-1], path_filter[-1]

	recurse = ft.partial( find_btd_entities,
		path_filter=path_filter, lookup=lookup, results=results )

	if isinstance(data, dict) and btd in data:
		if data and path_filter:
			query = list(reversed(path_filter))
			for k in path:
				if k == query[-1]: query.pop()
				if not query: break
			else: data = None
		if data and lookup:
			lk, lv = lookup.split('=', 1)
			for k, v in data.items():
				if str_norm(k) == lk and str_norm(str(v)) == lv: break
			else: data = None
		if data: results.append((path, data))

	elif isinstance(data, dict) and btd not in data:
		for k, v in data.items(): recurse(v, path=path + [str_norm(str(k))])
	elif isinstance(data, list):
		for n, v in enumerate(data): recurse(v, path=path + [n])
	return results


class PathLookupError(Exception): pass

def path_sub_ci(name, *p_list):
	s = str_norm(name)
	for p in p_list:
		for p_sub in p.iterdir():
			if str_norm(p_sub.name) == s: return p_sub
	raise PathLookupError(f'"{name}" not found within path(s): {p_list}')


# Struct/parser code from https://github.com/StoddardOXC/minicom/
# https://www.ufopaedia.org/index.php/TERRAIN
# https://www.ufopaedia.org/index.php/MAPS
# https://www.ufopaedia.org/index.php/MCD

MapRec = cs.namedtuple('MapRec', 'floor west north ob')
MapStruct = cs.namedtuple('MapStruct', 'cells height width depth')
def load_map(map_path):
	map_data = open(map_path, 'rb').read()
	eb = (len(map_data) - 3) % 4
	if eb > 0:
		#print("{}: {} extra bytes".format(map_path, eb))
		# many maps seem to have an extra byte tacked on.
		# must be a bug in some editor
		pass
	return MapStruct(
		[MapRec(*rec) for rec in struct.iter_unpack('4B', map_data[3:-eb])],
		*struct.unpack('3B', map_data[:3]) )

MCDRec = cs.namedtuple('MCDRec', '''path pos Frame LOFT ScanG UFO_Door
	Stop_LOS No_Floor Big_Wall Gravlift Door Block_Fire Block_Smoke
	u39 TU_Walk TU_Slide TU_Fly Armor HE_Block Die_MCD Flammable Alt_MCD
	u48 T_Level P_Level u51 Light_Block Footstep Tile_Type HE_Type
	HE_Strength Smoke_Blockage Fuel Light_Source Target_Type Xcom_Base u62''')
MCDStruct = struct.Struct("<8s12sH8x12B6Bb13B")
def load_mcd(mcd_path):
	for n, mcd in enumerate(MCDStruct.iter_unpack(open(mcd_path, 'rb').read())):
		mcd = MCDRec(None, None, *mcd)._asdict()
		mcd['Frame'] = struct.unpack('8B', mcd['Frame'])
		mcd['LOFT'] = struct.unpack('12B', mcd['LOFT'])
		mcd['path'], mcd['pos'] = mcd_path, n * 62
		yield MCDRec(**mcd)


def main(args=None):
	import argparse, textwrap
	dd = lambda text: (textwrap.dedent(text).strip('\n') + '\n').replace('\t', '  ')

	parser = argparse.ArgumentParser(
		formatter_class=argparse.RawTextHelpFormatter,
		description=dd('''
			Script to lookup openxcom map block
				and remove all lights from its associated mcd files.
			Exits with error if it can't find unique block via entity_lookup query.'''))

	parser.add_argument('ruleset',
		help='Ruleset with the entity that has battlescapeTerrainData definition.')
	parser.add_argument('entity_lookup',
		help=dd('''
			Lookup path for entity definition where map block should be edited.
			Example: "crafts type=str_fatsub" - to lookup battlescapeTerrainData
				in a mapping with that key=value match (case-insensitive),
				with "crafts" key somewhere in the path to it.
			https://github.com/mk-fg/fgtk/blob/master/yaml-flatten can help to navigate nesting.'''))

	parser.add_argument('-d', '--mod-dir', action='append', metavar='path',
		help=dd('''
			Path(s) to lookup "maps" and "terrain" dirs in.
			Defaults to current path, if none specified. Can be specified multiple times.'''))

	parser.add_argument('-n', '--dry-run', action='store_true', help='Do not update actual files.')
	opts = parser.parse_args(sys.argv[1:] if args is None else args)

	paths_map, paths_terrain = list(), list()
	for p_mod in map(pl.Path, (opts.mod_dir or ['.'])):
		for p_sub in p_mod.iterdir():
			s = str_norm(p_sub.name)
			if s == 'maps': paths_map.append(p_sub)
			if s == 'terrain': paths_terrain.append(p_sub)
	if not (paths_map and paths_terrain):
		return p_err('No maps/terrain subdirs within specified -d/--mod-dir paths')

	ruleset, entities = pl.Path(opts.ruleset), list()
	for n, src in enumerate(yaml.safe_load_all(ruleset.open()), 1):
		for path, entity in find_btd_entities(src, opts.entity_lookup):
			entities.append(([f'doc-{n}'] + path, entity))

	if len(entities) != 1:
		p_err( 'Failed to match unique block for lookup:'
			f' {opts.entity_lookup!r} (matches={len(entities)})' )
		for path, entity in entities:
			p('---------- Matched block: ' + '.'.join(map(str, path)))
			pprint.pprint(entity)
			p()
		return p_err('Aborting without unique match for a block to patch')
	btd = entities[0][1]['battlescapeTerrainData']

	maps = list(block['name'] for block in btd['mapBlocks'])
	mcds = btd['mapDataSets']

	tileset = list()
	for mcd in mcds:
		p_src = path_sub_ci(f'{mcd}.mcd', *paths_terrain)
		tileset.extend(load_mcd(p_src))
	p(f'Total tileset size: {len(tileset)} [{len(mcds)} mcd(s)]')

	tileset_map = dict()
	for m in maps:
		p_src = path_sub_ci(f'{m}.map', *paths_map)
		m = load_map(p_src)
		for cell in m.cells:
			for tile_idx in cell: tileset_map[tile_idx] = tileset[tile_idx]
	p(f'Used tiles from tileset: {len(tileset_map)} [{len(maps)} map(s)]')

	byte_flips = cs.defaultdict(dict)
	for tile_idx, tile in tileset_map.items():
		if not tile.Light_Source: continue
		byte_flips[tile.path][tile.pos + 58] = tile.Light_Source
	p(
		f'Performing {sum(len(s) for s in byte_flips.values())}'
		f' byte-flip(s) in {len(byte_flips)} mcd file(s)' )

	for p_mcd, flips in byte_flips.items():
		mcd_bak = p_mcd.read_bytes()
		mcd = bytearray(mcd_bak)
		for pos, v in sorted(flips.items()):
			v_chk, mcd[pos] = mcd[pos], 0
			if v_chk == v: continue
			return p_err(f'Sanity check fail for byte: {p_mcd} [byte={v_chk} expected={v}]')
		bak = p_mcd.parent / (p_mcd.name + '.bak.' + time.strftime('%Y%m%d_%H%M%S'))
		if not opts.dry_run:
			bak.write_bytes(mcd_bak)
			p_mcd.write_bytes(mcd)
			p(f'Updated mcd file: {p_mcd}')
		else: p(f'Not updating mcd file due to -n/--dry-run: {p_mcd}')

if __name__ == '__main__': sys.exit(main())
