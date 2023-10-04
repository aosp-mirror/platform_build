#!/bin/bash

# Find duplicate shared libraries by md5 checksum and possible duplicates by size.
# Results will be available in the out directory of the build.
# Usage:
# ./dupcheck.sh <out_dir> <image>

OUT_DIR="$1"
IMG="$2"
TMP_MD5="${OUT_DIR}/_dup_md5"
TMP_SIZE="${OUT_DIR}/_dup_size"
TMP_CHECK="${OUT_DIR}/_dup_tmp_check"
TMP_SIZE_REAL="${OUT_DIR}/_dup_size_real"
TMP_FILE1="${OUT_DIR}/_dup_f1"
TMP_FILE2="${OUT_DIR}/_dup_f2"
MD5_DUPLICATES="${OUT_DIR}/duplicate-libs-md5-${IMG}.txt"
SIZE_DUPLICATES="${OUT_DIR}/duplicate-libs-size-${IMG}.txt"

# Check arguments
if [ "$#" -ne 2 ]; then
	echo "Usage: ./dupcheck.sh <out_dir> <image>"
	exit 1
fi

# Check host and toolchain version
CHECK_HOST=$(uname)
if [ "${CHECK_HOST}" == "Linux" ]; then
	ARCH="linux-x86"
else
	ARCH="darwin-x86"
fi
BINUTILS_PATH="./prebuilts/clang/host/${ARCH}/llvm-binutils-stable"

# Remove any old files if they exist.
if [ -f "${MD5_DUPLICATES}" ]; then
	rm "${MD5_DUPLICATES}"
fi

if [ -f "${SIZE_DUPLICATES}" ]; then
	rm "${SIZE_DUPLICATES}"
fi

# Find all .so files and calculate their md5.
find ./"${OUT_DIR}"/${IMG}/ -name "lib*.so" -type f -print0 | xargs -0 md5sum | sed -e "s# .*/# #" | sort | uniq -c | sort -g | sed "/^.*1 /d" | sed "s/^. *[0-9] //" > "${TMP_MD5}" 2>&1

if [ -s "${TMP_MD5}" ]; then
	while read -r list; do
		checksum=$(echo "${list}" | cut -f1 -d ' ')
		filename=$(echo "${list}" | cut -f2 -d ' ')
		# For each md5, list the file paths that match.
		{
			echo "MD5: ${checksum}";											                \
			find ./"${OUT_DIR}"/${IMG}/ -name "${filename}" -type f -print0 | xargs -0 md5sum | grep "${checksum}" | sed 's/^.* //';	\
			echo "";													                \
		} >> "${MD5_DUPLICATES}"
	done <"${TMP_MD5}"
else
	echo "No duplicate files by md5 found." >> "${MD5_DUPLICATES}"
fi

# Cleanup
rm "${TMP_MD5}"

# Find possible duplicate .so files by size.
find ./"${OUT_DIR}"/${IMG}/ -name "*.so" -type f -print0 | xargs -0 stat --format="%s %n" 2>/dev/null | sed -e "s# .*/# #" | sort | uniq -c | sort -g | sed "/^.*1 /d" > "${TMP_SIZE}" 2>&1
if [ -s "${TMP_SIZE}" ]; then
	while read -r list; do
		size=$(echo "${list}" | cut -f2 -d ' ')
		filename=$(echo "${list}" | cut -f3 -d ' ')
		# Check if the files are not in the md5sum list and do nothing if that is the case.
		find ./"${OUT_DIR}"/${IMG}/ -name "${filename}" -type f -print0 | xargs -0 stat --format="%s %n" 2>/dev/null | grep "${size}" | sed "s/^.* //" | sort > "${TMP_CHECK}" 2>&1
		while read -r filepath; do
			found=$(grep -F "${filepath}" "${MD5_DUPLICATES}")
			if [ -z "${found}" ]; then
				echo "${filepath}" >> "${TMP_SIZE_REAL}"
			fi
		done<"${TMP_CHECK}"
		# For every duplication found, diff the .note and .text sections.
		if [ -s "${TMP_SIZE_REAL}" ]; then
			{
				echo "File: ${filename}, Size: ${size}";	\
				cat "${TMP_SIZE_REAL}";				\
				echo "";					\
			} >> "${SIZE_DUPLICATES}"
			count=$(wc -l "${TMP_SIZE_REAL}" | cut -f1 -d ' ')
			# Limitation: this only works for file pairs. If more than two possible duplications are found, the user need to check manually
			# all the possible combinations using the llvm-readelf and llvm-objdump commands below.
			if [ "${count}" = 2 ]; then
				file1=$(head -n 1 "${TMP_SIZE_REAL}")
				file2=$(tail -n 1 "${TMP_SIZE_REAL}")
				# Check .note section
				${BINUTILS_PATH}/llvm-readelf --wide --notes "${file1}" > "${TMP_FILE1}" 2>&1
				${BINUTILS_PATH}/llvm-readelf --wide --notes "${file2}" > "${TMP_FILE2}" 2>&1
				{
					diff -u "${TMP_FILE1}" "${TMP_FILE2}" | sed "1d;2d;3d";	\
					echo "";
				} >> "${SIZE_DUPLICATES}"
				# Check .text section
				${BINUTILS_PATH}/llvm-objdump --line-numbers --disassemble --demangle --reloc --no-show-raw-insn --section=.text "${file1}" | sed "1d;2d"> "${TMP_FILE1}" 2>&1
				${BINUTILS_PATH}/llvm-objdump --line-numbers --disassemble --demangle --reloc --no-show-raw-insn --section=.text "${file2}" | sed "1d;2d"> "${TMP_FILE2}" 2>&1
				{
					diff -u "${TMP_FILE1}" "${TMP_FILE2}" | sed "1d;2d;3d";	\
					echo "";
				} >> "${SIZE_DUPLICATES}"
				# Cleanup
				rm "${TMP_FILE1}" "${TMP_FILE2}"
			else
				echo "*Note: more than one duplicate. Manually verify all possible combinations." >> "${SIZE_DUPLICATES}"
			fi
			rm "${TMP_SIZE_REAL}"
			echo "" >> "${SIZE_DUPLICATES}"
		fi
	done <"${TMP_SIZE}"
	# Cleanup
	rm "${TMP_SIZE}" "${TMP_CHECK}"
else
	echo "No duplicate files by size found." >> "${SIZE_DUPLICATES}"
fi
