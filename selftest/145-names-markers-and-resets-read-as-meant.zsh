# A path named with pattern characters folds or splits as that path, a diff3 conflict's base
# marker counts as a marker, and an `--exec` building below the tip it started on needs `--base`
_ST_SCENARIO "\e[1;96m[145] a bracketed name is its path, a base marker a marker, a build below the tip needs --base\e[0m"
local NM_T NM_C NM_I NM_WT
# A fold named `app/[id].tsx` takes that file alone, a peer's staged `app/i.tsx` left staged
_ST_PZ_NEW nm1
mkdir app && print 1 > 'app/[id].tsx' && print 1 > app/i.tsx && print 1 > app/j.tsx
git add app && git commit -qm "NM1 app" && _ST_PZ_C t.txt t "NM1 tip"
print mine >> 'app/[id].tsx' && print peer >> app/i.tsx && git add app
_ST_RUN --amend-into="$(git rev-parse HEAD~1)" -- 'app/[id].tsx'
_ST_EQ "a bracketed name folds that file alone" "${RC}:$(git show --name-only --format= HEAD~1 | tr '\n' ' ')" "0:app/[id].tsx app/i.tsx app/j.tsx "
_ST_EQ "into the target as staged" "$(git show HEAD~1:'app/[id].tsx' | tail -1)" "mine"
_ST_EQ "the peer's file left staged" "$(git diff --cached --name-only)" "app/i.tsx"
# While a pattern meant as one still matches as one
print mine2 >> app/j.tsx && git add app/j.tsx
_ST_RUN --amend-into="$(git rev-parse HEAD~1)" -- 'app/[ij].tsx'
_ST_EQ "a pattern naming no path folds what it matches" "${RC}:$(git diff --cached --name-only | wc -l | tr -d ' ')" "0:0"
# A split named the same way takes that file alone into its first half
_ST_PZ_NEW nm2
_ST_PZ_C base.txt b "NM2 base"
mkdir app && print 1 > 'app/[id].tsx' && print 1 > app/i.tsx && git add app && git commit -qm "NM2 both"
_ST_RUN --split=HEAD --text "NM2 id alone" -- 'app/[id].tsx'
_ST_EQ "a split by a bracketed name takes that file alone" "${RC}:$(git show --name-only --format= HEAD~1 | tr '\n' ' ')" "0:app/[id].tsx "
# A resolution keeping a diff3 conflict's base marker line is refused like any other marker
_ST_PZ_NEW nm3
printf '%s\n' a b c > f.txt && git add f.txt && git commit -qm "NM3 base"
printf '%s\n' a B2 c > f.txt && git commit -qam "NM3 later"
_ST_PZ_C t.txt t "NM3 tip"
git config merge.conflictStyle diff3
printf '%s\n' a B1 c > f.txt && git add f.txt
_ST_RUN --amend-into="$(git rev-parse HEAD~2)" -- f.txt
NM_WT=$(_ST_PZ_WT)
_ST_RESOLVE "$NM_WT" f.txt $'a\nB1\n||||||| 1234567\nc'
_ST_RUN --continue
_ST_OUT_HAS "a resolution keeping a diff3 base marker is refused" 'still contains conflict markers'
_ST_RUN --abort
git config --unset merge.conflictStyle
git reset -q --hard
# An `--exec` going back below its start tip and building there drops what sat above – a peer's
# commit landed meanwhile – so it needs `--base`, however it got there
_ST_PZ_NEW nm4
_ST_PZ_C a.txt a "NM4 a" && _ST_PZ_C b.txt b "NM4 b" && _ST_PZ_C c.txt c "NM4 mine"
NM_C=$(git rev-parse HEAD)
_ST_PZ_C d.txt d "NM4 peer d"
NM_T=$(git rev-parse HEAD)
_ST_RUN --exec -- sh -c "git reset -q --hard $NM_C && echo e > e.txt && git add e.txt && git commit -qm 'NM4 e'"
_ST_EQ "a reset below the start tip plus a commit refuses" "${RC}:$(git rev-parse HEAD)" "1:$NM_T"
_ST_OUT_HAS "naming where HEAD went" "HEAD went back to ${NM_C:0:7}, below the tip"
_ST_OUT_HAS "and the peer's commit it would drop" 'NM4 peer d'
git config core.logAllRefUpdates false
_ST_RUN --exec -- sh -c "git update-ref HEAD $NM_C && git reset -q --hard && echo e > e.txt && git add e.txt && git commit -qm 'NM4 e'"
git config --unset core.logAllRefUpdates
_ST_EQ "as does plumbing's update-ref, reflogs off in the repo" "${RC}:$(git rev-parse HEAD)" "1:$NM_T"
_ST_RUN --exec -- sh -c 'git reset -q --soft HEAD~2 && git commit -qm "NM4 squashed by hand"'
_ST_EQ "a squash by hand needs --base too" "${RC}:$(git rev-parse HEAD)" "1:$NM_T"
_ST_RUN --exec --base="$NM_T" -- sh -c 'git reset -q --soft HEAD~2 && git commit -qm "NM4 squashed by hand"'
_ST_EQ "and lands with --base naming the tip it saw" "${RC}:$(git log --format=%s | tr '\n' '|')" "0:NM4 squashed by hand|NM4 b|NM4 a|"
_ST_RUN --exec -- env GIT_SEQUENCE_EDITOR="sed -i.bak 1d" git rebase -q -i HEAD~2
_ST_EQ "while a rebase dropping a commit it lists needs none" "${RC}:$(git log --format=%s | tr '\n' '|')" "0:NM4 squashed by hand|NM4 a|"
cd "$TMP/repo"
