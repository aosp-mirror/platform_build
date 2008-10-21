#!/bin/sh
#
# Convert EOL convention on source files from CRLF to LF.
#

echo "Scanning..."
FILES=`find . \( -iname '*.c' -o -iname '*.cpp' -o -iname '*.h' -o -iname '*.mk' -o -iname '*.html' -o -iname '*.css' \) -print`

echo "Converting..."
for file in $FILES ; do
	echo $file
	tr -d \\r < $file > _temp_file
	mv _temp_file $file
done
exit 0

