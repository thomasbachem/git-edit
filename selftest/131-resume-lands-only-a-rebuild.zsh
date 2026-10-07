_ST_SCENARIO "\e[1;96m[131] a resume lands only a rebuild that finished, with what was made there\e[0m"
local EG_WT EG_PID EG_T
# A split's own checks run apart from its authoring – a failure there restores nothing over it
_ST_PZ_NEW eg1
printf 'one\n' > f && git add f && git commit -qm "EG base"
printf 'one\ntwo\n' > f && print -r -- z > z && git add f z && git commit -qm "EG both"
_ST_RUN --split=HEAD --text "EG first"
EG_WT=$(_ST_PZ_WT)
printf 'one\n' > "${EG_WT:-$ST_NO_WT}/f"
_ST_RUN --continue --verify='grep -q two f'
_ST_EQ "a split's failed check keeps the authored first part" "$RC:$(<"${EG_WT:-$ST_NO_WT}/f")" "1:one"
_ST_RUN --no-verify --continue
_ST_EQ "which lands as authored" "$RC:$(git show HEAD~1:f | tr '\n' ' '):$(git show HEAD:f | tr '\n' ' ')" "0:one :one two "
# A rebase quit by hand in the worktree lands nothing, nor one aborted there
_ST_PZ_NEW eg2
_ST_PZ_C f.txt $'1\n2\n3' "EG2 c1"
_ST_PZ_C f.txt $'1\n2x\n3' "EG2 c2"
_ST_PZ_C f.txt $'1\n2xy\n3' "EG2 c3"
_ST_PZ_C g.txt g "EG2 c4"
EG_T=$(git rev-parse HEAD)
_ST_RUN -d -y HEAD~2
git -C "$(_ST_PZ_WT)" rebase --quit >/dev/null 2>&1
_ST_RUN --continue
_ST_EQ "a drop quit by hand in its worktree lands nothing" "$RC:$(git rev-parse HEAD)" "1:$EG_T"
_ST_RUN --abort
_ST_RUN -d -y HEAD~2
EG_WT=$(_ST_PZ_WT)
_ST_RESOLVE "$EG_WT" f.txt $'1\n2y\n3'
GIT_EDITOR=true git -C "${EG_WT:-$ST_NO_WT}" rebase --continue >/dev/null 2>&1
_ST_RUN --continue
_ST_EQ "one finished by hand there lands" "$RC:$(git log --format=%s | tr '\n' ' ')" "0:EG2 c4 EG2 c3 EG2 c1 "
EG_T=$(git rev-parse HEAD)
_ST_PZ_C f.txt $'1\n2z\n3' "EG2 c5"
_ST_PZ_C f.txt $'1\n2zz\n3' "EG2 c6"
EG_T=$(git rev-parse HEAD)
_ST_RUN -d -y HEAD~1
git -C "$(_ST_PZ_WT)" rebase --abort >/dev/null 2>&1
_ST_RUN --continue
_ST_EQ "a drop aborted by hand there lands nothing" "$RC:$(git rev-parse HEAD)" "1:$EG_T"
_ST_OUT_HAS "saying it was aborted" 'aborted by hand – nothing was applied'
_ST_RUN --abort
# Markers committed at a stop are caught as staged ones are
_ST_RUN -d -y HEAD~1
EG_WT=$(_ST_PZ_WT)
git -C "${EG_WT:-$ST_NO_WT}" add -A && git -C "${EG_WT:-$ST_NO_WT}" commit -qm "EG2 c6"
_ST_RUN --continue
_ST_EQ "markers committed at a stop refuse" "$RC:$(git rev-parse HEAD)" "2:$EG_T"
_ST_OUT_HAS "naming them" 'still contains conflict markers'
_ST_RUN --abort
# A resumed step keeps its message whole, `#`-led lines and all
_ST_PZ_NEW eg3
_ST_PZ_C f.txt $'1\n2\n3' "EG3 c1"
_ST_PZ_C f.txt $'1\n2x\n3' "EG3 c2"
print -r -- $'1\n2xy\n3' > f.txt && git add f.txt && printf 'EG3 c3\n\n#42 is fixed here\n' > "$TMP/eg3-msg" && git commit -q -F "$TMP/eg3-msg"
_ST_RUN -d -y HEAD~1
_ST_RESOLVE "$(_ST_PZ_WT)" f.txt $'1\n2y\n3'
_ST_RUN --continue
_ST_EQ "a resumed step keeps its #-led body line" "$RC:$(git log -1 --format=%b)" "0:#42 is fixed here"
# Commits made on a gate pause's built result are refused, never discarded
_ST_PZ_NEW eg4
_ST_PZ_C a.txt a "EG4 a" && _ST_PZ_C b.txt b "EG4 b" && _ST_PZ_C c.txt c "EG4 c"
EG_T=$(git rev-parse HEAD)
_ST_RUN -d -y --verify=false HEAD~1
EG_WT=$(_ST_PZ_WT)
print -r -- fix > "${EG_WT:-$ST_NO_WT}/fix.txt" && git -C "${EG_WT:-$ST_NO_WT}" add fix.txt && git -C "${EG_WT:-$ST_NO_WT}" commit -qm "EG4 fix"
_ST_RUN --no-verify --continue
_ST_EQ "a commit made on the built result refuses" "$RC:$(git rev-parse HEAD)" "1:$EG_T"
_ST_OUT_HAS "naming it" 'EG4 fix'
_ST_RUN --abort
# A gate cut off past an edit's amend is no authoring phase – edits made there refuse
_ST_PZ_NEW eg5
_ST_PZ_C a.txt a "EG5 a" && _ST_PZ_C b.txt b "EG5 b"
EG_T=$(git rev-parse HEAD)
_ST_RUN HEAD~1
EG_WT=$(_ST_PZ_WT)
print -r -- a2 > "${EG_WT:-$ST_NO_WT}/a.txt"
rm -f "$TMP/eg5-in" "$TMP/eg5-go"
GIT_EDIT_NO_AUTO_OPEN=1 "$SELF" --continue --verify="touch $TMP/eg5-in; $TMP/st-hold $TMP/eg5-go" </dev/null >/dev/null 2>&1 &
EG_PID=$!
local -i EG_W=0
until [ -e "$TMP/eg5-in" ] || (( ++EG_W > 1200 )); do sleep 0.1; done
# Released at once, as the run takes the signal only once the check it waits on is done
kill -INT $EG_PID 2>/dev/null
: > "$TMP/eg5-go"
wait $EG_PID 2>/dev/null
_ST_RUN --status
_ST_OUT_HAS "a gate cut off past the amend reads as built, not authoring" 'Past the amend'
print -r -- b2 > "${EG_WT:-$ST_NO_WT}/b.txt"
_ST_RUN --no-verify --continue
_ST_EQ "an edit made there refuses rather than vanish" "$RC:$(git rev-parse HEAD):$(<"${EG_WT:-$ST_NO_WT}/b.txt")" "1:$EG_T:b2"
_ST_RUN --abort
# A gate pause rewritten by a replay onto a moved tip keeps its marks
_ST_RUN HEAD~1
EG_WT=$(_ST_PZ_WT)
print -r -- a3 > "${EG_WT:-$ST_NO_WT}/a.txt"
_ST_RUN --continue --verify=false
_ST_PZ_C p.txt p "EG5 peer"
_ST_RUN --continue
print -r -- b3 > "${EG_WT:-$ST_NO_WT}/b.txt"
_ST_RUN --no-verify --continue
_ST_EQ "an edit at a gate pause after a re-replay refuses" "$RC:$(<"${EG_WT:-$ST_NO_WT}/b.txt")" "1:b3"
_ST_OUT_HAS "as a gate pause's" 'a gate pause has nothing to fold them into'
_ST_RUN --abort
# Commits made by hand on a finished replay are refused where the branch moved, never dropped
_ST_PZ_NEW eg6
_ST_PZ_C f.txt $'1\n2\n3' "EG6 c1"
_ST_PZ_C f.txt $'1\n2b\n3' "EG6 c2"
_ST_RUN HEAD~1
EG_WT=$(_ST_PZ_WT)
print -r -- $'1\n2a\n3' > "${EG_WT:-$ST_NO_WT}/f.txt"
_ST_RUN --continue
_ST_RESOLVE "$EG_WT" f.txt $'1\n2b\n3'
GIT_EDITOR=true git -C "${EG_WT:-$ST_NO_WT}" rebase --continue >/dev/null 2>&1
git -C "${EG_WT:-$ST_NO_WT}" commit -q --allow-empty -m "EG6 extra"
_ST_PZ_C p.txt p "EG6 peer"
EG_T=$(git rev-parse HEAD)
_ST_RUN --continue
_ST_EQ "a hand commit on a finished replay refuses where the branch moved" "$RC:$(git rev-parse HEAD)" "1:$EG_T"
_ST_OUT_HAS "naming it" 'EG6 extra'
_ST_RUN --abort
# A squash cancelling out amends under the hold-back – nothing announced before it lands
_ST_PZ_NEW eg7
_ST_PZ_C a.txt a "EG7 base"
_ST_PZ_C x.txt x "EG7 adds x"
_ST_PZ_C y.txt y "EG7 other"
git rm -q x.txt && git commit -qm "EG7 removes x"
printf '#!/bin/sh\ncat >> "%s/eg7-rewritten"\n' "$TMP" > .git/hooks/post-rewrite && chmod +x .git/hooks/post-rewrite
rm -f "$TMP/eg7-rewritten"
# Apart, so the squash runs as a rebase, its fold amended empty
_ST_RUN -s="$(git rev-parse HEAD~2)" -y --verify=false HEAD
_ST_OUT_HAS "the squashed commits cancel out" 'cancel each other out' 
_ST_RUN --abort
_ST_CHECK "a cancelled-out squash announces no rewrite it never landed" test ! -s "$TMP/eg7-rewritten"
rm -f .git/hooks/post-rewrite
cd "$TMP/repo"
