# --exec lands a history built before the run only on the tip --base names

# The CAS covers only the command's own run, so `reset --hard` to a history built earlier
# would drop whatever reached the branch meanwhile, with `ok`
# The harness clock dates its commits before any run, so a `commit-tree` here is built elsewhere
_ST_SCENARIO "\e[1;96m[89] exec lands a pre-built history only on the tip --base names\e[0m"
git reset -q --hard
echo "pb" > pb.txt && git add pb.txt && git commit -qm "PB one"
echo "pb two" >> pb.txt && git commit -qam "PB two"
local PB_BASE=$(git rev-parse HEAD)
local PB_BUILT=$(git commit-tree "$(git rev-parse HEAD^{tree})" -p HEAD^ -m "PB two, rebuilt")
echo "pc" > pc.txt && git add pc.txt && git commit -qm "PB peer"
local PB_PEER=$(git rev-parse HEAD)
_ST_RUN --exec -- git reset -q --hard "$PB_BUILT"
_ST_EQ "a pre-built history without --base refuses" "$RC" "1"
_ST_OUT_HAS "saying it carries commits made before the run" 'carrying 1 commit(s) made before this run'
_ST_OUT_HAS "naming the commit it would drop" '^    [0-9a-f]\{7,\} PB peer$'
_ST_EQ "which stays" "$(git rev-parse HEAD)" "$PB_PEER"
# A commit made on top in the run dates the tip anew – what it sits on still counts
_ST_RUN --exec -- sh -c "git reset -q --hard $PB_BUILT && git commit -q --allow-empty -m 'PB on top'"
_ST_EQ "nor with a fresh commit on top" "$RC" "1"
_ST_OUT_HAS "counting the one below it" 'carrying 1 commit(s) made before this run'
_ST_EQ "the peer's commit still there" "$(git rev-parse HEAD)" "$PB_PEER"
_ST_RUN --exec --base="$PB_BASE" -- git reset -q --hard "$PB_BUILT"
_ST_EQ "--base at a tip the branch moved past refuses" "$RC" "1"
_ST_OUT_HAS "naming what reached it since" '^    [0-9a-f]\{7,\} PB peer$'
_ST_OUT_HAS "and the rebase that carries it over" "git rebase --onto <your history> ${PB_BASE:0:12}"
# That rebase builds inside the run, so it lands – the rebuilt history, the peer's commit on top
_ST_RUN --exec --base="$PB_PEER" -- git rebase -q --onto "$PB_BUILT" "$PB_BASE"
_ST_EQ "the carry-over lands" "$RC" "0"
_ST_EQ "keeping the peer's commit" "$(git log --format=%s -3 | tr '\n' '|')" "PB peer|PB two, rebuilt|PB one|"
local PB_TIP=$(git rev-parse HEAD)
local PB_BUILT2=$(git commit-tree "$(git rev-parse HEAD^{tree})" -p HEAD^ -m "PB peer, rebuilt")
_ST_RUN --exec --base="$PB_TIP" -- git reset -q --hard "$PB_BUILT2"
_ST_EQ "pinned to the unmoved tip, a pre-built history lands" "$RC" "0"
_ST_EQ "as built" "$(git rev-parse HEAD)" "$PB_BUILT2"
# A descendant drops nothing, however old, while a rewind drops the tip, whoever made it
local PB_AHEAD=$(git commit-tree "$(git rev-parse HEAD^{tree})" -p HEAD -m "PB ahead")
_ST_RUN --exec -- git reset -q --hard "$PB_AHEAD"
_ST_EQ "a pre-built descendant lands without --base" "$RC" "0"
_ST_RUN --exec -- git reset -q --hard HEAD~1
_ST_EQ "a rewind refuses without --base" "$RC" "1"
_ST_OUT_HAS "pointing a drop at -d" 'git edit -d <sha>'
_ST_EQ "leaving the tip" "$(git rev-parse HEAD)" "$PB_AHEAD"
# A dry run builds in isolation, skips even a standing gate, moves nothing, and hands over
# the landing pinned to its base – which then lands what it built
git config edit.verifyCmd false
_ST_RUN --exec --dry-run -- git commit -q --amend --allow-empty -m "PB ahead, amended"
_ST_EQ "a dry run completes under a failing gate" "$RC" "0"
_ST_OUT_HAS "saying it neither verified nor applied" 'neither verified nor applied'
_ST_OUT_LACKS "running no gate" '# verify'
_ST_EQ "moving nothing" "$(git rev-parse HEAD)" "$PB_AHEAD"
_ST_OUT_HAS "its trailer naming what it built on what" "^git-edit: ok – dry run built [0-9a-f]\{40,64\} on $PB_AHEAD, refs/heads/[^ ]* unchanged$"
local PB_DRY=$(print -r -- "$OUT" | sed -n 's/^git-edit: ok – dry run built \([0-9a-f]*\) on .*/\1/p')
_ST_OUT_HAS "and the pinned landing" "git edit --exec --base=${PB_AHEAD:0:12} -- git reset -q --hard $PB_DRY"
git config --unset edit.verifyCmd
_ST_RUN --exec --base="${PB_AHEAD:0:12}" -- git reset -q --hard "$PB_DRY"
_ST_EQ "that landing lands the dry run's result" "$RC" "0"
_ST_EQ "as built" "$(git log --format=%s -1)" "PB ahead, amended"
# A base the branch was rewritten past has nothing since to list, so it says that instead
_ST_RUN --exec --base="$PB_BASE" -- true
_ST_EQ "--base the branch was rewritten past refuses" "$RC" "1"
_ST_OUT_HAS "saying it was rewritten" 'was rewritten since --base'
_ST_RUN --exec --base=0000000 -- true
_ST_EQ "--base naming no commit refuses" "$RC" "1"
_ST_OUT_HAS "saying so" 'names no commit here'
# A dry run let past the pushed guard hands the override on to its landing
git update-ref refs/remotes/pbguard/main HEAD
_ST_RUN --allow-pushed --exec --dry-run -- git commit -q --amend --allow-empty -m "PB pushed, amended"
_ST_EQ "a dry run over a pushed tip runs under --allow-pushed" "$RC" "0"
_ST_OUT_HAS "its landing carrying the override" 'git edit --exec --base=[0-9a-f]\{12\} --allow-pushed -- git reset'
git update-ref -d refs/remotes/pbguard/main
# Only a SHA pins, and both flags belong to --exec alone
_ST_RUN --exec --base=HEAD -- true
_ST_EQ "--base given a name refuses" "$RC" "1"
_ST_OUT_HAS "asking for the SHA" 'takes the SHA of the tip'
_ST_RUN --base="$PB_TIP" -M --text="PB nope" HEAD
_ST_EQ "--base without --exec refuses" "$RC" "1"
_ST_OUT_HAS "saying where it applies" '--base only applies to --exec'
_ST_RUN --dry-run -M --text="PB nope" HEAD
_ST_EQ "--dry-run without --exec refuses" "$RC" "1"
_ST_OUT_HAS "saying so too" '--dry-run only applies to --exec'
_ST_RUN --exec --dry-run --verify=true -- true
_ST_EQ "--dry-run with a gate refuses" "$RC" "1"
_ST_OUT_HAS "since it never verifies" '--dry-run never verifies'
# An opt-out given to a dry run would be dropped from its landing line, so it belongs there too
_ST_RUN --exec --dry-run --no-verify -- true
_ST_EQ "--dry-run with --no-verify refuses" "$RC" "1"
_ST_OUT_HAS "pointing verify flags at the landing" 'pass verify flags there'
_ST_RUN --exec --dry-run --no-verify-span -- true
_ST_EQ "and with --no-verify-span" "$RC" "1"
_ST_EQ "none of them moving anything" "$(git log --format=%s -1)" "PB ahead, amended"
