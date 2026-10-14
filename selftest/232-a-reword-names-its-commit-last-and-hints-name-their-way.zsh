# The lines a run ends on name what it did and the way on:
# • A reword names the commit it landed right above the trailer, its body by length – a dropped
#   body ending on its header, so a `tail` keeping one of its lines keeps that too
# • A put whose `--base` predates the tip names the rebuild from the tip, `git show` and all
# • A landing leaving a file on its conflict says the file lacks what landed until merged
# • `-h` lists the batch reword beside the single one
_ST_SCENARIO "\e[1;96m[232] a reword names its commit last, refusals name their way out\e[0m"
local RW_T RW_N RW_B

_ST_PZ_NEW rw
_ST_PZ_C init.txt i "RW init"
printf 'rw\n' > rw.txt && git add rw.txt && git commit -qm "RW target"
RW_T=$(git rev-parse HEAD)
_ST_PZ_C later.txt l "RW later"
_ST_RUN -M --text="$(printf 'RW reworded\n\n• new body line\n• second new line')" "$RW_T"
RW_N=$(git rev-parse HEAD~1)
_ST_EQ "a reword with a body names its commit right above the trailer, the body by length" \
	"$RC:$(print -r -- "$OUT" | tail -2 | head -1)" "0:  $(git log -1 --format=%h "$RW_N") RW reworded (with a 2-line body)"
_ST_OUT_LACKS "printing none of the body's lines" '    • new body line'
_ST_RUN -M --subject="RW subject alone" HEAD~1
RW_N=$(git rev-parse HEAD~1)
_ST_EQ "as does --subject, the body it kept named by length" \
	"$RC:$(print -r -- "$OUT" | tail -2 | head -1)" "0:  $(git log -1 --format=%h "$RW_N") RW subject alone (with a 2-line body)"
_ST_RUN -M --text="RW body dropped" HEAD~1
RW_N=$(git rev-parse HEAD~1)
_ST_EQ "a reword dropping the body ends on its commit, the way back and the dropped body's header above" \
	"$RC:$(print -r -- "$OUT" | tail -2 | head -1):$(print -r -- "$OUT" | tail -4 | head -1 | grep -c 'carried a 2-line body the new one drops'):$(print -r -- "$OUT" | tail -3 | head -1 | grep -c '^To put the body back')" \
	"0:  $(git log -1 --format=%h "$RW_N") RW body dropped:1:1"
_ST_EQ "its dropped lines above that header" "$(print -r -- "$OUT" | tail -6 | head -2 | tr -s ' ' | tr '\n' '|')" " • new body line| • second new line|"
_ST_RUN_IN "$(printf -- '--- %s\nRW batch\n' "$RW_N")" -M --text -
_ST_EQ "a batch reword names its commits last" "$RC:$(print -r -- "$OUT" | tail -2 | head -1)" "0:  $(git log -1 --format=%h HEAD~1) RW batch"

# A put on an older --base names the tip's copy and the --base it rests on then
RW_B=$(git rev-parse HEAD)
_ST_PZ_C rw.txt rw2 "RW tip moves rw.txt"
print -r -- "mine" > "$TMP/rw-put.txt"
_ST_RUN --commit --text "RW put" --put="rw.txt=$TMP/rw-put.txt" --base="$RW_B"
_ST_EQ "a put whose --base predates the tip's change refuses" "$RC" "1"
_ST_OUT_HAS "naming the rebuild from the tip and its --base" "Rebuild it from the tip – git show $(git rev-parse --short=12 HEAD):<path> plus your change – and put it again with --base=$(git rev-parse --short=12 HEAD)"

# A landing over a conflicting edit leaves the file lacking it until merged
_ST_PZ_NEW rw2
print -l {1..5} > f && git add f && git commit -qm "RW2 base"
print -l 1 2 3-mine 4 5 > f
GIT_EDIT_ACTOR=rw-peer _ST_RUN --exec -- sh -c "printf '%s\n' 1 2 3-L 4 5 > f && git commit -qam 'RW2 L'"
_ST_OUT_HAS "a landing leaving a file on its conflict says it lacks what landed until merged" 'Until merged, the file lacks what landed, as does anything run from the checkout'

_ST_RUN -h
_ST_OUT_HAS "-h lists the batch reword" "reword many                    git edit -M --text - < <file>"
cd "$TMP/repo"
