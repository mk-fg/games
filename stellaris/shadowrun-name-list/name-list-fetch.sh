#!/bin/bash

set -e -o pipefail

curl_headers=(
	'User-Agent: Mozilla/5.0 (X11; Linux x86_64; rv:52.0) Gecko/20100101 Firefox/52.0'
	'Accept: application/json, text/javascript, */*; q=0.01'
	'Accept-Language: en-US,ru;q=0.7,en;q=0.3'
	'Content-Type: application/x-www-form-urlencoded; charset=UTF-8'
	'x-requested-with: XMLHttpRequest'
	'Referer: http://shadowrun.itemcards.com/'
	'DNT: 1'
	'Cache-Control: max-age=0'
)

curl_args=( )
for h in curl_headers; do curl_args+=( -H "$h" ); done

grab() {
	# Appends 15 names from specified category ($1) to dst ($2)
	cat=$1 dst=$2
	curl -sS "${curl_args[@]}" \
			--data "action=fetchList&category=$cat" \
			http://shadowrun.itemcards.com/xhr.php |
		jq -r '.names[] | .'  >> "$dst"
	sleep 1 # 1 req/s
}


names_lang=(
	arabic chinese english-uk english-us french
	german italian japanese polish russian spanish )

names_sov=( ags aztlan cas hongkong mixed ucas )

n=0 n_max=10 n_echo=3
while :; do
	[[ $(( $n % $n_echo )) -ne 0 ]] || echo "loop: $n"
	### 22 + 12 + 5 + 2 ~ 40 req/iter
	for lang in "${names_lang[@]}"; do for g in male female; do
		grab "language/$lang/$g" "sr.names.origin.$lang.$g.txt"
	done; done
	for sov in "${names_sov[@]}"; do for g in male female; do
		grab "sovereignity/$sov/$g" "sr.names.sov.$sov.$g.txt"
	done; done
	for cat in weapons runners corporations gangs shops; do
		grab "$cat" "sr.$cat.txt"
	done
	for t in cities streets; do
		grab "places/$t" "sr.places.$t.txt"
	done
	(( n++ )) ||:
	[[ $n -lt $n_max ]] || break
done
