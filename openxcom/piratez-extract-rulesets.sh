#!/bin/bash

rul= rul_dir=
while read v d; do
	v=${d##*_} rul=ruleset_"$v".yaml rul_dir=$d
	[[ -e "$rul" ]] && continue
	echo "--- $rul"
	cp "$d"/user/mods/Piratez/Ruleset/Piratez.rul "$rul"
	sed -i -e '/^ \+\(categor\(y\|ies\)\|weight\|listOrder\): /d' -e 's/\r//g' "$rul"
done < <(
	ls -1d {OpenXcom,Dioxine}_XPiratez_* |
	awk -F_ '{print $NF, $0}' | sort -V )

[[ -z "$rul" ]] || {
	echo "Creating calc-cache: ${rul}.cache.json"
	./piratez-melee-calc.py --debug \
			-c "$rul".cache.json -s Bardiche \
			-r "$rul_dir"/user/mods/Piratez/Ruleset/Piratez.rul \
			-l "$rul_dir"/standard/xcom1/Language/en-US.yml \
			-l "$rul_dir"/user/mods/Piratez/Language/en-US.yml \
			-l "$rul_dir"/user/mods/Piratez/Ruleset/Piratez_lang.rul \
		>/dev/null || echo >&2 "ERROR: failed to create calc-cache json!!!"
}
