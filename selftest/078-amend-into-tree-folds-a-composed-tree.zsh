# A fold from a composed tree never reads the shared index
_ST_SCENARIO "\e[1;96m[78] --amend-into --tree folds a composed tree, the shared index untouched\e[0m"
printf 'tf1\n' > tf.txt && chmod +x tf.txt && git add tf.txt && git commit -qm "TF base"
local TF_BASE=$(git rev-parse HEAD)
echo "tf-later" > tf2.txt && git add tf2.txt && git commit -qm "TF later"
# A peer's staging on the very path, with its WIP on top – both must survive the fold
printf 'peer\n' > tf.txt && git add tf.txt && printf 'peer\nwip\n' > tf.txt
# Composed by `_ST_COMPOSE` as a caller would, and handed over as a commit on `HEAD`
local TF_IDX="$TMP/tf-index"
local TF_COMPOSED=$(_ST_COMPOSE tf.txt "tf1-folded")
_ST_RUN --amend-into="$TF_BASE" --tree="$TF_COMPOSED" -- tf.txt
_ST_EQ "a composed tree folds" "$RC" "0"
_ST_EQ "the target carries the composed content" "$(git show "$(git rev-parse HEAD~1):tf.txt")" "tf1-folded"
_ST_EQ "with the mode HEAD had" "$(git ls-tree HEAD -- tf.txt | cut -d' ' -f1)" "100755"
_ST_EQ "the peer's staging is untouched" "$(git show :tf.txt)" "peer"
_ST_OUT_HAS "and named as left alone" 'Index entries left alone.*tf\.txt'
_ST_EQ "the peer's WIP is untouched" "$(tr '\n' '|' < tf.txt)" "peer|wip|"
_ST_OUT_LACKS "nothing reads as staged leftovers" 'Left staged'
# Nothing staged on the path: its index entry, stranded on the pre-op tip, is re-synced
git reset -q --hard
local TF_BASE2=$(git rev-parse HEAD~1)
TF_COMPOSED=$(_ST_COMPOSE tf.txt "tf1-folded-twice")
_ST_RUN --amend-into="$TF_BASE2" --tree="$TF_COMPOSED" -- tf.txt
_ST_EQ "a second composed fold lands" "$RC" "0"
_ST_OUT_HAS "re-syncs the stranded entry" 'Index entries re-synced to the new tip: tf\.txt'
_ST_CHECK "so nothing reads as staged" sh -c "git diff --cached --quiet -- tf.txt"
_ST_OUT_HAS "and names the worktree as stale, with a restore offer" 'git restore --source=HEAD --worktree -- tf\.txt'
# `auto` reads the tree's diff for its blame evidence, as it reads the index's
git reset -q --hard
TF_COMPOSED=$(_ST_COMPOSE tf.txt "tf1-folded-thrice")
_ST_RUN --amend-into=auto --tree="$TF_COMPOSED"
_ST_EQ "auto targets from the tree's diff" "$RC" "0"
_ST_OUT_HAS "naming the commit that owns the line" 'amended: [0-9a-f]* TF base'
# Refusals: a tree composed on a tip that moved since, one matching `HEAD`,
# a bad tree-ish, and `--tree` outside a fold – the target as the fold above left it, as one it
# rewrote is refused before the tree is read
git reset -q --hard
TF_BASE2=$(git rev-parse HEAD~1)
TF_COMPOSED=$(_ST_COMPOSE tf.txt "tf-stale")
echo "tf-moved" > tf3.txt && git add tf3.txt && git commit -qm "TF moved"
_ST_RUN --amend-into="$TF_BASE2" --tree="$TF_COMPOSED" -- tf.txt
_ST_EQ "a tree composed on a moved tip is refused" "$RC" "1"
_ST_OUT_HAS "naming the value as given and both tips" 'tree [0-9a-f]\{7,\} was composed on [0-9a-f]\{7,\}, but HEAD is [0-9a-f]\{7,\} now'
_ST_RUN --amend-into="$TF_BASE2" --tree='HEAD^{tree}' -- tf.txt
_ST_EQ "a tree matching HEAD is refused" "$RC" "1"
_ST_OUT_HAS "as nothing to fold, the value named as given" 'tree HEAD^{tree} differs from HEAD in nothing under tf\.txt'
_ST_RUN --amend-into="$TF_BASE2" --tree=nonsense
_ST_EQ "an unknown tree-ish is refused" "$RC" "1"
_ST_OUT_HAS "by name" 'Unknown <tree-ish>: nonsense'
_ST_RUN --tree='HEAD^{tree}' -M --text="x" HEAD
_ST_EQ "--tree outside --amend-into is refused" "$RC" "1"
_ST_OUT_HAS "naming the mode it belongs to" 'only applies to --amend-into'
# A bare tree folds unpinned, `--text` rewording under the same ref update, and the mode guard
# reads the tree's diff as it reads the index's
TF_COMPOSED=$(_ST_COMPOSE tf.txt "tf1-bare")
_ST_RUN --amend-into="$(git rev-parse HEAD~2)" --tree="$TF_COMPOSED^{tree}" --text="TF base reworded" -- tf.txt
_ST_EQ "a bare tree folds unpinned, --text rewording the target" "$RC" "0"
_ST_EQ "which carries both" "$(git log -1 --format=%s HEAD~2)|$(git show HEAD~2:tf.txt)" "TF base reworded|tf1-bare"
rm -f "$TF_IDX" && GIT_INDEX_FILE=$TF_IDX git read-tree HEAD
GIT_INDEX_FILE=$TF_IDX git update-index --add --cacheinfo "100644,$(printf 'tf-flip\n' | git hash-object -w --stdin),tf.txt"
TF_COMPOSED=$(git commit-tree "$(GIT_INDEX_FILE=$TF_IDX git write-tree)" -p HEAD -m "flip")
_ST_RUN --amend-into="$(git rev-parse HEAD~2)" --tree="$TF_COMPOSED" -- tf.txt
_ST_EQ "a mode flip in the tree is refused" "$RC" "1"
_ST_OUT_HAS "naming it" 'mode change 100755 => 100644 tf\.txt'
# The intended use: the change made in main first and composed from there – the checkout reads
# as current, and with WIP on top the file is named as left alone, the WIP intact
printf 'tf1-main\n' > tf.txt
TF_COMPOSED=$(_ST_COMPOSE tf.txt "tf1-main")
_ST_RUN --amend-into="$(git rev-parse HEAD~2)" --tree="$TF_COMPOSED" -- tf.txt
_ST_EQ "a change made in main first folds" "$RC" "0"
_ST_OUT_HAS "and the checkout reads as current" 'Index re-synced, your checkout is current'
_ST_EQ "with nothing left to show" "$(git status --porcelain -- tf.txt)" ""
printf 'tf1-main2\nwip\n' > tf.txt
TF_COMPOSED=$(_ST_COMPOSE tf.txt "tf1-main2")
_ST_RUN --amend-into="$(git rev-parse HEAD~2)" --tree="$TF_COMPOSED" -- tf.txt
_ST_EQ "with WIP on top it folds too" "$RC" "0"
_ST_OUT_HAS "naming the file as left alone" 'Worktree files left alone.*tf\.txt'
_ST_EQ "the WIP intact, nothing staged" "$(git status --porcelain -- tf.txt)|$(git diff --no-color -- tf.txt | grep -c '^+wip')" " M tf.txt|1"
# A scoped fold takes the named path alone from a tree touching two
git reset -q --hard
TF_COMPOSED=$(_ST_COMPOSE tf.txt "tf1-scoped" tf2.txt "tf2-must-not-land")
_ST_RUN --amend-into="$(git rev-parse HEAD~2)" --tree="$TF_COMPOSED" -- tf.txt
_ST_EQ "a scoped fold takes the named path alone" "$RC" "0"
_ST_EQ "the other left as it was" "$(git show HEAD~2:tf.txt)|$(git show HEAD:tf2.txt)" "tf1-scoped|tf-later"
git reset -q --hard
# A conflicting composed fold pauses and continues like a staged one, reconciling the same way
printf 'c1\n' > tc.txt && git add tc.txt && git commit -qm "TC base"
local TC_BASE=$(git rev-parse HEAD)
printf 'c2\n' > tc.txt && git add tc.txt && git commit -qm "TC later"
TF_COMPOSED=$(_ST_COMPOSE tc.txt "c3")
_ST_RUN --amend-into="$TC_BASE" --tree="$TF_COMPOSED" -- tc.txt
_ST_EQ "a conflicting composed fold pauses" "$RC" "2"
local TC_WT=$(echo "$OUT" | sed -n 's/^git-edit: conflict – resolve in \([^ ]*\).*/\1/p' | head -1)
printf 'c1-folded\n' > "${TC_WT:-$ST_NO_WT}/tc.txt" && git -C "$TC_WT" add tc.txt
_ST_RUN --continue
_ST_EQ "and continues to completion" "$RC" "0"
_ST_EQ "the target carries the resolution" "$(git show "$(git rev-parse HEAD~1):tc.txt")" "c1-folded"
_ST_EQ "the tip the composed content" "$(git show HEAD:tc.txt)" "c3"
_ST_OUT_HAS "and the continue re-syncs the stranded entry" 'Index entries re-synced to the new tip: tc\.txt'
# An --abort names the tree as intact – nothing was staged to be "still staged"
git reset -q --hard
# What an earlier scenario left untracked stays as it was, measured against what is there now
local TC_STATUS=$(git status --porcelain)
TF_COMPOSED=$(_ST_COMPOSE tc.txt "c4")
_ST_RUN --amend-into="$(git rev-parse HEAD~1)" --tree="$TF_COMPOSED" -- tc.txt
_ST_EQ "a second conflicting composed fold pauses" "$RC" "2"
_ST_RUN --abort
_ST_EQ "and aborts" "$RC" "0"
_ST_OUT_HAS "naming the tree as intact" 'the tree is intact, ready to retry'
_ST_EQ "the branch and checkout untouched" "$(git show HEAD:tc.txt)|$(git status --porcelain)" "c3|$TC_STATUS"
git reset -q --hard
