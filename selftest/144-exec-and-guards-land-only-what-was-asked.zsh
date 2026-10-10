# An `--exec` lands only a finished result built on what it found, a placement only what it built,
# a resumed fold only a change, and pushed history stays guarded across a pause, an undo, a commit
# named twice and the environment a caller brings
_ST_SCENARIO "\e[1;96m[144] exec, placement and folds land only what was asked, pushed history guarded throughout\e[0m"
local XG_T XG_C XG_N XG_WT XG_A XG_B XG_S
# A command leaving a rebase stopped partway exits 0 with no result
_ST_PZ_NEW xg1
_ST_PZ_C a.txt a "XG1 a" && _ST_PZ_C b.txt b "XG1 b" && _ST_PZ_C c.txt c "XG1 c" && _ST_PZ_C d.txt d "XG1 d"
XG_T=$(git rev-parse HEAD)
_ST_RUN --exec -- env GIT_SEQUENCE_EDITOR="sed -i.bak 2s/^pick/edit/" git rebase -i --no-ff HEAD~3
_ST_EQ "an exec leaving a rebase stopped lands nothing" "${RC}:$(git rev-parse HEAD)" "1:$XG_T"
_ST_OUT_HAS "naming it" 'rebase-merge left in its worktree'
# A history built on the old tip in the very second the run starts still counts as built before it
# The build is dated just past a second's start, the peer's commit made before it so nothing else
# delays the run – a machine too loaded to start it within that second passes the check untested,
# never fails it
_ST_PZ_C e.txt e "XG1 peer e"
XG_T=$(git rev-parse HEAD)
zmodload zsh/datetime
XG_S=$EPOCHREALTIME
sleep $(( 1.01 - (XG_S - ${XG_S%.*}) ))
XG_N=$(GIT_COMMITTER_DATE="@$EPOCHSECONDS +0000" git commit-tree "HEAD~1^{tree}" -p HEAD~2 -m "XG1 d reworded")
_ST_RUN --exec -- git reset -q --hard "$XG_N"
_ST_EQ "a history built in the run's first second refuses, the peer's commit kept" "${RC}:$(git rev-parse HEAD)" "1:$XG_T"
_ST_OUT_HAS "as made before the run, not only as built below the tip" 'carrying 1 commit(s) made before this run'
# A placement whose replay runs clean but ends on another tree lands nothing
_ST_PZ_NEW xg2
printf '%s\n' b a a c b a > f.txt && git add f.txt && git commit -qm "XG2 anchor"
printf '%s\n' b a a c b a c > f.txt && git commit -qam "XG2 append c"
printf '%s\n' b a a b a > f.txt
XG_T=$(git rev-parse HEAD)
_ST_RUN --commit --text "XG2 drop the c lines" --after=HEAD~1 -- f.txt
_ST_EQ "a placement ending on another tree than built refuses" "${RC}:$(git rev-parse HEAD)" "1:$XG_T"
_ST_OUT_HAS "naming the file it changes" 'no longer ends as it was built – it changes f.txt'
# A dry run's placement conflict holds no pause
git checkout -q -- f.txt
XG_C=$(git rev-parse HEAD)
_ST_RUN --exec --dry-run --before="$XG_C" -- sh -c 'printf "%s\n" X > f.txt && git commit -qam "XG2 edit f"'
_ST_EQ "a dry run's placement conflict refuses, no pause held" "${RC}:$([ -e "$(git rev-parse --git-common-dir)/git-edit-state" ] && echo paused)" "1:"
_ST_OUT_HAS "saying a dry run pauses nothing" 'a dry run pauses nothing'
# A resumed fold resolved to the target's side folds nothing – refused, the staging kept
_ST_PZ_NEW xg3
printf '%s\n' 1 2 3 4 5 > a.txt && git add a.txt && git commit -qm "XG3 a"
_ST_PZ_C b.txt b "XG3 b"
printf '%s\n' 1 2 B 4 5 > a.txt && git commit -qam "XG3 edit a"
XG_T=$(git rev-parse HEAD)
printf '%s\n' 1 2 S 4 5 > a.txt && git add a.txt && printf '%s\n' 1 2 B 4 5 > a.txt
_ST_RUN --amend-into="$(git rev-parse HEAD~2)" -- a.txt
XG_WT=$(_ST_PZ_WT)
_ST_RESOLVE "$XG_WT" a.txt $'1\n2\n3\n4\n5'
_ST_RUN --continue
_ST_EQ "a resumed fold that changes nothing refuses, nothing landed" "${RC}:$(git rev-parse HEAD)" "1:$XG_T"
_ST_OUT_HAS "saying the fold left history unchanged" 'The fold left history unchanged'
_ST_RUN --abort
_ST_EQ "and the abort keeps the staging" "$(git show :a.txt | sed -n 3p)" "S"
git reset -q --hard
# A commit named twice is dropped once and guarded as itself, its pushed self refused – the commits
# made in one second, as an agent's are, where a timestamp sort can't order them
_ST_PZ_NEW xg4
export GIT_COMMITTER_DATE=1700000000 GIT_AUTHOR_DATE=1700000000
_ST_PZ_C base.txt base "XG4 base" && _ST_PZ_C a.txt a "XG4 A" && _ST_PZ_C b.txt b "XG4 B" && _ST_PZ_C c.txt c "XG4 C"
unset GIT_COMMITTER_DATE GIT_AUTHOR_DATE
git init -q --bare "$TMP/xg4.git" && git remote add origin "$TMP/xg4.git" && git push -q origin HEAD~2:refs/heads/main && git fetch -q origin
XG_A=$(git rev-parse ':/XG4 A') XG_B=$(git rev-parse ':/XG4 B') XG_T=$(git rev-parse HEAD)
_ST_RUN -d -y "$XG_A" "$XG_B" "$XG_B"
_ST_EQ "a pushed commit beside one named twice is still refused" "${RC}:$(git rev-parse HEAD)" "1:$XG_T"
_ST_OUT_HAS "as pushed" "Commit ${XG_A:0:7} is already pushed"
_ST_RUN -d -y "$XG_B" "$XG_B"
_ST_EQ "an unpushed one named twice is dropped once" "${RC}:$(git log --format=%s | tr '\n' '|')" "0:XG4 C|XG4 A|XG4 base|"
_ST_RUN --reorder "$XG_A" "$(git rev-parse HEAD)" "$XG_A" --allow-pushed
_ST_OUT_HAS "while --reorder refuses a commit named twice" 'names a commit more than once'
# A pause's landing checks pushed history again – pushed while it waited, it refuses
_ST_PZ_NEW xg5
_ST_PZ_C base.txt base "XG5 base" && _ST_PZ_C a.txt a "XG5 A" && _ST_PZ_C b.txt b "XG5 B"
git init -q --bare "$TMP/xg5.git" && git remote add origin "$TMP/xg5.git" && git push -q origin HEAD~2:refs/heads/main && git fetch -q origin
_ST_RUN "$(git rev-parse ':/XG5 A')"
XG_WT=$(_ST_PZ_WT)
print -r -- edited > "$XG_WT/a.txt" && git -C "$XG_WT" add a.txt
git push -q origin main && git fetch -q origin
XG_T=$(git rev-parse HEAD)
_ST_RUN --continue
_ST_EQ "a resume over commits pushed while it paused refuses" "${RC}:$(git rev-parse HEAD)" "1:$XG_T"
_ST_OUT_HAS "naming the push" 'pushed while this paused'
_ST_RUN --continue --allow-pushed
_ST_EQ "and lands once allowed" "${RC}:$(git show HEAD~1:a.txt)" "0:edited"
# An undo taking pushed commits off the branch refuses, as any rewrite of them does
_ST_PZ_C c.txt c "XG5 C"
git push -q -f origin main && git fetch -q origin
_ST_RUN --exec -- sh -c 'echo d > d.txt && git add d.txt && git commit -qm "XG5 D"'
git push -q origin main && git fetch -q origin
XG_T=$(git rev-parse HEAD)
_ST_RUN --undo
_ST_EQ "an undo taking a pushed commit off refuses" "${RC}:$(git rev-parse HEAD)" "1:$XG_T"
_ST_RUN --undo --allow-pushed
_ST_EQ "and goes through once allowed" "${RC}:$(git log -1 --format=%s)" "0:XG5 C"
# A `GIT_COMMON_DIR` naming another repository refuses, its object dir this one's or not
_ST_PZ_NEW xg6o
_ST_PZ_C o.txt o "XG6 other"
_ST_PZ_NEW xg6
_ST_PZ_C a.txt a "XG6 a" && _ST_PZ_C b.txt b "XG6 b"
XG_T=$(git rev-parse HEAD)
OUT=$(GIT_COMMON_DIR="$TMP/pz-xg6o/.git" GIT_OBJECT_DIRECTORY="$PWD/.git/objects" GIT_EDIT_NO_AUTO_OPEN=1 "$SELF" -M --text "XG6 x" HEAD </dev/null 2>&1)
RC=$?
_ST_EQ "a GIT_COMMON_DIR naming another repository refuses" "${RC}:$(git rev-parse HEAD)" "1:$XG_T"
# An exported `_PT_RAW` changes nothing in what a hint prints
XG_S='a\e[0mb.txt'
print x > "$XG_S" && git add -- "$XG_S" && git commit -qm "XG6 odd" && _ST_PZ_C t.txt t "XG6 top"
OUT=$(_PT_RAW=1 GIT_EDIT_NO_AUTO_OPEN=1 "$SELF" -d -y HEAD~1 </dev/null 2>&1)
_ST_OUT_LACKS "a caller's _PT_RAW leaves a printed name's backslash marked" "literal)ab\.txt"
_ST_OUT_HAS "the report naming the file as it is" 'Taken out of your checkout with the rewrite: a\\e\[0mb\.txt'
cd "$TMP/repo"
