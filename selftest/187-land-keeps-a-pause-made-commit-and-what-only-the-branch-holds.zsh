# What a land leaves where, said as it is:
# • A commit made in a catch-up land's pause stays the branch's own, landing back with it, while
#   the replay's copies stay the target's – and the resume counts the two apart
# • Commits a --base leaves out below it, held by the target in no form, keep the branch as it
#   is wherever it is checked out – no move or deletion offered – while one the target held and
#   dropped leaves the move onto the copies offered
# • The raw undo moves the ref alone, and the step `--status` names for the re-synced entries puts
#   those back as printed, a no-op before the undo, stopping whole on a peer's staging – where the
#   land could not bring the checkout along
_ST_SCENARIO "\e[1;96m[187] --land keeps a pause-made commit, and names what only the branch holds\e[0m"
local KP_WT KP_P KP_S KP_U
# Prints the step after <lead> in `OUT`, its color codes cut
_KP_STEP () {
	local S=$(print -r -- "$OUT" | sed -n "s/^.*$1//p" | head -1)
	print -r -- "${S%%$'\e'*}"
}

# A catch-up of main into feat pauses on a conflict, and the caller commits a fix of feat's own
# there besides the resolution – the resume counts the pick and that commit apart
_ST_PZ_NEW kp1
print -l l1 l2 l3 > f.txt && git add f.txt && git commit -qm "KP1 base"
git worktree add -q -b feat "$TMP/kp1-wt" main 2>/dev/null
print -l la l2 l3 > "$TMP/kp1-wt/f.txt" && git -C "$TMP/kp1-wt" commit -qam "KP1 A"
print -l lm l2 l3 > f.txt && git commit -qam "KP1 M1"
cd "$TMP/kp1-wt"
_ST_RUN --land=main
KP_WT=$(_ST_PZ_WT)
_ST_RESOLVE "${KP_WT:-$ST_NO_WT}" f.txt $'la-lm\nl2\nl3'
print -r -- fix > "${KP_WT:-$ST_NO_WT}/x.txt" && git -C "${KP_WT:-$ST_NO_WT}" add x.txt && git -C "${KP_WT:-$ST_NO_WT}" commit -qm "KP1 X made in the pause" -- x.txt >/dev/null
_ST_RUN --continue
_ST_EQ "a commit made in a catch-up's pause lands on the branch" "$RC:$(git log --format=%s feat | tr '\n' '|')" "0:KP1 M1|KP1 X made in the pause|KP1 A|KP1 base|"
_ST_OUT_HAS "the resume counts the pick and that commit apart" 'Landed 1 of 1 commit(s) from main onto feat, and 1 commit(s) made in its pause:$'
# Landed back, that commit is feat's own, while the copy of main's commit stays main's
cd "$TMP/pz-kp1"
_ST_RUN --land=feat --dry-run
_ST_OUT_HAS "the land back replays feat's own and the pause-made commit" "replaying 2 from 'feat' on top:"
_ST_OUT_HAS "the copy alone stays main's by the land's record" "^1 commit(s) are main's own by a land's record"
_ST_RUN --land=feat
_ST_RESOLVE "$(_ST_PZ_WT)" f.txt $'la-lm\nl2\nl3'
_ST_RUN --continue
_ST_EQ "and lands it, the copy left out" "$RC:$(git log --format=%s main | tr '\n' '|')" "0:KP1 X made in the pause|KP1 A|KP1 M1|KP1 base|"
_ST_OUT_HAS "the resume naming the copy left out" "^1 commit(s) left out as main's own by a land's record"
git worktree remove --force "$TMP/kp1-wt"

# A resolution committed by hand at the stop takes a date of its own, the pick's message kept – it
# is main's copy all the same, left out of the land back once main dropped what it copies
_ST_PZ_NEW kp1b
print -l l1 l2 l3 > f.txt && git add f.txt && git commit -qm "KP1B base"
git worktree add -q -b feat "$TMP/kp1b-wt" main 2>/dev/null
print -l la l2 l3 > "$TMP/kp1b-wt/f.txt" && git -C "$TMP/kp1b-wt" commit -qam "KP1B A"
print -l lm l2 l3 > f.txt && git commit -qam "KP1B M1" && KP_P=$(git rev-parse HEAD)
print -r -- t > t.txt && git add t.txt && git commit -qm "KP1B T"
cd "$TMP/kp1b-wt"
_ST_RUN --land=main
KP_WT=$(_ST_PZ_WT)
_ST_RESOLVE "${KP_WT:-$ST_NO_WT}" f.txt $'la-lm\nl2\nl3'
GIT_AUTHOR_DATE="@1900000000 +0000" git -C "${KP_WT:-$ST_NO_WT}" commit -qm "KP1B M1" >/dev/null 2>&1
_ST_RUN --continue
_ST_EQ "a resolution committed by hand lands on the branch" "$RC:$(git log --format=%s feat | tr '\n' '|')" "0:KP1B T|KP1B M1|KP1B A|KP1B base|"
cd "$TMP/pz-kp1b"
_ST_RUN -d "$KP_P"
_ST_RUN --land=feat --dry-run
_ST_OUT_HAS "its message marks it main's copy, out of the land back" "^2 commit(s) are main's own by a land's record"
_ST_OUT_HAS "which replays feat's own alone" "replaying 1 from 'feat' on top:"
git worktree remove --force "$TMP/kp1b-wt"

# Commits a --base leaves out below it, held by main in no form: the branch keeps them, checked out
# nowhere, in a linked worktree or in the main worktree – no move or deletion offered
for KP_S in nowhere linked primary; do
	_ST_PZ_NEW "kp2-$KP_S"
	_ST_PZ_C f.txt base "KP2 base"
	git branch feat
	_ST_PZ_C p.txt p1 "KP2 P peer"
	KP_P=$(git rev-parse HEAD)
	git checkout -q feat && _ST_PZ_C x.txt x1 "KP2 X own" && git cherry-pick "$KP_P" >/dev/null && KP_P=$(git rev-parse HEAD) && _ST_PZ_C c.txt c1 "KP2 C own"
	git checkout -q main
	case $KP_S in
		(linked) git worktree add -q "$TMP/kp2-wt" feat ;;
		(primary) git checkout -q feat && git worktree add -q "$TMP/kp2-wt" main && cd "$TMP/kp2-wt" ;;
	esac
	_ST_RUN --land=feat --base="$KP_P"
	_ST_EQ "a --base land leaving own commits below it lands what follows ($KP_S)" "$RC:$(git log --format=%s main | tr '\n' '|')" "0:KP2 C own|KP2 P peer|KP2 base|"
	_ST_OUT_HAS "naming the branch the only one holding them ($KP_S)" "^Branch feat keeps 1 commit(s) main holds in no form – left out below --base – and is the only branch holding them"
	_ST_OUT_HAS "naming the commit ($KP_S)" '^  [0-9a-f]* KP2 X own'
	_ST_OUT_LACKS "offering no move or deletion of it ($KP_S)" 'git branch -f\|git branch -D\|reset --keep\|land it there:'
	if [ "$KP_S" = nowhere ]; then
		KP_U=$(_KP_STEP 'Land them once they should go: ')
		_ST_EQ "the land it names is the plain one" "$KP_U" "git edit --land=feat"
		_ST_RUN --land=feat
		_ST_OUT_HAS "which names that commit as the branch's own" '^  [0-9a-f]* KP2 X own'
	fi
	cd "$TMP/pz-kp2-$KP_S"
	[ "$KP_S" = nowhere ] || git worktree remove --force "$TMP/kp2-wt"
done
# Every commit past it on main already, the branch is still not offered for deletion
_ST_PZ_NEW kp3
_ST_PZ_C f.txt base "KP3 base"
git branch feat
_ST_PZ_C p.txt p1 "KP3 P peer"
KP_P=$(git rev-parse HEAD)
git checkout -q feat && _ST_PZ_C x.txt x1 "KP3 X own" && git cherry-pick "$KP_P" >/dev/null && KP_P=$(git rev-parse HEAD) && _ST_PZ_C c.txt c1 "KP3 C own"
git checkout -q main && git cherry-pick feat >/dev/null
_ST_RUN --land=feat --base="$KP_P"
_ST_OUT_HAS "a --base land finding the rest landed ends already landed" 'git-edit: ok – refs/heads/main unchanged, already landed$'
_ST_OUT_HAS "still naming the branch the only one holding what it left out" "^Branch feat keeps 1 commit(s) main holds in no form – left out below --base"
_ST_OUT_LACKS "never offering its deletion" 'git branch -D'
# Resumed past a conflict, the land says so too, by its pause's record
_ST_PZ_NEW kp4
_ST_PZ_C f.txt base "KP4 base"
git branch feat
_ST_PZ_C p.txt p1 "KP4 P peer"
KP_P=$(git rev-parse HEAD)
git checkout -q feat && _ST_PZ_C x.txt x1 "KP4 X own" && git cherry-pick "$KP_P" >/dev/null && KP_P=$(git rev-parse HEAD) && _ST_PZ_C f.txt c1 "KP4 C own"
git checkout -q main && _ST_PZ_C f.txt m1 "KP4 M1"
_ST_RUN --land=feat --base="$KP_P"
_ST_RESOLVE "$(_ST_PZ_WT)" f.txt $'m1\nc1'
_ST_RUN --continue
_ST_EQ "a resumed --base land lands what follows" "$RC:$(git log --format=%s main | tr '\n' '|')" "0:KP4 C own|KP4 M1|KP4 P peer|KP4 base|"
_ST_OUT_HAS "naming the branch the only one holding what it left out" "^Branch feat keeps 1 commit(s) main holds in no form – left out below --base"
_ST_OUT_LACKS "offering no move or deletion of it" 'git branch -f\|git branch -D'
# A commit main held and dropped is no branch's own – below a --base, the move stays offered
_ST_PZ_NEW kp5
_ST_PZ_C f.txt base "KP5 base"
_ST_PZ_C d.txt d1 "KP5 D dropped"
git branch feat
_ST_PZ_C p.txt p1 "KP5 P peer"
KP_P=$(git rev-parse HEAD)
git checkout -q feat && git cherry-pick "$KP_P" >/dev/null && KP_P=$(git rev-parse HEAD) && _ST_PZ_C c.txt c1 "KP5 C own"
git checkout -q main
_ST_RUN -d HEAD~1
_ST_RUN --land=feat --base="$KP_P"
_ST_EQ "a --base past what main dropped lands what follows" "$RC:$(git log --format=%s main | tr '\n' '|')" "0:KP5 C own|KP5 P peer|KP5 base|"
_ST_OUT_HAS "the move onto the copies offered still" 'point it at those (git branch -f feat '
_ST_OUT_LACKS "no commit named as the branch's alone" 'is the only branch holding them'

# The raw undo moves the ref alone, and where the land could not bring the checkout along, the step
# `--status` names for the re-synced entries puts them back as printed – a peer's staged file kept
# throughout
_ST_PZ_NEW kp6
_ST_PZ_C f.txt base "KP6 base"
git worktree add -q -b feat "$TMP/kp6-wt" main 2>/dev/null
( cd "$TMP/kp6-wt" && _ST_PZ_C a.txt a1 "KP6 A" && print -r -- f2 >> f.txt && git commit -qam "KP6 F2" )
print -r -- peer > peer.txt && git add peer.txt
_ST_RUN_UNSYNCED --land=feat
_ST_RUN --status
KP_U=$(_KP_STEP 'Undo: git edit --undo  (or, the ref alone: ')
KP_U=${KP_U%)}
KP_S=$(_KP_STEP 'After the raw undo, re-sync the entries [^:]*: ')
_ST_EQ "the raw undo said to move the ref alone" "${KP_U%% -m *}" "git update-ref"
_ST_EQ "the step --status names for the re-synced entries" "$KP_S" "git diff-index --cached --exit-code --name-only $(git rev-parse --short=12 HEAD) -- a.txt f.txt && git restore --staged -- a.txt f.txt"
eval "${KP_S:-false}" >/dev/null
_ST_EQ "run before the undo, the step changes nothing" "$?:$(git status --short | LC_ALL=C sort | tr '\n' '|')" "0: D a.txt| M f.txt|A  peer.txt|"
eval "${KP_U:-false}" && eval "${KP_S:-false}" >/dev/null
_ST_EQ "after the raw undo it leaves nothing of the land staged, the peer's file kept" "$?:$(git log --format=%s | tr '\n' '|'):$(git status --short | LC_ALL=C sort | tr '\n' '|')" "0:KP6 base|:A  peer.txt|"
_ST_RUN --land=feat
_ST_EQ "and the land lands again" "$RC:$(git log --format=%s | tr '\n' '|')" "0:KP6 F2|KP6 A|KP6 base|"
# A peer staging one of those paths since stops the step whole, naming the path, its staging kept
_ST_PZ_NEW kp7
_ST_PZ_C f.txt base "KP7 base"
git worktree add -q -b feat "$TMP/kp7-wt" main 2>/dev/null
( cd "$TMP/kp7-wt" && _ST_PZ_C a.txt a1 "KP7 A" && print -r -- f2 >> f.txt && git commit -qam "KP7 F2" )
_ST_RUN_UNSYNCED --land=feat
_ST_RUN --status
KP_U=$(_KP_STEP 'Undo: git edit --undo  (or, the ref alone: ')
KP_U=${KP_U%)}
KP_S=$(_KP_STEP 'After the raw undo, re-sync the entries [^:]*: ')
print -r -- peer-f > f.txt && git add f.txt
eval "${KP_U:-false}"
KP_P=$(eval "${KP_S:-true}" 2>&1)
_ST_EQ "a peer's staging on one of them stops the step, naming it" "$?:$KP_P" "1:f.txt"
_ST_EQ "its staging kept, nothing reset" "$(git show :f.txt):$(git ls-files a.txt)" "peer-f:a.txt"
git worktree remove --force "$TMP/kp7-wt"
# An undo prints no raw undo of its own, so no step for one either
cd "$TMP/pz-kp6"
_ST_RUN --undo
_ST_OUT_HAS "an undo brings the checkout back itself" 'Your checkout came along'
_ST_OUT_LACKS "naming no step after a raw undo" 'After the raw undo'
git worktree remove --force "$TMP/kp6-wt"
cd "$TMP/repo"
