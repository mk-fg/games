#!/usr/bin/env python3

import itertools as it, operator as op, functools as ft
import os, sys, re, subprocess, contextlib, tempfile
import pathlib as pl, datetime as dt

import textx as tx

try: from unidecode import unidecode
except ImportError:
	unidecode = lambda name: \
		name.encode('ascii', 'replace').decode()


mod_path_default = '~/.local//share/Paradox Interactive/Stellaris/mod'

mm_mod = tx.metamodel_from_str('''
Model: items *= Item;
Comment: '#' /.*\\n/;
Item: Entry | Comment;
Entry: Val | Subblock;
Val: k=ID '=' v=STRING;
Subblock: sb=ID '=' '{' /[^}]+/ '}';
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
		with p.open(encoding='utf-8-sig') as src:
			model = mm_mod.model_from_str(src.read())
		mod = dict( (val.k, val.v)
			for val in tx.model.children_of_type('Val', model) )
		assert 'name' in mod, repr(p.read_text())
		assert mod['name'] not in mods, mod['name']
		mods[mod['name']] = AttrDict(mod)
	return mods

def get_dir_mtime(p_dir):
	ts_dir = 0
	if p_dir.exists():
		for root, dirs, files in os.walk(p_dir):
			for p in it.chain(dirs, files):
				ts = (pl.Path(root) / p).lstat().st_mtime
				if ts > ts_dir: ts_dir = ts
	return ts_dir


def main(args=None):
	import argparse
	parser = argparse.ArgumentParser(
		description='Unpack all mods and commit any updates to these into git repo.')
	parser.add_argument('repo_dir', help='Git repo directory. Be sure to run "git init" there.')
	parser.add_argument('-p', '--mod-dir',
		default=mod_path_default, metavar='path',
		help='Path to look for *.mod files in. Not the steam-path with *.zip stuff.')
	opts = parser.parse_args(sys.argv[1:] if args is None else args)

	p_repo = pl.Path(opts.repo_dir).resolve()
	assert (p_repo / '.git').is_dir(), p_repo

	mod_dir = pl.Path(opts.mod_dir).expanduser()
	mods = parse_mod_files(mod_dir.glob('*.mod'))

	for mod_name, mod in mods.items():
		p_zip = mod.get('archive')
		p_dst = p_repo / name_for_fs(mod.name)
		with contextlib.ExitStack() as ctx:
			if p_zip:
				p_zip = pl.Path(p_zip)
				if p_zip.lstat().st_mtime < get_dir_mtime(p_dst): continue
				p_mod = pl.Path(ctx.enter_context(tempfile.TemporaryDirectory(prefix=f'{p_dst}.')))
				subprocess.run(
					['bsdtar', '-xf', p_zip, '--cd', p_mod],
					stderr=subprocess.DEVNULL, check=False )
			else:
				p_mod = mod_dir / pl.Path(mod.path).name
			subprocess.run(['rsync', '-rc', '--delete', f'{p_mod}/.', p_dst], check=True)

	os.chdir(p_repo)
	subprocess.run(['git', 'add', '.'], check=True)
	proc = subprocess.run(['git', 'status', '--porcelain'], stdout=subprocess.PIPE, check=True)
	if proc.stdout:
		print('Mod changes:')
		for line in proc.stdout.splitlines(): print(f'  {line.decode()}')
		ts_str = dt.datetime.now().strftime('Update %Y-%m-%dT%H:%M:%S')
		subprocess.run(['git', 'commit', '-a', '-m', ts_str], stdout=subprocess.PIPE, check=True)

if __name__ == '__main__': sys.exit(main())
