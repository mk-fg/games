#!/usr/bin/env python3

import os, sys, re, pathlib as pl
import yaml, json

p_log = lambda fmt,*a,**k:\
	print(*( [fmt.format(*a,**k)]\
		if isinstance(fmt, str) and (a or k)
		else [[fmt] + list(a), k] ), file=sys.stderr, flush=True)


def parse_items(p_rul, p_lang=None, p_cqc=None):
	items, item_list = dict(), yaml.safe_load(pl.Path(p_rul).read_text())['items']
	for item in item_list:
		if item.get('delete'): continue
		t = item.get('type')
		if not t:
			p_log('Discarding item without type: {}', item)
			continue
		items[t] = item

	cqc = yaml.safe_load(pl.Path(p_cqc).read_text())['items']
	for item in cqc:
		t = item['type']
		if t not in items:
			items[t] = item
			continue
		item.pop('type')
		for k, v in item.items():
			if k in items[t]:
				p_log( 'Overriding main ruleset value from CqC'
					' for {t}: {k}={v1} -> {v2}', t=t, k=k, v1=items[t][k], v2=v )
			items[t][k] = v

	str_trans = dict()
	for p in p_lang or list():
		lang = yaml.safe_load(pl.Path(p).read_text())
		if isinstance(lang, dict):
			if 'en-US' in lang:
				str_trans.update(lang['en-US'])
				lang = None
			elif 'extraStrings' in lang:
				for trans in lang['extraStrings']:
					if trans.get('type') == 'en-US':
						str_trans.update(trans['strings'])
						lang = None
		if lang: raise ValueError(f'Failed to parse lang-file: {p!r}')

	items_discard = set()
	for t, item in items.items():
		item['name'] = item.get('name')
		if item['name']: item['name'] = str_trans.get(item['name']) or item['name']
		else: item['name'] = str_trans.get(t)
		for k in 'confAuto', 'confSnap', 'confAimed', 'confMelee':
			name = str_trans.get(k in item and item[k].get('name', ...))
			if name: item[f'name{k[4:]}'] = name
		if not item['name']:
			p_log('Discarding item with no matching name: {}', item['type'])
			items_discard.add(t)
			continue
	for t in items_discard: del items[t]

	if 'STR_OPENXCOM' not in str_trans:
		p_log('Missing STR_OPENXCOM with mod version in translation files')
	else:
		version = str_trans['STR_OPENXCOM'].split()[-1]
		version = re.sub(r'^v\.?', '', version)
		items['STR_VERSION'] = dict(type='STR_VERSION', value=version)

	return items


def main(args=None):
	import argparse
	parser = argparse.ArgumentParser(
		description='Script to create JSON cache for piratez-melee-calc.html.')
	parser.add_argument('cache_file', help='Resulting JSON cache file path.')
	parser.add_argument('-r', '--rul-main', metavar='path',
		help='Path to YAML ruleset file to use values from.')
	parser.add_argument('-m', '--rul-cqc', metavar='path',
		help='Path to CqC ruleset with CqC items and updates to items in the main one.')
	parser.add_argument('-l', '--rul-lang', metavar='path', action='append',
		help='Path to language file(s).'
			' Can be used multiple times, with strings in later ones overriding former.')
	opts = parser.parse_args(sys.argv[1:] if args is None else args)

	items = parse_items(opts.rul_main, p_lang=opts.rul_lang, p_cqc=opts.rul_cqc)
	pl.Path(opts.cache_file).write_text(json.dumps(items))

if __name__ == '__main__': sys.exit(main())
