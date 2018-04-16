#!/usr/bin/env python3

import itertools as it, operator as op, functools as ft
import os, sys, math, random, pathlib as pl


def main(args=None):
	w_default, w_sep = 100, '='

	import argparse
	parser = argparse.ArgumentParser(
		description='Pick unique names from specified'
			' list files (one name per line) at random with per-list weights.')
	parser.add_argument('nlist', nargs='+',
		help='Which list(s) to pick names from, with optional'
				f' weight value (default={w_default}), separated by "{w_sep}" sign.'
			f' Examples: names.polish'
				' names.french{w_sep}10 names.german{w_sep}=20')

	parser.add_argument('-t', '--list-tpl',
		default='{list_name}', metavar='template',
		help='Template for path to the list file. Default: %(default)s')
	parser.add_argument('-n', '--count', type=int, metavar='n',
		help='Approximate count of names to pick from all lists.'
			' Distribution of weights for specified lists is deterministic (non-random).'
			' For example, with two lists of equal weights, and 100 items,'
				' 50 will be picked from first one and 50 from the second one.'
			' Actual count can be more or less than that due to rounding errors and actual files.')
	parser.add_argument('-m', '--weight-as-count', action='store_true',
		help='Instead of using weight values for distribution,'
			' use these as exact count and ignore -n/--count value.')
	parser.add_argument('-w', '--weight-base',
		type=int, metavar='n', default=w_default,
		help='Default value of weight for list, if not specified explicitly [%(default)s].')

	parser.add_argument('-l', '--line-max-len', type=int, metavar='n',
		help='How many characters per line to allow before wrapping stuff to next line.')
	parser.add_argument('-x', '--name-max-len', type=int, metavar='n',
		help='Discard names longer than specified number of characters.')
	parser.add_argument('-r', '--raw', action='store_true',
		help='Print "raw" names without quoting, one per line.'
			' Can be used to produce new name lists from other lists.')

	opts = parser.parse_args(sys.argv[1:] if args is None else args)

	name_lists = dict()
	for lst in opts.nlist:
		if w_sep in lst: lst, w = lst.rsplit(w_sep, 1)
		else: w = opts.weight_base
		lst = opts.list_tpl.format(list_name=lst)
		name_lists[lst] = int(w)

	if not opts.weight_as_count:
		if opts.count is None:
			name_lists = dict.fromkeys(name_lists.keys())
		else:
			w_sum = sum(name_lists.values())
			name_lists.update(
				(lst, math.ceil(opts.count * (w / w_sum)))
				for lst, w in name_lists.items() )

	names, count_names_all = set(), 0
	for lst, n in name_lists.items():
		lst_names = set(pl.Path(lst).read_text().splitlines())
		if opts.name_max_len:
			lst_names = set(filter(
				lambda n: len(n) <= opts.name_max_len, lst_names ))
		count_names_all += len(lst_names)
		if n is None or len(lst_names) <= n: names.update(lst_names)
		else:
			lst_names_set, n_goal, sample = set(lst_names), len(names) + n, list()
			while lst_names_set and len(names) < n_goal:
				if sample: lst_names_set.difference_update(sample)
				sample = random.sample(list(lst_names_set), n)
				names.update(sample)

	names_by_len = dict((n, set(grp)) for n, grp in it.groupby(names, key=len))
	line, count, count_names = list(), 0, len(names)
	if not opts.raw: print('-----')
	while names:
		name = names.pop()
		if opts.line_max_len:
			len_max = opts.line_max_len - (len(line)-1 + sum(map(len, line))) - 2
			if len_max < len(name):
				while True:
					for n in range(len_max, 0, -1):
						if names_by_len.get(n): break
					else: n = 0
					if n:
						if name: names.add(name)
						while names_by_len[n]:
							name = names_by_len[n].pop()
							if name in names: break
							else: name = None
						if not name: continue
						names.remove(name)
						break
					else:
						if line:
							print(' '.join(line))
							line = list()
						break
		if name:
			if opts.raw: print(name)
			else: line.append('"{}"'.format(name.replace('"', "'")))
			count += 1
	if line: print(' '.join(line))
	if not opts.raw:
		print( f'----- all-lists={count_names_all:,d}'
			f' picked={count_names:,d} printed={count:,d}' )

if __name__ == '__main__': sys.exit(main())
