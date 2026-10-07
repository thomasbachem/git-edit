# The pause hint reads a todo's object, not its second word
# `amend!` autosquashes into `fixup -C <sha>`, whose second word is a flag –
# read as the object it drops that step from the hint, and hands `git log`
# its own copy-detection flag on the way
_ST_SCENARIO "\e[1;96m[63] conflict hint parses every todo command\e[0m"
git reset -q --hard
printf 'ah\n' > ah.txt && git add ah.txt && git commit -qm "AH base"
local AH_BASE=$(git rev-parse HEAD)
printf 'ah\nmid\n' > ah.txt && git commit -qam "AH middle"
printf 'ax\n' > ax.txt && git add ax.txt
git commit -q -m "amend! AH middle" -m "AH middle, reworded"
printf 'ah\nmid\ntip\n' > ah.txt && git commit -qam "AH tip"
printf 'ah\nfolded\n' > ah.txt && git add ah.txt
_ST_RUN --amend-into="$AH_BASE" -- ah.txt
_ST_EQ "the fold conflicts as set up" "$RC" "2"
_ST_OUT_HAS "the hint reaches the steps touching the file" 'Remaining steps also touch'
_ST_OUT_HAS "naming the one below the amend!" '^    [0-9a-f]\{7,\} AH middle$'
_ST_OUT_HAS "and the one above it" '^    [0-9a-f]\{7,\} AH tip$'
_ST_OUT_LACKS "while the amend! step, touching another file, stays out" '^    [0-9a-f]\{7,\} amend! AH middle$'
_ST_RUN --abort
git reset -q --hard
