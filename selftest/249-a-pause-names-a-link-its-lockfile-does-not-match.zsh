# A pause leaves its worktree on the link, so where the worktree locks something else a check run
# there fails on that alone – said with the pause, as the gate's own checks install what they lock
_ST_SCENARIO "\e[1;96m[249] a pause names a link its worktree's lockfile does not match\e[0m"
_ST_PZ_NEW pn
_ST_PZ_C .gitignore deps "PN ignore"
print -r -- x > pn_a.txt && git add pn_a.txt
_ST_PZ_C deps.lock v1 "PN lock"
_ST_PZ_C pn_a.txt y "PN work"
_ST_PZ_C deps.lock v2 "PN upgrade"
_ST_PZ_C pn_b.txt b "PN later"
mkdir deps && cp deps.lock deps/version
git config --add edit.worktreeLink deps
git config edit.deps.lockfile deps.lock
git config edit.deps.installCmd "mkdir -p deps && cp deps.lock deps/version"
_ST_RUN "$(git rev-parse ':/PN work')"
_ST_OUT_HAS "an edit pause below the upgrade" 'paused – edit'
_ST_OUT_HAS "names the link its worktree's lockfile does not match" "Checks run here get deps from .*/pz-pn/deps, installed from another deps.lock than this worktree's – a failure can be that alone, and .* run here would reach through the link into it$"
# An install run there would go through the link, and running one is the obvious fix to reach for
_ST_OUT_HAS "naming the install command that would" '`mkdir -p deps && cp deps.lock deps/version` run here'
_ST_RUN --abort
_ST_RUN "$(git rev-parse ':/PN later')"
_ST_OUT_HAS "one at the tip" 'paused – edit'
_ST_OUT_LACKS "has nothing to say of a link installed from its own lockfile" 'Checks run'
_ST_RUN --abort
# A conflict stop reads the lockfile its worktree holds, and with a gate says what it does
git config edit.verifyCmd true
print -r -- z > pn_a.txt && git add pn_a.txt
_ST_RUN --amend-into="$(git rev-parse ':/PN lock')" -- pn_a.txt
_ST_EQ "a fold conflicting below the upgrade stops" "$RC" "2"
_ST_OUT_HAS "naming the link there too, and the gate's own installs" "than this worktree's – a failure can be that alone, and .* run here would reach through the link into it, while the gate at --continue installs what its commits lock$"
_ST_RUN --abort
# A run declining the gate still names it, as a plain `--continue` runs it
_ST_RUN --no-verify --amend-into="$(git rev-parse ':/PN lock')" -- pn_a.txt
_ST_EQ "the same fold declining its gate stops too" "$RC" "2"
_ST_OUT_HAS "naming the gate --continue runs" 'while the gate at --continue installs what its commits lock$'
_ST_RUN --abort
git restore --staged pn_a.txt && git checkout -- pn_a.txt
# A verify pause names it for the commit that failed, which a caller inspects by checking it out
printf '#!/bin/sh\ncmp -s deps/version deps.lock && test ! -f pn_bad.txt\n' > "$TMP/pn_check.sh"
chmod +x "$TMP/pn_check.sh"
git config edit.verifyCmd "$TMP/pn_check.sh"
print -r -- bad > pn_bad.txt && git add pn_bad.txt
_ST_RUN --amend-into="$(git rev-parse ':/PN work')" -- pn_bad.txt
_ST_EQ "a fold breaking the check pauses" "$RC" "2"
_ST_OUT_HAS "naming the link a check of the failing commit gets" "Checks run there at [0-9a-f]* get deps from .*, installed from another deps.lock than that commit's – a failure can be that alone, and .* run there would reach through the link into it$"
_ST_RUN --abort
git restore --staged pn_bad.txt && rm -f pn_bad.txt
cd "$TMP/repo"
