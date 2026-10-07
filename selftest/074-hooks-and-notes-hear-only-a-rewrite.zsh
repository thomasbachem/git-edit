# Hooks and notes hear a rewrite that lands, once, and nothing else
# git copies notes and runs `post-rewrite` as its rebase finishes, ahead of the verify and the
# CAS – held back now for the landing to deliver, to a hook file and one defined in config alike
_ST_SCENARIO "\e[1;96m[74] hooks and notes hear only a rewrite that lands, once\e[0m"
cd "$TMP/repo"
git checkout -q main 2>/dev/null
git reset -q --hard
local HB_LOG=$TMP/hb-file.log
local HB_CLOG=$TMP/hb-config.log
local HB_PLOG=$TMP/hb-prerebase.log
local HB_HOOKS=$(git rev-parse --path-format=absolute --git-path hooks)
mkdir -p "$HB_HOOKS" "$TMP/hb-lib"
printf '#!/bin/sh\n{ echo "EVENT $1"; cat; } >> %q\n' "$HB_LOG" > "$HB_HOOKS/post-rewrite"
printf '#!/bin/sh\n{ echo "CONFIG $1"; cat; } >> %q\n' "$HB_CLOG" > "$TMP/hb-cfghook.sh"
printf '#!/bin/sh\necho "ran as $0" >> %q\n' "$HB_PLOG" > "$TMP/hb-lib/pre-rebase"
chmod +x "$HB_HOOKS/post-rewrite" "$TMP/hb-cfghook.sh" "$TMP/hb-lib/pre-rebase"
# A hook manager's symlink, which the held-back run's hooks dir has to keep running
ln -s "$TMP/hb-lib/pre-rebase" "$HB_HOOKS/pre-rebase"
git config hook.hbrecorder.event post-rewrite
git config hook.hbrecorder.command "$TMP/hb-cfghook.sh"
git config notes.rewriteRef refs/notes/commits
local HB_N
for HB_N in 1 2 3 4; do
	printf 'hb%s\n' "$HB_N" > "hb$HB_N.txt" && git add "hb$HB_N.txt" && git commit -qm "HB $HB_N"
done
git notes add -m "HB note" HEAD~1
local HB_TIP=$(git rev-parse HEAD)
local HB_TARGET=$(git rev-parse HEAD~2)
# Hooks defined in config come with git 2.54, and `git hook run` delivers to them from there
: > "$HB_LOG"; : > "$HB_CLOG"; : > "$HB_PLOG"
git hook run --ignore-missing post-rewrite -- probe </dev/null >/dev/null 2>&1
local HB_CONFIG=false
[ -s "$HB_CLOG" ] && HB_CONFIG=true
: > "$HB_LOG"; : > "$HB_CLOG"
# An aborted fold was never a rewrite
printf 'hb2 folded\n' > hb2.txt && git add hb2.txt
_ST_RUN --amend-into="$HB_TARGET" --verify=false -- hb2.txt
_ST_EQ "a fold whose verify fails pauses" "$RC" "2"
_ST_RUN --abort
_ST_EQ "and once aborted, no hook heard of it" "$(grep -c '^EVENT' "$HB_LOG")" "0"
_ST_EQ "nor was a note copied" "$(git notes list | wc -l | tr -d ' ')" "1"
_ST_EQ "and the abort left no hold-back files" "$(ls "$(git rev-parse --git-common-dir)" | grep -c '^git-edit-\(state\|capture\)')" "0"
_ST_CHECK "while a symlinked hook of another event ran, from its own path" grep -q "ran as $HB_HOOKS/pre-rebase" "$HB_PLOG"
# A fold that lands is announced once, as one rebase of the commits it replaced
git reset -q --hard "$HB_TIP"
: > "$HB_LOG"; : > "$HB_CLOG"
printf 'hb2 folded\n' > hb2.txt && git add hb2.txt
_ST_RUN --amend-into="$HB_TARGET" -- hb2.txt
_ST_EQ "a fold that lands applies" "$RC" "0"
_ST_OUT_HAS "with the hold-back armed" 'edit.captureRewrites=1'
_ST_EQ "and is announced once, as a rebase" "$(grep -c '^EVENT rebase' "$HB_LOG")" "$(grep -c '^EVENT' "$HB_LOG")"
_ST_EQ "listing its three rewritten commits" "$(grep -vc '^EVENT' "$HB_LOG")" "3"
_ST_CHECK "none of them the fold's own fixup! commit" \
	sh -c "! grep -v '^EVENT' '$HB_LOG' | while read -r OLD NEW; do git log -1 --format=%s \"\$OLD\"; done | grep -q '^fixup!'"
_ST_EQ "and the note followed its commit" "$(git notes show HEAD~1 2>/dev/null)" "HB note"
_ST_EQ "leaving no hold-back files behind" "$(ls "$(git rev-parse --git-common-dir)" | grep -c '^git-edit-\(state\|capture\)')" "0"
if [ "$HB_CONFIG" = "true" ]; then
	_ST_EQ "a hook defined in config heard it too" "$(grep -c '^CONFIG' "$HB_CLOG")" "1"
fi
# A fold a peer overtakes is refused at the CAS – the verify runs in that window
printf 'git -C %q update-ref refs/heads/main "$(git -C %q commit-tree "$(git -C %q rev-parse main^{tree})" -p main -m "HB peer")"\n' "$TMP/repo" "$TMP/repo" "$TMP/repo" > "$TMP/hb-peer.zsh"
git reset -q --hard "$HB_TIP"
: > "$HB_LOG"
local HB_NOTES=$(git notes list | wc -l | tr -d ' ')
printf 'hb2 folded\n' > hb2.txt && git add hb2.txt
_ST_RUN --amend-into="$HB_TARGET" --verify="zsh $TMP/hb-peer.zsh" -- hb2.txt
_ST_EQ "a fold a peer overtakes is refused" "$RC" "1"
_ST_EQ "and no hook heard of it" "$(grep -c '^EVENT' "$HB_LOG")" "0"
_ST_EQ "nor was a note copied" "$(git notes list | wc -l | tr -d ' ')" "$HB_NOTES"
# The plumbing routes deliver through `git hook run` as well
git reset -q --hard "$HB_TIP"
: > "$HB_LOG"; : > "$HB_CLOG"
_ST_RUN -M --text="HB 3 reworded" "$(git rev-parse HEAD~1)"
_ST_EQ "a reword is announced once" "$(grep -c '^EVENT' "$HB_LOG")" "1"
if [ "$HB_CONFIG" = "true" ]; then
	_ST_EQ "to a hook defined in config as well" "$(grep -c '^CONFIG' "$HB_CLOG")" "1"
fi
# An edit amends outside any rebase, then replays – both in the one announcement
git reset -q --hard "$HB_TIP"
: > "$HB_LOG"
_ST_RUN "$(git rev-parse HEAD~2)"
local HB_WT=$(echo "$OUT" | sed -n 's/^git-edit: paused – edit [0-9a-f]* in \([^;]*\);.*/\1/p')
printf 'hb2 edited\n' > "${HB_WT:-$ST_NO_WT}/hb2.txt"
_ST_RUN --continue
_ST_EQ "an edit is announced once" "$(grep -c '^EVENT' "$HB_LOG")" "1"
_ST_EQ "with the edited commit and the two it replayed" "$(grep -vc '^EVENT' "$HB_LOG")" "3"
# A drop lists what it replayed, never what it dropped
git reset -q --hard "$HB_TIP"
: > "$HB_LOG"
_ST_RUN -d HEAD~1
_ST_EQ "a drop is announced once" "$(grep -c '^EVENT' "$HB_LOG")" "1"
_ST_EQ "listing only the commit it replayed" "$(grep -vc '^EVENT' "$HB_LOG")" "1"
# A resolution finished by hand with a plain `git rebase --continue` let git announce it already
git reset -q --hard "$HB_TIP"
printf 'hb2 changed later\n' > hb2.txt && git commit -qam "HB 5 touches hb2"
: > "$HB_LOG"
printf 'hb2 folded\n' > hb2.txt && git add hb2.txt
_ST_RUN --amend-into="$HB_TARGET" -- hb2.txt
_ST_EQ "a fold into a file a later commit touches pauses" "$RC" "2"
local HB_CWT=$(echo "$OUT" | sed -n 's/^git-edit: conflict – resolve in \([^ ]*\).*/\1/p' | head -1)
local HB_STEPS=0
while [ -n "$HB_CWT" ] && [ -d "$(git -C "$HB_CWT" rev-parse --git-path rebase-merge 2>/dev/null)" ] && [ $HB_STEPS -lt 10 ]; do
	git -C "$HB_CWT" checkout --theirs -- hb2.txt 2>/dev/null
	git -C "$HB_CWT" add hb2.txt
	GIT_EDITOR=true git -C "$HB_CWT" rebase --continue >/dev/null 2>&1
	HB_STEPS=$((HB_STEPS + 1))
done
local HB_BY_GIT=$(grep -c '^EVENT' "$HB_LOG")
_ST_CHECK "git announced the rebase finished by hand itself" test "$HB_BY_GIT" -gt 0
_ST_RUN --continue
_ST_EQ "and git edit then applies it" "$RC" "0"
_ST_EQ "without announcing it a second time" "$(grep -c '^EVENT' "$HB_LOG")" "$HB_BY_GIT"
# One intermediate step typed in by hand, the rest through git edit – git never finished that
# run, so the landing still announces the rebase
git reset -q --hard "$HB_TIP"
printf 'hb2 changed later\n' > hb2.txt && git commit -qam "HB 5 touches hb2"
: > "$HB_LOG"
printf 'hb2 folded\n' > hb2.txt && git add hb2.txt
_ST_RUN --amend-into="$HB_TARGET" -- hb2.txt
HB_CWT=$(echo "$OUT" | sed -n 's/^git-edit: conflict – resolve in \([^ ]*\).*/\1/p' | head -1)
git -C "${HB_CWT:-$ST_NO_WT}" checkout --theirs -- hb2.txt 2>/dev/null
git -C "${HB_CWT:-$ST_NO_WT}" add hb2.txt 2>/dev/null
GIT_EDITOR=true git -C "${HB_CWT:-$ST_NO_WT}" rebase --continue >/dev/null 2>&1
_ST_CHECK "one step typed in by hand leaves the rebase mid-way" test -d "$(git -C "${HB_CWT:-$ST_NO_WT}" rev-parse --git-path rebase-merge 2>/dev/null)"
git -C "${HB_CWT:-$ST_NO_WT}" checkout --theirs -- hb2.txt 2>/dev/null
git -C "${HB_CWT:-$ST_NO_WT}" add hb2.txt 2>/dev/null
_ST_RUN --continue
_ST_EQ "and git edit finishes it" "$RC" "0"
_ST_EQ "announcing the rebase once all the same" "$(grep -c '^EVENT rebase' "$HB_LOG")" "1"
# A reword ahead of the fold keeps its map across conflict pauses, which memory alone would lose
git reset -q --hard "$HB_TIP"
printf 'hb2 changed later\n' > hb2.txt && git commit -qam "HB 5 touches hb2"
git notes add -m "HB fold note" "$HB_TARGET"
: > "$HB_LOG"
printf 'hb2 folded\n' > hb2.txt && git add hb2.txt
_ST_RUN --amend-into="$HB_TARGET" --text="HB 2, folded and reworded" -- hb2.txt
_ST_EQ "a reworded fold into a file a later commit touches pauses" "$RC" "2"
local HB_RWT
HB_STEPS=0
while [ "$RC" = "2" ] && [ $HB_STEPS -lt 5 ]; do
	HB_RWT=$(echo "$OUT" | sed -n 's/^git-edit: conflict – resolve in \([^ ]*\).*/\1/p' | head -1)
	[ -z "$HB_RWT" ] && break
	git -C "$HB_RWT" checkout --theirs -- hb2.txt 2>/dev/null
	git -C "$HB_RWT" add hb2.txt
	_ST_RUN --continue
	HB_STEPS=$((HB_STEPS + 1))
done
_ST_EQ "and resolved through git edit, applies" "$RC" "0"
_ST_EQ "announced once" "$(grep -c '^EVENT' "$HB_LOG")" "1"
_ST_EQ "with the target's note carried to its final commit" \
	"$(git log --format=%H | while read s; do git notes show $s 2>/dev/null; done | grep -c '^HB fold note$')" "1"
# Two runs overlapping in one repo, on two branches – the first held in its verify until the
# second has landed – announce their own rewrites, as one fixed capture file let the second
# discard the first run's list, so the first landed unannounced
git reset -q --hard "$HB_TIP"
git branch -f hb-side "$(git rev-parse HEAD~3)"
git worktree add -q "$TMP/hb-side" hb-side
printf 'hs1\n' > "$TMP/hb-side/hs1.txt" && git -C "$TMP/hb-side" add hs1.txt && git -C "$TMP/hb-side" commit -qm "HS 1"
printf 'hs2\n' > "$TMP/hb-side/hs2.txt" && git -C "$TMP/hb-side" add hs2.txt && git -C "$TMP/hb-side" commit -qm "HS 2"
local HB_SIDE_TIP=$(git -C "$TMP/hb-side" rev-parse HEAD)
: > "$HB_LOG"
rm -f "$TMP/hb-a-waiting" "$TMP/hb-b-done"
printf 'hb2 folded\n' > hb2.txt && git add hb2.txt
GIT_EDIT_NO_AUTO_OPEN=1 "$SELF" --amend-into="$HB_TARGET" --verify="touch $TMP/hb-a-waiting; i=0; while [ ! -f $TMP/hb-b-done ] && [ \$i -lt 1200 ]; do sleep 0.1; i=\$((i+1)); done" -- hb2.txt </dev/null > "$TMP/hb-a.out" 2>&1 &
local HB_APID=$!
HB_STEPS=0
while [ ! -f "$TMP/hb-a-waiting" ] && kill -0 $HB_APID 2>/dev/null && [ $HB_STEPS -lt 1200 ]; do sleep 0.1; HB_STEPS=$((HB_STEPS + 1)); done
printf 'hs1 folded\n' > "$TMP/hb-side/hs1.txt" && git -C "$TMP/hb-side" add hs1.txt
cd "$TMP/hb-side"
_ST_RUN --amend-into=HEAD~1 -- hs1.txt
cd "$TMP/repo"
touch "$TMP/hb-b-done"
wait $HB_APID
_ST_EQ "a run landing while another sits in its verify applies" "$RC" "0"
_ST_CHECK "and the run it overtook lands too" grep -q '^git-edit: ok' "$TMP/hb-a.out"
_ST_EQ "each announced once" "$(grep -c '^EVENT' "$HB_LOG")" "2"
local HB_OLD HB_MAIN_N=0 HB_SIDE_N=0
for HB_OLD in $(grep -v '^EVENT' "$HB_LOG" | cut -d' ' -f1); do
	if git merge-base --is-ancestor "$HB_OLD" "$HB_TIP" 2>/dev/null; then
		HB_MAIN_N=$((HB_MAIN_N + 1))
	elif git merge-base --is-ancestor "$HB_OLD" "$HB_SIDE_TIP" 2>/dev/null; then
		HB_SIDE_N=$((HB_SIDE_N + 1))
	fi
done
_ST_EQ "listing the three commits the fold on main replaced" "$HB_MAIN_N" "3"
_ST_EQ "and the two the fold on the side branch replaced" "$HB_SIDE_N" "2"
git worktree remove --force "$TMP/hb-side"
git branch -qD hb-side
# Armed, the capture steps count toward git's own step numbers – a pause must still number the
# picks alone and hide those steps, and the final step must still resolve itself
git reset -q --hard "$HB_TIP"
printf 'hbmv-base\n' > hbmv.txt && git add hbmv.txt && git commit -qm "HBMV base"
printf 'hbmv-base\nhbmv-A\n' > hbmv.txt && git add hbmv.txt && git commit -qm "HBMV A"
local HBMV_A=$(git rev-parse HEAD)
printf 'hbmv-base\nhbmv-B\nhbmv-A\n' > hbmv.txt && git add hbmv.txt && git commit -qm "HBMV B"
local HBMV_B=$(git rev-parse HEAD)
: > "$HB_LOG"
_ST_RUN --move="$HBMV_A" --after="$HBMV_B"
_ST_EQ "an armed swap of abutting commits pauses on its first step" "$RC" "2"
_ST_OUT_HAS "numbered among the picks alone" 'Step 1/2 rebuilds a state that never existed'
_ST_OUT_LACKS "listing no capture step among the remaining ones" 'git-edit-capture'
local HBMV_WT=$(echo "$OUT" | sed -n 's/.*resolve in \([^ ]*\) .*/\1/p' | tail -1)
printf 'hbmv-base\nhbmv-B\n' > "${HBMV_WT:-$ST_NO_WT}/hbmv.txt" && git -C "$HBMV_WT" add hbmv.txt
_ST_RUN --continue
_ST_EQ "and its final step still resolves itself" "$RC" "0"
_ST_OUT_HAS "as it does unarmed" 'Final step auto-resolved'
_ST_EQ "the swap announced once" "$(grep -c '^EVENT' "$HB_LOG")" "1"
# With nothing consuming rewrites, nothing is held back
rm -f "$HB_HOOKS/post-rewrite" "$HB_HOOKS/pre-rebase"
git config --unset notes.rewriteRef
git config --unset-all hook.hbrecorder.event
git config --unset hook.hbrecorder.command
git reset -q --hard "$HB_TIP"
printf 'hb2 folded\n' > hb2.txt && git add hb2.txt
_ST_RUN --amend-into="$HB_TARGET" -- hb2.txt
_ST_EQ "with no hook and no notes to carry, a fold applies" "$RC" "0"
_ST_OUT_LACKS "untouched by the hold-back" 'captureRewrites'
git reset -q --hard
