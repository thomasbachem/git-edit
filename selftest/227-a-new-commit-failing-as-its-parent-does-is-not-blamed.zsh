# A commit placed below the tip replaces none, so its parent answers who broke the check – a check
# that cannot run below a later commit failed there too, and the climb named that one the cure
_ST_SCENARIO "\e[1;96m[227] a new commit failing as its parent does is not blamed, nor healed above\e[0m"
local VP_TIP VP_ANCHOR
_ST_PZ_NEW vp1
_ST_PZ_C vp_base.txt base "VP base"
_ST_PZ_C vp_anchor.txt anchor "VP anchor"
VP_ANCHOR=$(git rev-parse HEAD)
_ST_PZ_C vp_mid.txt mid "VP mid"
_ST_PZ_C vp_ready.txt ready "VP ready"
VP_TIP=$(git rev-parse HEAD)
# The script names the deciding file, not the command – a token naming it would skip the
# commits lacking it rather than fail them
printf '#!/bin/sh\ntest -f vp_ready.txt\n' > "$TMP/vp_ready.sh"
chmod +x "$TMP/vp_ready.sh"
print -r -- placed > vp_placed.txt
_ST_RUN --commit --text "VP placed" --after="$VP_ANCHOR" --verify="$TMP/vp_ready.sh" -- vp_placed.txt
_ST_EQ "a placed commit failing its check lands nothing" "$RC:$(git rev-parse HEAD)" "1:$VP_TIP"
_ST_OUT_HAS "naming it as failing" '^  failing: [0-9a-f]* VP placed$'
_ST_OUT_HAS "disowning it for the commit below, as for a counterpart" 'below it fails the same check – not this commit'
_ST_OUT_HAS "naming that commit" '^  parent: [0-9a-f]* VP anchor$'
_ST_OUT_HAS "with the remedy where nothing is linked" 'edit.worktreeLink node_modules'
_ST_OUT_LACKS "and no cure above it" 'first green'
# A parent that passes leaves the failure the placed commit's own, and the climb answers as before
printf '#!/bin/sh\ntest -f vp_ready.txt || ! test -f vp_placed.txt\n' > "$TMP/vp_placed.sh"
chmod +x "$TMP/vp_placed.sh"
_ST_RUN --commit --text "VP placed" --after="$VP_ANCHOR" --verify="$TMP/vp_placed.sh" -- vp_placed.txt
_ST_EQ "one failing on its own content lands nothing either" "$RC:$(git rev-parse HEAD)" "1:$VP_TIP"
_ST_OUT_LACKS "never disowned for its parent" 'fails the same check'
_ST_OUT_HAS "but healed where the check passes again" '^  first green: [0-9a-f]* VP ready$'
rm -f vp_placed.txt
cd "$TMP/repo"
