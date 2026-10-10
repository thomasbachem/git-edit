# What a run prints or does holds only what it knows, each neighbor going on:
# • A work tree only `GIT_DIR` reaches is told a concrete `.git` path only where `GIT_WORK_TREE`
#   names its top – skip-worktree entries or a subdirectory mirroring the tracked names prove none
# • A tag or branch on a commit the rebase dropped as emptied is named as dropped, no subject guess –
#   a twin left standing keeps its counterpart, twins alike in authorship and subject the guess
# • A relative `TMPDIR`, or one opening with `-`, works as an absolute one, leaving nothing in it
# • A `--put` from a subdirectory of a path new to the tip whose name from the top is tracked
#   refuses, naming both readings – the absolute spelling and a really new file still land
# • `--amend-into` with inputs and paths but no `--whole` refuses without the usage text
_ST_SCENARIO "\e[1;96m[213] dotfile tops, emptied refs, relative TMPDIRs and put readings name what is meant\e[0m"
local SE_P SE_C SE_D SE_Y SE_N SE_H

# A `GIT_DIR` work tree whose entries are all skip-worktree, run from a subdirectory – nothing the
# index lists there reads as deleted, yet the top is unknown
SE_P=$TMP/se1
mkdir -p "$SE_P/wt/sub"
git init -q --bare "$SE_P/repo.git" && git --git-dir="$SE_P/repo.git" config core.bare false
cd "$SE_P/wt"
export GIT_DIR=$SE_P/repo.git
git config user.email p@x.invalid && git config user.name P
print -r -- a > a.txt && print -r -- s > sub/s.txt && git --work-tree=. add a.txt sub/s.txt && git --work-tree=. commit -qm "SE1 base"
git --work-tree=. update-index --skip-worktree a.txt sub/s.txt
cd sub
_ST_RUN -M --text "SE1 x" HEAD
unset GIT_DIR
_ST_EQ "skip-worktree entries from a subdirectory refuse" "$RC:$(git --git-dir="$SE_P/repo.git" log -1 --format=%s)" "1:SE1 base"
_ST_OUT_HAS "naming the .git file at its top, no path given" "> '<top of the work tree>/\.git'"
_ST_OUT_LACKS "never one in this subdirectory" "$SE_P/wt/sub/\.git"
# A subdirectory holding a file under every tracked name
SE_P=$TMP/se1b
mkdir -p "$SE_P/wt/sub"
git init -q --bare "$SE_P/repo.git" && git --git-dir="$SE_P/repo.git" config core.bare false
cd "$SE_P/wt"
export GIT_DIR=$SE_P/repo.git
git config user.email p@x.invalid && git config user.name P
print -r -- a > a.txt && print -r -- s > sub/s.txt && git --work-tree=. add a.txt sub/s.txt && git --work-tree=. commit -qm "SE1B base"
cd sub
mkdir -p sub && print -r -- other > a.txt && print -r -- other > sub/s.txt
_ST_RUN -M --text "SE1B x" HEAD
unset GIT_DIR
_ST_OUT_HAS "a subdirectory mirroring the tracked names gets no path either" "> '<top of the work tree>/\.git'"
_ST_OUT_LACKS "never that subdirectory" "$SE_P/wt/sub/\.git"
# `GIT_WORK_TREE` naming the top is taken, from a subdirectory too
export GIT_DIR=$SE_P/repo.git GIT_WORK_TREE=$SE_P/wt
_ST_RUN -M --text "SE1B x" HEAD
unset GIT_DIR GIT_WORK_TREE
_ST_EQ "while GIT_WORK_TREE's work tree refuses too" "$RC" "1"
_ST_OUT_HAS "naming its top by path" "> '*$(cd "$SE_P/wt" && pwd -P)/\.git'*\$"

# A drop empties a later commit sharing its subject with an earlier one – a ref on the emptied one is
# named as dropped, one on the earlier twin re-pointed to its counterpart
_ST_PZ_NEW se2
_ST_PZ_C a.txt a "SE2 base" && _ST_PZ_C x.txt x "SE2 add x" && _ST_PZ_C y.txt y "fix typo"
git rm -q x.txt && git commit -qm "fix typo"
_ST_PZ_C z.txt z "SE2 z"
git tag vC HEAD~1 && git branch side HEAD~1 && git tag vY HEAD~2
SE_C=$(git rev-parse HEAD~1) SE_D=$(git rev-parse HEAD~3)
_ST_RUN -d -y "$SE_D"
_ST_EQ "the drop lands, its emptied commit gone" "$RC:$(git log --format=%s | tr '\n' '|')" "0:SE2 z|fix typo|SE2 base|"
SE_Y=$(git rev-parse HEAD~1)
_ST_OUT_HAS "a tag on the emptied commit is named as dropped" "^Tag vC points at a commit this run dropped, with no counterpart in the new span"
_ST_OUT_LACKS "with no command re-pointing it" "git tag -f vC"
_ST_OUT_HAS "a branch on it alike" "^Branch side points at a commit this run dropped"
_ST_OUT_LACKS "never a guess at it" "git branch -f side"
_ST_OUT_HAS "the emptied one listed by its own SHA" "emptied: ${SE_C:0:7} fix typo"
_ST_OUT_HAS "while the twin left standing is re-pointed to its counterpart" "git tag -f vY ${SE_Y:0:12}"
# Twins alike in authorship and subject, one emptied – which went is no fact, so the guess stays
_ST_PZ_NEW se2b
_ST_PZ_C a.txt a "SE2B base" && _ST_PZ_C x.txt x "SE2B add x"
print -r -- y > y.txt && git add y.txt && GIT_AUTHOR_DATE="@1300000000 +0000" git commit -qm "fix twin"
git rm -q x.txt && GIT_AUTHOR_DATE="@1300000000 +0000" git commit -qm "fix twin"
_ST_PZ_C z.txt z "SE2B z"
git tag vT HEAD~1
_ST_RUN -d -y HEAD~3
_ST_EQ "twins' drop lands" "$RC:$(git log --format=%s | tr '\n' '|')" "0:SE2B z|fix twin|SE2B base|"
_ST_OUT_LACKS "a tag on either twin is never named as dropped" "^Tag vT points at a commit this run dropped"
_ST_OUT_HAS "but offered the hedged guess" "^Tag vT points into the rewritten span"

# A relative `TMPDIR`, and one opening with `-`, take a rebase-route mode as an absolute one does
_ST_PZ_NEW se3
print -r -- /reltmp/ > .git/info/exclude && print -r -- /-dash/ >> .git/info/exclude
mkdir -p -- reltmp -dash
printf 'l1\nl2\nl3\n' > f && git add f && git commit -qm "SE3 c1"
printf 'A\nl2\nl3\n' > f && git commit -qam "SE3 c2"
printf 'B\nl2\nl3\n' > f && git commit -qam "SE3 c3"
_ST_PZ_C g g "SE3 c4"
TMPDIR=reltmp _ST_RUN --move=HEAD --before=HEAD~1
_ST_EQ "a relative TMPDIR moves a commit" "$RC:$(git log --format=%s | tr '\n' '|')" "0:SE3 c3|SE3 c4|SE3 c2|SE3 c1|"
_ST_EQ "leaving nothing in it" "$(command ls -A reltmp)" ""
TMPDIR=-dash _ST_RUN --move=HEAD --before=HEAD~1
_ST_EQ "one opening with - too" "$RC:$(git log --format=%s | tr '\n' '|')" "0:SE3 c4|SE3 c3|SE3 c2|SE3 c1|"
_ST_EQ "leaving nothing in it either" "$(command ls -A -- -dash)" ""
_ST_RUN --move=HEAD --before=HEAD~1
_ST_EQ "while the absolute one goes on" "$RC:$(git log --format=%s | head -1)" "0:SE3 c3"

# `--put` from a subdirectory of a name the top tracks, new where read from here
_ST_PZ_NEW se4
mkdir sub && printf 'l1\nl2\n' > sub/f1 && printf 'l1\nl2\n' > sub/f2 && git add sub && git commit -qm "SE4 base"
print -r -- /p.tmp > .git/info/exclude && printf 'P\nl2\n' > p.tmp
SE_H=$(git rev-parse HEAD)
cd sub
_ST_RUN --amend-into=HEAD --put sub/f2=../p.tmp
_ST_EQ "a put of a top spelling from a subdirectory refuses" "$RC:$(git rev-parse HEAD)" "1:$SE_H"
_ST_OUT_HAS "naming both readings" "--put sub/f2: new to the tip – paths are read from where you stand, sub/, so it names sub/sub/f2, while sub/f2, its reading from the top, is tracked"
_ST_OUT_HAS "and the spelling meaning each" "Nothing landed – put f2=<file> for sub/f2, or $(cd .. && pwd -P)/sub/sub/f2=<file> to add sub/sub/f2"
_ST_RUN --amend-into=HEAD --put f2=../p.tmp
_ST_EQ "the spelling from here replaces the file" "$RC:$(git show HEAD:sub/f2 | head -1):$(git ls-tree -r --full-tree --name-only HEAD | tr '\n' ' ')" "0:P:sub/f1 sub/f2 "
_ST_RUN --amend-into=HEAD --put "$(cd .. && pwd -P)/sub/sub/f2=../p.tmp"
_ST_EQ "the absolute spelling adds the new file" "$RC:$(git ls-tree -r --full-tree --name-only HEAD | tr '\n' ' ')" "0:sub/f1 sub/f2 sub/sub/f2 "
_ST_RUN --commit --text "SE4 new" --put new=../p.tmp
_ST_EQ "and a name new from both readings is added" "$RC:$(git ls-tree -r --full-tree --name-only HEAD | tr '\n' ' ')" "0:sub/f1 sub/f2 sub/new sub/sub/f2 "
cd ..

# Inputs beside paths without `--whole` – one refusal naming the form, never the usage text
_ST_PZ_NEW se5
_ST_PZ_C a.txt $'1\n2' "SE5 a" && _ST_PZ_C w.txt w "SE5 w"
SE_H=$(git rev-parse HEAD)
print -r -- "w, mine" > w.txt
_ST_RUN --amend-into=HEAD --edits '{"a.txt": [["2\n", "TWO\n"]]}' -- w.txt
_ST_EQ "paths beside the inputs without --whole refuse" "$RC:$(git rev-parse HEAD)" "1:$SE_H"
_ST_OUT_LACKS "without the usage text" "^usage: git edit"
_ST_OUT_HAS "naming the --whole form as the next step" "Nothing landed – drop the paths to fold the inputs alone, or add --whole"
_ST_RUN --amend-into=HEAD --whole --edits '{"a.txt": [["2\n", "TWO\n"]]}' -- w.txt
_ST_EQ "which given, it folds" "$RC:$(git show HEAD:a.txt | tail -1):$(git show HEAD:w.txt)" "0:TWO:w, mine"
