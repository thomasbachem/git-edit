# A rewrite that lands a mode change says so
# A diffstat shows line counts only, so a dropped executable bit on a
# file that also changed content rides invisibly – the completion
# summary names it, tip vs pre-op tip
_ST_SCENARIO "\e[1;96m[61] mode changes land with a note\e[0m"
git reset -q --hard
printf '#!/bin/sh\necho mc\n' > mc.sh && chmod +x mc.sh && git add mc.sh && git commit -qm "MC base"
local MC_BASE=$(git rev-parse HEAD)
printf 'mo\n' > mo.txt && git add mo.txt && git commit -qm "MC top"
printf '#!/bin/sh\necho mc CHANGED\n' > mc.sh && chmod -x mc.sh && git add mc.sh
_ST_RUN --amend-into="$MC_BASE" --allow-mode-change -- mc.sh
_ST_EQ "the mode-dropping fold lands" "$RC" "0"
_ST_OUT_HAS "and names the mode change" 'Mode changes landed'
_ST_CHECK "the mode really changed at HEAD" sh -c "git ls-tree HEAD mc.sh | grep -q '^100644'"
# A mode-neutral fold stays silent
printf '#!/bin/sh\necho mc AGAIN\n' > mc.sh && git add mc.sh
_ST_RUN --amend-into="$(git rev-parse ':/MC base')" -- mc.sh
_ST_EQ "the mode-neutral fold lands" "$RC" "0"
_ST_OUT_LACKS "with no mode note" 'Mode changes landed'
git reset -q --hard
