#!/bin/bash
#
# A test suite for applypatch.  Run in a client where you have done
# envsetup, choosecombo, etc.
#
# DO NOT RUN THIS ON A DEVICE YOU CARE ABOUT.  It will mess up your
# system partition.
#
#
# TODO: find some way to get this run regularly along with the rest of
# the tests.

EMULATOR_PORT=5580
DATA_DIR=$ANDROID_BUILD_TOP/build/tools/applypatch/testdata

# This must be the filename that applypatch uses for its copies.
CACHE_TEMP_SOURCE=/cache/saved.file

# Put all binaries and files here.  We use /cache because it's a
# temporary filesystem in the emulator; it's created fresh each time
# the emulator starts.
WORK_DIR=/system

# partition that WORK_DIR is located on, without the leading slash
WORK_FS=system

# ------------------------

tmpdir=$(mktemp -d)

emulator -wipe-data -noaudio -no-window -port $EMULATOR_PORT &
pid_emulator=$!

ADB="adb -s emulator-$EMULATOR_PORT "

echo "emulator is $pid_emulator; waiting for startup"
$ADB wait-for-device
echo "device is available"
$ADB remount
# free up enough space on the system partition for the test to run.
$ADB shell rm -r /system/media

# run a command on the device; exit with the exit status of the device
# command.
run_command() {
  $ADB shell "$@" \; echo \$? | awk '{if (b) {print a}; a=$0; b=1} END {exit a}'
}

testname() {
  echo
  echo "$1"...
  testname="$1"
}

fail() {
  echo
  echo FAIL: $testname
  echo
  kill $pid_emulator
  exit 1
}

sha1() {
  sha1sum $1 | awk '{print $1}'
}

free_space() {
  run_command df | awk "/$1/ {print gensub(/K/, \"\", \"g\", \$6)}"
}


$ADB push $ANDROID_PRODUCT_OUT/system/bin/applypatch $WORK_DIR/applypatch

BAD1_SHA1=$(printf "%040x" $RANDOM)
BAD2_SHA1=$(printf "%040x" $RANDOM)
OLD_SHA1=$(sha1 $DATA_DIR/old.file)
NEW_SHA1=$(sha1 $DATA_DIR/new.file)
NEW_SIZE=$(stat -c %s $DATA_DIR/new.file)

# --------------- basic execution ----------------------

testname "usage message"
run_command $WORK_DIR/applypatch && fail

testname "display license"
run_command $WORK_DIR/applypatch -l | grep -q -i copyright || fail


# --------------- check mode ----------------------

$ADB push $DATA_DIR/old.file $WORK_DIR

testname "check mode single"
run_command $WORK_DIR/applypatch -c $WORK_DIR/old.file $OLD_SHA1 || fail

testname "check mode multiple"
run_command $WORK_DIR/applypatch -c $WORK_DIR/old.file $BAD1_SHA1 $OLD_SHA1 $BAD2_SHA1|| fail

testname "check mode failure"
run_command $WORK_DIR/applypatch -c $WORK_DIR/old.file $BAD2_SHA1 $BAD1_SHA1 && fail

$ADB push $DATA_DIR/old.file $CACHE_TEMP_SOURCE
# put some junk in the old file
run_command dd if=/dev/urandom of=$WORK_DIR/old.file count=100 bs=1024 || fail

testname "check mode cache (corrupted) single"
run_command $WORK_DIR/applypatch -c $WORK_DIR/old.file $OLD_SHA1 || fail

testname "check mode cache (corrupted) multiple"
run_command $WORK_DIR/applypatch -c $WORK_DIR/old.file $BAD1_SHA1 $OLD_SHA1 $BAD2_SHA1|| fail

testname "check mode cache (corrupted) failure"
run_command $WORK_DIR/applypatch -c $WORK_DIR/old.file $BAD2_SHA1 $BAD1_SHA1 && fail

# remove the old file entirely
run_command rm $WORK_DIR/old.file

testname "check mode cache (missing) single"
run_command $WORK_DIR/applypatch -c $WORK_DIR/old.file $OLD_SHA1 || fail

testname "check mode cache (missing) multiple"
run_command $WORK_DIR/applypatch -c $WORK_DIR/old.file $BAD1_SHA1 $OLD_SHA1 $BAD2_SHA1|| fail

testname "check mode cache (missing) failure"
run_command $WORK_DIR/applypatch -c $WORK_DIR/old.file $BAD2_SHA1 $BAD1_SHA1 && fail


# --------------- apply patch ----------------------

$ADB push $DATA_DIR/old.file $WORK_DIR
$ADB push $DATA_DIR/patch.xdelta3 $WORK_DIR

# Check that the partition has enough space to apply the patch without
# copying.  If it doesn't, we'll be testing the low-space condition
# when we intend to test the not-low-space condition.
testname "apply patches (with enough space)"
free_kb=$(free_space $WORK_FS)
echo "${free_kb}kb free on /$WORK_FS."
if (( free_kb * 1024 < NEW_SIZE * 3 / 2 )); then
  echo "Not enough space on /$WORK_FS to patch test file."
  echo
  echo "This doesn't mean that applypatch is necessarily broken;"
  echo "just that /$WORK_FS doesn't have enough free space to"
  echo "properly run this test."
  exit 1
fi

testname "apply xdelta3 patch"
run_command $WORK_DIR/applypatch $WORK_DIR/old.file $NEW_SHA1 $NEW_SIZE $BAD1_SHA1:$WORK_DIR/foo $OLD_SHA1:$WORK_DIR/patch.xdelta3 || fail
$ADB pull $WORK_DIR/old.file $tmpdir/patched
diff -q $DATA_DIR/new.file $tmpdir/patched || fail

testname "reapply xdelta3 patch"
run_command $WORK_DIR/applypatch $WORK_DIR/old.file $NEW_SHA1 $NEW_SIZE $BAD1_SHA1:$WORK_DIR/foo $OLD_SHA1:$WORK_DIR/patch.xdelta3 || fail
$ADB pull $WORK_DIR/old.file $tmpdir/patched
diff -q $DATA_DIR/new.file $tmpdir/patched || fail

$ADB push $DATA_DIR/old.file $WORK_DIR
$ADB push $DATA_DIR/patch.bsdiff $WORK_DIR

testname "apply bsdiff patch"
run_command $WORK_DIR/applypatch $WORK_DIR/old.file $NEW_SHA1 $NEW_SIZE $BAD1_SHA1:$WORK_DIR/foo $OLD_SHA1:$WORK_DIR/patch.bsdiff || fail
$ADB pull $WORK_DIR/old.file $tmpdir/patched
diff -q $DATA_DIR/new.file $tmpdir/patched || fail

testname "reapply bsdiff patch"
run_command $WORK_DIR/applypatch $WORK_DIR/old.file $NEW_SHA1 $NEW_SIZE $BAD1_SHA1:$WORK_DIR/foo $OLD_SHA1:$WORK_DIR/patch.bsdiff || fail
$ADB pull $WORK_DIR/old.file $tmpdir/patched
diff -q $DATA_DIR/new.file $tmpdir/patched || fail


# --------------- apply patch with low space on /system ----------------------

$ADB push $DATA_DIR/old.file $WORK_DIR
$ADB push $DATA_DIR/patch.xdelta3 $WORK_DIR
$ADB push $DATA_DIR/patch.bsdiff $WORK_DIR

free_kb=$(free_space $WORK_FS)
echo "${free_kb}kb free on /$WORK_FS; we'll soon fix that."
echo run_command dd if=/dev/zero of=$WORK_DIR/bloat.dat count=$((free_kb-512)) bs=1024 || fail
run_command dd if=/dev/zero of=$WORK_DIR/bloat.dat count=$((free_kb-512)) bs=1024 || fail
free_kb=$(free_space $WORK_FS)
echo "${free_kb}kb free on /$WORK_FS now."

testname "apply xdelta3 patch with low space"
run_command $WORK_DIR/applypatch $WORK_DIR/old.file $NEW_SHA1 $NEW_SIZE $BAD1_SHA1:$WORK_DIR/foo $OLD_SHA1:$WORK_DIR/patch.xdelta3 || fail
$ADB pull $WORK_DIR/old.file $tmpdir/patched
diff -q $DATA_DIR/new.file $tmpdir/patched || fail

testname "reapply xdelta3 patch with low space"
run_command $WORK_DIR/applypatch $WORK_DIR/old.file $NEW_SHA1 $NEW_SIZE $BAD1_SHA1:$WORK_DIR/foo $OLD_SHA1:$WORK_DIR/patch.xdelta3 || fail
$ADB pull $WORK_DIR/old.file $tmpdir/patched
diff -q $DATA_DIR/new.file $tmpdir/patched || fail

$ADB push $DATA_DIR/old.file $WORK_DIR

testname "apply bsdiff patch with low space"
run_command $WORK_DIR/applypatch $WORK_DIR/old.file $NEW_SHA1 $NEW_SIZE $BAD1_SHA1:$WORK_DIR/foo $OLD_SHA1:$WORK_DIR/patch.bsdiff || fail
$ADB pull $WORK_DIR/old.file $tmpdir/patched
diff -q $DATA_DIR/new.file $tmpdir/patched || fail

testname "reapply bsdiff patch with low space"
run_command $WORK_DIR/applypatch $WORK_DIR/old.file $NEW_SHA1 $NEW_SIZE $BAD1_SHA1:$WORK_DIR/foo $OLD_SHA1:$WORK_DIR/patch.bsdiff || fail
$ADB pull $WORK_DIR/old.file $tmpdir/patched
diff -q $DATA_DIR/new.file $tmpdir/patched || fail

# --------------- apply patch with low space on /system and /cache ----------------------

$ADB push $DATA_DIR/old.file $WORK_DIR
$ADB push $DATA_DIR/patch.xdelta3 $WORK_DIR
$ADB push $DATA_DIR/patch.bsdiff $WORK_DIR

free_kb=$(free_space $WORK_FS)
echo "${free_kb}kb free on /$WORK_FS"

run_command mkdir /cache/subdir
run_command 'echo > /cache/subdir/a.file'
run_command 'echo > /cache/a.file'
run_command mkdir -p /cache/recovery/otatest
run_command 'echo > /cache/recovery/otatest/b.file'
run_command "echo > $CACHE_TEMP_SOURCE"
free_kb=$(free_space cache)
echo "${free_kb}kb free on /cache; we'll soon fix that."
run_command dd if=/dev/zero of=/cache/bloat_small.dat count=128 bs=1024 || fail
run_command dd if=/dev/zero of=/cache/bloat_large.dat count=$((free_kb-640)) bs=1024 || fail
free_kb=$(free_space cache)
echo "${free_kb}kb free on /cache now."

testname "apply bsdiff patch with low space, full cache, can't delete enough"
$ADB shell 'cat >> /cache/bloat_large.dat' & open_pid=$!
echo "open_pid is $open_pid"

# size check should fail even though it deletes some stuff
run_command $WORK_DIR/applypatch -s $NEW_SIZE && fail
run_command ls /cache/bloat_small.dat && fail          # was deleted
run_command ls /cache/a.file && fail                   # was deleted
run_command ls /cache/recovery/otatest/b.file && fail  # was deleted
run_command ls /cache/bloat_large.dat || fail          # wasn't deleted because it was open
run_command ls /cache/subdir/a.file || fail            # wasn't deleted because it's in a subdir
run_command ls $CACHE_TEMP_SOURCE || fail              # wasn't deleted because it's the source file copy

# should fail; not enough files can be deleted
run_command $WORK_DIR/applypatch $WORK_DIR/old.file $NEW_SHA1 $NEW_SIZE $BAD1_SHA1:$WORK_DIR/foo $OLD_SHA1:$WORK_DIR/patch.bsdiff && fail
run_command ls /cache/bloat_large.dat || fail   # wasn't deleted because it was open
run_command ls /cache/subdir/a.file || fail     # wasn't deleted because it's in a subdir
run_command ls $CACHE_TEMP_SOURCE || fail       # wasn't deleted because it's the source file copy

kill $open_pid   # /cache/bloat_large.dat is no longer open

testname "apply bsdiff patch with low space, full cache, can delete enough"

# should succeed after deleting /cache/bloat_large.dat
run_command $WORK_DIR/applypatch -s $NEW_SIZE || fail
run_command ls /cache/bloat_large.dat && fail   # was deleted
run_command ls /cache/subdir/a.file || fail     # still wasn't deleted because it's in a subdir
run_command ls $CACHE_TEMP_SOURCE || fail       # wasn't deleted because it's the source file copy

# should succeed
run_command $WORK_DIR/applypatch $WORK_DIR/old.file $NEW_SHA1 $NEW_SIZE $BAD1_SHA1:$WORK_DIR/foo $OLD_SHA1:$WORK_DIR/patch.bsdiff || fail
$ADB pull $WORK_DIR/old.file $tmpdir/patched
diff -q $DATA_DIR/new.file $tmpdir/patched || fail
run_command ls /cache/subdir/a.file || fail     # still wasn't deleted because it's in a subdir
run_command ls $CACHE_TEMP_SOURCE && fail       # was deleted because patching overwrote it, then deleted it

# --------------- apply patch from cache ----------------------

$ADB push $DATA_DIR/old.file $CACHE_TEMP_SOURCE
# put some junk in the old file
run_command dd if=/dev/urandom of=$WORK_DIR/old.file count=100 bs=1024 || fail

testname "apply xdelta3 patch from cache (corrupted source) with low space"
run_command $WORK_DIR/applypatch $WORK_DIR/old.file $NEW_SHA1 $NEW_SIZE $BAD1_SHA1:$WORK_DIR/foo $OLD_SHA1:$WORK_DIR/patch.xdelta3 || fail
$ADB pull $WORK_DIR/old.file $tmpdir/patched
diff -q $DATA_DIR/new.file $tmpdir/patched || fail

$ADB push $DATA_DIR/old.file $CACHE_TEMP_SOURCE
# remove the old file entirely
run_command rm $WORK_DIR/old.file

testname "apply bsdiff patch from cache (missing source) with low space"
run_command $WORK_DIR/applypatch $WORK_DIR/old.file $NEW_SHA1 $NEW_SIZE $BAD1_SHA1:$WORK_DIR/foo $OLD_SHA1:$WORK_DIR/patch.bsdiff || fail
$ADB pull $WORK_DIR/old.file $tmpdir/patched
diff -q $DATA_DIR/new.file $tmpdir/patched || fail


# --------------- cleanup ----------------------

# not necessary if we're about to kill the emulator, but nice for
# running on real devices or already-running emulators.
run_command rm /cache/bloat*.dat $WORK_DIR/bloat.dat $CACHE_TEMP_SOURCE $WORK_DIR/old.file $WORK_DIR/patch.xdelta3 $WORK_DIR/patch.bsdiff $WORK_DIR/applypatch

kill $pid_emulator

rm -rf $tmpdir

echo
echo PASS
echo

