#!/bin/bash

[[ -e tech_n_1.png ]] || {
	echo >&2 "ERROR: failed to find overlay icons in current dir"
	exit 1
}

icons=( "$@" )
[[ "${#icons[@]}" -ne 0 ]] || icons=( $(find -name '*.dds.png') )

err=0
for p in "${icons[@]}"; do
	n=$(echo "$p" | gawk 'match($0,/_([0-9])\.dds/,a) {print a[1]}')
	[[ -n "$n" ]] || { echo >&2 "ERROR: failed to find tier n for file $p"; continue; }
	convert -composite -gravity center "$p" tech_n_$n.png "$p" \
		|| { echo >&2 "ERROR: convert exited with non-zero code for $p"; err=1; }
done

exit $err
