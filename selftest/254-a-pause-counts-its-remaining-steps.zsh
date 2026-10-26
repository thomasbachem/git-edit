# A pause counts the steps left, naming only those touching a conflicted file
# – a deep replay's list ran to hundreds of lines – while `--status` lists every one
_ST_SCENARIO "\e[1;96m[254] a pause counts its remaining steps, --status lists them\e[0m"
local RC_I
_ST_PZ_NEW rc
_ST_PZ_C f.txt 1 "RC base"
_ST_PZ_C f.txt 2 "RC target"
for RC_I in {1..12}; do _ST_PZ_C "g$RC_I.txt" "$RC_I" "RC other $RC_I"; done
_ST_PZ_C f.txt 3 "RC touch f"
_ST_PZ_C h.txt h "RC last"
print -r -- X > f.txt && git add f.txt
_ST_RUN --amend-into="$(git rev-parse ':/RC target')" -- f.txt
_ST_EQ "a fold conflicting at its own step pauses" "$RC" "2"
_ST_OUT_HAS "counting the steps left" "^Remaining steps (after resolution): 14 – the 1 touching a conflicted file listed below, all in 'git edit --status'$"
_ST_OUT_LACKS "listing none of them as a step" '^  pick '
_ST_OUT_HAS "naming the one touching the file below" '^    [0-9a-f]\{7,\} RC touch f$'
_ST_RUN --status
# Each subject bare where an older git writes the todo, behind a `#` elsewhere
_ST_EQ "--status lists every step left" "$(print -r -- "$OUT" | grep -c '^  pick [0-9a-f]* \(# \)\{0,1\}RC ')" "14"
_ST_OUT_LACKS "naming each step's subject once" 'RC other 1 # RC other 1$'
_ST_OUT_HAS "and still names the one touching the file" '^    [0-9a-f]\{7,\} RC touch f$'
_ST_RUN --abort
git restore --staged f.txt && git checkout -q f.txt
# A stop no remaining step touches says so
_ST_PZ_NEW rc2
_ST_PZ_C f.txt 1 "RC2 base"
_ST_PZ_C f.txt 2 "RC2 target"
_ST_PZ_C f.txt 3 "RC2 touch f"
_ST_PZ_C h.txt h "RC2 last"
print -r -- X > f.txt && git add f.txt
_ST_RUN --amend-into="$(git rev-parse ':/RC2 target')" -- f.txt
_ST_RESOLVE "$(_ST_PZ_WT)" f.txt X
_ST_RUN --continue
_ST_OUT_HAS "a later stop no step left touches says none does" "^Remaining steps (after resolution): 1 – none touching a conflicted file, all listed in 'git edit --status'$"
_ST_OUT_LACKS "naming none" 'Remaining steps also touch'
_ST_RUN --abort
git restore --staged f.txt && git checkout -q f.txt
cd "$TMP/repo"
