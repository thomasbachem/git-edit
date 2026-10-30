# A placed commit moving and extending a line a later commit rewords lands – its stops resolved
# to the older wording, the reword replayed onto the moved line, rebased there, not taken in
_ST_SCENARIO "\e[1;96m[266] a placement moving a line a later commit rewords lands\e[0m"
local MR_BASE MR_T MR_WT
local MR_OLD='// An edit dialog has no tab panel around its toggles'
local MR_NEW='// An edit dialog has no entry type panel around its toggles'
local MR_EXT=' – `panel` holds them for it all the same'
_ST_PZ_NEW mr
export GIT_EDIT_NO_SELF_RESOLVE=1
git config rerere.enabled false
print -l a "$MR_OLD" b c d > f.js && git add f.js && git commit -qm "MR base" && MR_BASE=$(git rev-parse HEAD)
print -l a "$MR_NEW" b c d > f.js && git commit -qam "MR reword"
print x > g.txt && git add g.txt && git commit -qm "MR tip" && MR_T=$(git rev-parse HEAD)
# Composed on the tip – the line moved below `d` and extended, in the tip's wording
print -l a b c d "$MR_NEW$MR_EXT" e > f.js
_ST_RUN --commit --after="${MR_BASE:0:12}" --text "MR placed" -- f.js
MR_WT=$(_ST_PZ_WT)
_ST_RESOLVE "${MR_WT:-$ST_NO_WT}" f.js "$(print -l a b c d "$MR_OLD$MR_EXT" e)"
_ST_RUN --continue
_ST_RESOLVE "${MR_WT:-$ST_NO_WT}" f.js "$(print -l a b c d "$MR_NEW$MR_EXT" e)"
_ST_RUN --continue
unset GIT_EDIT_NO_SELF_RESOLVE
_ST_EQ "the placement lands below the reword" "$RC:$(git log --format=%s | tr '\n' '|')" "0:MR tip|MR reword|MR placed|MR base|"
_ST_OUT_LACKS "never refused as a resolution taking the reword in" 'A resolution took in'
_ST_EQ "the reword replayed onto the moved line" "$(git show HEAD~1 -- f.js | LC_ALL=C grep -c '^[-+]// An edit dialog')" "2"
_ST_EQ "the tip as composed" "$(git show HEAD:f.js)" "$(print -l a b c d "$MR_NEW$MR_EXT" e)"
# As does one moving it into an indented block, the line otherwise as it was
_ST_PZ_NEW mi
export GIT_EDIT_NO_SELF_RESOLVE=1
git config rerere.enabled false
print -l a "$MR_OLD" b '{' c '}' > f.js && git add f.js && git commit -qm "MI base" && MR_BASE=$(git rev-parse HEAD)
print -l a "$MR_NEW" b '{' c '}' > f.js && git commit -qam "MI reword"
print x > g.txt && git add g.txt && git commit -qm "MI tip"
print -l a b '{' "	$MR_NEW" c '}' > f.js
_ST_RUN --commit --after="${MR_BASE:0:12}" --text "MI placed" -- f.js
MR_WT=$(_ST_PZ_WT)
_ST_RESOLVE "${MR_WT:-$ST_NO_WT}" f.js "$(print -l a b '{' "	$MR_OLD" c '}')"
_ST_RUN --continue
_ST_RESOLVE "${MR_WT:-$ST_NO_WT}" f.js "$(print -l a b '{' "	$MR_NEW" c '}')"
_ST_RUN --continue
unset GIT_EDIT_NO_SELF_RESOLVE
_ST_EQ "a placement indenting the line lands below the reword" "$RC:$(git log --format=%s | tr '\n' '|')" "0:MI tip|MI reword|MI placed|MI base|"
# The placed stop resolved to the tip's wording takes the reword in, emptying it – refused still
_ST_PZ_NEW mt
export GIT_EDIT_NO_SELF_RESOLVE=1
git config rerere.enabled false
print -l a "$MR_OLD" b c d > f.js && git add f.js && git commit -qm "MT base" && MR_BASE=$(git rev-parse HEAD)
print -l a "$MR_NEW" b c d > f.js && git commit -qam "MT reword"
print x > g.txt && git add g.txt && git commit -qm "MT tip" && MR_T=$(git rev-parse HEAD)
print -l a b c d "$MR_NEW$MR_EXT" e > f.js
_ST_RUN --commit --after="${MR_BASE:0:12}" --text "MT placed" -- f.js
MR_WT=$(_ST_PZ_WT)
_ST_RESOLVE "${MR_WT:-$ST_NO_WT}" f.js "$(print -l a b c d "$MR_NEW$MR_EXT" e)"
_ST_RUN --continue
_ST_RESOLVE "${MR_WT:-$ST_NO_WT}" f.js "$(print -l a b c d "$MR_NEW$MR_EXT" e)"
_ST_RUN --continue
unset GIT_EDIT_NO_SELF_RESOLVE
_ST_EQ "a stop taking the reword in refuses, the branch untouched" "$RC:$(git rev-parse HEAD)" "1:$MR_T"
_ST_OUT_HAS "refused for the reword it empties" 'MT reword – f\.js (left out as emptied)'
_ST_RUN --abort
# A reword of three lines, the last holding the first, a stop taking in the first two
# – refused still, the reword's own rewrite of the last never read as a moved copy of the first
_ST_PZ_NEW mx
export GIT_EDIT_NO_SELF_RESOLVE=1
git config rerere.enabled false
print -l a '// tab panel' '// tab bar' b '// tab panel – more' c > f.js && git add f.js && git commit -qm "MX base" && MR_BASE=$(git rev-parse HEAD)
print -l a '// entry type panel' '// entry type bar' b '// entry type panel – more' c > f.js && git commit -qam "MX reword"
print x > g.txt && git add g.txt && git commit -qm "MX tip" && MR_T=$(git rev-parse HEAD)
print -l a '// entry type panel!' '// entry type bar!' b '// entry type panel – more' c > f.js
_ST_RUN --commit --after="${MR_BASE:0:12}" --text "MX placed" -- f.js
MR_WT=$(_ST_PZ_WT)
_ST_RESOLVE "${MR_WT:-$ST_NO_WT}" f.js "$(print -l a '// entry type panel!' '// entry type bar!' b '// tab panel – more' c)"
_ST_RUN --continue
_ST_RESOLVE "${MR_WT:-$ST_NO_WT}" f.js "$(print -l a '// entry type panel!' '// entry type bar!' b '// entry type panel – more' c)"
_ST_RUN --continue
unset GIT_EDIT_NO_SELF_RESOLVE
_ST_EQ "a stop taking in most of a reword refuses, the branch untouched" "$RC:$(git rev-parse HEAD)" "1:$MR_T"
_ST_OUT_HAS "named as taken in" 'A resolution took in what a later commit changes'
_ST_RUN --abort
