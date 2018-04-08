#!/usr/bin/env python3

import itertools as it, operator as op, functools as ft
import os, sys, re, subprocess, pathlib as pl

import textx as tx


p_dst_asset = pl.Path('_convert.asset')
p_dst_txt = pl.Path('_convert.txt')

p_music = pl.Path('music')
p_loc = pl.Path('localisation')
p_mods = pl.Path('../_mods') # to find steam_id=name, can be done via descriptor.mod
p_ws = pl.Path('../_ws') # to check unpacked .asset via zipinfo
add_mod_prefix = True


mm_txt = tx.metamodel_from_str('''
Model: music *= Stuff;
Comment: '#' /.*\\n/;

Stuff: Block | Comment;
Block: Music | Song;
Music: 'music' '=' '{' vals *= Entry '}';
Song: 'song' '=' '{' vals *= Entry '}';

Entry: Val | Subblock | Comment;
Val: k=ID '=' ( v=STRING | v=NUMBER );
Subblock: sb=ID '=' '{' /[^}]+/ '}';
''')

mm_yml = tx.metamodel_from_str('''
Model: 'l_english:' items *= Item;
Comment: '#' /.*\\n/;
Item: Val | Comment;
Val: k=ID ':' INT v=STRING;
''')

mm_mod = tx.metamodel_from_str('''
Model: items *= Item;
Comment: '#' /.*\\n/;
Item: Entry | Comment;
Entry: Val | Subblock;
Val: k=ID '=' v=STRING;
Subblock: sb=ID '=' '{' /[^}]+/ '}';
''')


def main(args=None):
	import argparse

	parser = argparse.ArgumentParser(
		description='Localize and combine all the music .asset and .txt files.')
	parser.add_argument('-e', '--export', metavar='dir',
		help='Export (maybe-already-prefixed) tracks into per-mod directories under specified dir.'
			' All .ogg files will be renamed according to their in-game names from .asset files.')
	opts = parser.parse_args(sys.argv[1:] if args is None else args)


	### Parse localization

	loc = dict()
	if p_loc.exists():
		for p in p_loc.glob('**/*.yml'):
			loc_yaml = p.read_text(encoding='utf-8-sig').strip()
			if not loc_yaml.startswith('l_english:'): continue
			model = mm_yml.model_from_str(loc_yaml)
			for val in tx.model.children_of_type('Val', model):
				assert val.k not in loc, [p, val.k, val.v, loc[val.k]]
				loc[val.k] = val.v
			continue
	loc_unused = set(loc)


	### Parse mod files for mod-names

	mods = dict()
	for p in p_mods.glob('*.mod'):
		with p.open(encoding='utf-8-sig') as src:
			model = mm_mod.model_from_str(src.read())
		name = steam_id = None
		for val in tx.model.children_of_type('Val', model):
			if val.k == 'name': name = val.v
			elif val.k == 'remote_file_id': steam_id = int(val.v)
		if not steam_id: continue # local mods
		assert name, repr(p.read_text())
		mods[steam_id] = name

	mod_zips = set(p_ws.glob('**/*.zip'))
	mod_zips_used = set()


	### Process/combine .asset and .txt files into one

	assets = dict()
	for p_ass in p_music.glob('*.asset'):
		# p_txt = p_ass.with_suffix('.txt') - not needed
		mod_name = None

		model = mm_txt.model_from_str(p_ass.read_text(encoding='utf-8-sig'))
		for blk in tx.model.children_of_type('Music', model):
			vals = dict()
			for val in tx.model.children_of_type('Val', blk): vals[val.k] = val.v

			# Skip all "Main Theme" replacements
			if re.search(r'^maintheme\d*$', vals['name']): continue

			# Track name localization
			if vals['name'] in loc:
				loc_unused.discard(vals['name'])
				vals['name'] = loc[vals['name']]

			vals['name'] = vals['name'].strip('_') # ¯\_(ツ)_/¯

			if vals:
				if add_mod_prefix and not mod_name:
					for p_zip in it.chain(mod_zips, mod_zips_used):
						res = subprocess.run( ['zipinfo', p_zip, f'**/{p_ass.name}'],
							stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL )
						if not res.returncode: break
					else: assert False, p_ass
					if p_zip in mod_zips:
						mod_zips.remove(p_zip)
						mod_zips_used.add(p_zip)
					mod_name = mods[int(p_zip.parent.name)]
				assets.setdefault(mod_name, list()).append(vals)


	### Save resulting .asset/.txt files

	files = dict()
	with p_dst_asset.open('w') as dst_ass, p_dst_txt.open('w') as dst_txt:
		for mod_name, tracks in assets.items():
			for vals in tracks:
				name = name_mod = None
				name_ogg = vals.get('file')
				if not name_ogg or not (p_music / name_ogg).exists():
					print( 'Missing source ogg file, removing from assets:'
						f' {name_ogg!r} [mod={mod_name!r}, name={vals.get("name")!r}]' )
					continue
				dst_ass.write('music = {\n')
				dst_txt.write('song = {\n')
				for k,v in vals.items():
					if k == 'name':
						if add_mod_prefix:
							name_mod, name = mod_name, v
							v = f'{mod_name} :: {v}'
						elif ' :: ' in v: name_mod, name = v.split(' :: ')
						else: name = v
					if k == 'file': name_ogg = v
					if isinstance(v, str): v = '"{}"'.format(v.replace('"', "'"))
					dst_ass.write(f'  {k} = {v}\n')
					if k == 'name': dst_txt.write(f'  {k} = {v}\n')
				dst_ass.write('}\n')
				dst_txt.write('}\n')
				files.setdefault(name_mod, dict())[name] = name_ogg

	# if loc_unused:
	# 	print('loc unused:')
	# 	for k in sorted(loc_unused): print(f'  {k}: {loc[k]}')


	### Export

	if opts.export:
		p_export = pl.Path(opts.export)
		p_export.mkdir(parents=True, exist_ok=True)

		import shutil
		try: from unidecode import unidecode
		except ImportError:
			unidecode = lambda name: \
				name.encode('ascii', 'replace').decode()

		_name_subs = {
			r'[\\/]': '_', r'^\.+': '_', r'[\x00-\x1f]': '_', r':': '-_',
			r'<': '(', r'>': ')', r'\*': '+', r'[|!"]': '-', r'[\?\*]': '_',
			'[\'’]': '', r'\.+$': '_', r'\s+$': '', r'\s': '_' }
		_name_subs = list(
			(re.compile(k), v) for k,v in _name_subs.items() )

		def name_for_fs(name, fallback=...):
			if not name and fallback is not ...: return fallback
			for sub_re, sub in _name_subs:
				name = sub_re.sub(sub, name)
			name = unidecode(name)
			return name

		for name_mod, tracks in files.items():
			p_mod = p_export / name_for_fs(name_mod, '_unsorted')
			p_mod.mkdir(exist_ok=True)
			for name, name_ogg in tracks.items():
				p_ogg = p_music / name_ogg
				if not p_ogg.exists():
					print(f'Missing source ogg file: {p_ogg}')
					continue
				p_dst = p_mod / (name_for_fs(name) + '.ogg')
				if p_dst.exists() and p_ogg.stat().st_size == p_dst.stat().st_size: continue
				shutil.copyfile(p_ogg, p_dst)


if __name__ == '__main__': sys.exit(main())
