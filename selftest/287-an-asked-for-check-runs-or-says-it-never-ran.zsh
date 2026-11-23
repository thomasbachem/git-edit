# A check the command line asks for runs, or the run says it never did:
# • `--onto` with nothing to replay checks the branch's own commits where they stand, at the tier
#   asked – a failure refusing with the branch as it was, a branch moved meanwhile checked again
# • A run that built nothing to check says so above its trailer, which ends `nothing verified`
_ST_SCENARIO "\e[1;96m[287] an asked-for check runs or says it never ran\e[0m"

# Makes a repo `pz-<name>` with `feat` four commits above `main`, and `$TMP/ck-<name>.sh`,
# a check logging each subject, failing at `$CK_FAIL`'s, adding a commit to `feat`
# at `$CK_MOVE`'s and pausing a peer's edit on it at `$CK_PAUSE`'s
_CK_NEW () {
	# Args: <repo name>
	_ST_PZ_NEW "$1"
	_ST_PZ_C base.txt base base
	git checkout -q -b feat
	local F
	for F in one two three four; do _ST_PZ_C "$F.txt" "$F" "$F"; done
	: > "$TMP/ck-$1.log"
	cat > "$TMP/ck-$1.sh" <<CHECK
#!/bin/sh
S=\$(git log -1 --format=%s "\$GIT_EDIT_VERIFY_COMMIT")
printf '%s\n' "\$S" >> "$TMP/ck-$1.log"
if [ "\$S" = "\${CK_MOVE:-}" ] && [ ! -e "$TMP/ck-$1.moved" ]; then
	: > "$TMP/ck-$1.moved"
	T=\$(git -C "$TMP/pz-$1" rev-parse refs/heads/feat)
	git -C "$TMP/pz-$1" update-ref refs/heads/feat "\$(git -C "$TMP/pz-$1" commit-tree -p "\$T" -m peer "\$T^{tree}")"
fi
if [ "\$S" = "\${CK_PAUSE:-}" ] && [ ! -e "$TMP/ck-$1.paused" ]; then
	: > "$TMP/ck-$1.paused"
	(cd "$TMP/pz-$1" && GIT_EDIT_ACTOR=peer "$SELF" "\$(git rev-parse feat~3)" </dev/null >/dev/null 2>&1)
fi
case ",\${CK_FAIL:-}," in *",\$S,"*) exit 1 ;; esac
CHECK
	chmod +x "$TMP/ck-$1.sh"
}
# Prints the subjects the check read since the last call, comma-ended
_CK_READ () {
	# Args: <repo name>
	tr '\n' , < "$TMP/ck-$1.log"
	: > "$TMP/ck-$1.log"
}

# The default tier takes the first commit past the fork and the tip, saying what it left
_CK_NEW ck
_ST_RUN --onto=main --verify="$TMP/ck-ck.sh"
_ST_EQ "a branch already on top checks its own first commit and tip where they stand" \
	"$RC:$(_CK_READ ck)" "0:one,four,"
_ST_OUT_HAS "naming what it left to the span tier" '^Verified 2 of 4 commit(s) with .* – 2 unchecked in between, `--verify-span` covers them'
_ST_OUT_HAS "its trailer a plain ok" '^git-edit: ok – refs/heads/feat unchanged$'
_ST_RUN --onto=main --verify="$TMP/ck-ck.sh" --verify-span
_ST_EQ "the span tier checks each of them" "$RC:$(_CK_READ ck)" "0:one,two,three,four,"
_ST_OUT_HAS "and counts them all" '^Verified 4 commit(s) with '

# A standing check gates a rewrite, so with nothing to replay it waits for an ask
git config edit.verifyCmd "$TMP/ck-ck.sh"
_ST_RUN --onto=main
_ST_EQ "a standing edit.verifyCmd alone checks nothing on a branch already on top" "$RC:$(_CK_READ ck)" "0:"
_ST_OUT_HAS "which it is" '^Already on top of main – nothing to replay\.$'
_ST_OUT_LACKS "saying nothing of a check" 'Verify not run'
_ST_RUN --onto=main --verify-span
_ST_EQ "while --verify-span runs it at each commit" "$RC:$(_CK_READ ck)" "0:one,two,three,four,"
git config --unset edit.verifyCmd
_ST_RUN --onto=main --verify-span
_ST_EQ "with no command anywhere, --verify-span refuses" "$RC:$(_CK_READ ck)" "1:"
_ST_OUT_HAS "naming what it needs" '^git-edit: error – --verify-span needs a command'
_ST_OUT_LACKS "before it starts on any" 'Checking its own'
_ST_RUN --onto=main --verify="$TMP/ck-ck.sh" --no-verify
_ST_EQ "and --no-verify declines a check asked for" "$RC:$(_CK_READ ck)" "0:"

# A failure refuses with the branch as it was, a commit the gate passed answering without a run
local CK_TIP=$(git rev-parse feat)
CK_FAIL=three _ST_RUN --onto=main --verify="$TMP/ck-ck.sh" --verify-span
_ST_EQ "a failing commit refuses, the branch as it was, the one below it passed already" \
	"$RC:$(git rev-parse feat):$(_CK_READ ck)" "1:$CK_TIP:one,two,three,four,"
_ST_OUT_HAS "its trailer saying the branch stays as it is" '^git-edit: error – Verification failed at [0-9a-f]* – nothing was replayed, so the branch stays as it is'
_ST_OUT_HAS "naming where the check passes again" 'first green: [0-9a-f]* four'
_ST_OUT_HAS "as what the failing one needs, not what a rewrite left it needing" 'that commit carries what the failing one needs:$'
_ST_OUT_HAS "and the fix" 'Fix that commit with git edit [0-9a-f]*, then check again\.'
_ST_OUT_LACKS "never a resume there is none of" '\-\-continue'
# A tip failing on the default tier runs the commit below it, which the gate left unchecked
# – where that fails too it names it, never the fork as a commit the tip replaces
CK_FAIL=four,three,base _ST_RUN --onto=main --verify="$TMP/ck-ck.sh"
_ST_EQ "a tip failing on the default tier checks the one below it" "$RC:$(_CK_READ ck)" "1:one,four,three,"
_ST_OUT_HAS "saying the failure isn't the tip's doing" '^The commit below it fails the same check'
_ST_OUT_LACKS "never naming the fork a commit it replaces" 'commit it replaces'

# A branch moved while it checks runs again on the new tip, taking over what passed unchanged
export GIT_EDIT_NO_RERUN=
CK_MOVE=two _ST_RUN --onto=main --verify="$TMP/ck-ck.sh" --verify-span
_ST_EQ "a commit landing mid-check is checked on the re-run alone" "$RC:$(_CK_READ ck)" "0:one,two,three,four,peer,"
_ST_OUT_HAS "stopping where it saw the move" 'Verification stopped after 2 of 4 commit(s) – feat moved, so the commits it checks are no longer its own'
_ST_OUT_HAS "its re-run taking over the two it passed" '^Verified 5 commit(s) with .* – 2 of them passed unchanged on the run that lost the race$'
rm -f "$TMP/ck-ck.moved"
git update-ref refs/heads/feat feat~1
CK_MOVE=four _ST_RUN --onto=main --verify="$TMP/ck-ck.sh" --verify-span
_ST_EQ "one moved during its last check runs again too" "$RC:$(_CK_READ ck)" "0:one,two,three,four,peer,"
_ST_OUT_HAS "taking over all four" '– 4 of them passed unchanged on the run that lost the race$'
# A commit the lost run passed answers for the one above it failing on the re-run
rm -f "$TMP/ck-ck.moved"
git update-ref refs/heads/feat feat~1
CK_MOVE=two CK_FAIL=three _ST_RUN --onto=main --verify="$TMP/ck-ck.sh" --verify-span
_ST_EQ "a re-run failing above what it took over runs nothing below" "$RC:$(_CK_READ ck)" "1:one,two,three,four,"
export GIT_EDIT_NO_RERUN=1
# A peer's pause begun while it checks strands nothing of a run that lands nothing
CK_PAUSE=three _ST_RUN --onto=main --verify="$TMP/ck-ck.sh" --verify-span
_ST_EQ "a peer pausing on the branch mid-check leaves its pass a pass" "$RC:$(_CK_READ ck)" "0:one,two,three,four,peer,"
_ST_OUT_HAS "its trailer a plain ok" '^git-edit: ok – refs/heads/feat unchanged$'
_ST_CHECK "the peer's pause standing" test -f "$(git rev-parse --git-common-dir)/git-edit-state"
GIT_EDIT_ACTOR=peer "$SELF" --abort >/dev/null 2>&1

# A run that built nothing says so, as its ok would read as a pass to the ask
git update-ref refs/heads/feat feat~1
_ST_RUN --reorder --verify="$TMP/ck-ck.sh" ${(f)"$(git rev-list --reverse main..feat)"}
_ST_EQ "a reorder into the order it has checks nothing" "$RC:$(_CK_READ ck)" "0:"
_ST_OUT_HAS "saying so above its trailer" '^Verify not run – the run had nothing to check, so `.*ck-ck\.sh` never ran$'
_ST_OUT_HAS "which ends saying it too" '^git-edit: ok – refs/heads/feat unchanged, nothing verified$'
git config edit.verifyCmd "$TMP/ck-ck.sh"
_ST_RUN --reorder ${(f)"$(git rev-list --reverse main..feat)"}
_ST_OUT_HAS "while a standing check stays quiet there" '^git-edit: ok – refs/heads/feat unchanged$'
_ST_RUN --reorder --verify="$TMP/ck-ck.sh" --no-verify ${(f)"$(git rev-list --reverse main..feat)"}
_ST_OUT_HAS "as one --no-verify declines" '^git-edit: ok – refs/heads/feat unchanged$'
git config --unset edit.verifyCmd
git checkout -q -b level main
_ST_RUN --onto=main --verify="$TMP/ck-ck.sh"
_ST_OUT_HAS "as a branch at its upstream says it" '^git-edit: ok – refs/heads/level unchanged, nothing verified$'
git checkout -q main && _ST_PZ_C more.txt more more && git checkout -q level
_ST_RUN --onto=main --verify="$TMP/ck-ck.sh"
_ST_OUT_HAS "and one moved to it, with no commits of its own" '^git-edit: ok – refs/heads/level moved [0-9a-f]* → [0-9a-f]* – nothing verified$'
git checkout -q main
_ST_RUN --land=level --verify="$TMP/ck-ck.sh"
_ST_OUT_HAS "and a landing with nothing to land" '^git-edit: ok – refs/heads/main unchanged, .*nothing verified$'
_ST_EQ "none of them having run it" "$(_CK_READ ck)" ""

unfunction _CK_NEW _CK_READ
cd "$TMP/repo"
