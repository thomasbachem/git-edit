# A run losing the race reruns only the checks it can't reuse:
# • Its gate stops at the first check after the branch moved, as its CAS would refuse
# • Its re-run takes over each check passed on a commit rebuilt alike – tree, parents' trees,
#   author and message – and runs every other
_ST_SCENARIO "\e[1;96m[284] a re-run reuses what its lost run verified\e[0m"
local RV_TGT

# Makes a repo with `A.txt` staged for its `A` below `B`, `C` and `D`, `C` rewriting `B.txt`,
# and a gate logging each check and moving `main` by <peer> as it checks <subject>
_RV_NEW () {
	# Args: <repo name> <subject> <peer: sh lines>
	_ST_PZ_NEW "$1"
	_ST_PZ_C base.txt base "$1 base"
	_ST_PZ_C A.txt A "$1 A"
	_ST_PZ_C B.txt B "$1 B"
	_ST_PZ_C B.txt C "$1 C"
	_ST_PZ_C D.txt D "$1 D"
	RV_TGT=$(git rev-parse HEAD~3)
	print -r -- A2 > A.txt && git add A.txt
	cat > "$TMP/rv-$1.sh" <<RACE
#!/bin/sh
S=\$(git log -1 --format=%s "\$GIT_EDIT_VERIFY_COMMIT")
printf '%s\n' "\$S" >> "$TMP/rv-$1.log"
[ "\$S" = "$2" ] && [ ! -e "$TMP/rv-$1.moved" ] || exit 0
: > "$TMP/rv-$1.moved"
cd "$TMP/pz-$1" || exit 1
M=\$(git rev-parse refs/heads/main)
B=\$(git rev-parse "\$M~2")
C=\$(git rev-parse "\$M~1")
# Rebuilds <commit> on <parent> as <subject>, its tree and author date kept unless given
ct () {
	T=\${4:-}
	[ -n "\$T" ] || T="\$1^{tree}"
	GIT_AUTHOR_DATE=\${5:-\$(git log -1 --format=%ad --date=raw "\$1")} git commit-tree -p "\$2" -m "\$3" "\$T"
}
$3
RACE
	chmod +x "$TMP/rv-$1.sh"
}
# Prints the subjects the gate checked, comma-ended
_RV_CHECKED () {
	# Args: <repo name>
	tr '\n' , < "$TMP/rv-$1.log"
}
export GIT_EDIT_NO_RERUN=

# Losing at its last check, the re-run checks only the peer's commit – the rest passed unchanged
_RV_NEW rk "rk D" 'git update-ref refs/heads/main "$(git commit-tree -p "$M" -m "rk peer" "$M^{tree}")"'
_ST_RUN --amend-into="$RV_TGT" --verify="$TMP/rv-rk.sh" --verify-span -- A.txt
_ST_EQ "a fold losing the race at its last check lands on its re-run" \
	"$RC:$(git log --format=%s | tr '\n' ,):$(git show HEAD~4:A.txt)" "0:rk peer,rk D,rk C,rk B,rk A,rk base,:A2"
_ST_OUT_HAS "naming the loss" '^Lost the race – .* re-run 1 of 2'
_ST_EQ "its re-run checking only the commit the move brought" "$(_RV_CHECKED rk)" "rk A,rk B,rk C,rk D,rk peer,"
_ST_OUT_HAS "counting the checks it took over" 'Verified 5 commit(s) with .* – 4 of them passed unchanged on the run that lost the race$'

# A peer rewording `B` runs its check again – `C` and `D` above it, rebuilt alike, reuse theirs
_RV_NEW rw "rw D" 'NB=$(ct "$B" "$B^" "rw B reworded") && NC=$(ct "$C" "$NB" "rw C") && ND=$(ct "$M" "$NC" "rw D") &&
git update-ref refs/heads/main "$ND"'
_ST_RUN --amend-into="$RV_TGT" --verify="$TMP/rv-rw.sh" --verify-span -- A.txt
_ST_EQ "a fold whose peer reworded a commit above its target lands on its re-run" \
	"$RC:$(git log --format=%s | tr '\n' ,)" "0:rw D,rw C,rw B reworded,rw A,rw base,"
_ST_EQ "its re-run checking the reworded commit alone" "$(_RV_CHECKED rw)" "rw A,rw B,rw C,rw D,rw B reworded,"
_ST_OUT_HAS "the three above and below it taken over" 'Verified 4 commit(s) with .* – 3 of them passed unchanged on the run that lost the race$'

# A peer changing what `B` holds and when `D` was authored – `C` checked again, as its tree stands
# on a parent's changed one, and `D` too, though its tree and both parents' are as before
_RV_NEW rp "rp D" 'BLOB=$(printf "B2\n" | git hash-object -w --stdin)
GIT_INDEX_FILE="'"$TMP"'/rv-rp.index" git read-tree "$B" &&
GIT_INDEX_FILE="'"$TMP"'/rv-rp.index" git update-index --cacheinfo "100644,$BLOB,B.txt" &&
TB=$(GIT_INDEX_FILE="'"$TMP"'/rv-rp.index" git write-tree) &&
NB=$(ct "$B" "$B^" "rp B" "$TB") && NC=$(ct "$C" "$NB" "rp C") && ND=$(ct "$M" "$NC" "rp D" "" "1700000000 +0000") &&
git update-ref refs/heads/main "$ND"'
_ST_RUN --amend-into="$RV_TGT" --verify="$TMP/rv-rp.sh" --verify-span -- A.txt
_ST_EQ "a fold whose peer changed a commit above its target lands on its re-run" \
	"$RC:$(git log --format=%s | tr '\n' ,):$(git show HEAD~2:B.txt)" "0:rp D,rp C,rp B,rp A,rp base,:B2"
_ST_EQ "its re-run checking each commit whose tree, parent's tree or author changed" \
	"$(_RV_CHECKED rp)" "rp A,rp B,rp C,rp D,rp B,rp C,rp D,"
_ST_OUT_HAS "the one below them taken over" 'Verified 4 commit(s) with .* – 1 of them passed unchanged on the run that lost the race$'

# Moved at its first check, the gate stops there rather than check what can no longer land
_RV_NEW es "es A" 'git update-ref refs/heads/main "$(git commit-tree -p "$M" -m "es peer" "$M^{tree}")"'
_ST_RUN --amend-into="$RV_TGT" --verify="$TMP/rv-es.sh" --verify-span -- A.txt
_ST_EQ "a fold whose branch moved at its first check lands on its re-run" \
	"$RC:$(git log --format=%s | tr '\n' ,)" "0:es peer,es D,es C,es B,es A,es base,"
_ST_OUT_HAS "stopping its gate at the next check" "^Verification stopped after 1 of 4 commit(s) – main moved, so this result can't land$"
_ST_OUT_HAS "refused as moved since it read it" "^Branch 'main' moved from [0-9a-f]\{7\} to [0-9a-f]\{7\} since this run read it"
_ST_EQ "the first run checking that one commit, its re-run the rest" "$(_RV_CHECKED es)" "es A,es B,es C,es D,es peer,"
_ST_OUT_HAS "the one it checked taken over" 'Verified 5 commit(s) with .* – 1 of them passed unchanged on the run that lost the race$'

unfunction _RV_NEW _RV_CHECKED
cd "$TMP/repo"
