# A CAS refusal keeps the resolution instead of deleting it
_ST_SCENARIO "\e[1;96m[42] CAS refusal preserves the worktree\e[0m"
git reset -q --hard
printf 'cas one\ncas two\n' > cas.txt && git add cas.txt && git commit -qm "CAS base"
local CAS_TARGET=$(git rev-parse HEAD)
printf 'cas one\ncas CHANGED\n' > cas.txt && git add cas.txt && git commit -qm "CAS later"
printf 'cas one\ncas FOLDED\n' > cas.txt && git add cas.txt
_ST_RUN --amend-into="$CAS_TARGET" -- cas.txt
_ST_EQ "the fold conflicts" "$RC" "2"
local CAS_WT=$(echo "$OUT" | sed -n 's/^git-edit: conflict – resolve in \([^ ]*\).*/\1/p' | head -1)
# A parallel session lands a commit while the resolution is being worked out
printf 'other work\n' > other.txt && git add other.txt && git commit -qm "CAS parallel commit"
# The fold cascades onto the later commit, so resolve until it stops asking
local CAS_ROUNDS=0
while [ "$RC" = "2" ] && [ $CAS_ROUNDS -lt 4 ]; do
	CAS_ROUNDS=$((CAS_ROUNDS+1))
	local CAS_WT_NOW=$(echo "$OUT" | sed -n 's/^git-edit: conflict – resolve in \([^ ]*\).*/\1/p' | head -1)
	if [ -z "$CAS_WT_NOW" ] || [ ! -d "$CAS_WT_NOW" ]; then
		break
	fi
	CAS_WT=$CAS_WT_NOW
	_ST_RESOLVE "$CAS_WT" cas.txt $'cas one\ncas RESOLVED'
	_ST_RUN --continue
done
_ST_EQ "the CAS refuses the write" "$RC" "1"
_ST_OUT_HAS "says the branch moved" 'moved during resolution'
# A refusal must not fire the exit trap, which would delete the one copy of the work and
# leave a state whose worktree is gone
_ST_CHECK "the worktree survives the refusal" sh -c "[ -d '$CAS_WT' ]"
_ST_CHECK "and still holds the resolution" sh -c "grep -q 'cas FOLDED' '$CAS_WT/cas.txt' && git -C '$CAS_WT' show 'HEAD~1:cas.txt' | grep -q 'cas RESOLVED'"
_ST_OUT_HAS "points at the surviving worktree" 'resolution is intact'
_ST_RUN --status
_ST_OUT_LACKS "status is not orphaned" 'worktree is gone'
_ST_CHECK "the parallel commit was not clobbered" \
	sh -c "git log --format=%s | grep -qx 'CAS parallel commit'"
# Plumbing modes touch no worktree, so they once slipped the in-flight guard
# and moved the branch under the paused operation
_ST_RUN -M --text="sneaks past" HEAD
_ST_EQ "a reword is refused while paused" "$RC" "1"
_ST_OUT_HAS "and says why" 'operation is in flight'
_ST_CHECK "the branch did not move" sh -c "git log -1 --format=%s | grep -qx 'CAS parallel commit'"
_ST_RUN --amend-into=auto
_ST_EQ "a fold is refused too" "$RC" "1"
_ST_RUN --abort
_ST_EQ "abort clears the operation" "$RC" "0"
_ST_CHECK "and removes the worktree" sh -c "[ ! -d '$CAS_WT' ]"
# ...and the guard lifts once nothing is in flight
_ST_RUN -M --text="Reworded after abort" HEAD
_ST_EQ "reword works again afterwards" "$RC" "0"
git reset -q --hard
