# A squash refused at the tip names each line its result holds otherwise, and a redo starts clean:
# • A line the tip holds that a resolution dropped, or one the tip's history drops that a resolution
#   kept, is named by that resolution's stop, the commit to rework
# • Every file the result differs in is read – a resolution's line in the sixth one still decides
# • The refusing run's own trailer says paused – where none is named, it offers the redo alone
# • rerere forgets what it recorded at the refused stop, its conflict squashed again with markers,
#   and names one recorded before the run that replayed it, never removing that one
_ST_SCENARIO "\e[1;96m[265] a squash refused at the tip names lost lines and forgets the refused resolution\e[0m"
local TL_T TL_Z TL_TIP TL_WT TL_AT F
# Builds scenario 240's history in a repo of its own, under <subject prefix>
_S265_HISTORY () {
	# Args: <repo name> <subject prefix>
	_ST_PZ_NEW "$1"
	print -l x a b c d > f && git add f && git commit -qm "$2 base"
	print -l x1 a b c d > f && git commit -qam "$2 target"
	TL_T=$(git rev-parse HEAD)
	print -l y1 a b c d > f && git commit -qam "$2 later rewrite"
	_ST_PZ_C g m "$2 unrelated"
	print -l y1z a b c d > f && git commit -qam "$2 append z"
	TL_Z=$(git rev-parse HEAD)
	_ST_PZ_C h h "$2 top"
	TL_TIP=$(git rev-parse HEAD)
}
_S265_HISTORY tl TL
_ST_RUN -s="$TL_T" "$TL_Z"
TL_WT=$(_ST_PZ_WT)
# Resolved to the target's own line, `c` and `d` dropped
[ -n "$TL_WT" ] && print -l x1 a b > "$TL_WT/f" && git -C "$TL_WT" add f
_ST_RUN --continue
TL_AT=$(git -C "${TL_WT:-$ST_NO_WT}" log --format='%H %s' 2>/dev/null | awk 'NF == 3 && $2 == "TL" && $3 == "target" { print $1 }')
_ST_EQ "a resolution dropping lines the tip holds refuses, paused, the branch untouched" "$RC:$(git rev-parse HEAD)" "2:$TL_TIP"
_ST_OUT_HAS "naming the lines it lost by its stop" "f: the tip's lines 4-5, missing – ${TL_AT:0:7} (TL target), resolved at its stop\$"
_ST_OUT_HAS "that stop's commit the one to rework, not the clean pick's" "Rework ${TL_AT:0:12} in the replay kept there"
_ST_OUT_HAS "the run's own trailer saying its replay is kept" "^git-edit: paused – squash of ${TL_Z:0:7} would change the tip's content, its replay kept in .*; rework ${TL_AT:0:7} there"
_ST_OUT_LACKS "never an error" '^git-edit: error'
_ST_OUT_HAS "forgetting what rerere recorded at that stop" "Forgot the resolution rerere recorded at ${TL_AT:0:7}'s stop"
_ST_RUN --abort
_ST_OUT_LACKS "which leaves no record of it behind" 'outlive this run'
_ST_RUN -s="$TL_T" "$TL_Z"
TL_WT=$(_ST_PZ_WT)
_ST_EQ "squashed again, that stop's conflict comes back with its markers" "$RC:$(grep -c '^<<<<<<<' "${TL_WT:-$ST_NO_WT}/f" 2>/dev/null)" "2:1"
_ST_RUN --abort
# The wrong resolution recorded by hand before the run, which rerere then replays into its stop
_S265_HISTORY tp TP
git checkout -q --detach "$TL_T"
git -c rerere.enabled=true cherry-pick "$TL_Z" >/dev/null 2>&1
print -l x1 a b c > f && git add f && GIT_EDITOR=true git -c rerere.enabled=true cherry-pick --continue >/dev/null 2>&1
git checkout -q main
_ST_RUN -s="$TL_T" "$TL_Z"
TL_WT=$(_ST_PZ_WT)
_ST_EQ "the stop arrives pre-filled with it" "$(cat "${TL_WT:-$ST_NO_WT}/f" 2>/dev/null | tr '\n' ' ')" "x1 a b c "
[ -n "$TL_WT" ] && git -C "$TL_WT" add f
_ST_RUN --continue
TL_AT=$(git -C "${TL_WT:-$ST_NO_WT}" log --format='%H %s' 2>/dev/null | awk 'NF == 3 && $2 == "TP" && $3 == "target" { print $1 }')
F=$(sed -n 's/.*if it is wrong, remove: //p' <<<"$OUT")
_ST_OUT_HAS "a record from before the run that replayed the refused stop is named" "A resolution rerere recorded before this run replayed what ${TL_AT:0:7}'s stop holds"
_ST_EQ "and left in place" "$(test -d "${F:-$ST_NO_WT/none}" && print kept)" "kept"
_ST_OUT_LACKS "never forgotten" 'Forgot the resolution'
_ST_RUN --abort
# A later commit drops `d`, and the resolution at its stop keeps it
_ST_PZ_NEW tk
print -l x a b c d > f && git add f && git commit -qm "TK base"
print -l x1 a b c d > f && git commit -qam "TK target"
TL_T=$(git rev-parse HEAD)
print -l y1 a b c > f && git commit -qam "TK later rewrite"
print -l y1z a b c > f && git commit -qam "TK append z"
TL_Z=$(git rev-parse HEAD)
_ST_RUN -s="$TL_T" "$TL_Z"
TL_WT=$(_ST_PZ_WT)
[ -n "$TL_WT" ] && print -l x1z a b c d > "$TL_WT/f" && git -C "$TL_WT" add f
_ST_RUN --continue
[ -n "$TL_WT" ] && print -l y1z a b c d > "$TL_WT/f" && git -C "$TL_WT" add f
_ST_RUN --continue
TL_AT=$(git -C "${TL_WT:-$ST_NO_WT}" log --format='%H %s' 2>/dev/null | awk 'NF == 4 && $2 == "TK" && $3 == "later" { print $1 }')
_ST_EQ "a resolution keeping a line the tip's history drops refuses" "$RC" "2"
_ST_OUT_HAS "naming the line by the stop that kept it, past the earlier one resolved" "f:5 – older than the squash's target, kept at ${TL_AT:0:7} (TK later rewrite), resolved at its stop\$"
_ST_OUT_HAS "that stop's commit the one to rework" "Rework ${TL_AT:0:12} in the replay kept there"
# With the stops' resolutions unrecorded, as an older build's pause, none is named
F="$(git rev-parse --git-common-dir)/git-edit-state"
LC_ALL=C grep -v '^resolved=' "$F" > "$F.s265" && mv -f "$F.s265" "$F"
_ST_RUN --status
_ST_OUT_HAS "with none named, the trailer offers the redo alone" "^git-edit: paused – squash of ${TL_Z:0:7} would change the tip's content, its replay kept in .*; 'git edit --abort', then squash again\$"
_ST_RUN --abort
# `-s=auto` into two targets, each stop resolved by hand, the second's dropping its marker's line
# – an `amend!` one, that target found by its author date whatever its message by then
_ST_PZ_NEW ta
export GIT_EDIT_NO_SELF_RESOLVE=1
local -i TA_I=0
_S265_TA () {
	# Args: <content words> <subject> [<body>]
	TA_I+=1
	print -l ${=1} > f && git add f
	GIT_AUTHOR_DATE="2026-01-01T00:0${TA_I}:00Z" git commit -qm "$2" ${3:+-m "$3"}
}
_S265_TA "a x y c" "TA base"
_S265_TA "a1 x y c" "TA one"
_S265_TA "y1 x y c" "TA one later"
_S265_TA "y1z x y c" "fixup! TA one"
TL_T=$(git rev-parse HEAD)
_S265_TA "y1z x y c1" "TA two"
_S265_TA "y1z x y c2" "TA two later"
_S265_TA "y1z x y c2 d" "amend! TA two" "TA two reworded"
TL_Z=$(git rev-parse HEAD)
_ST_RUN -s=auto "$TL_T" "$TL_Z"
TL_WT=$(_ST_PZ_WT)
for F in "a1z x y c" "y1z x y c" "y1z x y c1"; do
	[ -n "$TL_WT" ] && print -l ${=F} > "$TL_WT/f" && git -C "$TL_WT" add f
	_ST_RUN --continue
done
unset GIT_EDIT_NO_SELF_RESOLVE
TL_AT=$(git -C "${TL_WT:-$ST_NO_WT}" log --format='%H %ad' --date=raw 2>/dev/null | awk '$2 == "1767225900" { print $1 }')
_ST_EQ "a marker's line its target's resolution dropped refuses" "$RC" "2"
_ST_OUT_HAS "naming that target's stop by its authorship, not the earlier one resolved" "f: the tip's line 5, missing – ${TL_AT:0:7} (TA two[ a-z]*), resolved at its stop\$"
_ST_RUN --abort
# Five files differing first on a clean pick's lines, the resolution's line in a sixth
_ST_PZ_NEW t6
for F in a1 a2 a3 a4 a5; do print -l x a > $F; done; print -l p q > f6; print -l u v > f7; git add . && git commit -qm "T6 base"
for F in a1 a2 a3 a4 a5; do print -l x1 a > $F; done; git commit -qam "T6 target"
TL_T=$(git rev-parse HEAD)
for F in a1 a2 a3 a4 a5; do print -l y1 a > $F; done; git commit -qam "T6 later rewrite"
for F in a1 a2 a3 a4 a5; do print -l y1z a > $F; done; git commit -qam "T6 append z"
TL_Z=$(git rev-parse HEAD)
_ST_RUN -s="$TL_T" "$TL_Z"
TL_WT=$(_ST_PZ_WT)
if [ -n "$TL_WT" ]; then
	for F in a1 a2 a3 a4 a5; do print -l x1 a > "$TL_WT/$F"; done
	print -l p q P > "$TL_WT/f6"
	print -l u > "$TL_WT/f7"
	git -C "$TL_WT" add -A
fi
_ST_RUN --continue
TL_AT=$(git -C "${TL_WT:-$ST_NO_WT}" log --format='%H %s' 2>/dev/null | awk 'NF == 3 && $2 == "T6" && $3 == "target" { print $1 }')
_ST_OUT_HAS "naming the sixth file's line" "f6:3 – ${TL_AT:0:7} (T6 target), resolved at its stop\$"
_ST_OUT_HAS "and the seventh's one line lost" "f7: the tip's line 2, missing – ${TL_AT:0:7} (T6 target), resolved at its stop\$"
_ST_OUT_HAS "its stop's commit the one to rework, past five files of a clean pick's lines" "Rework ${TL_AT:0:12} in the replay kept there"
_ST_RUN --abort
cd "$TMP/repo"
