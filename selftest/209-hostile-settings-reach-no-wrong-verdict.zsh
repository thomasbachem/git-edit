# What a repo's settings or the environment hold reaches no wrong verdict and runs nothing:
# • A guard reads bytes, never a textconv driver's view – a peer's staging that view hides survives
#   a raw undo's printed re-sync and a killed move's locked-index step, and a fold through such a
#   file folds, its paths named, whole or everything staged
# • A `TMPDIR` holding a space, or `$(…)`, runs a move, a fold and a `--continue` as any other
# • A quote in the repo's commit encoding stays inside its one config entry
# • An `edit.worktreeLink` path below a symlink the commit tracks is named for that
# • `color.ui=always` leaves a land's catch-up copies and a replay's pairing as they read without
_ST_SCENARIO "\e[1;96m[209] hostile settings and paths reach no wrong verdict\e[0m"
local H9_U H9_S H9_P H9_B H9_T H9_O H9_WT
local -i H9_I H9_K
printf '#!/bin/sh\ngrep -v "^#style" "$1"\n' > "$TMP/h209-tc" && chmod +x "$TMP/h209-tc"
# Makes and enters repo <name>, its `.doc` files diffed through a textconv hiding `#style` lines
_P209_REPO () {
	# Args: <name>
	_ST_PZ_NEW "$1" && git config diff.doc.textconv "$TMP/h209-tc" && print -r -- '*.doc diff=doc' > .gitattributes
}
# Lands branch `feat`, rewording `r.doc`, onto a moved `main` – `H9_U` the raw undo, `H9_S` the
# re-sync step `--status` names beside it
_P209_LANDED () {
	# Args: <repo name>
	_P209_REPO "$1"
	printf '#style plain\nHello\n' > r.doc && git add -A && git commit -qm "H9 base"
	git checkout -q -b feat && printf '#style plain\nHello world\n' > r.doc && git commit -qam "H9 reword"
	git checkout -q main && _ST_PZ_C o.txt o "H9 other"
	_ST_RUN --land=feat
	_ST_RUN --status
	H9_U=$(print -r -- "$OUT" | sed -n 's/^Undo: git edit --undo  (or, the ref alone: \(.*\))$/\1/p')
	H9_S=$(print -r -- "$OUT" | sed -n 's/^After the raw undo, re-sync the entries.*listing those: //p')
	H9_S=${H9_S%%$'\e'*}
}

# The raw undo's step re-syncs an entry still as the land staged it, and keeps one a peer staged
# since whose difference only the textconv view hides – porcelain's exit code reads that view
_P209_LANDED h209a
_ST_EQ "a land's raw-undo step guards by plumbing" "${H9_S%% -- *}" \
	"git diff-index --cached --exit-code --name-only $(git rev-parse --short=12 HEAD)"
eval "${H9_U:-false}" && eval "${H9_S:-false}" >/dev/null
_ST_EQ "it re-syncs an entry as the land staged it" "$?:$(git rev-parse :r.doc)" "0:$(git rev-parse HEAD:r.doc)"
_P209_LANDED h209b
printf '#style bold\nHello world\n' > r.doc && git add r.doc && H9_P=$(git rev-parse :r.doc)
eval "${H9_U:-false}" && eval "${H9_S:-false}" >/dev/null
_ST_EQ "and keeps a peer's staging only a textconv view hides" "$(git rev-parse :r.doc)" "$H9_P"

# A move SIGKILLed once journaled, its re-sync left to the next run – there the index is locked,
# and the step printed for later keeps a peer's staging that view hides, re-syncing one as before
_P209_REPO h209c
printf '#style plain\nHello\n' > r.doc && git add -A && git commit -qm "H9C base"
H9_B=$(git rev-parse HEAD)
printf '#style plain\nHello world\n' > r.doc
mkdir -p "$TMP/h209-bin"
{
	print -r -- '#!/bin/sh'
	print -r -- "if [ -e ${(q)TMP}/h209-arm ] && [ -s ${(q)PWD}/.git/git-edit-journal ]; then"
	print -r -- "	rm -f ${(q)TMP}/h209-arm; : > ${(q)TMP}/h209-in; ${(q)TMP}/st-hold ${(q)TMP}/h209-go"
	print -r -- "	${(q)commands[git]} \"\$@\"; rc=\$?; : > ${(q)TMP}/h209-out; exit \$rc"
	print -r -- 'fi'
	print -r -- "exec ${(q)commands[git]} \"\$@\""
} > "$TMP/h209-bin/git"
chmod +x "$TMP/h209-bin/git"
: > "$TMP/h209-arm"
PATH="$TMP/h209-bin:$PATH" GIT_EDIT_NO_AUTO_OPEN=1 "$SELF" --commit --text "H9C world" -- r.doc </dev/null >/dev/null 2>&1 &
H9_K=$!
H9_I=0; until [ -e "$TMP/h209-in" ] || ! kill -0 $H9_K 2>/dev/null || (( ++H9_I > 1200 )); do sleep 0.1; done
kill -9 $H9_K
wait $H9_K
: > "$TMP/h209-go"
H9_I=0; until [ -e "$TMP/h209-out" ] || (( ++H9_I > 1200 )); do sleep 0.1; done
: > .git/index.lock
_ST_RUN --status
rm -f .git/index.lock
H9_S=$(print -r -- "$OUT" | sed -n 's/^.*once it is free, re-sync each still so: //p')
H9_S=${H9_S%%$'\e'*}
_ST_EQ "a killed move's locked-index step guards by plumbing" "${H9_S%% -- *}" \
	"git diff-index --cached --exit-code --name-only ${H9_B:0:12}"
printf '#style bold\nHello\n' > r.doc && git add r.doc && H9_P=$(git rev-parse :r.doc)
eval "${H9_S:-false}" >/dev/null
_ST_EQ "it keeps a peer's staging only a textconv view hides" "$(git rev-parse :r.doc)" "$H9_P"
git update-index --cacheinfo "100644,$(git rev-parse "${H9_B}:r.doc"),r.doc"
eval "${H9_S:-false}" >/dev/null
_ST_EQ "and re-syncs one still as before the move" "$?:$(git rev-parse :r.doc)" "0:$(git rev-parse HEAD:r.doc)"

# A fold of a change only a textconv view hides folds – its paths named, whole, or all staged
_P209_REPO h209d
printf '#style plain\nHello\n' > r.doc && git add -A && git commit -qm "H9D base"
_ST_PZ_C o.txt o "H9D other"
for H9_O in "-- r.doc" "--whole -- r.doc" ""; do
	printf '#style %s\nHello\n' "${H9_O:-all}" > r.doc && git add r.doc && H9_P=$(git rev-parse :r.doc)
	_ST_RUN --amend-into=HEAD~1 ${=H9_O}
	_ST_EQ "a fold through a textconv view (${H9_O:-all staged}) folds" "$RC:$(git rev-parse HEAD~1:r.doc)" "0:$H9_P"
done
_ST_RUN --amend-into=HEAD~1 -- r.doc
_ST_EQ "while one with nothing staged still refuses" "$RC:$(git log -1 --format=%s)" "1:H9D other"
_ST_OUT_HAS "as nothing to fold" 'No staged changes under'

# A `TMPDIR` holding a space or a command substitution – git runs an editor value holding either
# through `sh` – moves, folds and resumes, running nothing it holds
for H9_T in "$TMP/h209 tmp/" "$TMP/h209x\$(touch\${IFS}$TMP/h209-pwned)/"; do
	mkdir -p "$H9_T"
	_ST_PZ_NEW h209e
	for H9_O in f g h; do _ST_PZ_C $H9_O $H9_O "H9E $H9_O"; done
	_ST_PZ_C c 1 "H9E c1" && _ST_PZ_C c 2 "H9E c2" && _ST_PZ_C c 3 "H9E c3"
	TMPDIR=$H9_T _ST_RUN --move=HEAD~3 --before=HEAD~4
	_ST_EQ "a move under TMPDIR ${${H9_T%/}:t} lands" "$RC:$(git log --format=%s | tr '\n' '|')" "0:H9E c3|H9E c2|H9E c1|H9E g|H9E h|H9E f|"
	print -r -- f2 > f && git add f
	TMPDIR=$H9_T _ST_RUN --amend-into="$(git rev-parse ':/H9E f')" -- f
	_ST_EQ "a fold under it lands" "$RC:$(git show "$(git rev-parse ':/H9E f'):f")" "0:f2"
	TMPDIR=$H9_T _ST_RUN -d -y "$(git rev-parse ':/H9E c2')"
	H9_WT=$(_ST_PZ_WT)
	_ST_RESOLVE "${H9_WT:-$ST_NO_WT}" c 3
	TMPDIR=$H9_T _ST_RUN --continue
	_ST_EQ "a --continue under it lands" "$RC:$(git log --format=%s | tr '\n' '|'):$(git show HEAD:c)" "0:H9E c3|H9E c1|H9E g|H9E h|H9E f|:3"
done
_ST_EQ "and nothing a TMPDIR holds ran" "$([ -e "$TMP/h209-pwned" ] && echo ran)" ""

# A quote in the repo's commit encoding stays inside its config entry, never adding one beside it
_ST_PZ_NEW h209f
_ST_PZ_C f 1 "H9F one" && _ST_PZ_C f 2 "H9F two"
_ST_RUN --exec -- sh -c 'git config --get i18n.logOutputEncoding >&2'
_ST_OUT_HAS "the log encoding pinned to UTF-8 without one" '^UTF-8$'
git config i18n.commitEncoding "UTF-8' 'safe.directory=*"
_ST_RUN --exec -- sh -c 'git config --get i18n.logOutputEncoding >&2; git config --show-scope --get-all safe.directory >&2'
_ST_OUT_HAS "a quote in the commit encoding stays in its value" "^UTF-8' 'safe.directory=\\*\$"
_ST_OUT_LACKS "adding no entry beside it" $'^command\t'

# A link value below a symlink the commit tracks is named for that, nothing written through it,
# while one a directory pattern misses keeps its own remedy
_ST_PZ_NEW h209g
mkdir -p "$TMP/h209-outside"
printf 'cache/\nvendor/\n' > .gitignore && git add .gitignore && git commit -qm "H9G ignore"
ln -s "$TMP/h209-outside" cache && git add -f cache && git commit -qm "H9G cache as a link"
_ST_PZ_C a x "H9G a"
git rm -q --cached cache && command mv cache cache.lnk && mkdir -p cache vendor && print -r -- data > cache/data
git commit -qm "H9G cache untracked"
git config --add edit.worktreeLink cache/data && git config --add edit.worktreeLink vendor
_ST_RUN HEAD~2
_ST_OUT_HAS "a link below a tracked symlink is named for it" 'Not linking cache/data – this commit tracks cache as a symlink'
_ST_OUT_HAS "a directory pattern's miss keeps its remedy" 'Drop the trailing slash'
_ST_OUT_LACKS "never the one below the link" 'cache/data.*its ignore pattern'
_ST_EQ "nothing written through the link" "$(command ls -A "$TMP/h209-outside")" ""
_ST_RUN --abort

# A land's catch-up copies, read by patch where author and message leave them open, read alike
# under `color.ui=always` – main's copy of the branch's own change, under another date and
# subject, leaves a commit made at the catch-up's stop under that subject the branch's own –
# and no `git log -p` feeding `patch-id` is colored, nor a guard's porcelain exit code read
# through a textconv or an external diff
_ST_PZ_NEW h209l
print -l l1 l2 l3 > f.txt && git add f.txt && git commit -qm "H9L base"
git worktree add -q -b feat "$TMP/h209l-wt" main 2>/dev/null
print -r -- x > "$TMP/h209l-wt/x.txt" && git -C "$TMP/h209l-wt" add x.txt && git -C "$TMP/h209l-wt" commit -qm "H9L F own"
print -l la l2 l3 > "$TMP/h209l-wt/f.txt" && git -C "$TMP/h209l-wt" commit -qam "H9L A own"
print -r -- x > x.txt && git add x.txt && GIT_AUTHOR_DATE="@1900000000 +0000" git commit -qm "H9L M1"
print -l lm l2 l3 > f.txt && git commit -qam "H9L T"
cd "$TMP/h209l-wt"
_ST_RUN --land=main
H9_WT=$(_ST_PZ_WT)
_ST_RESOLVE "${H9_WT:-$ST_NO_WT}" f.txt $'la-lm\nl2\nl3'
GIT_AUTHOR_DATE="@1950000000 +0000" git -C "${H9_WT:-$ST_NO_WT}" commit -qm "H9L M1" >/dev/null 2>&1
_ST_RUN --continue
cd "$TMP/pz-h209l"
_ST_RUN --land=feat --dry-run
H9_O=$(print -r -- "$OUT" | grep -E '^(  [0-9a-f]+ |[0-9]+ commit|main gained)')
git config color.ui always
_ST_RUN --land=feat --dry-run
git config --unset color.ui
_ST_EQ "a land under color.ui=always reads its copies as without" "$(print -r -- "$OUT" | grep -E '^(  [0-9a-f]+ |[0-9]+ commit|main gained)')" "$H9_O"
_ST_OUT_HAS "replaying the commit made at the stop as the branch's own" '^  [0-9a-f]* H9L M1$'
_ST_OUT_LACKS "never as main's" "main's own by a land's record"
git worktree remove --force "$TMP/h209l-wt"
cd "$TMP/repo"
_ST_EQ "no log patch feeding patch-id is colored" "$(grep -E 'log [^|]*-p [^|]*\| *git( -C "\$1")? patch-id' "$SELF" | grep -vc -e '--no-color')" "0"
_ST_EQ "no guard reads porcelain's exit code through a textconv" "$(grep -E 'git diff [^|;]*--(quiet|exit-code)' "$SELF" | grep -vc -e '--no-textconv')" "0"
