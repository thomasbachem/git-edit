# --selftest=<ids> runs those scenarios alone, with the ones they need
# A development run takes a few scenario files from the suite dir, so the pick must find every
# one in suite order, keep out what it was not asked for, and bring along what each one needs
_ST_SCENARIO "\e[1;96m[88] --selftest=<ids> runs those alone, with what they need\e[0m"
_ST_EQ "a pick of every scenario takes each file in the suite dir, in suite order" \
	"$(_SELFTEST_PICK "$SELFTEST_DIR" - && print -rl -- "${SELFTEST_FILES[@]:t}")" \
	"$(command ls "$SELFTEST_DIR" | command grep -v '^lib\.zsh$' | LC_ALL=C sort)"
# A helper defined inside one scenario is missing from a run without it
_ST_EQ "no scenario defines a helper of its own" \
	"$(command grep -l -E '^[[:space:]]*_ST_[A-Z_]* \(\) \{' "$SELFTEST_DIR"/[0-9]*.zsh)" ""
local ST_P1='_ST_SCENARIO "\e[1;96m[1] one\e[0m"'
local ST_P2='_ST_SCENARIO "\e[1;96m[2] two\e[0m" # needs 1'
local ST_P3='_ST_SCENARIO "\e[1;96m[3] three\e[0m"'
mkdir -p "$TMP"/pick{,-order,-ahead,-twice,-banner,-name,-weave}
print -r -- "$ST_P1" > "$TMP/pick/001-one.zsh"
print -r -- "$ST_P2" > "$TMP/pick/002-two.zsh"
print -r -- "$ST_P3" > "$TMP/pick/003-three.zsh"
_ST_EQ "a pick takes its own file and the one it needs" \
	"$(_SELFTEST_PICK "$TMP/pick" 2 && print -r -- "${SELFTEST_FILES[@]:t}")" "001-one.zsh 002-two.zsh"
_ST_EQ "naming what it runs" "$(_SELFTEST_PICK "$TMP/pick" 2 && print -r -- "$SELFTEST_SCOPE")" "scenarios 1-2 (2 of 3)"
_ST_EQ "one alone in the singular" "$(_SELFTEST_PICK "$TMP/pick" 3 && print -r -- "$SELFTEST_SCOPE")" "scenario 3 (1 of 3)"
_ST_EQ "a gap kept apart" "$(_SELFTEST_PICK "$TMP/pick" 1,3 && print -r -- "$SELFTEST_SCOPE")" "scenarios 1, 3 (2 of 3)"
_ST_EQ "an open end running to the suite's own" "$(_SELFTEST_PICK "$TMP/pick" 2- && print -r -- "$SELFTEST_SCOPE")" "scenarios 1-3 (3 of 3)"
# Suite order is by number, then letter, however the names are padded
print -r -- '_ST_SCENARIO "\e[1;96m[2] two\e[0m"' > "$TMP/pick-order/002-two.zsh"
print -r -- '_ST_SCENARIO "\e[1;96m[2b] two b\e[0m"' > "$TMP/pick-order/002b-two-b.zsh"
print -r -- '_ST_SCENARIO "\e[1;96m[9] nine\e[0m"' > "$TMP/pick-order/9-nine.zsh"
print -r -- '_ST_SCENARIO "\e[1;96m[10] ten\e[0m"' > "$TMP/pick-order/010-ten.zsh"
_ST_EQ "a letter follows its number, a number past 9 its predecessors" \
	"$(_SELFTEST_PICK "$TMP/pick-order" - && print -r -- "${SELFTEST_IDS[@]}")" "2 2b 9 10"
# A need no file order can meet, an id on two files, a banner naming another, or a file named
# otherwise refuses every pick, the cause named
print -r -- "$ST_P1 # needs 2" > "$TMP/pick-ahead/001-one.zsh"
print -r -- "$ST_P2" > "$TMP/pick-ahead/002-two.zsh"
OUT=$(_SELFTEST_PICK "$TMP/pick-ahead" 2 2>&1)
RC=$?
_ST_EQ "a need pointing ahead refuses" "$RC" "1"
_ST_OUT_HAS "naming the mark" 'scenario 1 needs 2, which is no scenario before it'
print -r -- "$ST_P1" > "$TMP/pick-twice/001-one.zsh"
print -r -- "$ST_P1" > "$TMP/pick-twice/1-again.zsh"
OUT=$(_SELFTEST_PICK "$TMP/pick-twice" 1 2>&1)
RC=$?
_ST_EQ "an id on two files refuses" "$RC" "1"
_ST_OUT_HAS "naming it" 'scenario 1 is declared twice'
print -r -- "${ST_P2% \# needs 1}" > "$TMP/pick-banner/001-one.zsh"
OUT=$(_SELFTEST_PICK "$TMP/pick-banner" 1 2>&1)
RC=$?
_ST_EQ "a banner naming another id than its file refuses" "$RC" "1"
_ST_OUT_HAS "naming the file" '001-one.zsh must open one _ST_SCENARIO line for \[1\]'
print -r -- "$ST_P1" > "$TMP/pick-name/one.zsh"
print -r -- "${ST_P2% \# needs 1}" > "$TMP/pick-name/002-two.zsh"
OUT=$(_SELFTEST_PICK "$TMP/pick-name" 2 2>&1)
RC=$?
_ST_EQ "a scenario file named otherwise, without a number too, refuses rather than drop out" "$RC" "1"
_ST_OUT_HAS "naming it" 'one.zsh is not named <id>-<name>.zsh'
# A file that fails to parse fails the run, the files after it still running – sourced alone, it
# would run up to its error and pass
mkdir -p "$TMP/pick-parse/selftest"
cp "$SELF" "$TMP/pick-parse/git-edit" && cp "$SELFTEST_DIR/lib.zsh" "$TMP/pick-parse/selftest/"
print -rl -- '_ST_SCENARIO "\e[1;96m[1] broken\e[0m"' 'if true; then' > "$TMP/pick-parse/selftest/001-broken.zsh"
print -rl -- '_ST_SCENARIO "\e[1;96m[2] fine\e[0m"' '_ST_EQ "after it" 1 1' > "$TMP/pick-parse/selftest/002-fine.zsh"
OUT=$(GIT_EDIT_NO_AUTO_OPEN=1 "$TMP/pick-parse/git-edit" --selftest </dev/null 2>&1)
RC=$?
_ST_EQ "a scenario file that fails to parse fails the run" "$RC" "1"
_ST_OUT_HAS "naming it" 'FAIL.* 001-broken.zsh does not parse'
_ST_OUT_HAS "the file after it still running" 'PASS.* after it'
_ST_OUT_HAS "counted as one failure" '^git-edit: error – selftest 1/2 failed$'
# Through the real dispatch, in both spellings, the trailer saying it was not the whole suite
_ST_RUN --selftest=70
_ST_EQ "a pick runs" "$RC" "0"
_ST_OUT_HAS "the scenario it names" '\[70\] --version'
_ST_OUT_LACKS "and not the one before" '\[69\] '
_ST_OUT_LACKS "nor the one after" '\[71\] '
_ST_OUT_HAS "its trailer naming the pick" '^git-edit: ok – selftest [0-9]*/[0-9]* passed – scenario 70 (1 of [0-9]*)$'
local ST_N70=$(print -r -- "$OUT" | sed -n 's/^git-edit: ok .* selftest \([0-9]*\)\/.*/\1/p')
_ST_RUN --selftest 70
_ST_EQ "the value may follow as its own word" "$RC" "0"
_ST_OUT_HAS "to the same run" 'passed – scenario 70 (1 of'
_ST_RUN --selftest=2
_ST_EQ "a pick needing another runs" "$RC" "0"
_ST_EQ "that one first, then its own, nothing past" \
	"$(print -r -- "$OUT" | command grep -o '\[[0-9]*\] [a-z]*' | tr '\n' '|')" "[1] reword|[2] undo|"
local ST_N12=$(print -r -- "$OUT" | sed -n 's/^git-edit: ok .* selftest \([0-9]*\)\/.*/\1/p')
_ST_RUN --selftest=999
_ST_EQ "a scenario the suite lacks refuses" "$RC" "1"
_ST_OUT_HAS "naming it" "scenario '999', which the suite does not have"
_ST_RUN --selftest=3-1
_ST_EQ "a range backwards refuses" "$RC" "1"
_ST_OUT_HAS "saying so" 'runs backwards'
_ST_RUN --selftest=
_ST_EQ "an empty pick refuses" "$RC" "1"
_ST_OUT_HAS "pointing at the full suite" 'leave the value off for the full suite'
_ST_RUN --selftest=1 --selftest=2
_ST_EQ "a second --selftest refuses" "$RC" "1"
_ST_OUT_HAS "as any repeat does" '--selftest given twice'
# `--jobs` runs the units the needs tie together side by side, then prints them in suite order
# under one count – the sum of what each counts alone
_ST_RUN --selftest=1-2,70 --jobs=2
_ST_EQ "a pick spread over jobs runs" "$RC" "0"
_ST_EQ "each scenario once, in suite order" "$(print -r -- "$OUT" | command grep -o '^\[[0-9a-z]*\]' | tr '\n' ' ')" "[1] [2] [70] "
_ST_EQ "under one trailer" "$(print -r -- "$OUT" | command grep -c '^git-edit: ')" "1"
_ST_OUT_HAS "counting what the runs alone counted" \
	"^git-edit: ok – selftest $(( ST_N12 + ST_N70 ))/$(( ST_N12 + ST_N70 )) passed – scenarios 1-2, 70 (3 of [0-9]*), 2 jobs\$"
_ST_RUN --jobs=2 --status
_ST_EQ "--jobs without --selftest refuses" "$RC" "1"
_ST_OUT_HAS "saying where it belongs" '--jobs only applies to --selftest'
_ST_RUN --selftest=70 --jobs=0
_ST_EQ "a count below one refuses" "$RC" "1"
_ST_OUT_HAS "naming it" '--jobs takes a count of 1 or more (got: 0)'
_ST_RUN --selftest= --jobs=2
_ST_EQ "an empty pick refuses over jobs too" "$RC" "1"
_ST_OUT_HAS "as it does alone" 'leave the value off for the full suite'
# A stand-in for the script plays the units – one holding two the suite runs apart, then one
# failing, then one dying without a trailer
print -rl -- '#!/bin/sh' 'case "$1" in' \
	'--selftest=1,2) printf "%s\n" "[1] one" "  PASS a" "[2] two" "  PASS b" "" "git-edit: ok – selftest 2/2 passed" ;;' \
	'--selftest=1,3) printf "%s\n" "[1] one" "  PASS a" "[3] three" "  PASS c" "git-edit: ok – selftest 2/2 passed" ;;' \
	'--selftest=2) printf "%s\n" "[2] two" "  PASS b" "git-edit: ok – selftest 1/1 passed" ;;' \
	'*) [ -n "$ST_JOBS_DIE" ] && { echo died; exit 3; }' \
	'printf "%s\n" "[3] three" "  FAIL c" "git-edit: error – selftest 1/1 failed"; exit 1 ;;' 'esac' > "$TMP/jobs-stand-in"
chmod +x "$TMP/jobs-stand-in"
print -r -- "$ST_P1" > "$TMP/pick-weave/001-one.zsh"
print -r -- "${ST_P2% \# needs 1}" > "$TMP/pick-weave/002-two.zsh"
print -r -- "$ST_P3 # needs 1" > "$TMP/pick-weave/003-three.zsh"
OUT=$(_COLOR=false; _SELFTEST_JOBS "$TMP/jobs-stand-in" "$TMP/pick-weave" --selftest 2 2>&1)
_ST_EQ "a unit holding two scenarios the suite runs apart prints each in its place" \
	"$(print -r -- "$OUT" | command grep -E '^(\[|  (PASS|FAIL) |git-edit: )' | tr '\n' '|')" \
	"[1] one|  PASS a|[2] two|  PASS b|[3] three|  PASS c|git-edit: ok – selftest 3/3 passed – 2 jobs|"
OUT=$(_COLOR=false; _SELFTEST_JOBS "$TMP/jobs-stand-in" "$TMP/pick" --selftest 2 2>&1)
RC=$?
_ST_EQ "a unit's failure fails the run" "$RC" "1"
_ST_EQ "its lines in suite order, each unit's own trailer gone" \
	"$(print -r -- "$OUT" | command grep -E '^(\[|  (PASS|FAIL) |git-edit: )' | tr '\n' '|')" \
	"[1] one|  PASS a|[2] two|  PASS b|[3] three|  FAIL c|git-edit: error – selftest 1/3 failed – 2 jobs|"
_ST_OUT_HAS "keeping every unit's output" "Every unit's output kept in"
OUT=$(export ST_JOBS_DIE=1 _COLOR=false; _SELFTEST_JOBS "$TMP/jobs-stand-in" "$TMP/pick" --selftest 2 2>&1)
RC=$?
_ST_EQ "a unit ending without a result fails it too" "$RC" "1"
_ST_OUT_HAS "named with its exit" 'Scenarios 3 ended without a result – exit 3'
_ST_OUT_HAS "and counted as one failure" '^git-edit: error – selftest 1/3 failed – 2 jobs$'
# The script's own handlers come back once the units are done, its report included in their reach
( _COLOR=false; trap - TERM; _SELFTEST_JOBS "$TMP/jobs-stand-in" "$TMP/pick" --selftest 2 >/dev/null 2>&1; trap > "$TMP/jobs-traps" )
_ST_EQ "the runner hands TERM back to the script's own handler" "$(grep -c '_ON_TERMINATION TERM 143' "$TMP/jobs-traps")" "1"
# A TERM reaching the runner alone, as a timeout sends one, takes the units along – each runs
# below a subshell, where they once ran on past its kill – and its temp dir, wherever that is
mkdir -p "$TMP/jobs-pids" "$TMP/jobs tmp"
printf '#!/bin/sh\necho $$ > "%s/${1#--selftest=}"\nexec sleep 600\n' "$TMP/jobs-pids" > "$TMP/jobs-sleeper"
chmod +x "$TMP/jobs-sleeper"
( _COLOR=false; TMPDIR="$TMP/jobs tmp"; _SELFTEST_JOBS "$TMP/jobs-sleeper" "$TMP/pick" --selftest 2 ) >/dev/null 2>&1 &
local ST_JR=$! ST_JW=0
until { [ -s "$TMP/jobs-pids/1,2" ] && [ -s "$TMP/jobs-pids/3" ]; } || ! kill -0 $ST_JR 2>/dev/null || (( ++ST_JW > 1200 )); do sleep 0.1; done
kill -TERM $ST_JR
wait $ST_JR
_ST_EQ "a TERM to the runner alone stops it, as SIGTERM's exit" "$?" "143"
local ST_JU=$(<"$TMP/jobs-pids/1,2") ST_JV=$(<"$TMP/jobs-pids/3")
ST_JW=0
while { kill -0 "$ST_JU" || kill -0 "$ST_JV"; } 2>/dev/null && (( ++ST_JW <= 300 )); do sleep 0.1; done
_ST_CHECK "and the units it was running with it" \
	sh -c "[ -n '$ST_JU' ] && [ -n '$ST_JV' ] && ! kill -0 '$ST_JU' 2>/dev/null && ! kill -0 '$ST_JV' 2>/dev/null"
kill "$ST_JU" "$ST_JV" 2>/dev/null
_ST_EQ "and its temp dir, a space in its path" "$(ls "$TMP/jobs tmp" | wc -l | tr -d ' ')" "0"
# The picks above run one level down – a level further means a pick reached this scenario
OUT=$(GIT_EDIT_SELFTEST_DEPTH=2 GIT_EDIT_NO_AUTO_OPEN=1 "$SELF" --selftest=70 </dev/null 2>&1)
RC=$?
_ST_EQ "a selftest two levels down refuses" "$RC" "1"
_ST_OUT_HAS "rather than nesting on" 'two levels inside another'
