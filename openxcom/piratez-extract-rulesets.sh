#!/bin/bash
shopt -s nullglob

rul= rul_dir=
while read v d; do
	v="$d"/user/mods/Piratez/Language/en-US.yml
	[[ -f "$v" ]] || { echo >&2 "Missing en-US.yml with version in $d"; exit 1; }
	v=$(awk 'match($0,/^ *STR_OPENXCOM: .* (\S+)\"$/,a) {print a[1]}' "$v")
	rul=ruleset_"$v".yaml rul_dir=$d
	[[ -e "$rul" ]] && continue
	echo "--- $rul"
	cp "$d"/user/mods/Piratez/Ruleset/Piratez.rul "$rul"
	sed -i -e '/^ \+\(categor\(y\|ies\)\|weight\|listOrder\): /d' -e 's/\r//g' "$rul"
done < <(
	ls -1d {OpenXcom,Dioxine}_XPiratez* |
	awk -F_ '{print $NF, $0}' | sort -V )

[[ -z "$rul" ]] || {
	echo "Creating calc-cache: ${rul}.cache.json"
	./piratez-melee-calc.py "$rul".cache.json \
			-r "$rul_dir"/user/mods/Piratez/Ruleset/Piratez.rul \
			-m "$rul_dir"/user/mods/Piratez/Ruleset/'Gun CqC'.rul \
			-l "$rul_dir"/standard/xcom1/Language/en-US.yml \
			-l "$rul_dir"/user/mods/Piratez/Language/en-US.yml \
		|| echo >&2 "ERROR: failed to create calc-cache json!!!"
}
