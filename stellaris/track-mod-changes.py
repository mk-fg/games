#!/usr/bin/env python3

import itertools as it, operator as op, functools as ft
import os, sys, re, subprocess, contextlib, tempfile
import pathlib as pl, datetime as dt

import textx as tx

try: from unidecode import unidecode
except ImportError:
	unidecode = lambda name: \
		name.encode('ascii', 'replace').decode()


path_home = pl.Path('~/.local//share/Paradox Interactive/Stellaris').expanduser()
path_mod = path_home / 'mod'
path_settings = path_home / 'settings.txt'

mm_mod = tx.metamodel_from_str('''
Model: items *= Item;
Comment: '#' /.*\\n/;
Item: Entry | Comment;
Entry: Val | Subblock | StringList;
Val: k=ID '=' v=Value;
Subblock: k=ID '=' '{' items*=Item '}';
StringList: k=ID '=' '{' strings*=STRING '}';
Value: STRING | ID | FLOAT | Bool;
Bool: 'yes' | 'no';
''')


_name_subs = {
	r'[\\/]': '_', r'^\.+': '_', r'[\x00-\x1f]': '_', r':': '-_',
	r'<': '(', r'>': ')', r'\*': '+', r'[|!"]': '-', r'[\?\*]': '_',
	'[\'’]': '', r'\.+$': '_', r'\s+$': '', r'\s': '_' }
def name_for_fs( name, fallback=...,
		_name_subs=list((re.compile(k), v) for k,v in _name_subs.items()) ):
	if not name and fallback is not ...: return fallback
	for sub_re, sub in _name_subs:
		name = sub_re.sub(sub, name)
	name = unidecode(name)
	return name

class AttrDict(dict):
	def __init__(self, *args, **kwargs):
		super(AttrDict, self).__init__(*args, **kwargs)
		for k, v in self.items():
			assert not getattr(self, k, None)
			if '-' in k: self[k.replace('-', '_')] = self.pop(k)
		self.__dict__ = self


def parse_mod_files(paths):
	mods = dict()
	for p in paths:
		descriptor = p.read_text(encoding='utf-8-sig')
		model = mm_mod.model_from_str(descriptor)
		mod = dict( (val.k, val.v)
			for val in tx.model.children_of_type('Val', model) )
		assert 'name' in mod, repr(p.read_text())
		assert mod['name'] not in mods, mod['name']
		mod['_descriptor'] = descriptor
		mods[mod['name']] = AttrDict(mod)
	return mods

def get_dir_mtime(p_dir):
	ts_dir = 0
	if p_dir.exists():
		ts_dir = p_dir.lstat().st_mtime
		for root, dirs, files in os.walk(p_dir):
			for p in it.chain(dirs, files):
				ts = (pl.Path(root) / p).lstat().st_mtime
				if ts > ts_dir: ts_dir = ts
	return ts_dir


def main(args=None):
	import argparse, textwrap

	dedent = lambda text: (textwrap.dedent(text).strip('\n') + '\n').replace('\t', '  ')
	class SmartHelpFormatter(argparse.HelpFormatter):
		def __init__(self, *args, **kws):
			return super().__init__(*args, **kws, width=100)
		def _fill_text(self, text, width, indent):
			if '\n' not in text: return super()._fill_text(text, width, indent)
			return ''.join(indent + line for line in text.splitlines(keepends=True))
		def _split_lines(self, text, width):
			return super()._split_lines(text, width)\
				if '\n' not in text else dedent(text).splitlines()

	parser = argparse.ArgumentParser(
		formatter_class=SmartHelpFormatter,
		description='Unpack all mods and commit any updates to these into git repo.')
	parser.add_argument('repo_dir', help='Git repo directory. Be sure to run "git init" there.')
	parser.add_argument('-d', '--stellaris-local-dir', metavar='path',
		help=f'''
			Base for dir mod/settings paths, to avoid
			  setting each of them separately can also be set separately.
			Default: {path_home}''')
	parser.add_argument('-p', '--mod-dir', metavar='path',
		help=f'''
			Path to look for *.mod files in. Not the steam-path with *.zip stuff.
			Default: {path_mod}''')
	parser.add_argument('-s', '--settings-file', metavar='path',
		help=f'''
			Path to game settings.txt file for a list of enabled mods.
			Can be set to "-" to disable tracking enabled mod list.
			Default: {path_settings}''')
	opts = parser.parse_args(sys.argv[1:] if args is None else args)

	p_repo = pl.Path(opts.repo_dir).resolve()
	assert (p_repo / '.git').is_dir(), p_repo
	p_home = ( pl.Path(opts.stellaris_local_dir).expanduser()
		if opts.stellaris_local_dir else None )
	p_mod_dir = ( pl.Path(opts.mod_dir).expanduser()
		if opts.mod_dir else (p_home / 'mod' if p_home else path_mod) )
	p_settings = ( pl.Path(opts.settings_file).expanduser()
		if opts.settings_file else (p_home / 'settings.txt' if p_home else path_settings) )
	if not p_home: p_home = path_home

	mods = parse_mod_files(p_mod_dir.glob('*.mod'))

	with p_settings.open(encoding='utf-8-sig') as src:
		model = mm_mod.model_from_str(src.read())
	mod_list = list( val for val in
		tx.model.children_of_type('StringList', model) if val.k == 'last_mods' )
	if mod_list: mod_list = sorted(mod_list[0].strings)
	(p_repo / 'mod_list.txt').write_text('\n'.join(mod_list + ['']))

	for mod_name, mod in mods.items():
		p_zip = mod.get('archive')
		p_dst = p_repo / name_for_fs(mod.name)
		p_dst_mtime = get_dir_mtime(p_dst)
		with contextlib.ExitStack() as ctx:
			if p_zip:
				p_zip = pl.Path(p_zip)
				if not p_zip.exists() or p_zip.lstat().st_mtime < p_dst_mtime: continue
				p_mod = pl.Path(ctx.enter_context(tempfile.TemporaryDirectory(prefix=f'{p_dst}.')))
				subprocess.run(
					['bsdtar', '-xf', p_zip, '--cd', p_mod],
					stderr=subprocess.DEVNULL, check=False )
			else:
				p_mod = p_mod_dir / pl.Path(mod.path).name
				if get_dir_mtime(p_mod) < p_dst_mtime: continue
			print(f'Syncing mod: {mod_name}')
			(p_mod / 'descriptor.mod').write_text(mod._descriptor)
			subprocess.run(['rsync', '-rc', '--delete', f'{p_mod}/.', p_dst], check=True)
			p_dst.touch()

	os.chdir(p_repo)
	subprocess.run(['git', 'add', '.'], check=True)
	proc = subprocess.run(['git', 'status', '--porcelain'], stdout=subprocess.PIPE, check=True)
	if proc.stdout:
		print('Mod changes:')
		for line in proc.stdout.splitlines(): print(f'  {line.decode()}')
		ts_str = dt.datetime.now().strftime('Update %Y-%m-%dT%H:%M:%S')
		subprocess.run(['git', 'commit', '-a', '-m', ts_str], stdout=subprocess.PIPE, check=True)

if __name__ == '__main__': sys.exit(main())
