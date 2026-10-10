_ST_SCENARIO "\e[1;96m[127] a caller's environment changes nothing the tool reads\e[0m"
local CE_N CE_T CE_TIP CE_WT
# GIT_DIFF_OPTS widens git's diffs past the -U0 a line-level guard reads – an edit beside another
# caller's landing then looked like one on its lines, which hid the landing it lacked
_ST_PZ_NEW ce1
print -l {1..20} > f.txt && git add f.txt && git commit -qm "CE base"
print -l {1..9} 10p {11..20} > f.txt
OUT=$(GIT_EDIT_ACTOR=ce-peer GIT_EDIT_NO_AUTO_OPEN=1 "$SELF" --commit --text "CE peer" -- f.txt </dev/null 2>&1)
print -l {1..10} 11m {12..20} > f.txt
OUT=$(GIT_DIFF_OPTS=--unified=3 GIT_EDIT_ACTOR=ce-self GIT_EDIT_NO_AUTO_OPEN=1 "$SELF" --commit --text "CE self" -- f.txt </dev/null 2>&1)
RC=$?
_ST_EQ "GIT_DIFF_OPTS leaves the landing guard reading -U0" "$RC:$(git log -1 --format=%s)" "1:CE peer"
_ST_OUT_HAS "naming the landing it would take back" "f.txt – ce-peer's"
git checkout -q -- f.txt
# As it leaves the auto-target's blame on the staged lines alone – a pure insertion folds into the
# newest commit touching the file, never into the one owning the lines around it
_ST_PZ_C g.txt g "CE other"
print -l new {1..9} 10p {11..20} > f.txt && git add f.txt
GIT_DIFF_OPTS=--unified=3 _ST_RUN --amend-into=auto -- f.txt
_ST_OUT_HAS "GIT_DIFF_OPTS leaves an insertion's auto-target as the newest commit on the file" 'Amending staged changes into [0-9a-f]* (CE peer)'
# `i18n.logOutputEncoding` re-encodes what a rebuild reads of a message and an author
_ST_PZ_NEW ce2
_ST_PZ_C a.txt a "CE2 base"
_ST_PZ_C b.txt b "CE2 Привет"
_ST_PZ_C c.txt c "CE2 tip"
git config i18n.logOutputEncoding KOI8-R
_ST_RUN -M --text "CE2 base reworded" HEAD~2
git config --unset i18n.logOutputEncoding
_ST_EQ "a rebuild under i18n.logOutputEncoding keeps a UTF-8 subject" "$RC:$(git log -1 --format=%s HEAD~1)" "0:CE2 Привет"
# A squash's -m template comments in the configured character, which is what gets stripped
git config core.commentChar ';'
_ST_TTY GIT_EDITOR=: -- -S -m -y HEAD~1 HEAD
git config --unset core.commentChar
_ST_EQ "a -S -m left as opened keeps no line of its template" "$RC:$(git log -1 --format=%B | grep -c 'Combined message')" "0:0"
# `GREP_OPTIONS` colors every grep the tool reads on BSD
GREP_OPTIONS=--color=always _ST_RUN -M --text "CE2 under GREP_OPTIONS" HEAD
_ST_EQ "GREP_OPTIONS changes nothing" "$RC:$(git log -1 --format=%s)" "0:CE2 under GREP_OPTIONS"
# A path the upstream renamed takes a replant past edits on it, which its guard reads by both names
# where no sync can bring them along – the checkout halfway through a sequence
_ST_PZ_NEW ce3
print -l {1..8} > r.txt && git add r.txt && git commit -qm "CE3 base"
git checkout -q -b ce3-up && git mv r.txt s.txt && git commit -qm "CE3 up renames" && git checkout -q main
_ST_PZ_C t.txt t "CE3 own"
print -l {1..9} > r.txt
CE_TIP=$(git rev-parse HEAD)
_ST_RUN_UNSYNCED --onto=ce3-up
_ST_EQ "a replant past edits on a path the upstream renamed refuses there" "$RC:$(git rev-parse HEAD)" "1:$CE_TIP"
_ST_OUT_HAS "naming it" 'r.txt'
git checkout -q -- r.txt
# A staged submodule bump is a staged change whatever diff.ignoreSubmodules hides
_ST_PZ_NEW ce4
_ST_PZ_C a.txt a "CE4 base"
git update-index --add --cacheinfo "160000,$(git rev-parse HEAD),sub" && git commit -qm "CE4 sub"
_ST_PZ_C b.txt b "CE4 tip"
CE_T=$(git rev-parse HEAD~1)
git update-index --cacheinfo "160000,$CE_T,sub"
git config diff.ignoreSubmodules all
_ST_RUN --amend-into="$CE_T" -- sub
_ST_EQ "a staged submodule bump folds under diff.ignoreSubmodules=all" "$RC:$(git rev-parse HEAD~1:sub)" "0:$CE_T"
git config --unset diff.ignoreSubmodules
# A name holding a quote is read from git's NUL-separated form – the line form quotes it
_ST_PZ_NEW ce5
for CE_N in {1..12}; do echo "q line $CE_N"; done > 'q"old.txt'
git add 'q"old.txt' && git commit -qm "CE5 add"
CE_T=$(git rev-parse HEAD)
git mv 'q"old.txt' 'q"new.txt' && git commit -qm "CE5 rename"
sed 's/^q line 3$/q line 3 fixed/' 'q"new.txt' > q.tmp && mv q.tmp 'q"new.txt' && git add 'q"new.txt'
_ST_RUN --amend-into="$CE_T" -- 'q"new.txt'
_ST_EQ "a fold follows a rename of a name holding a quote, into its old path" "$RC:$(git show 'HEAD~1:q"old.txt' | sed -n 3p)" "0:q line 3 fixed"
# A name a printed step pastes back holds its `!` single-quoted, which an interactive shell would
# expand – a conflict's merge here
_ST_PZ_NEW ce6
_ST_PZ_C a.txt a "CE6 base"
print -r -- x > 'x!y.txt' && git add 'x!y.txt' && git commit -qm "CE6 adds"
print -r -- y > 'x!y.txt' && git commit -qam "CE6 changes"
_ST_PZ_C c.txt c "CE6 tip"
print -r -- mine > 'x!y.txt'
_ST_RUN -d -y HEAD~1
_ST_OUT_HAS "a printed step's name holding ! comes single-quoted" "git merge-file -- 'x!y.txt'"
# A command echoed keeps its own spacing – a path with two spaces names that path
_ST_RUN -d -y -C="$TMP/ce two  spaces" HEAD
_ST_OUT_HAS "a printed command keeps a path's double space" "ce two  spaces"
git worktree remove --force "$TMP/ce two  spaces" 2>/dev/null
cd "$TMP/repo"
