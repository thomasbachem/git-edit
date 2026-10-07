# A squash names the body its --text drops, as a reword does
# `--text` replaces every squashed message whole, and each summary line is a subject, so a
# subject-only message reads as clean – on either route, and only where a body is really lost
_ST_SCENARIO "\e[1;96m[73] a squash names the body its --text drops\e[0m"
printf 'sb1\n' > sb1.txt && git add sb1.txt
git commit -q -F - <<-'SBMSG'
	SB first

	• first body line
	• second body line
SBMSG
local SB_FIRST=$(git rev-parse HEAD)
printf 'sb2\n' > sb2.txt && git add sb2.txt && git commit -qm "SB second"
_ST_RUN -s --text="SB squashed" "$SB_FIRST" HEAD
_ST_EQ "a plumbing-route squash applies" "$RC" "0"
_ST_OUT_HAS "naming the body it drops, with its length" 'carried a 2-line body the new one drops'
_ST_OUT_HAS "and where it stays readable" "still readable at ${SB_FIRST:0:12}"
# The rebase route, a target with a body taking in a commit that isn't adjacent
printf 'sb3\n' > sb3.txt && git add sb3.txt
git commit -q -F - <<-'SBMSG'
	SB third

	• third body line
SBMSG
local SB_THIRD=$(git rev-parse HEAD)
printf 'sb4\n' > sb4.txt && git add sb4.txt && git commit -qm "SB fourth"
printf 'sb5\n' > sb5.txt && git add sb5.txt && git commit -qm "SB fifth"
_ST_RUN -s="$SB_THIRD" --text="SB third and fifth" HEAD
_ST_EQ "a rebase-route squash applies" "$RC" "0"
_ST_OUT_HAS "naming the target's body too" "carried a 1-line body the new one drops – it is still readable at ${SB_THIRD:0:12}"
# Neighbor: a message that restates the body discards none
printf 'sb6\n' > sb6.txt && git add sb6.txt
git commit -q -F - <<-'SBMSG'
	SB sixth

	• sixth body line
SBMSG
printf 'sb7\n' > sb7.txt && git add sb7.txt && git commit -qm "SB seventh"
_ST_RUN -s --text="$(printf 'SB sixth and seventh\n\n• sixth body line')" HEAD~1 HEAD
_ST_OUT_LACKS "a message restating the body draws no notice" 'carried a .*-line body'
# A `--text` with a body of its own that restates only part of a squashed one – the missing
# lines print, as they do for a reword
printf 'sb10\n' > sb10.txt && git add sb10.txt
git commit -q -F - <<-'SBMSG'
	SB tenth

	• tenth body line
	• tenth second line
SBMSG
local SB_TENTH=$(git rev-parse HEAD)
printf 'sb11\n' > sb11.txt && git add sb11.txt && git commit -qm "SB eleventh"
_ST_RUN -s --text="$(printf 'SB tenth and eleventh\n\n• tenth body line')" HEAD~1 HEAD
_ST_EQ "a body-cutting squash applies" "$RC" "0"
_ST_OUT_HAS "names the lines the new body lacks" "carried a 2-line body – the new one lacks 1 of its lines, still readable at ${SB_TENTH:0:12}"
_ST_OUT_HAS "and prints them" '    • tenth second line'
_ST_EQ "but not the kept one" "$(print -r -- "$OUT" | grep -c '    • tenth body line')" "0"
# Negative: subject-only commits have no body to lose
printf 'sb8\n' > sb8.txt && git add sb8.txt && git commit -qm "SB eighth"
printf 'sb9\n' > sb9.txt && git add sb9.txt && git commit -qm "SB ninth"
_ST_RUN -s --text="SB eighth and ninth" HEAD~1 HEAD
_ST_OUT_LACKS "nor does squashing subject-only commits" 'carried a .*-line body'
git reset -q --hard
