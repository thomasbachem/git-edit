# As `git commit -- <paths>` takes them, composed apart from the shared index – refused where
# another caller's landing would go back out with them
_ST_SCENARIO "\e[1;96m[113] --commit and --whole take files whole from the checkout\e[0m"
export GIT_EDIT_ACTOR=wc-self
printf 'a\nb\nc\nd\ne\nf\ng\nh\n' > wc.txt && printf '#!/bin/sh\n' > wc.sh && chmod +x wc.sh
echo staged > wc-staged.txt && git add wc-staged.txt
_ST_RUN --commit --text "WC add whole files" -- wc.txt wc.sh
_ST_EQ "new files land whole, with no git add" "$RC:$(git log -1 --format=%s):$(git show HEAD:wc.txt | wc -l | tr -d ' ')" "0:WC add whole files:8"
_ST_EQ "an executable one keeps its bit" "$(git ls-tree HEAD -- wc.sh | awk '{print $1}')" "100755"
_ST_EQ "the reflog names it a commit, with its caller" "$(git reflog show -1 --format=%gs "$(git symbolic-ref -q HEAD)")" "git edit: commit [wc-self]"
_ST_OUT_HAS "the run names what it commits" 'Committing 2 whole file(s) on'
_ST_OUT_LACKS "with no internal command shown" '_COMMIT_WHOLE_TREE'
_ST_OUT_HAS "the branch reads as advanced, not rewritten" 'advanced – index re-synced, your checkout is current'
_ST_CHECK "the checkout is clean there" test -z "$(git status --porcelain -- wc.txt wc.sh)"
_ST_EQ "a staged file it was not named stays staged and out" "$(git show :wc-staged.txt):$(git cat-file -e HEAD:wc-staged.txt 2>/dev/null && echo in || echo out)" "staged:out"
git restore --staged -- wc-staged.txt && rm -f wc-staged.txt
export EXEC_LABEL=stray
_ST_RUN --exec -- git commit --allow-empty -qm "WC empty"
unset EXEC_LABEL
_ST_EQ "an EXEC_LABEL in the caller's environment renames no exec run" "$RC:$(git reflog show -1 --format=%gs "$(git symbolic-ref -q HEAD)")" "0:git edit: exec [wc-self]"
_ST_OUT_HAS "nor hides its command, quoted as pasted" "git commit --allow-empty -qm 'WC empty' # (in "
mkdir -p wc-sub && echo inner > wc-sub/in.txt && echo i >> wc.txt && rm wc.sh
cd wc-sub
_ST_RUN --commit --text "WC change, remove, add" -- ../wc.txt ../wc.sh in.txt
cd "$TMP/repo"
_ST_EQ "a change, a removal and an addition land, read from where the caller stands" "$RC:$(git show HEAD:wc.txt | tail -1):$(git cat-file -e HEAD:wc.sh 2>/dev/null && echo kept || echo gone):$(git show HEAD:wc-sub/in.txt)" "0:i:gone:inner"
_ST_CHECK "the checkout is clean there too" test -z "$(git status --porcelain -- wc.txt wc.sh wc-sub)"
mv wc-sub/in.txt wc-sub/moved.txt && ln -s wc.txt wc-link
_ST_RUN --commit --text "WC move and link" -- wc-sub/in.txt wc-sub/moved.txt wc-link
_ST_EQ "a plain mv lands named at both paths, a link as a link" "$RC:$(git cat-file -e HEAD:wc-sub/in.txt 2>/dev/null && echo kept || echo gone):$(git show HEAD:wc-sub/moved.txt):$(git ls-tree HEAD -- wc-link | awk '{print $1}')" "0:gone:inner:120000"
# Refusals, each before anything lands
local WC_TIP=$(git rev-parse HEAD)
_ST_RUN --commit -- wc.txt
_ST_OUT_HAS "a commit without --text refuses" 'needs a message'
_ST_RUN --commit -m "x" -- wc.txt
_ST_OUT_HAS "and one given -m, as git commit takes it, points at --text" 'takes its message as --text'
_ST_RUN --commit --text "x"
_ST_OUT_HAS "and one without files" 'needs the files to take'
_ST_RUN --commit --text "x" -- wc-sub
_ST_OUT_HAS "a directory refuses, naming the files instead" 'is a directory – name its files'
_ST_RUN --commit --text "x" -- wc-nope.txt
_ST_OUT_HAS "a path neither the checkout nor the tip has refuses" 'no such file'
_ST_RUN --commit --text "x" -- ':wc-nope.txt'
_ST_OUT_HAS "and its error keeps a colon-led name whole" '^:wc-nope\.txt: no such file'
_ST_RUN --commit --text "x" -- ../wc-outside.txt
_ST_OUT_HAS "a path outside the repository refuses" 'names no file inside the repository'
echo wc-ignored.txt >> .git/info/exclude && echo x > wc-ignored.txt
_ST_RUN --commit --text "x" -- wc-ignored.txt
_ST_OUT_HAS "an ignored file the tip lacks refuses" 'is ignored'
_ST_RUN --commit --text "x" -- wc.txt
_ST_OUT_HAS "files as the tip has them refuse" 'Nothing to take'
chmod +x wc.txt && echo j >> wc.txt
_ST_RUN --commit --text "x" -- wc.txt
_ST_OUT_HAS "a mode change refuses" 'file-mode change rides along'
_ST_RUN --commit --text "x" --reorder -- wc.txt
_ST_OUT_HAS "--commit takes no other mode beside it" 'cannot be combined'
_ST_RUN --whole -- wc.txt
_ST_OUT_HAS "--whole without --amend-into refuses" 'only applies to --amend-into'
# Where case tells no names apart, a second spelling would land beside the first
local WC_ICASE=$(git config core.ignorecase) WC_BR=$(git symbolic-ref --short HEAD)
git config core.ignorecase true
mkdir -p WC-SUB && echo n > WC-SUB/new.txt
_ST_RUN --commit --text "x" -- WC-SUB/new.txt
_ST_OUT_HAS "a name the tip spells otherwise refuses where case tells none apart" "WC-SUB differs from the tip's directory wc-sub only in case"
echo n > wc-new.txt && echo n > WC-NEW.txt
_ST_RUN --commit --text "x" -- wc-new.txt WC-NEW.txt
_ST_OUT_HAS "as do two names here differing only in case" 'WC-NEW.txt and wc-new.txt differ only in case'
rm -f WC-SUB/new.txt wc-new.txt WC-NEW.txt && rmdir WC-SUB 2>/dev/null
git config core.ignorecase "${WC_ICASE:-false}"
git checkout -q --detach
_ST_RUN --commit --text "x" -- wc.txt
_ST_OUT_HAS "a detached HEAD refuses" 'requires being on a branch'
git checkout -q "$WC_BR"
_ST_EQ "no refusal moved the branch" "$(git rev-parse HEAD)" "$WC_TIP"
_ST_RUN --commit --text "WC take the bit" --allow-mode-change -- wc.txt
_ST_EQ "--allow-mode-change lets it through" "$RC:$(git ls-tree HEAD -- wc.txt | awk '{print $1}')" "0:100755"
# The repo's hooks run on it, and its filters, as `git commit` runs them
local WC_HOOK=$(git rev-parse --git-path hooks/pre-commit)
printf '#!/bin/sh\ngit diff --cached --name-only | grep -q wc-hook && exit 1\nexit 0\n' > "$WC_HOOK" && chmod +x "$WC_HOOK"
echo x > wc-hook.txt
WC_TIP=$(git rev-parse HEAD)
_ST_RUN --commit --text "x" -- wc-hook.txt
_ST_EQ "a pre-commit hook refusing it leaves the branch" "$RC:$(git rev-parse HEAD)" "1:$WC_TIP"
rm -f "$WC_HOOK" wc-hook.txt
# A relative hooks path the temp worktree lacks – husky's untracked `.husky/_`, say – runs from
# the checkout, where it would otherwise go unrun
mkdir -p wc-hooks/_ && printf '*\n' > wc-hooks/_/.gitignore
printf '#!/bin/sh\nexit 1\n' > wc-hooks/_/pre-commit && chmod +x wc-hooks/_/pre-commit
git config core.hooksPath wc-hooks/_
echo x > wc-hook.txt
_ST_RUN --commit --text "x" -- wc-hook.txt
_ST_EQ "a hook under a relative path only the checkout has refuses it" "$RC:$(git rev-parse HEAD)" "1:$WC_TIP"
_ST_RUN --exec -- git commit --allow-empty -qm "WC exec past the hook"
_ST_EQ "as it refuses a commit an --exec makes" "$RC:$(git rev-parse HEAD)" "1:$WC_TIP"
# The override keeps to this repository – another one an --exec command commits in runs its own
git init -q "$TMP/wc-other" && git -C "$TMP/wc-other" config user.email o@x.invalid && git -C "$TMP/wc-other" config user.name O
_ST_RUN --exec -- git -C "$TMP/wc-other" commit -q --allow-empty -m "WC other"
_ST_EQ "a commit an --exec makes in another repository runs none of this one's hooks" "$(git -C "$TMP/wc-other" log -1 --format=%s 2>/dev/null)" "WC other"
_ST_RUN --exec -- sh -c 'D=$(git rev-parse --git-dir)/modules/wc-sm && git init -q --bare "$D" && echo "wc-sm hooks:[$(git --git-dir="$D" config --get core.hooksPath)]"'
_ST_OUT_HAS "nor does a submodule's, its git dir below the temp worktree's" 'wc-sm hooks:\[\]$'
git config --unset core.hooksPath && rm -rf wc-hooks wc-hook.txt "$TMP/wc-other"
# A repository path the override's glob would read as a pattern – a `[`, a `\` – gets it all the
# same, and prints as itself in the banner and in a hint's cd
local WC_ODD=$TMP/'wc-odd[1]\e[0m'
git init -q "$WC_ODD" && cd "$WC_ODD" && git config user.email o@x.invalid && git config user.name O
mkdir -p hk/_ sub && printf '*\n' > hk/_/.gitignore && printf '#!/bin/sh\nexit 1\n' > hk/_/pre-commit && chmod +x hk/_/pre-commit
echo s > sub/s.txt && git add sub && git commit -qm "WC odd base"
git config core.hooksPath hk/_
echo t >> sub/s.txt
_ST_RUN --commit --text "x" -- sub/s.txt
_ST_EQ "a hook under a repository path holding glob characters refuses it" "$RC:$(git log -1 --format=%s)" "1:WC odd base"
_ST_OUT_HAS "while the banner shows that path as itself" 'past commits .*wc-odd\[1\]\\e\[0m$'
git config --unset core.hooksPath
export GIT_EDIT_ACTOR=wc-peer
_ST_RUN --exec -- sh -c "echo a > added.txt && git add added.txt && git commit -qm 'WC odd peer adds'"
export GIT_EDIT_ACTOR=wc-self
cd sub
_ST_RUN --commit --text "x" -- s.txt ../added.txt
_ST_OUT_HAS "as does a hint's cd" "Take what landed with: cd '.*wc-odd\\[1\\]\\\\e\\[0m' && git restore --source=HEAD"
cd "$TMP/repo"
rm -rf "$WC_ODD"
# A tracked hooks directory sourcing an untracked helper, as husky 5 to 8 lay one out, runs too
mkdir -p wc-hk2 && printf '#!/bin/sh\n. "$(dirname "$0")/_/helper.sh"\n' > wc-hk2/pre-commit && chmod +x wc-hk2/pre-commit
_ST_RUN --commit --text "WC tracked hooks dir" -- wc-hk2/pre-commit
mkdir -p wc-hk2/_ && printf '*\n' > wc-hk2/_/.gitignore && printf 'true\n' > wc-hk2/_/helper.sh
git config core.hooksPath wc-hk2
echo h > wc-hook.txt
_ST_RUN --commit --text "WC past a tracked hooks dir" -- wc-hook.txt
_ST_EQ "a tracked hooks directory's untracked helper is found" "$RC:$(git log -1 --format=%s)" "0:WC past a tracked hooks dir"
git config --unset core.hooksPath && rm -rf wc-hk2/_
git config filter.wcupper.clean 'tr a-z A-Z' && echo '*.wcup filter=wcupper' >> .git/info/attributes && echo loud > wc.wcup
_ST_RUN --commit --text "WC filtered" -- wc.wcup
_ST_EQ "a file goes through its clean filter, as git add takes it" "$RC:$(git show HEAD:wc.wcup)" "0:LOUD"
# A fold takes files whole the same way
local WC_TARGET=$(git log -1 --format=%H --grep='^WC move and link')
echo 'inner, folded' > wc-sub/moved.txt
_ST_RUN --amend-into="$WC_TARGET" --whole -- wc-sub/moved.txt
_ST_EQ "--whole folds a file whole into a past commit" "$RC:$(git show "$(git log -1 --format=%H --grep='^WC move and link')":wc-sub/moved.txt)" "0:inner, folded"
_ST_CHECK "leaving the checkout clean there" test -z "$(git status --porcelain -- wc-sub)"
echo 'inner, folded again' > wc-sub/moved.txt
WC_TARGET=$(git log -1 --format=%H --grep='^WC move and link')
cd wc-sub
_ST_RUN --amend-into="$WC_TARGET" --whole -- moved.txt
cd "$TMP/repo"
_ST_EQ "--whole takes a path as named from a subdirectory" "$RC:$(git show "$(git log -1 --format=%H --grep='^WC move and link')":wc-sub/moved.txt)" "0:inner, folded again"
