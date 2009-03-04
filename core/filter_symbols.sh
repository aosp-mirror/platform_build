NM=$1

shift

PREFIX=$1

shift

SUFFIX=$1

shift

while test "$1" != ""
do
    $NM -g -fp $1 | while read -a line
    do
	type=${line[1]}
	# if [[ "$type" != "V" && "$type" != "U" ]]; then
	#if [[ "$type" != "W" && "$type" != "V" && "$type" != "U" ]]; then
	    echo "$PREFIX${line[0]}$SUFFIX # ${line[1]}"
	#fi
    done

    shift
done
