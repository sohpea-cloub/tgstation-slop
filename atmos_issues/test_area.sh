#!/bin/bash
# Builds and runs only the tests in code/modules/unit_tests/atmos_<group>.dm.
# Usage: atmos_issues/test_area.sh <group> [extra test types to also run...]
#   e.g. atmos_issues/test_area.sh lungs /datum/unit_test/lungs
# Every test in that file must be a subtype of /datum/unit_test/atmos_<group>.
# Other atmos_*.dm test files are left out, so this also checks the file stands alone.
# Set ATMOS_ROOT to build a different checkout (e.g. a worktree) with this script.
# Leaves tgstation.dme and _unit_tests.dm untouched, so several groups can build at once.
set -u
AREA="$1"
shift
EXTRA_TESTS="$*"
ROOT="${ATMOS_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
OUT="$ROOT/data/atmos_tests"
NAME="tgstation.atmos_$AREA"
UT="code/modules/unit_tests"
BIN="${BYOND_BIN:-/c/Program Files (x86)/BYOND/bin}"
cd "$ROOT" || exit 1
mkdir -p "$OUT"

if [ ! -f "$UT/atmos_$AREA.dm" ]; then
	echo "missing $UT/atmos_$AREA.dm"
	exit 1
fi

if [ ! -f data/next_map.json ]; then
	cp _maps/map_jsons/runtimestation.json data/next_map.json
fi

# Copy of _unit_tests.dm with only this group's atmos file, focusing its tests and any extra ones.
awk -v area="$AREA" -v extra="$EXTRA_TESTS" '
	/^#include "atmos_[a-z_]+\.dm"/ { next }
	/^\/\/ END_INCLUDE/ {
		print "#include \"atmos_" area ".dm\""
		print "/datum/unit_test/atmos_" area
		print "\ttest_flags = UNIT_TEST_FOCUS"
		n = split(extra, types, " ")
		for(i = 1; i <= n; i++) {
			print types[i]
			print "\ttest_flags = UNIT_TEST_FOCUS"
		}
	}
	{ print }
' "$UT/_unit_tests.dm" > "$UT/_unit_tests.atmos_$AREA.dm"

sed "s#code\\\\modules\\\\unit_tests\\\\_unit_tests.dm#code\\\\modules\\\\unit_tests\\\\_unit_tests.atmos_$AREA.dm#" tgstation.dme > "$NAME.dme"
if ! grep -q "_unit_tests.atmos_$AREA.dm" "$NAME.dme"; then
	echo "failed to redirect the unit test include"
	exit 1
fi

rm -f "$NAME.dmb"
"$BIN/dm.exe" -DCBT -DCIBUILDING "$NAME.dme" > "$OUT/$AREA.compile.log" 2>&1
grep -E "error|warning" "$OUT/$AREA.compile.log" | grep -v "^tgstation.atmos" | head -40
tail -2 "$OUT/$AREA.compile.log"
if [ ! -f "$NAME.dmb" ]; then
	echo "COMPILE FAILED (full log: $OUT/$AREA.compile.log)"
	exit 2
fi

rm -rf "data/logs/atmos_$AREA"
"$BIN/dd.exe" "$NAME.dmb" -close -trusted -verbose -params "log-directory=atmos_$AREA" > "$OUT/$AREA.run.log" 2>&1
echo "=== results (full log: $OUT/$AREA.run.log, data/logs/atmos_$AREA/) ==="
grep -E "PASS|FAIL|FAILURE|Runtime|runtime error|::error::" "$OUT/$AREA.run.log" | grep -v "UNIT_TEST_FOCUS present" | head -120
