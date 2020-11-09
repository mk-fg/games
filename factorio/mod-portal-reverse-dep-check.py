#!/usr/bin/env python

import urllib.request as ul, urllib.error as ule, urllib.parse as ulp
import pathlib as pl, dbm.gnu as gdbm, itertools as it, functools as ft
import os, sys, json, time, unicodedata


p = ft.partial(print, flush=True)
p_err = lambda s, *sx: p('ERROR: {s}', *sx, file=sys.stderr)
str_norm = lambda v: unicodedata.normalize('NFKC', v.strip()).casefold()


class FetchError(Exception): pass

def api_fetch(cache, key, mod=None, query=None, update=False, state=None):
	if isinstance(key, (tuple, list)): key = '\0'.join(map(str, key)).encode()
	if key in cache: return json.loads(cache[key])
	if state:
		ts = time.monotonic()
		delay = state.get('delay', 0) - (ts - state.get('ts_last'))
		if delay > 0: time.sleep(delay)
		state['ts_last'] = ts
	mod = f'/{ulp.quote(mod)}/full' if mod else ''
	url = f'https://mods.factorio.com/api/mods{mod}'
	if query: url = f'{url}?{ulp.urlencode(query)}'
	# p(f'--- req: {url}')
	try:
		body, req = '', ul.Request(url, headers={
			'User-Agent': 'mod-portal-reverse-dep-check/1.0', 'Accept': 'application/json' })
		with ul.urlopen(req) as req: status, err, body = req.getcode(), req.reason, req.read()
	except ule.URLError as err_ex:
		status, err = 1000, str(err_ex)
		if isinstance(err_ex, ule.HTTPError): status, body = err_ex.code, err_ex.read()
	if status >= 300:
		if body and len(body) < 400: err = repr(body.decode('utf-8', 'backslashreplace'))
		raise FetchError(f'API request failed (status={status}): {url!r} - {err}')
	cache[key], data = body, json.loads(body)
	return data


def main(args=None):
	import argparse, textwrap
	dd = lambda text: (textwrap.dedent(text).strip('\n') + '\n').replace('\t', '  ')
	fill = lambda s,w=90,ind='',ind_next='  ',**k: textwrap.fill(
		s, w, initial_indent=ind, subsequent_indent=ind if ind_next is None else ind_next, **k )

	parser = argparse.ArgumentParser(
		formatter_class=argparse.RawTextHelpFormatter,
		description=dd('''
			List all mods on mods.factorio.com that depend on a specified mod.
			This requires multiple API queries, results of which are cached in -c/--cache-file,
				so that script can be stopped and resumed anytime without any meaningful extra work.'''))

	parser.add_argument('mod_slug',
		help='Name of the mod (as presented in URL!) to lookup in other mods dependencies.')

	group = parser.add_argument_group('Caching options')
	group.add_argument('-c', '--cache-file',
		metavar='file', default='factorio-mod-portal-api.cache.db',
		help=dd('''
			File to cache mod list and mod information in as json lines with a key prefix.
			This cache will only be updated if missing or if options to do that are specified.
			With mod list and all mod info cached,
				repeated lookups will not query anything from the Mod Portal API.
			Default: %(default)s'''))
	group.add_argument('-u', '--cache-update', action='store_true',
		help='Update mod list and any mods that changed versions.')

	group = parser.add_argument_group('Fetch parameters')
	group.add_argument('-d', '--api-req-delay',
		type=float, metavar='s', default=1.0,
		help='Delay (in seconds) between API requests. Default: %(default)ss')
	group.add_argument('-r', '--report-steps',
		type=int, metavar='n', default=50,
		help='Report progress after every 1/Nth of processed mods. Default: %(default)s')

	opts = parser.parse_args(sys.argv[1:] if args is None else args)

	mod_slug = str_norm(opts.mod_slug)

	with gdbm.open(opts.cache_file, 'cs') as cache:
		# Cache keys: "list\0{page}", "mod\0{name}\0{sha1}"
		fetch_state = dict(ts_last=0, delay=opts.api_req_delay)
		fetch = ft.partial(api_fetch, cache, state=fetch_state)

		mods, n = list(), 1
		while True:
			page = fetch( ('list', n),
				update=opts.cache_update, query=dict(page=n, page_size='max') )
			mods.extend(page['results'])
			pn, n = page['pagination'], n + 1
			if pn is None or pn['page'] >= pn['page_count']: break

		n_max, n_report = len(mods), int(len(mods) / opts.report_steps) + 1
		for n, mod in enumerate(mods, 1):
			if not n % n_report: p(f'-- done: {n} / {n_max}')
			mod_name = mod['name']
			mod_title = f'{mod["title"]} [id={mod_name}]'
			mod_rel = mod.get('latest_release')
			if not mod_rel: continue
			mod = fetch(('mod', mod_name, mod_rel['sha1']), mod_name)
			for rel in mod['releases']:
				if rel['version'] == mod_rel['version'] and rel['sha1'] == mod_rel['sha1']: break
			else:
				p_err( 'No release matching "latest_release"'
					f' in the mod-list for mod, skipping it: {mod_title}' )
				continue
			try: deps = rel['info_json']['dependencies']
			except KeyError:
				p_err(f'No mod dependency info for mod, skipping it: {mod_title}')
				continue
			for dep in deps:
				dep = str_norm(dep).lstrip('?!').strip()
				if dep.startswith('(?)'): dep = dep[3:].strip()
				for c in '><=': dep = dep.split(c)[0].strip()
				if mod_slug == dep: break
			else: continue
			p( f'{mod_title}'
				f'\n  url: https://mods.factorio.com/mod/{ulp.quote(mod_name)}'
				f'\n  dependency: {dep}' )

if __name__ == '__main__': sys.exit(main())
