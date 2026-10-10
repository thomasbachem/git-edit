# A run that can no longer land stops at once, and a pause wins over a run in flight:
# • A fold already replaying when another caller pauses on its branch refuses at its CAS, so the
#   pause's resolution lands – an edit's too – while a pause on another branch is not in its way
# • A fold whose branch moved during its replay refuses at its conflict rather than pausing, and
#   one with a gate refuses before the gate runs – a `-C` path's replay taken back
# • A resume on a moved branch refuses before it replays, its resolution kept
# • Each names who moved the branch – a git-edit run by its label, else a commit outside git-edit
# • A lost race points at the fixup recipe only where others landed on its branch 3 times in 10 min
_ST_SCENARIO "\e[1;96m[222] a run that can no longer land stops, and a pause wins over a run in flight\e[0m"
local S_C1 S_C2 S_G S_TIP S_MOVED S_WT S_OLD S_PEER S_SIDE S_L S_WTS
local -i S_N

# Writes `<dir>/git`, stalling a run's first `rebase` until `<dir>/go` is there – `<dir>/in` saying
# it got there – so a peer can act while the run replays
_S222_STALL_GIT () {
	# Args: <dir>
	mkdir -p "$1"
	{
		print -r -- '#!/bin/sh'
		print -r -- "case \" \$* \" in *\" rebase \"*) if [ -e ${(q)1}/arm ]; then mv ${(q)1}/arm ${(q)1}/in; ${(q)TMP}/st-hold ${(q)1}/go; fi ;; esac"
		print -r -- "exec ${(q)commands[git]} \"\$@\""
	} > "$1/git"
	chmod +x "$1/git"
	: > "$1/arm"
}
# Starts `git edit <arg>...` in the background under label <label>, the stand-in in <dir> first on
# `PATH` – its output and status into `$TMP/<name>.out` and `.rc` – and waits up to 60 s for it to
# stall there or end
_S222_BG () {
	# Args: <name> <label> <dir> <arg>...
	local N=$1 L=$2 D=$3
	local -i I=0
	shift 3
	( env GIT_EDIT_NO_AUTO_OPEN=1 GIT_EDIT_ACTOR=$L PATH="$D:$PATH" "$SELF" "$@" </dev/null >"$TMP/$N.out" 2>&1
	  print -r -- $? >"$TMP/$N.rc" ) &
	until [ -e "$D/in" ] || [ -s "$TMP/$N.rc" ] || (( ++I > 600 )); do sleep 0.1; done
}
# Lets the run stalled in <dir> go on and waits up to 60 s for background run <name> to end, its
# output and status into `OUT` and `RC`
_S222_END () {
	# Args: <name> <dir>
	local -i I=0
	: > "$2/go"
	until [ -s "$TMP/$1.rc" ] || (( ++I > 600 )); do sleep 0.1; done
	OUT=$(<"$TMP/$1.out")
	RC=$(<"$TMP/$1.rc")
}
# Makes a repo whose `f.txt` a drop of `S_C2` conflicts on, `S_G` holding `g.txt` to fold into
_S222_REPO () {
	# Args: <name>
	_ST_PZ_NEW "$1"
	_ST_PZ_C f.txt $'1\n2\n3' "S222 c1" && _ST_PZ_C g.txt g1 "S222 g" && \
		_ST_PZ_C f.txt $'1\n2x\n3' "S222 c2" && _ST_PZ_C f.txt $'1\n2xy\n3' "S222 c3"
	S_C1=$(git rev-parse HEAD~3)
	S_G=$(git rev-parse HEAD~2)
	S_C2=$(git rev-parse HEAD~1)
	S_TIP=$(git rev-parse HEAD)
}

# A fold already replaying when another caller's drop pauses on the branch refuses at its CAS – its
# landing would strand the drop's resolution – and that resolution then lands
_S222_REPO s222a
print -r -- g2 > g.txt && git add g.txt
_S222_STALL_GIT "$TMP/s222-a"
_S222_BG s222a s-fold "$TMP/s222-a" --amend-into="$S_G" -- g.txt
export GIT_EDIT_ACTOR=s-drop
_ST_RUN -d -y "$S_C2"
export GIT_EDIT_ACTOR=
_ST_EQ "a drop pauses at its conflict while a fold replays" "$RC" "2"
_S222_END s222a "$TMP/s222-a"
_ST_EQ "the fold, replaying when the pause began, refuses at its CAS, the branch unmoved" "$RC:$(git rev-parse HEAD)" "1:$S_TIP"
_ST_OUT_HAS "naming the pause and whose it is" "in flight on main (paused for resolution – s-drop's) – it paused while this one ran, so nothing was applied"
_ST_OUT_HAS "and the rerun that waits for it" "rerun with --wait=600: it waits for that pause, then runs on the new tip"
_ST_EQ "its staging untouched" "$(git diff --cached --name-only)" "g.txt"
_ST_RESOLVE "$(_ST_PZ_WT)" f.txt $'1\n2y\n3'
export GIT_EDIT_ACTOR=s-drop
_ST_RUN --continue
export GIT_EDIT_ACTOR=
_ST_EQ "the pause's resolution then lands" "$RC:$(git show HEAD:f.txt | tr '\n' ,)" "0:1,2y,3,"

# A pause on another branch is not in the fold's way – it lands
_S222_REPO s222n
git branch side "$S_C2"
S_SIDE="$TMP/s222n-side"
git worktree add -q "$S_SIDE" side
print -r -- g2 > g.txt && git add g.txt
_S222_STALL_GIT "$TMP/s222-n"
_S222_BG s222n s-fold "$TMP/s222-n" --amend-into="$S_G" -- g.txt
OUT=$(cd "$S_SIDE" && GIT_EDIT_NO_AUTO_OPEN=1 GIT_EDIT_ACTOR=s-side "$SELF" "$S_C1" </dev/null 2>&1)
_ST_EQ "an edit pauses on another branch while a fold replays" "$?:$(git -C "$S_SIDE" rev-parse HEAD)" "2:$S_C2"
_S222_END s222n "$TMP/s222-n"
_ST_EQ "the fold, that pause not in its way, lands" "$RC:$(git show HEAD~2:g.txt)" "0:g2"
OUT=$(cd "$S_SIDE" && GIT_EDIT_ACTOR=s-side "$SELF" --abort </dev/null 2>&1)

# A fold whose branch another caller's commit moved during its replay refuses at its conflict, no
# pause written for a resolution that could never land
_S222_REPO s222b
print -r -- $'1\n2F\n3' > f.txt && git add f.txt
S_WTS=$(git worktree list | wc -l | tr -d ' ')
_S222_STALL_GIT "$TMP/s222-b"
_S222_BG s222b s-fold "$TMP/s222-b" --amend-into="$S_C1" -- f.txt
print -r -- m > m.txt
export GIT_EDIT_ACTOR=s-mover
_ST_RUN --commit --text "S222 mover" -- m.txt
export GIT_EDIT_ACTOR=
S_MOVED=$(git rev-parse HEAD)
_S222_END s222b "$TMP/s222-b"
_ST_EQ "a fold whose branch moved during its replay refuses rather than pausing at its conflict" "$RC:$([ -e .git/git-edit-state ] && echo paused)" "1:"
_ST_OUT_HAS "naming the move and the git-edit run that made it, by its label" "^Branch 'main' moved from ${S_TIP:0:7} to ${S_MOVED:0:7} since this run read it – git edit .* by \[s-mover\] – nothing was applied"
_ST_OUT_HAS "and the way on" "Run it again on the new tip"
_ST_EQ "its worktree gone, its staging kept" "$(git worktree list | wc -l | tr -d ' '):$(git diff --cached --name-only)" "$S_WTS:f.txt"
# The same fold on a branch nobody moves pauses at that conflict as ever
_ST_RUN --amend-into="$S_C1" -- f.txt
_ST_EQ "while the same fold, the branch left alone, pauses there" "$RC:$([ -e .git/git-edit-state ] && echo paused)" "2:paused"
_ST_RUN --abort

# A gated fold whose branch a plain commit moved refuses before its gate, which never runs
_S222_REPO s222c
print -r -- g2 > g.txt && git add g.txt
printf '#!/bin/sh\n: > "%s/s222-gated"\n' "$TMP" > "$TMP/s222-gate.sh" && chmod +x "$TMP/s222-gate.sh"
_S222_STALL_GIT "$TMP/s222-c"
_S222_BG s222c s-fold "$TMP/s222-c" --amend-into="$S_G" --verify="$TMP/s222-gate.sh" -- g.txt
print -r -- p > p.txt && git add p.txt && git commit -qm "S222 plain" -- p.txt
S_MOVED=$(git rev-parse HEAD)
_S222_END s222c "$TMP/s222-c"
_ST_EQ "a gated fold whose branch moved refuses before its gate, which stays unrun" "$RC:$([ -e "$TMP/s222-gated" ] && echo gated)" "1:"
_ST_OUT_HAS "naming the commit outside git-edit that moved it" "^Branch 'main' moved from ${S_TIP:0:7} to ${S_MOVED:0:7} since this run read it – a commit outside git-edit (commit 'S222 plain') – nothing was applied"
_ST_RUN --amend-into="$S_G" --verify="$TMP/s222-gate.sh" -- g.txt
_ST_EQ "while run again on the new tip it gates and lands" "$RC:$([ -e "$TMP/s222-gated" ] && echo gated):$(git show HEAD~3:g.txt)" "0:gated:g2"

# A resume on a branch moved meanwhile refuses before it replays, its pause and resolution kept
_S222_REPO s222d
export GIT_EDIT_ACTOR=s-drop
_ST_RUN -d -y "$S_C2"
export GIT_EDIT_ACTOR=
S_WT=$(_ST_PZ_WT)
_ST_RESOLVE "${S_WT:-$ST_NO_WT}" f.txt $'1\n2y\n3'
print -r -- p > p.txt && git add p.txt && git commit -qm "S222 plain two" -- p.txt
S_MOVED=$(git rev-parse HEAD)
export GIT_EDIT_ACTOR=s-drop
_ST_RUN --continue
export GIT_EDIT_ACTOR=
_ST_EQ "a resume on a moved branch refuses, the branch as the commit left it" "$RC:$(git rev-parse HEAD)" "1:$S_MOVED"
_ST_OUT_HAS "naming who moved it" "^Branch 'main' moved from ${S_TIP:0:7} to ${S_MOVED:0:7} since this run read it – a commit outside git-edit (commit 'S222 plain two') – nothing was applied"
_ST_OUT_HAS "keeping the resolution" 'Your resolution is intact in'
_ST_EQ "before replaying – stopped where it paused, the resolution staged, the pause kept" \
	"$(git -C "${S_WT:-$ST_NO_WT}" rev-parse -q --verify REBASE_HEAD >/dev/null && echo stopped):$(git -C "${S_WT:-$ST_NO_WT}" show :f.txt 2>/dev/null | tr '\n' ,):$([ -e .git/git-edit-state ] && echo paused)" \
	"stopped:1,2y,3,:paused"
export GIT_EDIT_ACTOR=s-drop
_ST_RUN --status
_ST_OUT_HAS "--status names the abort and redo, not the --continue that refuses" \
	"^git-edit: paused – .* can no longer land: 'git edit --abort', then redo it against the new tip"
_ST_OUT_LACKS "and no resolve-then-continue" 'Resolve there, then'
_ST_RUN --abort
export GIT_EDIT_ACTOR=

# A lost race points at the fixup recipe only where other callers landed 3 times in the last 10
# minutes – the caller's own landings never count
_S222_REPO s222e
S_N=0
for S_L in s-me s-me s-me s-other4 s-other5; do
	S_N+=1
	print -r -- "l$S_N" > "l$S_N.txt"
	export GIT_EDIT_ACTOR=$S_L
	_ST_RUN --commit --text "S222 l$S_N" -- "l$S_N.txt"
done
export GIT_EDIT_ACTOR=
print -r -- g9 > g.txt && git add g.txt
S_OLD=$(git rev-parse HEAD)
S_PEER=$(git commit-tree -p HEAD -m "S222 peer" "HEAD^{tree}")
printf '#!/bin/sh\ngit update-ref refs/heads/main %s\n' "$S_PEER" > "$TMP/s222-race.sh" && chmod +x "$TMP/s222-race.sh"
export GIT_EDIT_ACTOR=s-me
_ST_RUN --amend-into="$S_G" --verify="$TMP/s222-race.sh" -- g.txt
export GIT_EDIT_ACTOR=
_ST_EQ "a fold whose branch moves under its gate loses the race at its CAS" "$RC" "1"
_ST_OUT_HAS "as moved during it" "moved during autosquash"
_ST_OUT_LACKS "with 3 own and 2 other callers' landings, no busy hint" "is busy"
git update-ref refs/heads/main "$S_OLD"
print -r -- l6 > l6.txt
export GIT_EDIT_ACTOR=s-other6
_ST_RUN --commit --text "S222 l6" -- l6.txt
export GIT_EDIT_ACTOR=s-me
S_OLD=$(git rev-parse HEAD)
S_PEER=$(git commit-tree -p HEAD -m "S222 peer two" "HEAD^{tree}")
printf '#!/bin/sh\ngit update-ref refs/heads/main %s\n' "$S_PEER" > "$TMP/s222-race.sh"
_ST_RUN --amend-into="$S_G" --verify="$TMP/s222-race.sh" -- g.txt
export GIT_EDIT_ACTOR=
_ST_EQ "the race lost again" "$RC" "1"
_ST_OUT_HAS "with a third other caller's landing, points at the recipe" "main is busy – other callers landed on it 3 times in the last 10 minutes.* 'fixup! <target's subject>' commit"
git update-ref refs/heads/main "$S_OLD"
git reset -q

# An edit's pause wins too – a fold below its target, replaying as it began, would take that
# target out of the branch, the edit's work then nowhere to land
_S222_REPO s222f
print -r -- g2 > g.txt && git add g.txt
_S222_STALL_GIT "$TMP/s222-f"
_S222_BG s222f s-fold "$TMP/s222-f" --amend-into="$S_G" -- g.txt
export GIT_EDIT_ACTOR=s-edit
_ST_RUN "$S_C2"
export GIT_EDIT_ACTOR=
_ST_EQ "an edit pauses above the fold's target while the fold replays" "$RC" "2"
S_WT=$(_ST_PZ_WT)
_S222_END s222f "$TMP/s222-f"
_ST_EQ "the fold refuses at its CAS, the branch unmoved" "$RC:$(git rev-parse HEAD)" "1:$S_TIP"
_ST_OUT_HAS "naming the edit's pause" "paused for resolution – s-edit's"
print -r -- e > "${S_WT:-$ST_NO_WT}/e.txt" && git -C "${S_WT:-$ST_NO_WT}" add e.txt
export GIT_EDIT_ACTOR=s-edit
_ST_RUN --continue
export GIT_EDIT_ACTOR=
_ST_EQ "so the edit's work lands" "$RC:$(git show HEAD~1:e.txt 2>/dev/null)" "0:e"
git reset -q

# A first run refused at its conflict in a `-C` path takes its replay back, so the rerun reuses it
_S222_REPO s222g
_S222_STALL_GIT "$TMP/s222-g"
_S222_BG s222g s-drop "$TMP/s222-g" -d -y -C="$TMP/s222-kept" "$S_C2"
print -r -- p > p.txt && git add p.txt && git commit -qm "S222 plain three" -- p.txt
_S222_END s222g "$TMP/s222-g"
_ST_EQ "a drop in a -C path whose branch moved refuses at its conflict" "$RC:$([ -e .git/git-edit-state ] && echo paused)" "1:"
_ST_EQ "the path left halfway through no rebase, no conflict in it" \
	"$([ -e "$(git -C "$TMP/s222-kept" rev-parse --path-format=absolute --git-path rebase-merge)" ] && echo rebasing):$(git -C "$TMP/s222-kept" status --porcelain | tr -d '\n')" ":"
export GIT_EDIT_ACTOR=s-drop
_ST_RUN -d -y -C="$TMP/s222-kept" "$S_C2"
_ST_EQ "so the rerun as printed runs there, pausing at the conflict" "$RC" "2"
_ST_RUN --abort
export GIT_EDIT_ACTOR=

# The busy hint reads the branch the run lands on – a pause on another branch taking the slot
# never makes that branch's landings count
_S222_REPO s222h
git branch side "$S_C2"
git worktree add -q "$TMP/s222h-side" side
for S_L in s-a s-b s-c; do
	print -r -- "$EPOCHSECONDS refs/heads/side $S_TIP $S_TIP x"$'\t'"$S_L" >> .git/git-edit-journal
done
print -r -- $'1\n2F\n3' > f.txt && git add f.txt
_S222_STALL_GIT "$TMP/s222-h"
_S222_BG s222h s-fold "$TMP/s222-h" --amend-into="$S_C1" -- f.txt
OUT=$(cd "$TMP/s222h-side" && GIT_EDIT_NO_AUTO_OPEN=1 GIT_EDIT_ACTOR=s-side "$SELF" "$S_C1" </dev/null 2>&1)
_S222_END s222h "$TMP/s222-h"
_ST_EQ "a fold reaching its conflict with another branch's pause in the slot refuses" "$RC" "1"
_ST_OUT_LACKS "pointing at no other branch's busyness" "side is busy"
OUT=$(cd "$TMP/s222h-side" && GIT_EDIT_ACTOR=s-side "$SELF" --abort </dev/null 2>&1)
git reset -q

# A journal line cut short or corrupt counts for nothing, the hint reading on without a warning
_S222_REPO s222i
print -r -- "99999999999999999999999 refs/heads/main x y z"$'\t'"s-x" >> .git/git-edit-journal
print -r -- g9 > g.txt && git add g.txt
S_PEER=$(git commit-tree -p HEAD -m "S222 peer three" "HEAD^{tree}")
printf '#!/bin/sh\ngit update-ref refs/heads/main %s\n' "$S_PEER" > "$TMP/s222-race.sh" && chmod +x "$TMP/s222-race.sh"
_ST_RUN --amend-into="$S_G" --verify="$TMP/s222-race.sh" -- g.txt
_ST_EQ "a race lost beside a corrupt journal line" "$RC" "1"
_ST_OUT_LACKS "warns nothing over it" "number truncated"
git reset -q
