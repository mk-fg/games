#!/usr/bin/env python3

import itertools as it, operator as op, functools as ft
import os, sys, re, pathlib as pl

import textx as tx


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

class adict(dict):
	def __init__(self, *args, **kwargs):
		super().__init__(*args, **kwargs)
		for k, v in self.items():
			assert not getattr(self, k, None)
			if '-' in k: self[k.replace('-', '_')] = self.pop(k)
		self.__dict__ = self

def parse_file(p):
	descriptor = p.read_text(encoding='utf-8-sig')
	try: model = mm_mod.model_from_str(descriptor)
	except tx.exceptions.TextXSyntaxError as err:
		print('-'*10, p)
		print(descriptor)
		print('-'*50)
		print(err)
		exit()
	mod = dict( (val.k, val.v)
		for val in tx.model.children_of_type('Val', model) )
	assert 'name' in mod, repr(descriptor)
	return adict(mod)


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
		description='Create .mod files from track-mod-changes.py dirs to freeze mods state.'
			' descriptor.mod is used as a template,'
				' with "archive=..." lines updated to proper "path=mod/...".'
			' Skips local mods that have path="mod/*" already.')
	parser.add_argument('local_mod_dir',
		help='Directory with mod dirs from track-mod-changes.py')
	parser.add_argument('-v', '--ver', metavar='version',
		help='Override supported_version string in .mod files. Example: --ver="2.1.*"')
	opts = parser.parse_args(sys.argv[1:] if args is None else args)

	p_repo = pl.Path(opts.local_mod_dir).resolve()
	for p in p_repo.iterdir():
		p_desc = p / 'descriptor.mod'
		if not p.is_dir() or not p_desc.exists(): continue
		mod = parse_file(p_desc)
		if mod.get('path', '').startswith('mod/'):
			assert not mod.get('archive', ''), mod
			continue
		assert mod.get('archive', ''), mod

		mm = p_desc.read_text().replace('\r', '')
		mm = re.sub(r'\n\s*archive=[^\n]+(\n|$)', f'\npath="mod/{p.name}"\n', mm)
		if opts.ver:
			mm = re.sub(
				r'\n\s*supported_version=[^\n]+\n',
				f'\nsupported_version="{opts.ver}"\n', mm )
		p_desc_new = p_repo / f'local_{mod.remote_file_id}.mod'
		p_desc_new.write_text(mm)

		mod = parse_file(p_desc)
		assert mod.get('archive', '') and not mod.get('path', ''), mod

if __name__ == '__main__': sys.exit(main())
