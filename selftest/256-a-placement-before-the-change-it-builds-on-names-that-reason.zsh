# A commit placed before a later rewrap of the comment it rewrites leaves the rewrap
# nothing to replay – refused for that, not as a resolution taking the rewrap in,
# its status offering the cancel alone, as a resume refuses again
_ST_SCENARIO "\e[1;96m[256] a placement before the change it builds on names that reason\e[0m"
local PB_BASE PB_WRAP PB_T PB_WT PB_PAST

# Prints `f.js` – `a()` returning <a>, its comment as <c1> and <c2>, the function named <fn>
_PB_F () {
	# Args: <a> <c1> <c2> <fn>
	print -l 'function a() {' "	return $1" '}' '' "// $2" "// $3" "function $4() {" '	return 2' '}'
}
local PB_O1='Fixes jumping of grid content when the band height changes dynamically'
local PB_O2='due to late injection of the rollover chip'
local PB_W1='Fixes jumping of grid content when the band height changes'
local PB_W2='dynamically due to late injection of the rollover chip'
local PB_P1='Fixes jumping of grid content as the band resizes for late chips'
local PB_P2='– the rollover one, or one re-added after a form closes'
_ST_PZ_NEW pb
git config rerere.enabled false
_PB_F 1 "$PB_O1" "$PB_O2" fix > f.js && git add f.js && git commit -qm "PB base" && PB_BASE=$(git rev-parse HEAD)
_PB_F 10 "$PB_O1" "$PB_O2" fix > f.js && git commit -qam "PB a"
_PB_F 10 "$PB_W1" "$PB_W2" fix > f.js && git commit -qam "PB rewrap" && PB_WRAP=$(git rev-parse HEAD)
print x > g.txt && git add g.txt && git commit -qm "PB tip" && PB_T=$(git rev-parse HEAD)
# The placed change rewrites the rewrapped comment – placed before it, it holds none of its lines
_PB_F 10 "$PB_P1" "$PB_P2" fixAll > f.js
_ST_RUN --commit --after="${PB_BASE:0:12}" --text "PB placed" -- f.js
_ST_OUT_HAS "the placement stops" '^git-edit: conflict'
PB_WT=$(_ST_PZ_WT)
_ST_RESOLVE "${PB_WT:-$ST_NO_WT}" f.js "$(_PB_F 1 "$PB_P1" "$PB_P2" fixAll)"
_ST_RUN --continue
_ST_OUT_HAS "the rewrap's stop has no answer of its own" 'PB rewrap keeps no change of its own there'
_ST_RESOLVE "${PB_WT:-$ST_NO_WT}" f.js "$(_PB_F 10 "$PB_P1" "$PB_P2" fixAll)"
_ST_RUN --continue
_ST_EQ "resolved to the placed text, it refuses" "$RC:$(git rev-parse HEAD)" "1:$PB_T"
_ST_OUT_HAS "led by the reason the stop gave" "A later commit's change is what the placed one builds on – placed before it, that change empties, so nothing was applied"
_ST_OUT_LACKS "never as a resolution taking it in" 'A resolution took in'
_ST_OUT_HAS "naming the rewrap, left out as emptied" "${PB_WRAP:0:7} PB rewrap – f\.js (left out as emptied)"
_ST_OUT_HAS "and the placement past it" "placed past that change: --after=${PB_WRAP:0:12} in place of --after=${PB_BASE:0:7}"
_ST_RUN --status
_ST_OUT_HAS "its status names the refusal" 'refused by the check of what its stops took in – a resume refuses it again as it stands'
_ST_OUT_HAS "offering the cancel alone" "git-edit: paused – the replay in .* was refused, which a resume repeats; 'git edit --abort' cancels it$"
_ST_OUT_LACKS "never the resume" 'checks it, landing it where it passes'
_ST_RUN --continue
_ST_EQ "as a resume refuses again" "$RC:$(git rev-parse HEAD)" "1:$PB_T"
PB_PAST=$(sed -n 's/.*placed past that change: \(--after=[0-9a-f]*\) in place of.*/\1/p' <<<"$OUT")
_ST_RUN --abort
_ST_RUN --commit ${PB_PAST:---after=none} --text "PB placed" -- f.js
_ST_EQ "run again as named, it lands past the rewrap" "$RC:$(git log --format=%s | tr '\n' '|')" "0:PB tip|PB placed|PB rewrap|PB a|PB base|"

# A stop taking in a later commit's change to a line the placed one
# never touched is a resolution's doing – named as taken in still
# – its stops resolved by hand, as the placed commit's own edits would resolve them
_ST_PZ_NEW pc
export GIT_EDIT_NO_SELF_RESOLVE=1
git config rerere.enabled false
print -l 1 2 3 4 > f.txt && git add f.txt && git commit -qm "PC base" && PB_BASE=$(git rev-parse HEAD)
print -l 1 2 R 4 > f.txt && git commit -qam "PC later"
print x > g.txt && git add g.txt && git commit -qm "PC tip" && PB_T=$(git rev-parse HEAD)
print -l 1 P R 4 > f.txt
_ST_RUN --commit --after="${PB_BASE:0:12}" --text "PC placed" -- f.txt
PB_WT=$(_ST_PZ_WT)
_ST_RESOLVE "${PB_WT:-$ST_NO_WT}" f.txt "$(print -l 1 P R 4)"
_ST_RUN --continue
_ST_RESOLVE "${PB_WT:-$ST_NO_WT}" f.txt "$(print -l 1 P R 4)"
_ST_RUN --continue
_ST_EQ "a stop taking in a change it never built on refuses" "$RC:$(git rev-parse HEAD)" "1:$PB_T"
_ST_OUT_HAS "named as taken in" 'A resolution took in what a later commit changes'
_ST_OUT_LACKS "never as what the placed one builds on" 'is what the placed one builds on'
_ST_RUN --abort
unset GIT_EDIT_NO_SELF_RESOLVE
