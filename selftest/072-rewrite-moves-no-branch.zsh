# Git applies `rebase.updateRefs` as its rebase completes, ahead of the verify and the CAS, so
# an aborted or refused rewrite would leave a branch in the span rewritten – pinned off, with
# the branch named instead, on either route, and never one a worktree has checked out
_ST_SCENARIO "\e[1;96m[72] a rewrite moves no branch but its own, whatever rebase.updateRefs says\e[0m"
cd "$TMP/repo"
git checkout -q main 2>/dev/null
git reset -q --hard
printf 'ub\n' > ub.txt && git add ub.txt && git commit -qm "UB below"
git branch ub-below
printf 'ut\n' > ut.txt && git add ut.txt && git commit -qm "UB target"
local UB_TARGET=$(git rev-parse HEAD)
printf 'um\n' > um.txt && git add um.txt && git commit -qm "UB mid"
local UB_SIDE=$(git rev-parse HEAD)
git branch ub-side
git branch ub-live
git worktree add -q "$TMP/ub-live" ub-live
git checkout -q -b ub-top && printf 'uo\n' > uo.txt && git add uo.txt && git commit -qm "UB on top" && git checkout -q main
printf 'ux\n' > ux.txt && git add ux.txt && git commit -qm "UB tip"
local UB_TIP=$(git rev-parse HEAD)
git config rebase.updateRefs true
printf 'ut2\n' > ut.txt && git add ut.txt
_ST_RUN --amend-into="$UB_TARGET" -- ut.txt
_ST_EQ "a fold with rebase.updateRefs set applies" "$RC" "0"
_ST_EQ "leaving the branch in the span where it was" "$(git rev-parse ub-side)" "$UB_SIDE"
_ST_OUT_HAS "which it names" '^Branch ub-side points into the rewritten span'
_ST_OUT_HAS "with its exact counterpart" "Branch ub-side .*the same change: UB mid"
_ST_OUT_HAS "and the command moving it there" "git branch -f ub-side $(git rev-parse --short=12 HEAD~1)$"
_ST_OUT_HAS "and why the key moved nothing" 'rebase.updateRefs is set, but git edit moves only the branch it rewrites'
# A checked-out branch is stranded exactly as ub-side is – the difference is that someone may
# be working in it right now, which makes silence there the worse of the two, so it is named
# without a command, since moving it is that checkout's to do over whatever sits in it
_ST_OUT_HAS "and a branch a worktree has checked out, the same way" '^Branch ub-live points into the rewritten span, checked out in '
_ST_OUT_HAS "with its counterpart" "its counterpart here is $(git rev-parse --short=12 HEAD~1) – the same change: UB mid"
_ST_OUT_LACKS "but no command aimed at someone else's worktree" 'git branch -f ub-live'
_ST_OUT_LACKS "nor one below the span" 'Branch ub-below'
_ST_OUT_LACKS "nor one built on top of it" 'Branch ub-top'
_ST_EQ "and the checked-out one stays where it was too" "$(git -C "$TMP/ub-live" rev-parse HEAD)" "$UB_SIDE"
# A failing verify pauses before the CAS, and the abort leaves nothing moved
git reset -q --hard "$UB_TIP"
printf 'ut2\n' > ut.txt && git add ut.txt
_ST_RUN --amend-into="$UB_TARGET" --verify=false -- ut.txt
_ST_EQ "a fold whose verify fails pauses" "$RC" "2"
_ST_EQ "with the branch in the span untouched" "$(git rev-parse ub-side)" "$UB_SIDE"
_ST_RUN --abort
_ST_EQ "and still untouched once aborted" "$(git rev-parse ub-side)" "$UB_SIDE"
# A peer landing mid-fold makes the CAS refuse – the verify runs in that window
printf 'git -C %q update-ref refs/heads/main "$(git -C %q commit-tree "$(git -C %q rev-parse main^{tree})" -p main -m "UB peer")"\n' "$TMP/repo" "$TMP/repo" "$TMP/repo" > "$TMP/ub-peer.zsh"
git reset -q --hard "$UB_TIP"
printf 'ut2\n' > ut.txt && git add ut.txt
_ST_RUN --amend-into="$UB_TARGET" --verify="zsh $TMP/ub-peer.zsh" -- ut.txt
_ST_EQ "a fold a peer overtakes is refused" "$RC" "1"
_ST_EQ "leaving the branch in the span untouched even so" "$(git rev-parse ub-side)" "$UB_SIDE"
# The plumbing route names it from its own rebuild record, and an unset key goes unmentioned
git config --unset rebase.updateRefs
git reset -q --hard "$UB_TIP"
_ST_RUN -M --text="UB target reworded" "$UB_TARGET"
_ST_EQ "a reword applies" "$RC" "0"
_ST_OUT_HAS "naming the branch with its rebuilt counterpart" "git branch -f ub-side $(git rev-parse --short=12 HEAD~1)$"
_ST_OUT_LACKS "without a note about a key that isn't set" 'rebase.updateRefs is set'
git worktree remove --force "$TMP/ub-live"
git branch -qD ub-below ub-side ub-live ub-top
git reset -q --hard
