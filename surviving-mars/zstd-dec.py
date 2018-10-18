#!/usr/bin/env python3

import os, sys, struct, pathlib as pl, subprocess as sp
import contextlib, stat, tempfile


@contextlib.contextmanager
def safe_replacement(path, mode=None):
	if mode is None:
		with contextlib.suppress(OSError):
			mode = stat.S_IMODE(os.lstat(path).st_mode)
	path = pl.Path(path)
	kws = dict(delete=False, dir=path.parent, prefix=path.name+'.')
	with tempfile.NamedTemporaryFile(**kws) as tmp:
		try:
			if mode is not None: os.fchmod(tmp.fileno(), mode)
			yield tmp
			if not tmp.closed: tmp.flush()
			os.rename(tmp.name, path)
		finally:
			with contextlib.suppress(OSError): os.unlink(tmp.name)


def main(args=None):
	import argparse
	parser = argparse.ArgumentParser(
		description='Decompress zstd-compressed file(s).')
	parser.add_argument('path', nargs='*',
		help='File path(s) to decompress in-place.'
			' Non-zstd file contents are unchanged, though files are still replaced.'
			' Stdin/stdout is used if none specified or instead of "-".')
	opts = parser.parse_args(sys.argv[1:] if args is None else args)

	file_list = opts.path or ['-']
	for p in file_list:
		src, dst = ( (open(p, 'rb'), safe_replacement(p)) if p != '-'
			else (open(sys.stdin.fileno(), 'rb'), open(sys.stdout.fileno(), 'wb')) )
		with src as src, dst as dst:
			if src.read(4) != b'ZSTD':
				src.seek(0)
				dst.write(src.read())
				continue

			dst_len, bs, offset = struct.unpack('III', src.read(12))
			offset_list = [offset]
			while src.tell() < offset:
				offset_list.append(struct.unpack('I', src.read(4))[0])
			assert src.tell() == offset, [src.tell(), offset, offset_list]

			buff = list()
			for n, offset in enumerate(offset_list):
				src.seek(offset)
				if n + 1 < len(offset_list):
					chunk_len = offset_list[n+1] - offset
					assert chunk_len == bs, [chunk_len, bs]
				else: chunk_len = None
				buff.append(src.read(chunk_len))
			buff = b''.join(buff)

			if len(buff) != dst_len:
				dec = sp.run(['zstd', '-d'], input=buff, stdout=sp.PIPE, check=True)
				buff = dec.stdout
				assert len(buff) == dst_len, [dst_len, buff[:30]]
			dst.write(buff)

if __name__ == '__main__': sys.exit(main())
