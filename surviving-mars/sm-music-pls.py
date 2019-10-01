#!/usr/bin/env python3

import os, sys, re, random, pathlib as pl


class adict(dict):
	def __init__(self, *args, **kws):
		super().__init__(*args, **kws)
		self.__dict__ = self


def main(args=None):
	import argparse
	parser = argparse.ArgumentParser(
		description='Surviving Mars music shuffler script.'
			' Produces radio-like playlist with radio blurbs/talks interspersed with music.'
			' Source files can be extracted from hpk files with https://github.com/nickelc/hpk')
	parser.add_argument('src_dir',
		help='Source path with mp3/ogg/opus music files.'
			' These should be organized as "station/file.ogg",'
				' with filenames preserved from hpk, except for filename'
				' extensions (can be mp3, ogg or original opus).')
	parser.add_argument('dst_pls',
		help='Destination pls file to produce.')
	parser.add_argument('--chance-pre',
		type=float, default=0.8, metavar='float',
		help='Chance of adding blurb/talk before music track (range: 0 - 1.0). Default: %(default)s')
	parser.add_argument('--chance-talk',
		type=float, default=0.7, metavar='float',
		help='Chance of adding talk segment instead'
			' of blurb before music track (if any, range: 0 - 1.0). Default: %(default)s')
	parser.add_argument('--chance-ad',
		type=float, default=0.5, metavar='float',
		help='Chance of adding commercial segment before'
			' any blurb/talk/music track combo (range: 0 - 1.0). Default: %(default)s')
	opts = parser.parse_args(sys.argv[1:] if args is None else args)

	### Find tracks

	src = pl.Path(opts.src_dir)
	src_lists = dict()
	src_t_res = dict( blurb=re.compile(r'^Blurb_'),
		talk=re.compile(r'^Talks_'), ad=re.compile('^Commercials_'), music=re.compile('.') )

	src_rp = str(src.resolve())
	for root, dirs, files, dir_fd in os.fwalk(src, follow_symlinks=True):
		root = pl.Path(root)
		st = str(root.resolve())
		if st.startswith(src_rp):
			st = st[len(src_rp)+1:]
			if st: st = st.rsplit('/', 1)[-1]
		for p in files:
			if not re.search(r'(?i)\.(ogg|oga|mp3|opus)$', p): continue
			track = re.sub(r'^Radio_[^_]+_', '', p.rsplit('.', 1)[0])
			for t, rx in src_t_res.items():
				if not rx.search(track): continue
				if st not in src_lists: src_lists[st] = adict()
				if t not in src_lists[st]: src_lists[st][t] = adict()
				src_lists[st][t][track] = root / p
				break
			else: raise RuntimeError(f'Failed to detect track type: {track} [{root} / {p}]')

	### Assemble playlist

	pls = list()

	if '' in src_lists:
		tracks = src_lists.pop('').music.values()
		random.shuffle(tracks)
		pls.extend(tracks)

	# Weighted random is used so that longest track-list won't end up in the tail
	src_weights = adict((k, len(v.music)) for k,v in src_lists.items())
	while src_weights:
		t, = random.choices(list(src_weights.keys()), src_weights.values())
		src_list = src_lists[t]
		if not src_list.music:
			src_weights.pop(t)
			continue

		if random.random() < opts.chance_ad and src_list.get('ad'):
			k = random.choice(list(src_list.ad))
			p = src_list.ad.pop(k)
			pls.append(p)

		if random.random() < opts.chance_pre:
			k = 'blurb' if random.random() > opts.chance_talk else 'talk'
			files = src_list.get(k)
			if not files: files = src_list.get(next(iter({'blurb', 'talk'}.difference([k]))))
			if files:
				k = random.choice(list(files))
				p = files.pop(k)
				pls.append(p)

		k = random.choice(list(src_list.music))
		p = src_list.music.pop(k)
		pls.append(p)

	### Write playlist

	pl.Path(opts.dst_pls).write_text(''.join(f'{p}\n' for p in pls))

if __name__ == '__main__': sys.exit(main())
