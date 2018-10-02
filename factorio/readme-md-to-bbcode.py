#!/usr/bin/env python3

import os, sys, re, pathlib as pl


def main(args=None):
	import argparse
	parser = argparse.ArgumentParser(
		description='Convert README.md to bbcode to'
			' post/update on mod forum and output to stdout.')
	parser.add_argument('-f', '--file',
		metavar='file', default='README.md',
		help='README file to process. Default: %(default)s')
	parser.add_argument('-u', '--urls-only', action='store_true',
		help='Only convert links from md to bbcode,'
			' leaving rest as mostly-readable plaintext.')
	opts = parser.parse_args(sys.argv[1:] if args is None else args)

	text = pl.Path(opts.file).read_text()
	text = re.sub(r'\[([^\[\]]+)\]\(([^)]+)\)', r'[url=\g<2>]\g<1>[/url]', text, re.DOTALL)
	lines = text.split('\n')

	list_stack = list()
	last_item = last_nonempty = None

	lines.append('---') # to close all lists
	n = 0
	while True:
		n += 1
		if n > len(lines) - 1: break

		line_is_empty = not lines[n].strip()
		line_is_item = re.search('^ *- ', lines[n])
		line_indent = len(re.search('^ *', lines[n]).group(0))
		line_indent_item = line_indent + (2 * bool(line_is_item))

		# Process lists
		if line_is_item and (not list_stack or line_indent > list_stack[-1]):
			list_stack.append(line_indent_item)
			if not opts.urls_only: lines[n-1] += '\n{}[list]'.format(' '*line_indent)
		if list_stack:
			if not line_is_empty and line_indent_item < list_stack[-1]:
				if not opts.urls_only: lines[last_nonempty] += '\n{}[/list]'.format(' '*(list_stack[-1]-2))
				list_stack.pop()
				n -= 1
				continue
			if line_is_item:
				if not opts.urls_only: lines[n] = re.sub(r'^( *)- ', r'\g<1>[*]', lines[n])
				else:
					m = re.search(r'^( +)- ', lines[n])
					if m: lines[n] = m.group(1).replace('    ', '- ') + lines[n].lstrip()

		# Process headers
		if not opts.urls_only:
			lines[n] = re.sub(r'^( *)#+\s+(.*?)\s*$', r'\g<1>[h]\g<2>[/h]', lines[n])

		if not line_is_empty: last_nonempty = n
	lines.pop()

	print('\n'.join(lines).strip())

if __name__ == '__main__': sys.exit(main())
