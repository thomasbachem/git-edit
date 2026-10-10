# A checkout differing from the new tip only in mode is named apart
# A file moved into place drops its executable bit, and the reconcile listed the file just
# committed among "uncommitted edits" – inviting a commit of "the rest", which lands the loss
_ST_SCENARIO "\e[1;96m[90] a checkout differing only in mode is named apart\e[0m"
git reset -q --hard
printf 'mx\n' > mx.sh && printf 'my\n' > my.sh && chmod +x mx.sh my.sh && printf 'mz\n' > mz.txt
git add mx.sh my.sh mz.txt && git commit -qm "MX to change"
# The change made in the checkout first, a mode drifting on the way – a temp file moved in
# loses the bit, a stray chmod adds one
printf 'mx changed\n' > mx.tmp && mv mx.tmp mx.sh
printf 'mz changed\n' > mz.txt && chmod +x mz.txt
_ST_RUN --exec -- sh -c 'printf "mx changed\n" > mx.sh && printf "mz changed\n" > mz.txt && git commit -qam "MX changed"'
_ST_EQ "the exec lands" "$RC" "0"
_ST_EQ "keeping the committed modes" "$(git ls-tree HEAD -- mx.sh mz.txt | awk '{print $1}' | tr '\n' ' ')" "100755 100644 "
_ST_OUT_HAS "names a lost bit by both modes" 'only their mode differing.*mx\.sh (100644 here, 100755 committed)'
_ST_OUT_HAS "and a gained one" 'only their mode differing.*mz\.txt (100755 here, 100644 committed)'
_ST_OUT_HAS "offering the chmods that match the commit" 'Match the committed mode: chmod -- +x mx\.sh && chmod -- -x mz\.txt'
_ST_OUT_LACKS "never among uncommitted edits" 'Worktree files left alone\|edits merged onto'
_ST_OUT_LACKS "nor claiming the checkout current" 'your checkout is current'
_ST_CHECK "the content untouched" sh -c "test \"\$(cat mx.sh)\" = 'mx changed'"
# A real edit on top stays among the edits, whatever its mode
printf 'my changed\nlocal wip\n' > my.tmp && mv my.tmp my.sh
_ST_RUN --exec -- sh -c 'printf "my changed\n" > my.sh && git commit -qam "MY changed"'
_ST_EQ "an exec under a real edit lands too" "$RC" "0"
_ST_EQ "that edit stays, uncommitted" "$(sed -n 2p my.sh):$(git status --porcelain -- my.sh)" "local wip: M my.sh"
_ST_OUT_LACKS "not named as a mode difference" 'only their mode differing'
git reset -q --hard
