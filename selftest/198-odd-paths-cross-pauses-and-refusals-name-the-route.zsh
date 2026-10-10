# Odd paths cross a pause as themselves, and refusals over unusual paths name the route that works:
# • A fold pausing over a name with a tab re-syncs it on landing – its state lists every name
#   quoted, and one an older build joined by tabs still reads
# • One pausing over a name with a newline refuses, naming it, with nothing landed
# • The fold's summary names its paths capped and as they are, a comma inside one included
# • A `:`-leading name with no magic is that path to a fold or split, as to a commit – magic stays
# • A submodule taken whole, an auto fold of a pointer, a `GIT_DIR` naming the only repository,
#   an edit of a filtered file's smudged text and `--commit -- .` each name what works
_ST_SCENARIO "\e[1;96m[198] odd paths cross pauses, and refusals over them name the route\e[0m"
local PH_TB=$'ta\tb.txt' PH_NL=$'new\nline.txt' PH_T PH_WT PH_H PH_V PH_SF PH_CMD PH_P PH_S
local -a PH_L PH_L2

# A tab name and a plain one, folded under a later commit's change, pause twice
# Writes the three-commit fixture, its later line changed in each named file, the fold staged
PH_SETUP () {
	local F
	for F in "$@"; do printf 'l1\nl2\nl3\n' > "$F"; done
	git add -A && git commit -qm "PH base"
	PH_T=$(git rev-parse HEAD)
	for F in "$@"; do printf 'l1\nl2 later\nl3\n' > "$F"; done
	git commit -qam "PH later"
	for F in "$@"; do printf 'l1\nl2 folded\nl3\n' > "$F"; done
	git add -- "${@/#/:(literal)}"
}
# Resolves each named file in the pause's worktree to <line 2>
PH_RESOLVE () {
	# Args: <line 2> <file>...
	local L=$1 F
	shift
	PH_WT=$(_ST_PZ_WT)
	for F in "$@"; do printf 'l1\n%s\nl3\n' "$L" > "${PH_WT:-$ST_NO_WT}/$F"; done
	git -C "${PH_WT:-$ST_NO_WT}" add -A
}
_ST_PZ_NEW ph1
PH_SETUP "$PH_TB" plain.txt
_ST_RUN --amend-into="$PH_T"
# The quoted list last, so it wins – the tab-joined one ahead of it for an older copy resuming the pause
_ST_EQ "a fold over a tab name pauses, its state listing the names quoted" \
	"$RC:$(grep -c '^files_q=' .git/git-edit-state):$(grep '^files\(_q\)\{0,1\}=' .git/git-edit-state | cut -d= -f1 | tr '\n' ' ')" \
	"2:1:files files_q "
PH_RESOLVE "l2 folded" "$PH_TB" plain.txt
_ST_RUN --continue
PH_RESOLVE "l2 later" "$PH_TB" plain.txt
_ST_RUN --continue
_ST_EQ "and lands it, re-syncing the tab name as the plain one" \
	"$RC:$(git show "HEAD~1:$PH_TB" | sed -n 2p):$(git diff --cached --name-only | wc -l | tr -d ' ')" "0:l2 folded:0"
_ST_OUT_LACKS "never naming it left staged" 'Left staged'
# Scoped by pathspecs, the tab name among them, a file outside them stays staged alone
_ST_PZ_NEW ph2
PH_SETUP "$PH_TB" plain.txt
print -r -- o > o.txt && git add o.txt
_ST_RUN --amend-into="$PH_T" -- "$PH_TB" plain.txt
PH_RESOLVE "l2 folded" "$PH_TB" plain.txt
_ST_RUN --continue
PH_RESOLVE "l2 later" "$PH_TB" plain.txt
_ST_RUN --continue
_ST_EQ "a scoped fold carries a tab name in its pathspecs, the rest left staged" \
	"$RC:$(git diff --cached --name-only)" "0:o.txt"
_ST_OUT_HAS "and named as outside them" 'Left staged (outside the pathspec): o\.txt'
# A pause an older build wrote, its lists joined by tabs, still lands as it did
_ST_PZ_NEW ph3
PH_SETUP 'sp ace.txt' p2.txt
print -r -- o > o.txt && git add o.txt
_ST_RUN --amend-into="$PH_T" -- 'sp ace.txt' p2.txt
PH_SF=.git/git-edit-state
if grep -q '^files_q=' "$PH_SF"; then
	PH_V=$(sed -n 's/^files_q=//p' "$PH_SF") && PH_L=("${(@Q)${(z)PH_V}}")
	PH_V=$(sed -n 's/^pathspecs_q=//p' "$PH_SF") && PH_L2=("${(@Q)${(z)PH_V}}")
	{ grep -v -e '^files_q=' -e '^pathspecs_q=' "$PH_SF"; print -r -- "files=${(pj:\t:)PH_L}"; print -r -- "pathspecs=${(pj:\t:)PH_L2}"; } > "$PH_SF.ph" && mv "$PH_SF.ph" "$PH_SF"
fi
PH_RESOLVE "l2 folded" 'sp ace.txt' p2.txt
_ST_RUN --continue
PH_RESOLVE "l2 later" 'sp ace.txt' p2.txt
_ST_RUN --continue
_ST_EQ "a pause in the tab-joined form an older build wrote lands as before" \
	"$RC:$(git show 'HEAD~1:sp ace.txt' | sed -n 2p):$(git diff --cached --name-only)" "0:l2 folded:o.txt"
# The snapshot fold carries the same lists across its pause
if _ST_MERGE_BASE_OK; then
	_ST_PZ_NEW ph4
	PH_SETUP "$PH_TB" plain.txt
	_ST_RUN --amend-into="$PH_T" --snapshot
	PH_RESOLVE "l2 folded" "$PH_TB" plain.txt
	_ST_RUN --continue
	_ST_EQ "a snapshot fold over a tab name lands, re-syncing it" \
		"$RC:$(git show "HEAD~1:$PH_TB" | sed -n 2p):$(git diff --cached --name-only | wc -l | tr -d ' ')" "0:l2 folded:0"
fi

# A newline name refuses a pause, naming it, nothing landed – folded with no pause, it lands
_ST_PZ_NEW ph5
PH_SETUP "$PH_NL"
PH_H=$(git rev-parse HEAD)
_ST_RUN --amend-into="$PH_T"
_ST_OUT_HAS "a fold pausing over a newline name names it, nothing landed" "pause: ..new\\\\nline\\.txt. – nothing landed"
_ST_OUT_HAS "naming the rename alone" 'untouched – rename the file\.$'
_ST_OUT_LACKS "never the plain-git route, which refuses a shared checkout's unstaged edits" 'git commit --fixup'
_ST_EQ "the branch, the staging and no pause as they were" \
	"$RC:$(git rev-parse HEAD):$(git diff --cached --name-only -z | tr '\0' '|'):$([ -e .git/git-edit-state ] && echo paused)" "1:$PH_H:$PH_NL|:"
_ST_RUN --amend-into="$PH_H"
_ST_EQ "while one landing with no pause takes it" "$RC:$(git show "HEAD:$PH_NL" | sed -n 2p)" "0:l2 folded"

# The fold's summary is a report – ten names, the rest counted, each as it is
_ST_PZ_NEW ph6
for PH_P in {01..12}; do print -r -- "$PH_P" > "f$PH_P.txt"; done
print -r -- c > 'c,d.txt' && git add -A && git commit -qm "PH6 base"
PH_T=$(git rev-parse HEAD)
print -r -- later > z.txt && git add z.txt && git commit -qm "PH6 later"
for PH_P in {01..12}; do print -r -- "$PH_P x" > "f$PH_P.txt"; done
git add -A
_ST_RUN --amend-into="$PH_T"
_ST_OUT_HAS "a fold over many paths names ten, the rest counted" 'Folded f01\.txt f02\.txt f03\.txt .* f10\.txt … and 2 more – '
print -r -- c2 > 'c,d.txt' && print -r -- 01 > f01.txt && git add -A
_ST_RUN --amend-into="$(git rev-parse HEAD~1)"
_ST_OUT_HAS "and a comma inside a name stays as it is" 'Folded c,d\.txt f01\.txt – '

# A `:`-leading name is that path to a fold, a split and a commit, where git reads `:a` as `a`
_ST_PZ_NEW ph7
print -r -- a > ':colon.txt' && print -r -- b > b.txt && git add -A && git commit -qm "PH7 base"
PH_T=$(git rev-parse HEAD)
print -r -- o > o.txt && git add o.txt && git commit -qm "PH7 c2"
print -r -- more >> ':colon.txt' && print -r -- more >> b.txt && git add -A
_ST_RUN --amend-into="$PH_T" -- ':colon.txt' b.txt
_ST_EQ "--amend-into folds a :-leading name as that path" \
	"$RC:$(git show 'HEAD~1::colon.txt' | tail -1):$(git diff --cached --name-only)" "0:more:"
print -r -- again >> ':colon.txt' && print -r -- again >> b.txt && git add -A
_ST_RUN --amend-into="$(git rev-parse HEAD~1)" -- ':!b.txt'
_ST_EQ "while magic given outright stays magic" "$RC:$(git show 'HEAD~1::colon.txt' | tail -1):$(git diff --cached --name-only)" "0:again:b.txt"
_ST_RUN --amend-into="$(git rev-parse HEAD~1)" -- ':b.txt'
_ST_EQ "and one naming no path reads as git reads it" "$RC:$(git show HEAD~1:b.txt | tail -1):$(git diff --cached --name-only)" "0:again:"
print -r -- split >> ':colon.txt' && print -r -- split >> b.txt && git commit -qam "PH7 mixed"
_ST_RUN --split="$(git rev-parse HEAD)" --text "PH7 colon" -- ':colon.txt'
_ST_EQ "--split extracts a :-leading name as that path" "$RC:$(git diff-tree -r --name-only --no-commit-id HEAD~1)" "0::colon.txt"
print -r -- whole >> ':colon.txt'
_ST_RUN --commit --text "PH7 whole" -- ':colon.txt'
_ST_EQ "as --commit takes it" "$RC:$(git show 'HEAD::colon.txt' | tail -1)" "0:whole"

# A submodule taken whole refuses, naming the route that records its pointer, and that route works
_ST_PZ_NEW ph8
git init -q sub && git -C sub config user.email p@x.invalid && git -C sub config user.name P
git -C sub commit -q --allow-empty -m s1 && git -C sub commit -q --allow-empty -m s2
git update-index --add --cacheinfo 160000,"$(git -C sub rev-parse HEAD~1)",sub && git commit -qm "PH8 add sub"
PH_T=$(git rev-parse HEAD)
_ST_PZ_C o.txt o "PH8 later"
PH_H=$(git rev-parse HEAD)
_ST_RUN --amend-into="$PH_T" --whole -- sub
_ST_EQ "--whole of a submodule refuses, nothing folded" "$RC:$(git rev-parse HEAD)" "1:$PH_H"
_ST_OUT_HAS "naming the staged fold that records its pointer" "Stage its pointer and fold that: git add -- sub && git edit --amend-into=${PH_T:0:7} -- sub"
_ST_OUT_LACKS "never a commit inside it" 'commit inside it'
git add -- sub
_ST_RUN --amend-into="$PH_T" -- sub
_ST_EQ "which folds the pointer" "$RC:$(git rev-parse HEAD~1:sub)" "0:$(git -C sub rev-parse HEAD)"
# Auto can't attribute a pointer – it names that, and the explicit route
git -C sub checkout -q HEAD~1
git add -- sub
_ST_RUN --amend-into=auto
_ST_OUT_HAS "auto refuses a staged pointer, naming why" "auto can't attribute a submodule pointer (sub) – nothing was folded"
_ST_EQ "the staging kept" "$RC:$(git diff --cached --name-only)" "1:sub"
_ST_OUT_HAS "and the explicit target" '--amend-into=<sha> in place of auto'
git reset -q -- sub
PH_H=$(git rev-parse HEAD)
_ST_RUN --commit --text "PH8 bump" -- sub
_ST_EQ "--commit of one refuses, nothing committed" "$RC:$(git rev-parse HEAD)" "1:$PH_H"
_ST_OUT_HAS "naming the --exec route that records its pointer" "Commit its pointer at the tip: git edit --exec -- sh -c 'git update-index --cacheinfo 160000,$(git -C sub rev-parse HEAD),sub && git commit -m \"…\"'"
PH_CMD=$(print -r -- "$OUT" | sed -n 's/^ *Commit its pointer at the tip: git edit //p' | head -1)
eval "_ST_RUN $PH_CMD"
_ST_EQ "a route that commits the pointer at the tip" "$RC:$(git log -1 --format=%s):$(git rev-parse HEAD:sub)" "0:…:$(git -C sub rev-parse HEAD)"

# A work tree whose only repository `GIT_DIR` names is pointed at the `.git` file that works
PH_P=$TMP/ph9
mkdir -p "$PH_P/wt"
git init -q --bare "$PH_P/repo.git"
cd "$PH_P/wt"
export GIT_DIR=$PH_P/repo.git GIT_WORK_TREE=$PH_P/wt
git config user.email p@x.invalid && git config user.name P
print -r -- a > a.txt && git add a.txt && git commit -qm "PH9 base"
print -r -- b >> a.txt
_ST_RUN --commit --text "PH9 a" -- a.txt
unset GIT_DIR GIT_WORK_TREE
_ST_EQ "a GIT_DIR naming the work tree's only repository refuses" "$RC:$(git --git-dir="$PH_P/repo.git" log -1 --format=%s)" "1:PH9 base"
_ST_OUT_HAS "naming the .git file that works" 'Give the work tree a .git file pointing there'
PH_CMD=$(print -r -- "$OUT" | sed -n 's/.*then run git edit without GIT_DIR: //p' | head -1)
eval "$PH_CMD"
_ST_RUN --commit --text "PH9 a" -- a.txt
_ST_EQ "which done, it runs" "$RC:$(git log -1 --format=%s)" "0:PH9 a"
# One naming this directory's own repository is still taken
print -r -- c >> a.txt
export GIT_DIR=$PH_P/repo.git
_ST_RUN --commit --text "PH9 own" -- a.txt
unset GIT_DIR
_ST_EQ "while one naming the repository found anyway is taken" "$RC:$(git log -1 --format=%s)" "0:PH9 own"

# An edit whose old text is a filter's smudged form names the filter, and --put lands it
_ST_PZ_NEW ph10
git config filter.phk.clean "sed 's/real/@KEY@/'" && git config filter.phk.smudge "sed 's/@KEY@/real/'"
print -r -- 'k.txt filter=phk' > .gitattributes && print -r -- 'key=real' > k.txt && git add -A && git commit -qm "PH10 base"
_ST_EQ "the fixture stores the clean form" "$(git show HEAD:k.txt)" "key=@KEY@"
PH_H=$(git rev-parse HEAD)
_ST_RUN --commit --text "PH10 edit" --edits '{"k.txt": [["key=real\n", "key=real\nmore\n"]]}'
_ST_OUT_HAS "an edit of the smudged text names the filter" "no match for edit 1 – its phk filter stores the cleaned text"
_ST_OUT_HAS "and the --put that works" 'put the whole file instead, which git cleans as git add does: --put=k.txt=<file>'
_ST_EQ "nothing landed" "$RC:$(git rev-parse HEAD)" "1:$PH_H"
printf 'key=real\nmore\n' > "$TMP/ph10-k"
_ST_RUN --commit --text "PH10 put" --put="k.txt=$TMP/ph10-k"
_ST_EQ "which lands it cleaned" "$RC:$(git show HEAD:k.txt | tr '\n' '|')" "0:key=@KEY@|more|"
_ST_RUN --commit --text "PH10 clean edit" --edits '{"k.txt": [["more\n", "more2\n"]]}'
_ST_EQ "while an edit of the stored text lands" "$RC:$(git show HEAD:k.txt | tail -1)" "0:more2"
_ST_RUN --commit --text "PH10 peer" --edits '{"k.txt": [["absent\n", "x\n"]]}'
_ST_OUT_HAS "and one matching neither keeps its message" "a peer's line sits inside it"

# The top named as `.` is a directory, as any other is
_ST_RUN --commit --text "PH11" -- .
_ST_OUT_HAS "--commit -- . names a directory" '– \. is a directory – name its files'
mkdir -p d && print -r -- x > d/x.txt && git add d/x.txt && git commit -qm "PH11 d"
cd d
_ST_RUN --commit --text "PH11" -- ..
_ST_OUT_HAS "as does .. from a subdirectory" '– \.\. is a directory – name its files'
_ST_RUN --commit --text "PH11" -- ../..
_ST_OUT_HAS "while a path above the top names no file inside" 'names no file inside the repository'
cd "$TMP/repo"
