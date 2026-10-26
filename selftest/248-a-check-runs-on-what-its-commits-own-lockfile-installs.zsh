# A link holds what the checkout installed from its own lockfile, so a check at a commit locking
# something else fails on that alone – an install named for the path runs each check on its own
_ST_SCENARIO "\e[1;96m[248] a check runs on what its commit's own lockfile installs\e[0m"
local DP_WT DP_STAMP
_ST_PZ_NEW dp
_ST_PZ_C .gitignore deps "DP ignore"
_ST_PZ_C deps.lock v1 "DP lock"
_ST_PZ_C dp_a.txt a "DP work"
_ST_PZ_C deps.lock v2 "DP upgrade"
_ST_PZ_C dp_b.txt b "DP later"
# The checkout's install, from the tip's lockfile, and a check needing the version a commit locks
mkdir deps && cp deps.lock deps/version
printf '#!/bin/sh\ncmp -s deps/version deps.lock && test ! -f dp_bad.txt\n' > "$TMP/dp_check.sh"
chmod +x "$TMP/dp_check.sh"
git config edit.verifyCmd "$TMP/dp_check.sh"
git config --add edit.worktreeLink deps
print -r -- a2 > dp_a.txt && git add dp_a.txt
_ST_RUN --amend-into="$(git rev-parse ':/DP work')" -- dp_a.txt
_ST_EQ "on the link alone, a fold below the upgrade pauses" "$RC" "2"
_ST_OUT_HAS "its check failing as the replaced commit's does" 'replaces fails the same check'
_ST_RUN --abort
git config edit.deps.lockfile deps.lock
# Named in the stamp before it runs, and creating its directory as one already there would let it
# – so a link left standing would take its write
git config edit.deps.installCmd "grep -qx deps \"\$(git rev-parse --path-format=absolute --git-path git-edit-installed)\" && mkdir -p deps && cp deps.lock deps/version && echo x >>'$TMP/dp_installs'"
: > "$TMP/dp_installs"
_ST_RUN --amend-into="$(git rev-parse ':/DP work')" -- dp_a.txt
_ST_EQ "with its install named, the fold lands" "$RC" "0"
_ST_OUT_HAS "checking the folded commit on its own" "Installed deps from [0-9a-f]*'s deps.lock in [0-9]*s"
_ST_EQ "and the tip on the link, as its lockfile matches" "$(wc -l < "$TMP/dp_installs" | tr -d ' ')" "1"
_ST_EQ "never writing through the link" "$(cat deps/version)" "v2"
_ST_CHECK "into the checkout's own install" sh -c 'test -d deps && test ! -L deps'
# One install serves every commit locking the same
: > "$TMP/dp_installs"
print -r -- c > dp_c.txt && git add dp_c.txt
_ST_RUN --verify-span --amend-into="$(git rev-parse ':/DP lock')" -- dp_c.txt
_ST_EQ "a span fold lands" "$RC" "0"
_ST_OUT_HAS "checking each commit" 'Verified 4 commit(s)'
_ST_EQ "on one install for the two locking v1" "$(wc -l < "$TMP/dp_installs" | tr -d ' ')" "1"
# A failure of the commit's own is placed on its own install too, and its pause holds the link
print -r -- bad > dp_bad.txt && git add dp_bad.txt
_ST_RUN --amend-into="$(git rev-parse ':/DP work')" -- dp_bad.txt
_ST_EQ "a fold breaking the check pauses" "$RC" "2"
_ST_OUT_HAS "naming the failing commit" '^  failing: [0-9a-f]* DP work$'
_ST_OUT_LACKS "never disowned, as the commit it replaces passes on its own install" 'fails the same check'
DP_WT=$(_ST_PZ_WT)
_ST_CHECK "the pause holds the link again" sh -c "test -L '${DP_WT:-$ST_NO_WT}/deps'"
# A run cut off midway leaves an install its stamp names, which the resume clears
DP_STAMP=$(git -C "${DP_WT:-$ST_NO_WT}" rev-parse --path-format=absolute --git-path git-edit-installed 2>/dev/null)
rm -f "${DP_WT:-$ST_NO_WT}/deps" && mkdir "${DP_WT:-$ST_NO_WT}/deps" && print -r -- v9 > "${DP_WT:-$ST_NO_WT}/deps/version"
print -r -- deps > "${DP_STAMP:-$ST_NO_WT}"
_ST_RUN --continue
_ST_EQ "the resume pauses on the same failure" "$RC" "2"
_ST_CHECK "the leftover install having given way to the link" sh -c "test -L '${DP_WT:-$ST_NO_WT}/deps' && test ! -e '${DP_STAMP:-$ST_NO_WT}'"
_ST_RUN --abort
git restore --staged dp_bad.txt && rm -f dp_bad.txt
# An install failing leaves the check on the link, said once for its lockfile
git config edit.deps.installCmd 'exit 3'
print -r -- d > dp_d.txt && git add dp_d.txt
_ST_RUN --amend-into="$(git rev-parse ':/DP work')" -- dp_d.txt
_ST_EQ "a failing install leaves the fold paused on the link" "$RC" "2"
_ST_OUT_HAS "naming the install" "Could not install deps from [0-9a-f]*'s deps.lock (exit 3) – checking on the link instead"
_ST_EQ "once for its lockfile" "$(grep -c 'Could not install' <<<"$OUT")" "1"
_ST_RUN --abort
git restore --staged dp_d.txt && rm -f dp_d.txt
# A link lagging its own lockfile fails where the commit's own install passes
# – read for every path, so one checked after it that locks nothing leaves that rerun standing
git config edit.deps.installCmd "mkdir -p deps && cp deps.lock deps/version"
git config --add edit.worktreeLink dp_two
git config edit.dp_two.lockfile dp_two.lock
git config edit.dp_two.installCmd true
print -r -- v0 > deps/version
print -r -- b2 > dp_b.txt && git add dp_b.txt
_ST_RUN --amend-into="$(git rev-parse HEAD)" -- dp_b.txt
_ST_EQ "a check failing on a lagging link lands on its own install" "$RC" "0"
_ST_OUT_HAS "saying the link's install may lag" 'passed on its own install after failing on the link to .*deps – that install may lag its lockfile'
print -r -- v2 > deps/version
# A commit locking nothing keeps the link, nothing installed for it
printf '#!/bin/sh\ntest ! -f deps.lock || cmp -s deps/version deps.lock\n' > "$TMP/dp_check0.sh"
chmod +x "$TMP/dp_check0.sh"
print -r -- e > dp_e.txt && git add dp_e.txt
_ST_RUN --verify="$TMP/dp_check0.sh" --amend-into="$(git rev-parse ':/DP ignore')" -- dp_e.txt
_ST_EQ "a fold into a commit locking nothing lands" "$RC" "0"
_ST_OUT_HAS "checking it" '^Verified '
_ST_OUT_LACKS "installing nothing" 'Installed '
_ST_OUT_LACKS "nor trying to" 'Could not install'
# An install the ignore rules miss would reach the amend, so the path keeps its link instead
git config --add edit.worktreeLink dp_more
git config edit.dp_more.lockfile deps.lock
git config edit.dp_more.installCmd 'mkdir dp_more && cp deps.lock dp_more/version'
print -r -- a4 > dp_a.txt && git add dp_a.txt
_ST_RUN --amend-into="$(git rev-parse ':/DP work')" -- dp_a.txt
_ST_EQ "a fold with an unignored install lands" "$RC" "0"
_ST_OUT_HAS "taking that install back out" "Could not install dp_more from [0-9a-f]*'s deps.lock (it is not ignored there, so an amend would commit it)"
_ST_EQ "once for the whole gate" "$(grep -c 'Could not install dp_more' <<<"$OUT")" "1"
_ST_CHECK "so it never reaches a commit" sh -c '! git log --format= --name-only | grep -q dp_more'
# A path whose removal could reach past the worktree is never installed,
# and a setting no install can come of is named rather than read as one in force
mkdir -p "$TMP/tmp/dp_outside" && print -r -- keep > "$TMP/tmp/dp_outside/f"
git config --add edit.worktreeLink ../dp_outside
git config edit.../dp_outside.lockfile deps.lock
git config edit.../dp_outside.installCmd 'true'
git config --add edit.worktreeLink dp_half
git config edit.dp_half.installCmd 'true'
git config edit.dp_unlinked.lockfile deps.lock
git config edit.dp_unlinked.installCmd 'true'
print -r -- a5 > dp_a.txt && git add dp_a.txt
_ST_RUN --amend-into="$(git rev-parse ':/DP work')" -- dp_a.txt
_ST_OUT_HAS "a path leaving the worktree is refused" 'Not installing ../dp_outside – an install replaces what stands there'
_ST_EQ "and what lies there stays" "$(cat "$TMP/tmp/dp_outside/f" 2>/dev/null)" "keep"
_ST_OUT_HAS "a command with no lockfile is named" 'Not installing dp_half – edit.dp_half.installCmd needs edit.dp_half.lockfile beside it'
_ST_OUT_HAS "as is a path no link names" 'Not installing dp_unlinked – edit.worktreeLink does not name it'
_ST_EQ "once" "$(grep -c 'Not installing dp_unlinked' <<<"$OUT")" "1"
# A nested path installs where it sits, from every lockfile beside it, and the link's are read where
# it resolves – a checkout's path may link on to another's install, whatever its own lockfile says
_ST_PZ_NEW dq
_ST_PZ_C .gitignore sub/deps "DQ ignore"
mkdir sub && print -r -- e1 > sub/extra.lock && git add sub/extra.lock
_ST_PZ_C sub/deps.lock v1 "DQ lock"
_ST_PZ_C dq_a.txt a "DQ work"
_ST_PZ_C sub/deps.lock v2 "DQ upgrade"
_ST_PZ_C dq_b.txt b "DQ later"
mkdir -p "$TMP/dq_store/deps" && print -r -- v2 > "$TMP/dq_store/deps/version"
print -r -- v2 > "$TMP/dq_store/deps.lock" && print -r -- e1 > "$TMP/dq_store/extra.lock"
ln -s "$TMP/dq_store/deps" sub/deps && print -r -- v3 > sub/deps.lock
printf '#!/bin/sh\ncmp -s sub/deps/version sub/deps.lock\n' > "$TMP/dq_check.sh"
chmod +x "$TMP/dq_check.sh"
git config edit.verifyCmd "$TMP/dq_check.sh"
git config --add edit.worktreeLink sub/deps
git config --add edit.sub/deps.lockfile deps.lock
git config --add edit.sub/deps.lockfile extra.lock
git config edit.sub/deps.installCmd "mkdir -p deps && cp deps.lock deps/version && echo x >>'$TMP/dq_installs'"
: > "$TMP/dq_installs"
print -r -- a2 > dq_a.txt && git add dq_a.txt
_ST_RUN --amend-into="$(git rev-parse ':/DQ work')" -- dq_a.txt
_ST_EQ "a fold below a nested path's upgrade lands" "$RC" "0"
_ST_EQ "on one install, the tip on the link its resolved lockfiles match" "$(wc -l < "$TMP/dq_installs" | tr -d ' ')" "1"
print -r -- e0 > "$TMP/dq_store/extra.lock"
: > "$TMP/dq_installs"
print -r -- a3 > dq_a.txt && git add dq_a.txt
_ST_RUN --amend-into="$(git rev-parse ':/DQ work')" -- dq_a.txt
_ST_EQ "every lockfile counts, so one differing installs the tip too" "$RC:$(wc -l < "$TMP/dq_installs" | tr -d ' ')" "0:2"
cd "$TMP/repo"
