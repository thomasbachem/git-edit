# An `--exec` rebase lands however git logs its steps – a reword or edit below the tip, a `--root`
# reword – while a result built below the tip it started on needs `--base` however it was built:
# plumbing's `commit-tree`, a squash by hand, a root of its own, a rebase replaying nothing
_ST_SCENARIO "\e[1;96m[161] exec rebases land however logged, a build below the tip needs --base however made\e[0m"
local EB_T EB_B EB_C
# A rebase's own fast-forward past an unchanged pick is one of its steps, not a reset below the tip
_ST_PZ_NEW eb1
_ST_PZ_C a.txt a "EB1 a" && _ST_PZ_C b.txt b "EB1 b" && _ST_PZ_C c.txt c "EB1 mine"
EB_C=$(git rev-parse HEAD)
_ST_PZ_C d.txt d "EB1 peer d"
EB_T=$(git rev-parse HEAD)
_ST_RUN --exec -- env GIT_SEQUENCE_EDITOR="sed -i.bak 1s/^pick/reword/" GIT_EDITOR="sed -i.bak 1s/mine/mine2/" git rebase -q -i HEAD~2
_ST_EQ "a rebase rewording a commit below the tip lands" "${RC}:$(git log --format=%s | tr '\n' '|')" "0:EB1 peer d|EB1 mine2|EB1 b|EB1 a|"
git reset -q --hard "$EB_T"
_ST_RUN --exec -- sh -c 'GIT_SEQUENCE_EDITOR="sed -i.bak 1s/^pick/edit/" git rebase -q -i HEAD~2 && git commit -q --amend -m "EB1 mine3" && git rebase --continue >/dev/null'
_ST_EQ "as does one amending a commit below the tip at its stop" "${RC}:$(git log --format=%s | tr '\n' '|')" "0:EB1 peer d|EB1 mine3|EB1 b|EB1 a|"
git reset -q --hard "$EB_T"
_ST_RUN --exec -- env GIT_SEQUENCE_EDITOR="sed -i.bak 1s/^pick/reword/" GIT_EDITOR="sed -i.bak 1s/a/a2/" git rebase -q -i --root
_ST_EQ "and a --root reword" "${RC}:$(git log --format=%s | tr '\n' '|')" "0:EB1 peer d|EB1 mine|EB1 b|EB1 a2|"
git reset -q --hard "$EB_T"
_ST_RUN --exec -- git rebase -q --apply --onto HEAD~2 HEAD~1
_ST_EQ "and an --apply rebase dropping what it was told to" "${RC}:$(git log --format=%s | tr '\n' '|')" "0:EB1 peer d|EB1 b|EB1 a|"
git reset -q --hard "$EB_T"
# While a reset below the tip at a rebase's stop is no step of the rebase's own
_ST_RUN --exec -- sh -c 'GIT_SEQUENCE_EDITOR="sed -i.bak 1s/^pick/edit/" git rebase -q -i HEAD~2 && git reset -q --hard HEAD~1 && git rebase --continue >/dev/null'
_ST_EQ "a reset below the tip at a rebase's stop still refuses" "${RC}:$(git rev-parse HEAD)" "1:$EB_T"
_ST_OUT_HAS "naming where HEAD went" 'below the tip this run started on'
# A result built below the tip – by plumbing, by hand or as a root of its own – drops what sat
# above as surely, so needs `--base`, named in full
EB_B=$(git rev-parse HEAD~2)
_ST_RUN --exec -- sh -c 'git update-ref HEAD "$(git commit-tree -p HEAD~2 -m "EB2 built below" HEAD~2^{tree})"'
_ST_EQ "plumbing's commit-tree below the tip, moved to by update-ref, refuses" "${RC}:$(git rev-parse HEAD)" "1:$EB_T"
_ST_OUT_HAS "naming what it was built on" "was built on ${EB_B:0:7}, below the tip this run started on"
_ST_OUT_HAS "and the peer's commit it would drop" '^    [0-9a-f]\{7,\} EB1 peer d$'
_ST_OUT_HAS "and the --base that lands it" "git edit --exec --base=${EB_T:0:12} -- <the same command>"
git reset -q --hard "$EB_T"
_ST_RUN --exec -- sh -c 'git reset -q --hard "$(git commit-tree -p HEAD~3 -m "EB2 squashed by hand" HEAD^{tree})"'
_ST_EQ "as does a squash by hand through commit-tree and reset --hard" "${RC}:$(git rev-parse HEAD)" "1:$EB_T"
git reset -q --hard "$EB_T"
_ST_RUN --exec -- sh -c 'git update-ref HEAD "$(git commit-tree -p HEAD~2 -m "EB2 x" HEAD~2^{tree})" && git commit -q --allow-empty -m "EB2 on it"'
_ST_EQ "and a commit made on such a build" "${RC}:$(git rev-parse HEAD)" "1:$EB_T"
git reset -q --hard "$EB_T"
_ST_RUN --exec -- sh -c 'git checkout -q --orphan eb2 && git commit -qm "EB2 all in one" && git checkout -q --detach && git branch -q -D eb2'
_ST_EQ "and an orphan commit" "${RC}:$(git rev-parse HEAD)" "1:$EB_T"
_ST_OUT_HAS "named as a root of its own" 'is a root commit, built on nothing the tip this run started on holds'
git reset -q --hard "$EB_T"
_ST_RUN --exec -- sh -c 'git rebase -q --onto HEAD~2 HEAD && git commit -q --allow-empty -m "EB2 after"'
_ST_EQ "and a rebase replaying nothing, a reset in disguise" "${RC}:$(git rev-parse HEAD)" "1:$EB_T"
_ST_OUT_HAS "naming where it went" "HEAD went back to ${EB_B:0:7}, below the tip"
git reset -q --hard "$EB_T"
_ST_RUN --exec --base="$EB_T" -- sh -c 'git update-ref HEAD "$(git commit-tree -p HEAD~2 -m "EB2 built below" HEAD~2^{tree})"'
_ST_EQ "while --base at the tip lands a build below it" "${RC}:$(git log --format=%s | tr '\n' '|')" "0:EB2 built below|EB1 b|EB1 a|"
git reset -q --hard "$EB_T"
_ST_RUN --exec --base="$EB_T" -- sh -c 'git checkout -q --orphan eb2 && git commit -qm "EB2 all in one" && git checkout -q --detach && git branch -q -D eb2'
_ST_EQ "and an orphan commit with it" "${RC}:$(git log --format=%s | tr '\n' '|')" "0:EB2 all in one|"
git reset -q --hard "$EB_T"
# And what builds on the tip or names what it drops lands as ever: plumbing on the tip, a side
# built in the run and merged after an amend, a rebase onto one
_ST_RUN --exec -- sh -c 'git reset -q --hard "$(git commit-tree -p HEAD -m "EB3 on top" HEAD^{tree})"'
_ST_EQ "commit-tree on the tip lands" "${RC}:$(git log -1 --format=%s)" "0:EB3 on top"
git reset -q --hard "$EB_T"
_ST_RUN --exec -- sh -c 'git commit -q --amend -m "EB3 peer d2" && Y=$(git rev-parse HEAD) && git checkout -q HEAD~2 && git commit -q --allow-empty -m "EB3 side" && S=$(git rev-parse HEAD) && git checkout -q "$Y" && git merge -q --no-edit "$S"'
_ST_EQ "as does a side built in the run, merged after an amend" "${RC}:$(git log -1 --format=%p | wc -w | tr -d ' '):$(git log --first-parent --format=%s HEAD~1 | tr '\n' '|')" "0:2:EB3 peer d2|EB1 mine|EB1 b|EB1 a|"
git reset -q --hard "$EB_T"
_ST_RUN --exec -- sh -c 'git checkout -q HEAD~2 && git commit -q --allow-empty -m "EB3 side" && S=$(git rev-parse HEAD) && git checkout -q - && git rebase -q "$S"'
_ST_EQ "and a rebase onto it" "${RC}:$(git log --format=%s | tr '\n' '|')" "0:EB1 peer d|EB1 mine|EB3 side|EB1 b|EB1 a|"
cd "$TMP/repo"
