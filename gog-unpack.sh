#!/bin/bash

usage() {
	bin=$(basename $0)
	echo >&2 "Usage: $bin /path/to/gog-game.sh"
	echo >&2 "Will create *.mojosetup.tar.gz and *.zip in the current dir."
	exit ${1:-0}
}
[[ -z "$1" || "$1" = -h || "$1" = --help ]] && usage

p=$1
makeself_lines=$(grep -am1 -oP '(?<=SKIP=)\d+' "$p")
mojo_size=$(grep -am1 -oP '(?<=^filesizes=")\d+(?=")' "$p")
tail -n +$makeself_lines "$p" | head -c $mojo_size > "$(basename "$p")".mojosetup.tar.gz
tail -c +$(( $(head -n $(($makeself_lines - 1)) "$p" | wc -c) + 1 + $mojo_size )) "$p" > "$(basename "$p")".zip
